import '../entities/hackathon.dart';
import '../repositories/hackathon_repository.dart';

class GetHackathons {
  final HackathonRepository repository;
  GetHackathons(this.repository);
  Future<List<Hackathon>> call() async => await repository.getHackathons();
}

class CreateHackathon {
  final HackathonRepository repository;
  CreateHackathon(this.repository);
  Future<int> call(Hackathon hackathon) async =>
      await repository.createHackathon(hackathon);
}

class UpdateHackathon {
  final HackathonRepository repository;
  UpdateHackathon(this.repository);
  Future<int> call(Hackathon hackathon) async =>
      await repository.updateHackathon(hackathon);
}

class DeleteHackathon {
  final HackathonRepository repository;
  DeleteHackathon(this.repository);
  Future<int> call(int id) async => await repository.deleteHackathon(id);
}

class GetHackathonDistinctLoginMails {
  final HackathonRepository repository;
  GetHackathonDistinctLoginMails(this.repository);
  Future<List<String>> call() async => await repository.getDistinctLoginMails();
}
