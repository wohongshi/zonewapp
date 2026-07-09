import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/account.dart';
import '../models/settings.dart';

class StorageService {
  static final StorageService instance = StorageService._();
  StorageService._();

  Box<dynamic>? _settingsBox;
  Box<dynamic>? _accountsBox;

  Future<void> init() async {
    _settingsBox = await Hive.openBox('settings');
    _accountsBox = await Hive.openBox('accounts');
  }

  // Settings
  Future<AppSettings> loadSettings() async {
    final json = _settingsBox?.get('app_settings');
    if (json != null) {
      return AppSettings.fromJson(jsonDecode(json));
    }
    return AppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _settingsBox?.put('app_settings', jsonEncode(settings.toJson()));
  }

  // Accounts
  Future<List<Account>> loadAccounts() async {
    final List<Account> accounts = [];
    final keys = _accountsBox?.keys.toList() ?? [];
    for (final key in keys) {
      final json = _accountsBox?.get(key);
      if (json != null) {
        try {
          accounts.add(Account.fromJson(jsonDecode(json)));
        } catch (e) {
          // skip invalid entries
        }
      }
    }
    accounts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return accounts;
  }

  Future<void> addAccount(Account account) async {
    await _accountsBox?.put(account.id, jsonEncode(account.toJson()));
  }

  Future<void> updateAccount(Account account) async {
    await _accountsBox?.put(account.id, jsonEncode(account.toJson()));
  }

  Future<void> deleteAccount(String id) async {
    await _accountsBox?.delete(id);
  }

  // Backup & Restore
  Future<String> exportData() async {
    final settings = await loadSettings();
    final accounts = await loadAccounts();

    final Map<String, dynamic> data = {
      'settings': settings.toJson(),
      'accounts': accounts.map((a) => a.toJson()).toList(),
      'exported_at': DateTime.now().toIso8601String(),
    };

    return jsonEncode(data);
  }

  Future<bool> importData(String jsonStr) async {
    try {
      final data = jsonDecode(jsonStr);

      if (data['settings'] != null) {
        final settings = AppSettings.fromJson(data['settings']);
        await saveSettings(settings);
      }

      if (data['accounts'] != null) {
        for (final accountJson in data['accounts']) {
          final account = Account.fromJson(accountJson);
          await addAccount(account);
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
