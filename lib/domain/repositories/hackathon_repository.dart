import '../entities/hackathon.dart';

abstract class HackathonRepository {
  Future<List<Hackathon>> getHackathons();
  Future<int> createHackathon(Hackathon hackathon);
  Future<int> updateHackathon(Hackathon hackathon);
  Future<int> deleteHackathon(int id);
}
