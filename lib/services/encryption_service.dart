import 'package:cryptography/cryptography.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

class Emn178Encryption {
  /// Encrypts text using emn178.github.io compatible format
  /// Returns hex string in format: "Salted__" + salt + encrypted_data
  static Future<String> encrypt(String plaintext, String password) async {
    try {
      // Generate random salt (8 bytes)
      final random = Random.secure();
      final salt = Uint8List.fromList(List<int>.generate(8, (_) => random.nextInt(256)));
      
      // Derive key and IV using PBKDF2 with SHA256, 1000 iterations
      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 1000,
        bits: 384, // 48 bytes total (32 for key + 16 for IV)
      );
      
      final secretKey = await pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: salt,
      );
      
      final keyBytes = await secretKey.extractBytes();
      final key = SecretKey(keyBytes.sublist(0, 32)); // First 32 bytes for AES-256
      final iv = keyBytes.sublist(32, 48); // Next 16 bytes for IV
      
      // Encrypt using AES-256-CBC
      final algorithm = AesCbc.with256bits(macAlgorithm: MacAlgorithm.empty);
      final secretBox = await algorithm.encrypt(
        utf8.encode(plaintext),
        secretKey: key,
        nonce: iv,
      );
      
      // Format: "Salted__" + salt + encrypted_data
      final salted = utf8.encode("Salted__");
      final result = salted + salt + secretBox.cipherText;
      
      // Convert to hex string
      return result.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }
  
  /// Decrypts hex string from emn178.github.io compatible format
  static Future<String> decrypt(String hexData, String password) async {
    try {
      // Convert hex string to bytes
      final data = Uint8List.fromList([
        for (int i = 0; i < hexData.length; i += 2)
          int.parse(hexData.substring(i, i + 2), radix: 16)
      ]);
      
      // Check for "Salted__" prefix
      final saltedPrefix = utf8.encode("Salted__");
      if (data.length < 16 || !_listEquals(data.sublist(0, 8), saltedPrefix)) {
        throw Exception('Invalid encrypted data format');
      }
      
      // Extract salt and encrypted data
      final salt = data.sublist(8, 16);
      final encrypted = data.sublist(16);
      
      // Derive key and IV using PBKDF2 with SHA256, 1000 iterations
      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 1000,
        bits: 384, // 48 bytes total (32 for key + 16 for IV)
      );
      
      final secretKey = await pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: salt,
      );
      
      final keyBytes = await secretKey.extractBytes();
      final key = SecretKey(keyBytes.sublist(0, 32)); // First 32 bytes for AES-256
      final iv = keyBytes.sublist(32, 48); // Next 16 bytes for IV
      
      // Decrypt using AES-256-CBC
      final algorithm = AesCbc.with256bits(macAlgorithm: MacAlgorithm.empty);
      final secretBox = SecretBox(encrypted, nonce: iv, mac: Mac.empty);
      final decryptedBytes = await algorithm.decrypt(secretBox, secretKey: key);
      
      return utf8.decode(decryptedBytes);
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }
  
  /// Test function to verify format compatibility
  static Future<String> testEncryptionFormat() async {
    try {
      const testText = "cat";
      const testPassword = "password";
      
      final encrypted = await encrypt(testText, testPassword);
      final decrypted = await decrypt(encrypted, testPassword);
      
      return 'Test: "$testText" -> $encrypted -> "$decrypted"';
    } catch (e) {
      return 'Test failed: $e';
    }
  }

  /// Helper function to compare byte lists
  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}