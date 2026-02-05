import '../../repositories/security_repository.dart';

class ValidatePin {
  final SecurityRepository repository;

  ValidatePin(this.repository);

  Future<bool> call(String pin) async {
    return await repository.verifyPin(pin);
  }
}
