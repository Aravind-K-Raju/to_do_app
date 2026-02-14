import 'package:flutter/material.dart';
import '../../domain/entities/hackathon.dart';
import '../../domain/usecases/hackathon_usecases.dart';
import '../../core/services/notification_scheduler.dart';

class HackathonProvider extends ChangeNotifier {
  final GetHackathons getHackathons;
  final CreateHackathon createHackathon;
  final UpdateHackathon updateHackathon;
  final DeleteHackathon deleteHackathon;
  final GetHackathonDistinctLoginMails getDistinctLoginMails;

  HackathonProvider({
    required this.getHackathons,
    required this.createHackathon,
    required this.updateHackathon,
    required this.deleteHackathon,
    required this.getDistinctLoginMails,
  });

  List<Hackathon> _hackathons = [];
  List<Hackathon> get hackathons => _hackathons;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<String> _distinctLoginMails = [];
  List<String> get distinctLoginMails => _distinctLoginMails;

  Future<void> loadHackathons() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        getHackathons(),
        getDistinctLoginMails(),
      ]);

      _hackathons = results[0] as List<Hackathon>;
      _distinctLoginMails = results[1] as List<String>;
    } catch (e) {
      debugPrint('Error loading hackathons data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDistinctLoginMails() async {
    try {
      _distinctLoginMails = await getDistinctLoginMails();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading distinct login mails: $e');
    }
  }

  Future<void> addHackathon(Hackathon hackathon) async {
    await createHackathon(hackathon);
    await loadHackathons();
    final created = _hackathons
        .where((h) => h.name == hackathon.name)
        .lastOrNull;
    if (created?.id != null) {
      await NotificationScheduler.scheduleForHackathon(
        hackathonId: created!.id!,
        title: hackathon.name,
        startDate: hackathon.startDate,
        timeline: hackathon.timeline
            .map((e) => {'date': e.date, 'description': e.description})
            .toList(),
      );
    }
  }

  Future<void> editHackathon(Hackathon hackathon) async {
    if (hackathon.id != null) {
      // 1. Cancel OS alarms for old rows + delete DB rows
      await NotificationScheduler.cancelForItem('hackathon_id', hackathon.id!);
    }
    await updateHackathon(hackathon);
    await loadHackathons();
    if (hackathon.id != null) {
      // 2. Insert new rows + schedule OS
      await NotificationScheduler.scheduleForHackathon(
        hackathonId: hackathon.id!,
        title: hackathon.name,
        startDate: hackathon.startDate,
        timeline: hackathon.timeline
            .map((e) => {'date': e.date, 'description': e.description})
            .toList(),
      );
    }
  }

  Future<void> removeHackathon(int id) async {
    // 1. Query IDs → Cancel OS → Delete DB rows
    await NotificationScheduler.cancelForItem('hackathon_id', id);
    // 2. Delete parent (CASCADE also cleans DB rows)
    await deleteHackathon(id);
    await loadHackathons();
  }
}
