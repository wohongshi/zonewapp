import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/task_template.dart';
import '../../providers/settings_provider.dart';
import '../../providers/account_provider.dart';
import 'template_editor_screen.dart';
import 'zongping_browser_screen.dart';

class TemplateListScreen extends ConsumerStatefulWidget {
  const TemplateListScreen({super.key});

  @override
  ConsumerState<TemplateListScreen> createState() =>
      _TemplateListScreenState();
}

class _TemplateListScreenState extends ConsumerState<TemplateListScreen> {
  List<TaskTemplate> _templates = [];
  final _loginUrlController = TextEditingController();
  final _baseUrlController = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _loginUrlController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  void _ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    try {
      final settings = ref.read(settingsProvider);
      final config = settings.aiConfig ?? {};
      final templateData = config['taskTemplates'];

      _loginUrlController.text =
          config['loginUrl'] ?? 'https://szpj.sdei.edu.cn/zhszpj/web/login.htm';
      _baseUrlController.text =
          config['baseUrl'] ?? 'https://szpj.sdei.edu.cn/zhszpj/web';

      if (templateData != null && templateData is List && templateData.isNotEmpty) {
        _templates = templateData
            .map((e) {
              try {
                return TaskTemplate.fromJson(Map<String, dynamic>.from(e));
              } catch (_) {
                return null;
              }
            })
            .whereType<TaskTemplate>()
            .toList();
      }

      // Only load defaults if no templates at all
      if (_templates.isEmpty) {
        _templates = TaskTemplate.defaults();
      }
    } catch (_) {
      _templates = TaskTemplate.defaults();
    }
  }

  Future<void> _saveTemplates() async {
    final templateJson = _templates.map((t) => t.toJson()).toList();
    final currentConfig =
        Map<String, dynamic>.from(ref.read(settingsProvider).aiConfig ?? {});
    currentConfig['taskTemplates'] = templateJson;
    currentConfig['loginUrl'] = _loginUrlController.text.trim();
    currentConfig['baseUrl'] = _baseUrlController.text.trim();

    await ref.read(settingsProvider.notifier).updateAiConfig(currentConfig);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 配置已保存')),
      );
    }
  }

  void _onTemplateUpdated(int index, TaskTemplate updated) {
    setState(() => _templates[index] = updated);
    _saveTemplates();
  }

  @override
  Widget build(BuildContext context) {
    _ensureLoaded();
    final accounts = ref.watch(accountProvider);
    final configuredCount =
        _templates.where((t) => t.steps.any((s) => s.selector.isNotEmpty)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('综评项目配置'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _templates = TaskTemplate.defaults();
                _loaded = false;
              });
            },
            child: const Text('重置默认'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== 登录网址 =====
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.login,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('登录网址',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _loginUrlController,
                    decoration: const InputDecoration(
                      labelText: '综评平台登录页',
                      hintText: 'https://szpj.sdei.edu.cn/zhszpj/web/login.htm',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _saveTemplates(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ===== 账号提示 =====
          if (accounts.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.people, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '已有 ${accounts.length} 个账号，综评填写时可选择账号自动填充内容',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ]),
              ),
            ),
          if (accounts.isNotEmpty) const SizedBox(height: 12),

          // ===== 进度 =====
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.settings,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('12 个综评项目',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: configuredCount / 12,
                    backgroundColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 4),
                  Text('已配置 $configuredCount / 12 个项目',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ===== 项目列表 =====
          ..._templates.asMap().entries.map((entry) {
            final index = entry.key;
            final t = entry.value;
            final hasSelectors = t.steps.any((s) => s.selector.isNotEmpty);

            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: t.enabled
                      ? (hasSelectors
                          ? Colors.green.shade100
                          : Colors.orange.shade100)
                      : Colors.grey.shade200,
                  child: Text('${index + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        color: t.enabled
                            ? (hasSelectors ? Colors.green : Colors.orange)
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      )),
                ),
                title: Row(children: [
                  Text(t.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: t.enabled ? null : Colors.grey,
                      )),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: t.useAi
                          ? Colors.blue.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: t.useAi
                            ? Colors.blue.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Text(
                      t.useAi ? 'AI' : '直接',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: t.useAi
                            ? Colors.blue.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ),
                ]),
                subtitle: Text(
                  t.url.replaceAll(
                      'https://szpj.sdei.edu.cn/zhszpj/web/', ''),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Switch(
                  value: t.enabled,
                  onChanged: (v) {
                    setState(() => _templates[index] = t.copyWith(enabled: v));
                    _saveTemplates();
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onTap: () => _openBrowser(index),
                onLongPress: () => _editTemplate(index),
              ),
            );
          }),

          // ===== 基础网址 =====
          const SizedBox(height: 4),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.language, size: 18),
                    const SizedBox(width: 8),
                    Text('基础网址',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                      hintText: 'https://szpj.sdei.edu.cn/zhszpj/web',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link, size: 16),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: (_) => _saveTemplates(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          Text(
            '💡 点击项目 → 内置浏览器 | 长按 → 快速编辑',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: _saveTemplates,
            icon: const Icon(Icons.save),
            label: const Text('保存所有配置'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  void _openBrowser(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ZongpingBrowserScreen(
          template: _templates[index],
          loginUrl: _loginUrlController.text.trim(),
          onStepsChanged: (updated) => _onTemplateUpdated(index, updated),
        ),
      ),
    );
  }

  Future<void> _editTemplate(int index) async {
    final result = await Navigator.push<TaskTemplate>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TemplateEditorScreen(template: _templates[index]),
      ),
    );
    if (result != null) {
      setState(() => _templates[index] = result);
      _saveTemplates();
    }
  }
}
