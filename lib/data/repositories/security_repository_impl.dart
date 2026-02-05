import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/repositories/security_repository.dart';

class SecurityRepositoryImpl implements SecurityRepository {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _pinKey = 'user_pin';

  @override
  Future<void> savePin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  @override
  Future<bool> verifyPin(String pin) async {
    final storedPin = await _storage.read(key: _pinKey);
    return storedPin == pin;
  }

  @override
  Future<bool> hasPin() async {
    final storedPin = await _storage.read(key: _pinKey);
    return storedPin != null && storedPin.isNotEmpty;
  }

  @override
  Future<void> removePin() async {
    await _storage.delete(key: _pinKey);
  }
}
