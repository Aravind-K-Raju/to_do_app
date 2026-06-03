import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DraftService {
  final _storage = const FlutterSecureStorage();

  Future<void> saveDraft(String key, String jsonStr) async {
    await _storage.write(key: key, value: jsonStr);
  }

  Future<String?> getDraft(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> clearDraft(String key) async {
    await _storage.delete(key: key);
  }
}
