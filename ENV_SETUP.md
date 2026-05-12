# Environment Configuration Guide

## Setup Instructions

### 1. Create .env File
The `.env` file contains sensitive configuration like encryption keys. **Never commit this file to version control.**

```bash
# Copy the example file to create your own .env
cp .env.example .env
```

### 2. .env File Format
```
ENCRYPTION_KEY=aB3$cD9@eF2!gH7&jK4*mN6%pQ8^rS1+
APP_ENV=production
APP_DEBUG=false
```

### 3. Using Encryption Key in Your Code

```dart
import 'services/config_service.dart';

// Get the encryption key
final encryptionKey = ConfigService().encryptionKey;

// Encrypt/Decrypt sensitive data
import 'package:encrypt/encrypt.dart' as encrypt;

final key = encrypt.Key.fromUtf8(ConfigService().encryptionKey);
final iv = encrypt.IV.fromLength(16);
final encrypter = encrypt.Encrypter(encrypt.AES(key));

// Encrypt
final encrypted = encrypter.encrypt('sensitive data', iv: iv);

// Decrypt
final decrypted = encrypter.decrypt(encrypted, iv: iv);
```

### 4. Security Best Practices

✅ **DO:**
- Store .env file locally only
- Add .env to .gitignore (already done)
- Use strong encryption keys (32+ characters recommended)
- Rotate encryption keys periodically
- Never hardcode sensitive values in code

❌ **DON'T:**
- Commit .env file to version control
- Share encryption keys via email or chat
- Use weak or default keys in production
- Expose encryption keys in error logs
- Commit the actual .env to Git

### 5. Environment Variables Available

| Variable | Purpose | Required |
|----------|---------|----------|
| `ENCRYPTION_KEY` | AES encryption key for sensitive data | Yes |
| `APP_ENV` | Application environment (production/staging/development) | Yes |
| `APP_DEBUG` | Enable debug logging | No |

### 6. Accessing Environment Variables

```dart
final config = ConfigService();

// Get specific environment variables
String encryptionKey = config.encryptionKey;
String appEnv = config.appEnv;
bool isDebug = config.isDebug;

// Get any custom variable
String? customValue = config.getEnv('CUSTOM_KEY');

// Get with default fallback
String value = config.getEnvWithDefault('KEY', 'default');

// Check if variable exists
bool exists = config.hasEnv('KEY');
```

### 7. For Production Deployment

Before deploying to production:

1. Generate a strong, random encryption key
   ```bash
   # On Linux/Mac:
   openssl rand -base64 32
   ```

2. Update .env with production values
   ```
   ENCRYPTION_KEY=<production-key-here>
   APP_ENV=production
   APP_DEBUG=false
   ```

3. Ensure .env is deployed to the server/device securely
4. Never share production .env file

### 8. Troubleshooting

**Error: "ENCRYPTION_KEY not found in .env file"**
- Ensure .env file exists in project root
- Run `flutter pub get` after creating .env
- Ensure .env is in flutter assets (pubspec.yaml)

**Error: "ENCRYPTION_KEY must be at least 16 characters"**
- Update .env with a longer encryption key (32+ characters recommended)

**Missing flutter_dotenv dependency?**
- Run `flutter pub get`
- Restart your app
