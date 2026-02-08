import '../../domain/entities/hackathon.dart';
import '../../domain/entities/event_link.dart';
import '../../domain/entities/event_date.dart';
import '../../domain/repositories/hackathon_repository.dart';
import '../database/database_helper.dart';

class HackathonRepositoryImpl implements HackathonRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<List<Hackathon>> getHackathons() async {
    final result = await _dbHelper.getAllHackathons();
    final List<Hackathon> list = [];
    for (var map in result) {
      list.add(await _fromMapWithDetails(map));
    }
    return list;
  }

  @override
  Future<int> createHackathon(Hackathon hackathon) async {
    final id = await _dbHelper.createHackathon(_toMap(hackathon));

    if (hackathon.links.isNotEmpty) {
      await _dbHelper.insertHackathonLinks(
        id,
        hackathon.links
            .map<Map<String, dynamic>>(
              (l) => {'url': l.url, 'description': l.description},
            )
            .toList(),
      );
    }

    if (hackathon.timeline.isNotEmpty) {
      await _dbHelper.insertHackathonDates(
        id,
        hackathon.timeline
            .map<Map<String, dynamic>>(
              (d) => {
                'date_val': d.date.toIso8601String(),
                'description': d.description,
              },
            )
            .toList(),
      );
    }

    return id;
  }

  @override
  Future<int> updateHackathon(Hackathon hackathon) async {
    final count = await _dbHelper.updateHackathon(_toMap(hackathon));

    if (hackathon.id != null) {
      await _dbHelper.updateHackathonLinks(
        hackathon.id!,
        hackathon.links
            .map<Map<String, dynamic>>(
              (l) => {'url': l.url, 'description': l.description},
            )
            .toList(),
      );
      await _dbHelper.updateHackathonDates(
        hackathon.id!,
        hackathon.timeline
            .map<Map<String, dynamic>>(
              (d) => {
                'date_val': d.date.toIso8601String(),
                'description': d.description,
              },
            )
            .toList(),
      );
    }

    return count;
  }

  @override
  Future<int> deleteHackathon(int id) async {
    return await _dbHelper.deleteHackathon(id);
  }

  @override
  Future<List<String>> getDistinctLoginMails() async {
    return await _dbHelper.getDistinctLoginMails();
  }

  Future<Hackathon> _fromMapWithDetails(Map<String, dynamic> map) async {
    final id = map['id'] as int;

    final linksData = await _dbHelper.getLinksForHackathon(id);
    final datesData = await _dbHelper.getDatesForHackathon(id);

    final links = linksData
        .map(
          (l) => EventLink(
            id: l['id'],
            url: l['url'],
            description: l['description'],
          ),
        )
        .toList();

    final timeline = datesData
        .map(
          (d) => EventDate(
            id: d['id'],
            date: DateTime.parse(d['date_val']),
            description: d['description'],
          ),
        )
        .toList();

    return Hackathon(
      id: id,
      name: map['name'],
      theme: map['theme'],
      description: map['description'],
      startDate: DateTime.parse(map['start_date']),
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
      teamSize: map['team_size'],
      techStack: map['tech_stack'],
      outcome: map['outcome'],
      projectLink: map['project_link'],
      loginMail: map['login_mail'],
      links: links,
      timeline: timeline,
    );
  }

  // Keeping simplified _fromMap for internal use if needed, but prefer _fromMapWithDetails
  Hackathon _fromMap(Map<String, dynamic> map) {
    // This method is now less useful given we need async data.
    // Ideally refactor getHackathons to use loop with await.
    // See updated getHackathons above.
    return Hackathon(
      id: map['id'],
      name: map['name'],
      theme: map['theme'],
      description: map['description'],
      startDate: DateTime.parse(map['start_date']),
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
      teamSize: map['team_size'],
      techStack: map['tech_stack'],
      outcome: map['outcome'],
      projectLink: map['project_link'],
      loginMail: map['login_mail'],
    );
  }

  Map<String, dynamic> _toMap(Hackathon hackathon) {
    return {
      'id': hackathon.id,
      'name': hackathon.name,
      'theme': hackathon.theme,
      'description': hackathon.description,
      'start_date': hackathon.startDate.toIso8601String(),
      'end_date': hackathon.endDate?.toIso8601String(),
      'team_size': hackathon.teamSize,
      'tech_stack': hackathon.techStack,
      'outcome': hackathon.outcome,
      'project_link': hackathon.projectLink,
      'login_mail': hackathon.loginMail,
    };
  }
}
