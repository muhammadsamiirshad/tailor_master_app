import 'package:encrypt/encrypt.dart' as enc;

/// Provides AES-256 (CBC mode) encryption and decryption for sensitive data.
///
/// ⚠️  Replace [_keyString] and [_ivString] with secure, externally-supplied
/// values before releasing to production.
class SecurityService {
  // ── Keys ──────────────────────────────────────────────────────────────────
  /// Must be exactly 32 characters (256-bit key for AES-256).
  static const String _keyString = 'MySecretKey12345MySecretKey12345';

  /// Must be exactly 16 characters (128-bit IV for AES-CBC).
  static const String _ivString = 'MyIV123456789012';

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
