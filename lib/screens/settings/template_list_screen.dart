import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/task_template.dart';
import '../../providers/settings_provider.dart';
import 'template_editor_screen.dart';

/// Screen for managing all 12 综评 task templates.
class TemplateListScreen extends ConsumerStatefulWidget {
  const TemplateListScreen({super.key});

  @override
  ConsumerState<TemplateListScreen> createState() =>
      _TemplateListScreenState();
}

class _TemplateListScreenState extends ConsumerState<TemplateListScreen> {
  List<TaskTemplate> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  void _loadTemplates() {
    final settings = ref.read(settingsProvider);
    final templateData = settings.aiConfig?['taskTemplates'];

    if (templateData != null && templateData is List) {
      _templates = (templateData as List)
          .map((e) => TaskTemplate.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      // Load defaults
      _templates = TaskTemplate.defaults();
    }
  }

  Future<void> _saveTemplates() async {
    final templateJson = _templates.map((t) => t.toJson()).toList();
    final currentConfig =
        ref.read(settingsProvider).aiConfig ?? {};
    final newConfig = Map<String, dynamic>.from(currentConfig);
    newConfig['taskTemplates'] = templateJson;

    await ref.read(settingsProvider.notifier).updateAiConfig(newConfig);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 模板已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final configuredCount =
        _templates.where((t) => t.steps.any((s) => s.selector.isNotEmpty)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('综评项目配置'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _templates = TaskTemplate.defaults());
            },
            child: const Text('重置默认'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('综评项目自动化配置',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '配置 12 个综评项目的页面 URL、表单选择器和填写规则。\n'
                    '首次使用需要逐个配置，填写各页面的 CSS 选择器。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
          const SizedBox(height: 16),

          // Template list
          ..._templates.asMap().entries.map((entry) {
            final index = entry.key;
            final template = entry.value;
            final hasSelectors =
                template.steps.any((s) => s.selector.isNotEmpty);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: template.enabled
                      ? (hasSelectors
                          ? Colors.green.shade100
                          : Colors.orange.shade100)
                      : Colors.grey.shade200,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: template.enabled
                          ? (hasSelectors ? Colors.green : Colors.orange)
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  template.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: template.enabled ? null : Colors.grey,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.url.replaceAll(
                          'https://szpj.sdei.edu.cn/zhszpj/web/', ''),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (template.aiPrompt != null)
                          const Icon(Icons.smart_toy,
                              size: 12, color: Colors.blue),
                        if (hasSelectors)
                          const Icon(Icons.check_circle,
                              size: 12, color: Colors.green),
                        if (!hasSelectors)
                          const Icon(Icons.warning,
                              size: 12, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          hasSelectors ? '已配置选择器' : '需要配置选择器',
                          style: TextStyle(
                            fontSize: 11,
                            color: hasSelectors ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Switch(
                  value: template.enabled,
                  onChanged: (v) {
                    setState(() {
                      _templates[index] = template.copyWith(enabled: v);
                    });
                  },
                ),
                onTap: () => _editTemplate(index),
              ),
            );
          }),

          const SizedBox(height: 16),

          // Save button
          FilledButton.icon(
            onPressed: _saveTemplates,
            icon: const Icon(Icons.save),
            label: const Text('保存所有配置'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 8),

          // Help
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📋 配置指南',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    '1. 在电脑浏览器中打开综评平台\n'
                    '2. 按 F12 打开开发者工具\n'
                    '3. 用选择工具点击表单元素\n'
                    '4. 记录元素的 id 或 class\n'
                    '5. 在对应项目中填入 CSS 选择器\n\n'
                    '选择器示例：\n'
                    '• #username (id选择器)\n'
                    '• .btn-submit (class选择器)\n'
                    '• button[type=submit] (属性选择器)\n'
                    '• input[name=content] (表单元素)',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    }
  }
}
