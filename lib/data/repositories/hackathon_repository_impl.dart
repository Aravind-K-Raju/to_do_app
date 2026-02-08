import '../../domain/entities/hackathon.dart';
import '../../domain/entities/event_link.dart';
import '../../domain/entities/event_date.dart';
import '../../domain/repositories/hackathon_repository.dart';

import '../database/database_helper.dart';

class HackathonRepositoryImpl implements HackathonRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<List<Hackathon>> getHackathons() async {
    final db = await _dbHelper.database;
    final result = await _dbHelper.getAllHackathons();

    if (result.isEmpty) return [];

    // Batch fetch related data
    final allLinks = await db.query('hackathon_links');
    final allDates = await db.query('hackathon_dates');

    // Group by hackathon_id
    final linksMap = <int, List<EventLink>>{};
    for (var l in allLinks) {
      final hId = l['hackathon_id'] as int;
      if (!linksMap.containsKey(hId)) linksMap[hId] = [];
      linksMap[hId]!.add(
        EventLink(
          id: l['id'] as int,
          url: l['url'] as String,
          description: l['description'] as String,
        ),
      );
    }

    final datesMap = <int, List<EventDate>>{};
    for (var d in allDates) {
      final hId = d['hackathon_id'] as int;
      if (!datesMap.containsKey(hId)) datesMap[hId] = [];
      datesMap[hId]!.add(
        EventDate(
          id: d['id'] as int,
          date: DateTime.parse(d['date_val'] as String),
          description: d['description'] as String,
        ),
      );
    }

    // Map to entities
    return result.map((map) {
      final id = map['id'] as int;
      return Hackathon(
        id: id,
        name: map['name'] as String,
        theme: map['theme'] as String?,
        description: map['description'] as String?,
        startDate: DateTime.parse(map['start_date'] as String),
        endDate: map['end_date'] != null
            ? DateTime.parse(map['end_date'] as String)
            : null,
        teamSize: map['team_size'] as int?,
        techStack: map['tech_stack'] as String?,
        outcome: map['outcome'] as String?,
        projectLink: map['project_link'] as String?,
        loginMail: map['login_mail'] as String?,
        links: linksMap[id] ?? [],
        timeline: datesMap[id] ?? [],
      );
    }).toList();
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
