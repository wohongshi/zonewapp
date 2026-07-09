import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../services/web_server_service.dart';
import 'ai_mode_screen.dart';
import 'template_list_screen.dart';
import 'content_settings_screen.dart';
import 'backup_restore_screen.dart';
import 'about_screen.dart';
import 'debug_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  String get _lanIp {
    try {
      for (final iface in NetworkInterface.listSync()) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return 'localhost';
  }
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Theme setting
        Card(
          child: ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('主题'),
            subtitle: Text(_getThemeName(settings.themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeDialog(),
          ),
        ),
        const SizedBox(height: 8),

        // AI Mode setting
        Card(
          child: ListTile(
            leading: const Icon(Icons.smart_toy),
            title: const Text('AI模式选择'),
            subtitle: Text(settings.aiMode == 'api' ? 'API模式' : settings.aiMode == 'web' ? '网页模式' : '未配置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AiModeScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Content settings
        Card(
          child: ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('创新探究内容设置'),
            subtitle: const Text('设置各科目的探究内容'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContentSettingsScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Template config
        Card(
          child: ListTile(
            leading: Icon(Icons.view_list, color: Theme.of(context).colorScheme.primary),
            title: const Text('综评项目配置'),
            subtitle: const Text('配置12个综评项目的页面URL和表单选择器'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TemplateListScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Backup & Restore
        Card(
          child: ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('备份与恢复'),
            subtitle: const Text('备份和恢复应用数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BackupRestoreScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Notification setting
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('通知'),
            subtitle: const Text('开启/关闭通知提醒'),
            value: settings.notificationEnabled,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).updateNotification(value);
            },
          ),
        ),
        const SizedBox(height: 8),

        // Web Service
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.language),
            title: const Text('Web服务'),
            subtitle: Text(WebServerService.instance.isRunning
                ? '运行中 - $_lanIp:35535'
                : '未运行'),
            value: WebServerService.instance.isRunning,
            onChanged: (value) async {
              if (value) {
                await WebServerService.instance.start();
              } else {
                await WebServerService.instance.stop();
              }
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: 8),

        // Predictive Back
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.swipe),
            title: const Text('手势预测返回'),
            subtitle: const Text('Android 预测性返回动画（需重启生效）'),
            value: settings.predictiveBackEnabled,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).updatePredictiveBack(value);
            },
          ),
        ),
        const SizedBox(height: 8),

        // Debug
        Card(
          child: ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('调试'),
            subtitle: const Text('API连接性检测与诊断'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DebugScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // About
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              radius: 16,
              child: Icon(Icons.info, size: 20),
            ),
            title: const Text('关于'),
            subtitle: const Text('软件信息'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getThemeName(String mode) {
    switch (mode) {
      case 'light':
        return '白天模式';
      case 'dark':
        return '夜间模式';
      case 'system':
        return '跟随系统';
      case 'monet':
        return '莫奈取色';
      default:
        return '跟随系统';
    }
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption('light', '白天模式', Icons.light_mode),
            _buildThemeOption('dark', '夜间模式', Icons.dark_mode),
            _buildThemeOption('system', '跟随系统', Icons.phone_android),
            _buildThemeOption('monet', '莫奈取色', Icons.palette),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(String value, String label, IconData icon) {
    final settings = ref.watch(settingsProvider);
    final isSelected = settings.themeMode == value;

    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
      onTap: () {
        ref.read(settingsProvider.notifier).updateThemeMode(value);
        Navigator.pop(context);
      },
    );
  }
}
