import 'dart:io';
import 'package:encrypt/encrypt.dart' as enc;

/// Provides AES-256 (CBC mode) encryption and decryption for sensitive data.
///
/// Keys are loaded from environment variables (ENCRYPTION_KEY and ENCRYPTION_IV).
/// ⚠️  NEVER hardcode keys. Always use environment variables or secure storage.
class SecurityService {
  // ── Keys ──────────────────────────────────────────────────────────────────
  /// Must be exactly 32 characters (256-bit key for AES-256).
  /// Loaded from ENCRYPTION_KEY environment variable.
  static final String _keyString = _getEncryptionKey();

  /// Must be exactly 16 characters (128-bit IV for AES-CBC).
  /// Loaded from ENCRYPTION_IV environment variable.
  static final String _ivString = _getEncryptionIV();

  /// Gets encryption key from environment, with fallback validation.
  static String _getEncryptionKey() {
    final key = Platform.environment['ENCRYPTION_KEY'] ?? '';
    if (key.isEmpty) {
      throw Exception(
        'ENCRYPTION_KEY environment variable not set. '
        'Generate a secure 32-character key and set it before running the app.',
      );
    }
    if (key.length != 32) {
      throw Exception(
        'ENCRYPTION_KEY must be exactly 32 characters. Current length: ${key.length}',
      );
    }
    return key;
  }

  /// Gets encryption IV from environment, with fallback validation.
  static String _getEncryptionIV() {
    final iv = Platform.environment['ENCRYPTION_IV'] ?? '';
    if (iv.isEmpty) {
      throw Exception(
        'ENCRYPTION_IV environment variable not set. '
        'Generate a secure 16-character IV and set it before running the app.',
      );
    }
    if (iv.length != 16) {
      throw Exception(
        'ENCRYPTION_IV must be exactly 16 characters. Current length: ${iv.length}',
      );
    }
    return iv;
  }

  // Singleton ----------------------------------------------------------------
  SecurityService._internal();
  static final SecurityService instance = SecurityService._internal();

  // ── Lazy-initialised cipher helpers ───────────────────────────────────────
  late final enc.Key _key = enc.Key.fromUtf8(_keyString);
  late final enc.IV _iv = enc.IV.fromUtf8(_ivString);
  late final enc.Encrypter _encrypter = enc.Encrypter(enc.AES(_key));

  // ── Public API ────────────────────────────────────────────────────────────

  /// Encrypts [text] with AES-256-CBC and returns a Base64-encoded string.
  ///
  /// Returns [text] unchanged if it is null or empty.
  String encryptData(String text) {
    if (text.isEmpty) return text;
    final encrypted = _encrypter.encrypt(text, iv: _iv);
    return encrypted.base64;
  }

  /// Decrypts a Base64-encoded [encryptedText] produced by [encryptData].
  ///
  /// Returns [encryptedText] unchanged if decryption fails (e.g. the value
  /// was stored before encryption was introduced — graceful degradation).
  String decryptData(String encryptedText) {
    if (encryptedText.isEmpty) return encryptedText;
    try {
      final encrypted = enc.Encrypted.fromBase64(encryptedText);
      return _encrypter.decrypt(encrypted, iv: _iv);
    } catch (_) {
      // Value may be plain-text from a pre-encryption database row.
      // Return it as-is so the app keeps working without crashing.
      return encryptedText;
    }
  }
}
