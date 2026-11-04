# NaNa Wallet — Flutter mobile app

NaNa Wallet is a Flutter school-project demo client for a Laravel wallet API. It includes account access, wallet views, transfers, bill payments, mobile top-up demo flow, quick loans, and a chatbot interface where supported by the configured API.

## Requirements

- Flutter stable and Dart SDK compatible with `pubspec.yaml`
- Android SDK for Android builds
- A reachable NaNa Wallet Laravel API

## Configure the API URL

The API URL is injected at build time through `API_BASE_URL`. The default in `lib/core/config/api_config.dart` targets a Laravel API running on the Android emulator at `http://10.0.2.2:8000/api`.

For the hosted school demo API:

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=https://nana-wallet-api.onrender.com/api
```

Build a debug APK:

```sh
flutter build apk --debug --dart-define=API_BASE_URL=https://nana-wallet-api.onrender.com/api
```

For a physical phone, use a publicly reachable API URL. Do not commit API secrets, production credentials, signing keys, or local SDK path files. Wallet activity and user data are stored by the backend database, not in this Flutter source repository.

## Project layout

- `lib/core/` — shared configuration, constants and utilities
- `lib/features/` — wallet, authentication, loan, and other app features
- `android/` — Android application configuration and launcher assets

This is a demo client. Mobile carrier top-ups and payment-provider integrations are simulated unless a real provider has been separately configured in the backend.
