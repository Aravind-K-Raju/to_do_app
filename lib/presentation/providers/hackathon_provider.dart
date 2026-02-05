import 'package:flutter/material.dart';
import '../../domain/entities/hackathon.dart';
import '../../domain/usecases/hackathon_usecases.dart';

class HackathonProvider extends ChangeNotifier {
  final GetHackathons getHackathons;
  final CreateHackathon createHackathon;
  final UpdateHackathon updateHackathon;
  final DeleteHackathon deleteHackathon;

  HackathonProvider({
    required this.getHackathons,
    required this.createHackathon,
    required this.updateHackathon,
    required this.deleteHackathon,
  });

  List<Hackathon> _hackathons = [];
  List<Hackathon> get hackathons => _hackathons;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadHackathons() async {
    _isLoading = true;
    notifyListeners();
    try {
      _hackathons = await getHackathons();
    } catch (e) {
      debugPrint('Error loading hackathons: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
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
