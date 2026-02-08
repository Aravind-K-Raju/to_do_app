import 'package:flutter/material.dart';
import '../../domain/entities/hackathon.dart';
import '../../domain/usecases/hackathon_usecases.dart';

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
  }

  Future<void> editHackathon(Hackathon hackathon) async {
    await updateHackathon(hackathon);
    await loadHackathons();
  }

  Future<void> removeHackathon(int id) async {
    await deleteHackathon(id);
    await loadHackathons();
  }
}
