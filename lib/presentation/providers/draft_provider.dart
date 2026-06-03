import 'package:flutter/material.dart';
import '../../core/services/draft_service.dart';

class DraftProvider extends ChangeNotifier {
  final DraftService _draftService;

  bool _hasCourseDraft = false;
  bool _hasHackathonDraft = false;
  bool _hasAssignmentDraft = false;
  bool _hasTaskDraft = false;

  bool get hasCourseDraft => _hasCourseDraft;
  bool get hasHackathonDraft => _hasHackathonDraft;
  bool get hasAssignmentDraft => _hasAssignmentDraft;
  bool get hasTaskDraft => _hasTaskDraft;

  DraftProvider(this._draftService) {
    _loadInitialDraftStates();
  }

  Future<void> _loadInitialDraftStates() async {
    _hasCourseDraft = (await _draftService.getDraft('draft_course')) != null;
    _hasHackathonDraft = (await _draftService.getDraft('draft_hackathon')) != null;
    _hasAssignmentDraft = (await _draftService.getDraft('draft_assignment')) != null;
    _hasTaskDraft = (await _draftService.getDraft('draft_task')) != null;
    notifyListeners();
  }

  Future<void> saveDraft(String key, String jsonStr) async {
    await _draftService.saveDraft(key, jsonStr);
    _updateDraftState(key, true);
  }

  Future<String?> getDraft(String key) async {
    return await _draftService.getDraft(key);
  }

  Future<void> clearDraft(String key) async {
    await _draftService.clearDraft(key);
    _updateDraftState(key, false);
  }

  void _updateDraftState(String key, bool hasDraft) {
    bool changed = false;
    switch (key) {
      case 'draft_course':
        if (_hasCourseDraft != hasDraft) {
          _hasCourseDraft = hasDraft;
          changed = true;
        }
        break;
      case 'draft_hackathon':
        if (_hasHackathonDraft != hasDraft) {
          _hasHackathonDraft = hasDraft;
          changed = true;
        }
        break;
      case 'draft_assignment':
        if (_hasAssignmentDraft != hasDraft) {
          _hasAssignmentDraft = hasDraft;
          changed = true;
        }
        break;
      case 'draft_task':
        if (_hasTaskDraft != hasDraft) {
          _hasTaskDraft = hasDraft;
          changed = true;
        }
        break;
    }
    if (changed) {
      notifyListeners();
    }
  }
}
