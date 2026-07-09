import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/account.dart';
import '../models/settings.dart';
import '../utils/crypto_utils.dart';

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
          final decoded = jsonDecode(json);
          // Decrypt password if encrypted
          if (decoded['password'] != null) {
            decoded['password'] = CryptoUtils.decrypt(decoded['password']);
          }
          accounts.add(Account.fromJson(decoded));
        } catch (e) {
          // skip invalid entries
        }
      }
    }
    accounts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return accounts;
  }

  Future<void> addAccount(Account account) async {
    final data = account.toJson();
    // Encrypt password before storing
    data['password'] = CryptoUtils.encrypt(account.password);
    await _accountsBox?.put(account.id, jsonEncode(data));
  }

  Future<void> updateAccount(Account account) async {
    final data = account.toJson();
    // Encrypt password before storing
    data['password'] = CryptoUtils.encrypt(account.password);
    await _accountsBox?.put(account.id, jsonEncode(data));
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
      'accounts': accounts.map((a) {
        final json = a.toJson();
        // Encrypt password in export
        json['password'] = CryptoUtils.encrypt(a.password);
        return json;
      }).toList(),
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
          // Decrypt password if encrypted
          if (accountJson['password'] != null) {
            accountJson['password'] = CryptoUtils.decrypt(accountJson['password']);
          }
          final account = Account.fromJson(accountJson);
          await addAccount(account); // re-encrypts on store
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
