import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

/// Serviço de encriptação para proteger dados de viagens
class EncryptionService {
  // Chave de 32 bytes para AES-256
  static final List<int> _keyBytes = [
    84, 114, 105, 112, 108, 97, 110, 65,  // Triplan A
    73, 50, 48, 50, 54, 83, 101, 99,      // I 2026Sec
    117, 114, 101, 75, 101, 121, 49, 50,  // ureKey12
    51, 52, 53, 54, 55, 56, 57, 48        // 34567890
  ];

  // IV de 16 bytes
  static final List<int> _ivBytes = [
    84, 114, 105, 112, 108, 97, 110, 73,  // TriplanI
    86, 49, 50, 51, 52, 53, 54, 55        // V1234567
  ];

  late final Key _key;
  late final IV _iv;
  late final Encrypter _encrypter;

  EncryptionService() {
    _key = Key(Uint8List.fromList(_keyBytes));
    _iv = IV(Uint8List.fromList(_ivBytes));
    _encrypter = Encrypter(AES(_key));
  }

  /// Encripta dados JSON e retorna Base64
  String encrypt(Map<String, dynamic> data) {
    try {
      // Adicionar marca d'água para validação
      final enrichedData = {
        ...data,
        '_app': 'TriplanAI',
        '_encrypted_at': DateTime.now().toIso8601String(),
      };

      final jsonString = jsonEncode(enrichedData);
      final encrypted = _encrypter.encrypt(jsonString, iv: _iv);

      // Adicionar prefixo para identificação
      return 'TRIPLAN_V1:${encrypted.base64}';
    } catch (e) {
      throw Exception('Erro ao encriptar dados: $e');
    }
  }

  /// Desencripta dados Base64 e retorna JSON
  Map<String, dynamic> decrypt(String encryptedData) {
    try {
      // Validar prefixo
      if (!encryptedData.startsWith('TRIPLAN_V1:')) {
        throw Exception('Formato de ficheiro inválido');
      }

      // Remover prefixo
      final base64Data = encryptedData.substring(11);

      // Desencriptar
      final encrypted = Encrypted.fromBase64(base64Data);
      final decrypted = _encrypter.decrypt(encrypted, iv: _iv);

      // Parse JSON
      final data = jsonDecode(decrypted) as Map<String, dynamic>;

      // Validar marca d'água
      if (data['_app'] != 'TriplanAI') {
        throw Exception('Ficheiro não foi criado pelo TriplanAI');
      }

      // Remover metadados de encriptação
      data.remove('_app');
      data.remove('_encrypted_at');

      return data;
    } catch (e) {
      throw Exception('Erro ao desencriptar dados: $e');
    }
  }

  /// Gera hash SHA256 para validação de integridade
  String generateHash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Valida hash de integridade
  bool validateHash(String data, String hash) {
    return generateHash(data) == hash;
  }
}
