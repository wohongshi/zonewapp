import 'dart:convert';
import 'dart:math';

/// Simple password obfuscation for local storage.
/// This is NOT production-grade encryption — it prevents casual reading
/// of plaintext passwords from Hive/SQLite files.
/// For stronger security, consider using flutter_secure_storage or HiveAesCipher.
class CryptoUtils {
  static const String _key = 'zonewapp_v1_2024';

  /// Encrypt a plaintext string using XOR + base64.
  static String encrypt(String plaintext) {
    if (plaintext.isEmpty) return plaintext;
    final bytes = utf8.encode(plaintext);
    final keyBytes = utf8.encode(_key);
    final encrypted = List<int>.generate(
      bytes.length,
      (i) => bytes[i] ^ keyBytes[i % keyBytes.length],
    );
    return base64Encode(encrypted);
  }

  /// Decrypt an encrypted string back to plaintext.
  static String decrypt(String encrypted) {
    if (encrypted.isEmpty) return encrypted;
    try {
      final bytes = base64Decode(encrypted);
      final keyBytes = utf8.encode(_key);
      final decrypted = List<int>.generate(
        bytes.length,
        (i) => bytes[i] ^ keyBytes[i % keyBytes.length],
      );
      return utf8.decode(decrypted);
    } catch (e) {
      // If decoding fails, return as-is (backward compatibility with plaintext)
      return encrypted;
    }
  }

  /// Check if a string looks like it's been encrypted (base64 pattern).
  static bool isEncrypted(String value) {
    if (value.isEmpty) return false;
    try {
      base64Decode(value);
      // base64 strings are typically longer than the original for short passwords
      // and don't contain Chinese characters or common password chars directly
      return !value.contains(RegExp(r'[^\w+/=]'));
    } catch (e) {
      return false;
    }
  }
}
