import '../../domain/entities/hackathon.dart';
import '../../domain/repositories/hackathon_repository.dart';
import '../database/database_helper.dart';

class HackathonRepositoryImpl implements HackathonRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<List<Hackathon>> getHackathons() async {
    final result = await _dbHelper.getAllHackathons();
    return result.map((map) => _fromMap(map)).toList();
  }

  @override
  Future<int> createHackathon(Hackathon hackathon) async {
    return await _dbHelper.createHackathon(_toMap(hackathon));
  }

  @override
  Future<int> updateHackathon(Hackathon hackathon) async {
    return await _dbHelper.updateHackathon(_toMap(hackathon));
  }

  @override
  Future<int> deleteHackathon(int id) async {
    return await _dbHelper.deleteHackathon(id);
  }

  Hackathon _fromMap(Map<String, dynamic> map) {
    return Hackathon(
      id: map['id'],
      name: map['name'],
      theme: map['theme'],
      startDate: DateTime.parse(map['start_date']),
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
      teamSize: map['team_size'],
      techStack: map['tech_stack'],
      outcome: map['outcome'],
      projectLink: map['project_link'],
    );
  }

  Map<String, dynamic> _toMap(Hackathon hackathon) {
    return {
      'id': hackathon.id,
      'name': hackathon.name,
      'theme': hackathon.theme,
      'start_date': hackathon.startDate.toIso8601String(),
      'end_date': hackathon.endDate?.toIso8601String(),
      'team_size': hackathon.teamSize,
      'tech_stack': hackathon.techStack,
      'outcome': hackathon.outcome,
      'project_link': hackathon.projectLink,
    };
  }
}
