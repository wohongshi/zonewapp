import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/account_provider.dart';
import '../../services/storage_service.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _isBacking = false;
  bool _isRestoring = false;
  String? _lastBackupPath;
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final s = await StorageService.instance.getBackupSummary();
    if (mounted) setState(() => _summary = s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== 当前数据概览 =====
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.dashboard,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('当前数据',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  if (_summary != null) ...[
                    _summaryRow('账号数量', '${_summary!['accounts']} 个'),
                    _summaryRow('AI模式', '${_summary!['aiMode']}'),
                    _summaryRow('主题模式', '${_summary!['themeMode']}'),
                    _summaryRow('综评配置',
                        _summary!['hasTemplates'] ? '已配置' : '未配置'),
                  ] else
                    const Text('加载中...',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ===== 备份内容说明 =====
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.inventory_2_outlined,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('备份包含',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  _backupItem('所有账号信息（用户名、密码、选科、职务、奖惩）'),
                  _backupItem('AI模式及API配置'),
                  _backupItem('12个综评项目配置（URL、步骤、AI提示词）'),
                  _backupItem('创新探究内容设置'),
                  _backupItem('主题、通知等偏好设置'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ===== 备份 =====
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.backup,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('备份',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Text('选择一个目录保存备份文件',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  // 选择目录备份
                  FilledButton.icon(
                    onPressed: _isBacking ? null : _backupToDirectory,
                    icon: _isBacking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.folder_open),
                    label: Text(_isBacking ? '备份中...' : '选择目录并备份'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 快速备份到默认目录
                  OutlinedButton.icon(
                    onPressed: _isBacking ? null : _backupToDefault,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('快速备份到应用目录'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                  if (_lastBackupPath != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '上次备份: $_lastBackupPath',
                            style: TextStyle(
                                fontSize: 11, color: Colors.green.shade700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ===== 恢复 =====
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.restore,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('恢复',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Text('从备份文件恢复数据（将覆盖当前数据）',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      )),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isRestoring ? null : _restoreFromFile,
                    icon: _isRestoring
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_file),
                    label: Text(_isRestoring ? '恢复中...' : '选择备份文件恢复'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ===== 危险操作 =====
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.warning_amber, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Text('危险操作',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700)),
                  ]),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _clearAllData,
                    icon: Icon(Icons.delete_forever,
                        color: Colors.red.shade700, size: 18),
                    label: Text('清除所有数据',
                        style: TextStyle(color: Colors.red.shade700)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade300),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _backupItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('• ', style: TextStyle(fontSize: 12)),
        Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12))),
      ]),
    );
  }

  // ==================== Backup ====================

  Future<void> _backupToDirectory() async {
    setState(() => _isBacking = true);
    try {
      // Pick directory
      final dirPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择备份保存位置',
      );
      if (dirPath == null) {
        setState(() => _isBacking = false);
        return;
      }

      final filePath =
          await StorageService.instance.exportToFile(dirPath);
      setState(() => _lastBackupPath = filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ 备份成功\n$filePath'),
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('备份失败: $e')));
      }
    } finally {
      setState(() => _isBacking = false);
    }
  }

  Future<void> _backupToDefault() async {
    setState(() => _isBacking = true);
    try {
      final filePath = await StorageService.instance.exportToDefault();
      setState(() => _lastBackupPath = filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ 备份成功\n$filePath'),
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('备份失败: $e')));
      }
    } finally {
      setState(() => _isBacking = false);
    }
  }

  // ==================== Restore ====================

  Future<void> _restoreFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: '选择备份文件',
    );
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.first.path;
    if (filePath == null) return;

    // Show preview of what will be restored
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认恢复'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('将从以下文件恢复数据：',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Text(filePath,
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 12),
            Text('⚠️ 此操作将覆盖当前所有数据！',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.orange),
            child: const Text('确定恢复'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRestoring = true);
    try {
      final success =
          await StorageService.instance.importFromFile(filePath);

      if (success) {
        ref.invalidate(settingsProvider);
        ref.invalidate(accountProvider);
        await _loadSummary();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ 恢复成功，请重启应用'),
                duration: Duration(seconds: 3)),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('恢复失败，文件格式错误')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('恢复失败: $e')));
      }
    } finally {
      setState(() => _isRestoring = false);
    }
  }

  // ==================== Danger ====================

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除所有数据'),
        content: const Text('确定要清除所有数据吗？\n\n此操作不可恢复！建议先备份。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确定清除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Clear Hive boxes
      await StorageService.instance.init(); // ensure boxes are open
      final settings = ref.read(settingsProvider.notifier);
      final accounts = ref.read(accountProvider.notifier);

      // Reset settings
      await settings.updateThemeMode('system');
      await settings.updateAiMode(null);
      await settings.updateAiConfig(null);

      // Delete all accounts
      final allAccounts = ref.read(accountProvider);
      for (final a in allAccounts) {
        await accounts.deleteAccount(a.id);
      }

      await _loadSummary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 数据已清除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('清除失败: $e')));
      }
    }
  }
}
