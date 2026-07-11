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
import 'help_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  String _lanIp = 'localhost';

  @override
  void initState() {
    super.initState();
    _loadLanIp();
  }

  Future<void> _loadLanIp() async {
    try {
      for (final iface in await NetworkInterface.list()) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            if (mounted) setState(() => _lanIp = addr.address);
            return;
          }
        }
      }
    } catch (_) {}
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
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.language),
                title: const Text('Web服务'),
                subtitle: Text(WebServerService.instance.isRunning
                    ? '运行中 - ${settings.lanAccessEnabled ? _lanIp : "127.0.0.1"}:${settings.webServicePort}'
                    : '未运行'),
                value: WebServerService.instance.isRunning,
                onChanged: (value) async {
                  if (value) {
                    await WebServerService.instance.start(
                      lanAccess: settings.lanAccessEnabled,
                      port: settings.webServicePort,
                    );
                    // Show access token to user
                    if (mounted) {
                      _showTokenDialog();
                    }
                  } else {
                    await WebServerService.instance.stop();
                  }
                  setState(() {});
                },
              ),
              if (WebServerService.instance.isRunning) ...[
                const Divider(height: 1),
                // Access token display
                ListTile(
                  leading: const Icon(Icons.key, size: 20),
                  title: const Text('访问令牌', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    WebServerService.instance.accessToken ?? '未生成',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      // Copy token to clipboard
                    },
                  ),
                ),
              ],
              const Divider(height: 1),
              // LAN access toggle
              SwitchListTile(
                secondary: const Icon(Icons.wifi),
                title: const Text('局域网访问'),
                subtitle: const Text('允许局域网内其他设备访问 Web 管理界面'),
                value: settings.lanAccessEnabled,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).updateLanAccess(value);
                  // If server is running, restart with new settings
                  if (WebServerService.instance.isRunning) {
                    WebServerService.instance.stop();
                    WebServerService.instance.start(
                      lanAccess: value,
                      port: settings.webServicePort,
                    );
                    setState(() {});
                  }
                },
              ),
              const Divider(height: 1),
              // Port configuration
              ListTile(
                leading: const Icon(Icons.numbers),
                title: const Text('端口号'),
                subtitle: Text('${settings.webServicePort}'),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: () => _showPortDialog(settings.webServicePort),
              ),
            ],
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

        // Help
        Card(
          child: ListTile(
            leading: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.primary),
            title: const Text('使用帮助'),
            subtitle: const Text('功能说明、变量列表、常见问题'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpScreen()),
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

  void _showTokenDialog() {
    final settings = ref.read(settingsProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('访问令牌'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请在浏览器中输入此令牌进行登录：'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                WebServerService.instance.accessToken ?? '',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '访问地址: http://${settings.lanAccessEnabled ? _lanIp : "127.0.0.1"}:${settings.webServicePort}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showPortDialog(int currentPort) {
    final controller = TextEditingController(text: currentPort.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置端口号'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '端口号',
            hintText: '1024-65535',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final port = int.tryParse(controller.text);
              if (port != null && port >= 1024 && port <= 65535) {
                ref.read(settingsProvider.notifier).updateWebServicePort(port);
                // Restart server if running
                if (WebServerService.instance.isRunning) {
                  WebServerService.instance.stop();
                  WebServerService.instance.start(
                    lanAccess: ref.read(settingsProvider).lanAccessEnabled,
                    port: port,
                  );
                  setState(() {});
                }
                Navigator.pop(context);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
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
