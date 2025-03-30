FROM dart:3.7.2

RUN groupadd -r user && useradd --no-log-init -r -g user user

WORKDIR /home/user/app

COPY . .

RUN dart pub get

RUN dart compile exe bin/gemt_bot.dart -o server

EXPOSE 4400

USER user 

CMD [ "/home/user/app/server" ]
