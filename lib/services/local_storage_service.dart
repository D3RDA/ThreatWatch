import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/face_profile.dart';
import '../models/face_recognition_log.dart';
import '../models/saved_cve_entry.dart';
import '../models/scan_history_item.dart';
import '../models/security_checklist.dart';

class LocalStorageService {
  LocalStorageService._();

  static final LocalStorageService instance = LocalStorageService._();

  static const _historyKey = 'scan_history_items';
  static const _watchlistKey = 'watched_products';
  static const _checklistKey = 'security_checklist';
  static const _savedCvesKey = 'saved_cve_entries';
  static const _faceProfilesKey = 'face_profiles';
  static const _faceLogsKey = 'face_recognition_logs';

  Future<SharedPreferencesAsync> _prefs() async {
    return SharedPreferencesAsync();
  }

  Future<List<ScanHistoryItem>> loadHistory() async {
    final prefs = await _prefs();
    final raw = await prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => ScanHistoryItem.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> saveHistory(List<ScanHistoryItem> items) async {
    final prefs = await _prefs();
    final raw = jsonEncode(items.map((item) => item.toJson()).toList());
    await prefs.setString(_historyKey, raw);
  }

  Future<void> addHistoryItem(ScanHistoryItem item) async {
    final current = await loadHistory();
    current.insert(0, item);
    if (current.length > 100) {
      current.removeRange(100, current.length);
    }
    await saveHistory(current);
  }

  Future<void> clearHistory() async {
    final prefs = await _prefs();
    await prefs.remove(_historyKey);
  }

  Future<List<String>> loadWatchlist() async {
    final prefs = await _prefs();
    final raw = await prefs.getString(_watchlistKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((item) => item.toString()).toList();
  }

  Future<void> saveWatchlist(List<String> items) async {
    final prefs = await _prefs();
    await prefs.setString(_watchlistKey, jsonEncode(items));
  }

  Future<Map<String, SavedCveEntry>> loadSavedCveEntries() async {
    final prefs = await _prefs();
    final raw = await prefs.getString(_savedCvesKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(raw);
    if (decoded is List<dynamic>) {
      final map = <String, SavedCveEntry>{};
      for (final item in decoded) {
        final cveId = item.toString();
        map[cveId] = SavedCveEntry.empty(cveId);
      }
      await saveSavedCveEntries(map);
      return map;
    }

    if (decoded is Map<String, dynamic>) {
      return decoded.map(
        (key, value) => MapEntry(
          key,
          SavedCveEntry.fromJson(value as Map<String, dynamic>),
        ),
      );
    }

    return {};
  }

  Future<void> saveSavedCveEntries(Map<String, SavedCveEntry> items) async {
    final prefs = await _prefs();
    final raw = jsonEncode(
      items.map((key, value) => MapEntry(key, value.toJson())),
    );
    await prefs.setString(_savedCvesKey, raw);
  }

  Future<List<String>> loadSavedCves() async {
    final entries = await loadSavedCveEntries();
    return entries.keys.toList()..sort();
  }

  Future<void> saveSavedCves(List<String> items) async {
    final mapped = {
      for (final item in items) item: SavedCveEntry.empty(item),
    };
    await saveSavedCveEntries(mapped);
  }

  Future<bool> toggleSavedCve(String cveId) async {
    final current = await loadSavedCveEntries();
    final exists = current.containsKey(cveId);
    if (exists) {
      current.remove(cveId);
    } else {
      current[cveId] = SavedCveEntry.empty(cveId);
    }
    await saveSavedCveEntries(current);
    return !exists;
  }

  Future<SavedCveEntry?> getSavedCveEntry(String cveId) async {
    final current = await loadSavedCveEntries();
    return current[cveId];
  }

  Future<void> upsertSavedCveEntry(SavedCveEntry entry) async {
    final current = await loadSavedCveEntries();
    current[entry.cveId] = entry.copyWith(updatedAt: DateTime.now());
    await saveSavedCveEntries(current);
  }

  Future<void> removeSavedCve(String cveId) async {
    final current = await loadSavedCveEntries();
    current.remove(cveId);
    await saveSavedCveEntries(current);
  }

  Future<SecurityChecklist> loadChecklist() async {
    final prefs = await _prefs();
    final raw = await prefs.getString(_checklistKey);
    if (raw == null || raw.isEmpty) {
      return SecurityChecklist.empty();
    }

    return SecurityChecklist.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveChecklist(SecurityChecklist checklist) async {
    final prefs = await _prefs();
    await prefs.setString(_checklistKey, jsonEncode(checklist.toJson()));
  }


  Future<List<FaceProfile>> loadFaceProfiles() async {
    final prefs = await _prefs();
    final raw = await prefs.getString(_faceProfilesKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => FaceProfile.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> saveFaceProfiles(List<FaceProfile> profiles) async {
    final prefs = await _prefs();
    final raw = jsonEncode(profiles.map((item) => item.toJson()).toList());
    await prefs.setString(_faceProfilesKey, raw);
  }

  Future<void> upsertFaceProfile(FaceProfile profile) async {
    final current = await loadFaceProfiles();
    final index = current.indexWhere((item) => item.id == profile.id);
    if (index == -1) {
      current.add(profile);
    } else {
      current[index] = profile;
    }
    await saveFaceProfiles(current);
  }

  Future<void> removeFaceProfile(String profileId) async {
    final current = await loadFaceProfiles();
    current.removeWhere((item) => item.id == profileId);
    await saveFaceProfiles(current);
  }

  Future<List<FaceRecognitionLog>> loadFaceRecognitionLogs() async {
    final prefs = await _prefs();
    final raw = await prefs.getString(_faceLogsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => FaceRecognitionLog.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> saveFaceRecognitionLogs(List<FaceRecognitionLog> items) async {
    final prefs = await _prefs();
    final raw = jsonEncode(items.map((item) => item.toJson()).toList());
    await prefs.setString(_faceLogsKey, raw);
  }

  Future<void> addFaceRecognitionLog(FaceRecognitionLog log) async {
    final current = await loadFaceRecognitionLogs();
    current.insert(0, log);
    if (current.length > 120) {
      current.removeRange(120, current.length);
    }
    await saveFaceRecognitionLogs(current);
  }

}
