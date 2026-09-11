# Poetium

Flutter mobile application backed by an Express API and PostgreSQL.

## API

Create `server/.env` from `server/.env.example`, then set `DATABASE_URL`,
`JWT_SECRET`, and `PORT`. Do not commit the environment file.

```powershell
Set-Location server
npm install
npm run migrate
npm start
```

The API stores accounts, password hashes, password reset requests, poems,
selected recipients, and criterion ratings. JWT access tokens are stateless.

## Flutter

The Android emulator reaches the host API through `10.0.2.2` by default.

```powershell
flutter pub get
flutter run -d emulator-5554
```

Override the API URL for another device or environment:

```powershell
flutter run --dart-define=API_URL=http://192.168.1.10:3000
```

Development builds allow cleartext HTTP for the local API. Production builds
must use an HTTPS endpoint.

## Verification

```powershell
flutter analyze
flutter test
Set-Location server
npm audit --omit=dev
```
