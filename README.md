# Tailor Master — Offline-First Tailor Management App

A Flutter app for tailors to manage customers, orders, measurements, and payments with **Firebase authentication**, **Realtime Database**, and **AES-256 encryption** for sensitive data.

---

## 📋 Features

- **Customer Management**: Store measurements (chest, collar, sleeves, etc.) with notes
- **Order Tracking**: Create, update, and complete orders with delivery dates
- **Payment Tracking**: Record advances and track dues (udhaar)
- **Urgent Orders**: Real-time alerts for orders due today/tomorrow
- **Search**: Find customers by name or phone
- **Encryption**: Phone numbers encrypted with AES-256
- **Offline Support**: Data syncs automatically when connection returns
- **Multi-platform**: Android, iOS, Web, Windows, macOS, Linux

---

## 🔐 Security

- **Phone numbers** are encrypted in the Firebase Realtime Database using AES-256-CBC
- **Encryption keys** are loaded from environment variables (NOT hardcoded)
- **Firebase Auth** secures all data access per user

---

## ⚙️ Prerequisites

- **Flutter 3.11+** ([install](https://docs.flutter.dev/get-started/install))
- **Firebase Project** ([create one](https://console.firebase.google.com))
- **Dart 3.11+** (comes with Flutter)
- Environment variables for encryption (see Setup)

---

## 📦 Installation

### 1. Clone the repository
```bash
git clone <your-repo-url>
cd tailor_master
```

### 2. Set up environment variables

Create a `.env` file in the project root (add to `.gitignore`):
```env
ENCRYPTION_KEY=YourSecure32CharacterKeyHere1234
ENCRYPTION_IV=YourSecure16CharIV123
```

**Generate secure keys**:
```bash
# On macOS/Linux:
openssl rand -base64 32 | tr -d '=' | cut -c1-32
openssl rand -base64 16 | tr -d '=' | cut -c1-16

# On Windows (use openssl if installed, or use online generator):
# https://www.browserling.com/tools/random-byte-generator (copy first 32 and 16 chars)
```

### 3. Set up Firebase

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project (or use existing)
3. Add Android/iOS/Web apps
4. Download `google-services.json` (Android) and place it in `android/app/`
5. Download `GoogleService-Info.plist` (iOS) and add it to Xcode
6. Enable **Email/Password** authentication in Firebase → Authentication → Sign-in method

### 4. Install dependencies
```bash
flutter pub get
```

### 5. Run on device/emulator
```bash
# List available devices
flutter devices

# Run on a specific device
flutter run -d <device-id>

# Or just run (uses default device)
flutter run
```

---

## 🛠️ Development

### Project Structure
```
lib/
├── main.dart              # App entry point
├── models/                # Data models (Customer, Order)
├── providers/             # State management (DarziProvider)
├── screens/               # UI screens
│   ├── auth/             # Login, Signup, Forgot Password
│   ├── customers_screen.dart
│   ├── orders_screen.dart
│   ├── dashboard_screen.dart
│   └── ...
├── services/             # Business logic
│   ├── auth_service.dart       # Firebase Auth
│   ├── rtdb_service.dart       # Firebase RTDB
│   └── security_service.dart   # AES-256 Encryption
└── database/             # (if using Hive/SQLite)
```

### Running in debug mode
```bash
flutter run
```

### Building APK (Android release)
```bash
flutter build apk --release
```

### Building AAB (Google Play)
```bash
flutter build appbundle --release
```

---

## 📱 Architecture & Services

### AuthService (`lib/services/auth_service.dart`)
- Email/password login, signup, password reset
- Firebase Authentication
- Friendly error messages

### RTDBService (`lib/services/rtdb_service.dart`)
- CRUD operations for customers and orders
- Search, filtering, payment tracking
- Offline-aware (data syncs when online)

### SecurityService (`lib/services/security_service.dart`)
- AES-256-CBC encryption/decryption
- Encrypts phone numbers before storing in DB
- Environment-variable key management

### DarziProvider (`lib/providers/darzi_provider.dart`)
- State management using Provider package
- Aggregates auth, database, and business logic

---

## 🧪 Testing

```bash
# Run unit tests
flutter test

# Run integration tests (requires emulator/device)
flutter test integration_test/
```

---

## 🚨 Common Issues

### `ENCRYPTION_KEY environment variable not set`
**Fix**: Create `.env` file with `ENCRYPTION_KEY` and `ENCRYPTION_IV` as described in Step 2.

### Firebase: `Configuration not found`
**Fix**: 
1. Ensure `google-services.json` is in `android/app/`
2. Run `flutter pub get` and `flutter clean`
3. Run `flutter pub get` again

### Offline data not syncing
**Fix**: Firebase Realtime Database should auto-sync. Ensure:
1. User is authenticated
2. Device has internet
3. No rate limiting from Firebase

---

## 🔄 Environment Setup for Different Platforms

### Android
- Requires `google-services.json` in `android/app/`
- Minimum SDK: 21

### iOS
- Requires `GoogleService-Info.plist` added to Xcode
- Minimum iOS: 12.0

### Web
- Download config file from Firebase Console
- Update `web/index.html` if needed

---

## 📝 License

[Specify your license here, e.g., MIT, GPL, etc.]

---

## 👤 Author

Tailor Master Development Team

For questions or issues, contact: [your-email@example.com]
