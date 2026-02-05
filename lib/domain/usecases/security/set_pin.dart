import '../../repositories/security_repository.dart';

class SetPin {
  final SecurityRepository repository;

  SetPin(this.repository);

  Future<void> call(String pin) async {
    return await repository.savePin(pin);
  }
}
