import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/models/app_settings.dart';

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings.empty) {
    _load();
  }

  static const _key = 'app_settings';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      state = AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
  }

  Future<void> save(AppSettings s) async {
    // No-op when nothing changed, so re-saving identical settings doesn't
    // rebuild downstream providers (which would reset the active conversation).
    if (s == state) return;
    state = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(s.toJson()));
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier());
