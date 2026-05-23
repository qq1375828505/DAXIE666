import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageDataSource {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> writeApiKey(String configId, String apiKey) async {
    await _storage.write(key: 'api_key_$configId', value: apiKey);
  }

  Future<String?> readApiKey(String configId) async {
    return await _storage.read(key: 'api_key_$configId');
  }

  Future<void> deleteApiKey(String configId) async {
    await _storage.delete(key: 'api_key_$configId');
  }
}
