import 'package:dotenv/dotenv.dart';

abstract class Env {
  static late DotEnv env;

  static void load() => env = DotEnv(includePlatformEnvironment: true)..load();

  static final String botToken = env['TG_BOT_TOKEN']!;
  static final String geminiApiKey = env['GEMINI_API_KEY']!;
}
