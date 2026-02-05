abstract class SecurityRepository {
  Future<void> savePin(String pin);
  Future<bool> verifyPin(String pin);
  Future<bool> hasPin();
  Future<void> removePin();
}
