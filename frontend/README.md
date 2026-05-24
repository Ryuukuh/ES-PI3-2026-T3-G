# frontend

Aplicativo Flutter do projeto MesclaInvest.

## Descrição

Este diretório contém o app Flutter usado como frontend do projeto. Ele inclui telas de login, cadastro e a estrutura inicial para exibir startups e simular investimentos.

## Como executar

Abra o terminal em `frontend/` e execute:

```powershell
flutter pub get
flutter run
```

Para iniciar um dispositivo específico ou rodar com um arquivo de entrada:

```powershell
flutter run -t lib/main.dart
```

## Dependências principais

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`

## Observações

- O arquivo `lib/firebase_options.dart` foi gerado pelo FlutterFire CLI.
- `flutter run` deve ser executado dentro da pasta `frontend`, pois o `pubspec.yaml` está aqui.

## Estrutura básica

- `lib/main.dart`: ponto de entrada do app.
- `lib/screens/`: telas do app, como `login_screen.dart` e `register_screen.dart`.
- `lib/theme/`: definições de cores e tema.

## Dicas

- Se o app estiver com tela branca, verifique se o Firebase está inicializado corretamente e se o terminal está na pasta `frontend`.
- Para atualizar o Firebase no frontend, use o FlutterFire CLI para regenerar `lib/firebase_options.dart`.
