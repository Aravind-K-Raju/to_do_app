import '../../repositories/security_repository.dart';

class CheckPinExists {
  final SecurityRepository repository;

  CheckPinExists(this.repository);

  Future<bool> call() async {
    return await repository.hasPin();
  }
}
