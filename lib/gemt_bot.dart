import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:teledart/model.dart';
import 'package:teledart/teledart.dart';
import 'package:teledart/telegram.dart';

import 'env.dart';

class BotConfig {
  static const geminiApiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=';

  static const maxMessageLength = 3000;
  static const markdownV2SpecialChars = r'_*[]()~`>#+-=|{}.!';

  static const welcomeMessages = {
    'en': 'Hello! I am a Gemini-powered bot. How can I help you?',
    'ru': 'Привет! Я бот с искусственным интеллектом Gemini. Чем могу помочь?',
    'es': '¡Hola! Soy un bot con tecnología Gemini. ¿Cómo puedo ayudarte?',
    'fr': 'Bonjour! Je suis un bot alimenté par Gemini. Comment puis-je aider?',
    'de': 'Hallo! Ich bin ein mit Gemini betriebener Bot. Wie kann ich helfen?',
    'zh': '你好！我是由Gemini驱动的机器人。需要什么帮助？',
  };
}

class GeminiService {
  static Future<String> getResponse(String query) async {
    try {
      final response = await _makeApiRequest(query);
      return _parseApiResponse(response);
    } catch (e, stackTrace) {
      log('Gemini API request failed', error: e, stackTrace: stackTrace);
      return 'Sorry, I encountered an error. Please try again later.';
    }
  }

  static Future<http.Response> _makeApiRequest(String query) async {
    final uri = Uri.parse('${BotConfig.geminiApiUrl}${Env.geminiApiKey}');
    final requestBody = _buildRequestBody(query);

    return await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );
  }

  static String _buildRequestBody(String query) {
    return jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": query},
          ],
        },
      ],
    });
  }

  static String _parseApiResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception('API returned status ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json["candidates"]?[0]["content"]["parts"]?[0]["text"] ??
        'No response from AI';
  }
}

class MessageHandler {
  static String escapeMarkdownV2(String text) {
    return text
        .replaceAllMapped(RegExp(r'(```[\s\S]*?```|`[^`]*`)'), (match) {
          return match.group(0)!;
        })
        .replaceAllMapped(
          RegExp('([${BotConfig.markdownV2SpecialChars}])'),
          (match) => '\\${match.group(1)}',
        );
  }

  static List<String> splitMessage(String text) {
    final codeBlockRegex = RegExp(r'```[\s\S]*?```');
    final chunks = <String>[];
    var lastPos = 0;

    for (final match in codeBlockRegex.allMatches(text)) {
      _addTextChunk(text.substring(lastPos, match.start), chunks);
      chunks.add(match.group(0)!);
      lastPos = match.end;
    }

    _addTextChunk(text.substring(lastPos), chunks);

    return chunks.where((chunk) => chunk.trim().isNotEmpty).toList();
  }

  static void _addTextChunk(String text, List<String> chunks) {
    for (var i = 0; i < text.length; i += BotConfig.maxMessageLength) {
      final end = (i + BotConfig.maxMessageLength).clamp(0, text.length);
      final chunk = text.substring(i, end).trim();
      if (chunk.isNotEmpty) chunks.add(chunk);
    }
  }

  static Future<void> sendMessage(TeleDartMessage message, String text) async {
    try {
      await message.reply(escapeMarkdownV2(text), parseMode: 'MarkdownV2');
    } catch (e) {
      log('Markdown send failed, falling back to plain text', error: e);
      try {
        await message.reply(_stripAllMarkdown(text), parseMode: null);
      } catch (e) {
        log('Critical error - failed to send fallback message', error: e);
      }
    }
  }

  static String _stripAllMarkdown(String text) {
    return text
        .replaceAllMapped(RegExp(r'\\?([_*\[\]()~`>#+-=|{}.!])'), (m) => m[1]!)
        .replaceAll('```', '')
        .replaceAll('`', '');
  }
}

class GeminiBot {
  final TeleDart _bot;

  GeminiBot(String token, String username)
    : _bot = TeleDart(token, Event(username));

  void start() {
    _configureHandlers();
    _bot.start();
  }

  void _configureHandlers() {
    _bot
      ..onCommand('start').listen(_handleStartCommand)
      ..onMessage().listen(_handleRegularMessage);
  }

  void _handleStartCommand(TeleDartMessage message) {
    final userLanguage = message.from?.languageCode ?? 'en';
    final welcomeText =
        BotConfig.welcomeMessages[userLanguage] ??
        BotConfig.welcomeMessages['en']!;

    MessageHandler.sendMessage(message, welcomeText);
  }

  Future<void> _handleRegularMessage(TeleDartMessage message) async {
    if (message.text?.trim().isEmpty ?? true) return;

    try {
      final aiResponse = await GeminiService.getResponse(message.text!);
      await _sendResponseInChunks(message, aiResponse);
    } catch (e, stackTrace) {
      log('Error processing message', error: e, stackTrace: stackTrace);
      await MessageHandler.sendMessage(
        message,
        'Error processing your request',
      );
    }
  }

  Future<void> _sendResponseInChunks(
    TeleDartMessage originalMessage,
    String responseText,
  ) async {
    final chunks = MessageHandler.splitMessage(responseText);

    for (final chunk in chunks) {
      await MessageHandler.sendMessage(originalMessage, chunk);
    }
  }
}

void main() async {
  try {
    log('Initializing bot...');
    Env.load();

    final telegram = Telegram(Env.botToken);
    final user = await telegram.getMe();

    final bot = GeminiBot(Env.botToken, user.username ?? user.firstName);
    bot.start();

    log('Bot started as @${user.username}');

    // Keep the process alive
    await Future.delayed(Duration(days: 365));
  } catch (e, stackTrace) {
    log('Fatal error', error: e, stackTrace: stackTrace);
  }
}
