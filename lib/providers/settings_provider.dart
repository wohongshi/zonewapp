import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/settings.dart';
import '../services/storage_service.dart';

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await StorageService.instance.loadSettings();
    state = settings;
  }

  Future<void> updateThemeMode(String mode) async {
    state = state.copyWith(themeMode: mode);
    await _saveSettings();
  }

  Future<void> updateAiMode(String? mode) async {
    state = state.copyWith(aiMode: mode);
    await _saveSettings();
  }

  Future<void> updateAiConfig(Map<String, dynamic>? config) async {
    state = state.copyWith(aiConfig: config);
    await _saveSettings();
  }

  Future<void> updateSubjectContent(String subject, String content) async {
    final contents = Map<String, String>.from(state.subjectContents);
    contents[subject] = content;
    state = state.copyWith(subjectContents: contents);
    await _saveSettings();
  }

  Future<void> updateNotification(bool enabled) async {
    state = state.copyWith(notificationEnabled: enabled);
    await _saveSettings();
  }

  Future<void> updateWebService(bool enabled) async {
    state = state.copyWith(webServiceEnabled: enabled);
    await _saveSettings();
  }

  Future<void> updatePredictiveBack(bool enabled) async {
    state = state.copyWith(predictiveBackEnabled: enabled);
    await _saveSettings();
  }

  Future<void> updateLanAccess(bool enabled) async {
    state = state.copyWith(lanAccessEnabled: enabled);
    await _saveSettings();
  }

  Future<void> updateWebServicePort(int port) async {
    state = state.copyWith(webServicePort: port);
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    await StorageService.instance.saveSettings(state);
  }

  Future<void> restoreSettings(AppSettings settings) async {
    state = settings;
    await _saveSettings();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
