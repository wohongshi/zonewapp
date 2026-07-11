import 'dart:convert';
import 'dart:math';
import 'package:hive/hive.dart';

/// Password obfuscation for local storage.
/// On first run, generates a random per-device key and persists it in Hive.
/// This is NOT production-grade encryption — it prevents casual reading
/// of plaintext passwords from Hive/SQLite files.
/// For stronger security, consider using flutter_secure_storage or HiveAesCipher.
class CryptoUtils {
  static const String _keyBoxName = 'crypto';
  static const String _keyFieldName = 'encryption_key';
  static const int _keyLength = 32;
  static String? _cachedKey;

  /// Get or generate the encryption key.
  static Future<String> _getKey() async {
    if (_cachedKey != null) return _cachedKey!;

    final box = await Hive.openBox(_keyBoxName);
    String? storedKey = box.get(_keyFieldName);

    if (storedKey == null || storedKey.isEmpty) {
      // Generate a cryptographically random key on first run
      final random = Random.secure();
      final keyBytes = List<int>.generate(_keyLength, (_) => random.nextInt(256));
      storedKey = base64Encode(keyBytes);
      await box.put(_keyFieldName, storedKey);
    }

    _cachedKey = storedKey;
    return storedKey;
  }

  /// Encrypt a plaintext string using XOR + base64 with per-device key.
  static Future<String> encrypt(String plaintext) async {
    if (plaintext.isEmpty) return plaintext;
    final key = await _getKey();
    final bytes = utf8.encode(plaintext);
    final keyBytes = utf8.encode(key);
    final encrypted = List<int>.generate(
      bytes.length,
      (i) => bytes[i] ^ keyBytes[i % keyBytes.length],
    );
    return base64Encode(encrypted);
  }

  /// Decrypt an encrypted string back to plaintext.
  static Future<String> decrypt(String encrypted) async {
    if (encrypted.isEmpty) return encrypted;
    try {
      final key = await _getKey();
      final bytes = base64Decode(encrypted);
      final keyBytes = utf8.encode(key);
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
      return !value.contains(RegExp(r'[^\w+/=]'));
    } catch (e) {
      return false;
    }
  }
}
