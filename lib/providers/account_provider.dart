import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account.dart';
import '../services/storage_service.dart';

class AccountNotifier extends StateNotifier<List<Account>> {
  AccountNotifier() : super([]) {
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await StorageService.instance.loadAccounts();
    state = accounts;
  }

  Future<void> addAccount(Account account) async {
    await StorageService.instance.addAccount(account);
    state = [...state, account];
  }

  Future<void> updateAccount(Account account) async {
    await StorageService.instance.updateAccount(account);
    state = [
      for (final a in state)
        if (a.id == account.id) account else a,
    ];
  }

  Future<void> deleteAccount(String id) async {
    await StorageService.instance.deleteAccount(id);
    state = state.where((a) => a.id != id).toList();
  }

  Future<void> updateAccountStatus(String id, String status) async {
    final account = state.firstWhere((a) => a.id == id);
    final updated = account.copyWith(
      status: status,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await updateAccount(updated);
  }

  Account? getNextIncompleteAccount() {
    final incomplete = state.where((a) => a.status == '未完成').toList();
    incomplete.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return incomplete.isNotEmpty ? incomplete.first : null;
  }

  List<Account> getAccountsByStatus(String status) {
    return state.where((a) => a.status == status).toList();
  }

  Future<void> restoreAccounts(List<Account> accounts) async {
    for (final account in accounts) {
      await StorageService.instance.addAccount(account);
    }
    state = accounts;
  }
}

final accountProvider = StateNotifierProvider<AccountNotifier, List<Account>>((ref) {
  return AccountNotifier();
});

final incompleteAccountsProvider = Provider<List<Account>>((ref) {
  final accounts = ref.watch(accountProvider);
  return accounts.where((a) => a.status == '未完成').toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
});

final completedAccountsProvider = Provider<List<Account>>((ref) {
  return ref.watch(accountProvider).where((a) => a.status == '已完成').toList();
});

final errorAccountsProvider = Provider<List<Account>>((ref) {
  return ref.watch(accountProvider).where((a) => a.status == '状态异常').toList();
});
