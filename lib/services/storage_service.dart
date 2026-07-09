import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
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

  // ==================== Settings ====================

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

  // ==================== Accounts ====================

  Future<List<Account>> loadAccounts() async {
    final List<Account> accounts = [];
    final keys = _accountsBox?.keys.toList() ?? [];
    for (final key in keys) {
      final json = _accountsBox?.get(key);
      if (json != null) {
        try {
          final decoded = jsonDecode(json);
          if (decoded['password'] != null) {
            decoded['password'] = CryptoUtils.decrypt(decoded['password']);
          }
          accounts.add(Account.fromJson(decoded));
        } catch (_) {}
      }
    }
    accounts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return accounts;
  }

  Future<void> addAccount(Account account) async {
    final data = account.toJson();
    data['password'] = CryptoUtils.encrypt(account.password);
    await _accountsBox?.put(account.id, jsonEncode(data));
  }

  Future<void> updateAccount(Account account) async {
    final data = account.toJson();
    data['password'] = CryptoUtils.encrypt(account.password);
    await _accountsBox?.put(account.id, jsonEncode(data));
  }

  Future<void> deleteAccount(String id) async {
    await _accountsBox?.delete(id);
  }

  // ==================== Backup ====================

  /// Export all data to a JSON string.
  Future<String> exportToJson() async {
    final settings = await loadSettings();
    final accounts = await loadAccounts();

    final Map<String, dynamic> data = {
      'version': 1,
      'settings': settings.toJson(),
      'accounts': accounts.map((a) {
        final json = a.toJson();
        json['password'] = CryptoUtils.encrypt(a.password);
        return json;
      }).toList(),
      'exported_at': DateTime.now().toIso8601String(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Export to a file in the chosen directory.
  /// Returns the full file path.
  Future<String> exportToFile(String directoryPath) async {
    final json = await exportToJson();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-')
        .substring(0, 19);
    final fileName = 'zonewapp_backup_$timestamp.json';
    final file = File('$directoryPath/$fileName');
    await file.writeAsString(json);
    return file.path;
  }

  /// Export to the app's default documents directory.
  Future<String> exportToDefault() async {
    final dir = await getApplicationDocumentsDirectory();
    return exportToFile(dir.path);
  }

  /// Import from a JSON string.
  Future<bool> importFromJson(String jsonStr) async {
    try {
      final data = jsonDecode(jsonStr);

      if (data['settings'] != null) {
        final settings = AppSettings.fromJson(
            Map<String, dynamic>.from(data['settings']));
        await saveSettings(settings);
      }

      if (data['accounts'] != null) {
        // Clear existing accounts first
        await _accountsBox?.clear();

        for (final accountJson in data['accounts']) {
          final decoded = Map<String, dynamic>.from(accountJson);
          if (decoded['password'] != null) {
            decoded['password'] = CryptoUtils.decrypt(decoded['password']);
          }
          final account = Account.fromJson(decoded);
          await addAccount(account);
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Import from a file path.
  Future<bool> importFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      final jsonStr = await file.readAsString();
      return importFromJson(jsonStr);
    } catch (e) {
      return false;
    }
  }

  /// Get a summary of what will be backed up.
  Future<Map<String, dynamic>> getBackupSummary() async {
    final settings = await loadSettings();
    final accounts = await loadAccounts();
    return {
      'accounts': accounts.length,
      'aiMode': settings.aiMode ?? '未配置',
      'themeMode': settings.themeMode,
      'hasTemplates': settings.aiConfig?['taskTemplates'] != null,
    };
  }
}
