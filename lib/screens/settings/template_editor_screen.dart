import 'package:flutter/material.dart';
import '../models/task_template.dart';

/// Screen for editing a single task template.
class TemplateEditorScreen extends StatefulWidget {
  final TaskTemplate template;

  const TemplateEditorScreen({super.key, required this.template});

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _aiPromptController;
  late List<TemplateStep> _steps;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template.name);
    _urlController = TextEditingController(text: widget.template.url);
    _aiPromptController =
        TextEditingController(text: widget.template.aiPrompt ?? '');
    _steps = List.from(widget.template.steps);
    _enabled = widget.template.enabled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _aiPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('编辑: ${widget.template.name}'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Basic info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('基本信息',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('启用'),
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '项目名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: '页面 URL',
                      hintText: 'https://szpj.sdei.edu.cn/zhszpj/web/...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // AI prompt
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI 提示词',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    '使用 {title} 作为变量名（如职务名称、奖惩名称）',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _aiPromptController,
                    decoration: const InputDecoration(
                      labelText: 'AI 提示词模板',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Steps
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('操作步骤',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: _addStep,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '按顺序执行的操作。使用 {ai_content} 作为 AI 生成内容的占位符。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (_steps.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('暂无步骤，点击 + 添加',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                  ..._steps.asMap().entries.map((entry) =>
                      _buildStepCard(entry.key, entry.value)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Help
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡 操作类型说明',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _helpItem('click', '点击元素 — 需要填写 CSS 选择器'),
                  _helpItem('fill', '填写输入框 — 选择器 + 填写内容'),
                  _helpItem('select', '下拉选择 — 选择器 + 选项值'),
                  _helpItem('wait', '等待 — 填写等待时间(毫秒)'),
                  _helpItem('screenshot', '截图保存 — 无需填写'),
                  _helpItem('navigate', '跳转页面 — 填写 URL'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(int index, TemplateStep step) {
    IconData icon;
    Color color;
    switch (step.action) {
      case 'click':
        icon = Icons.touch_app;
        color = Colors.blue;
        break;
      case 'fill':
        icon = Icons.edit;
        color = Colors.green;
        break;
      case 'select':
        icon = Icons.arrow_drop_down;
        color = Colors.orange;
        break;
      case 'wait':
        icon = Icons.timer;
        color = Colors.grey;
        break;
      case 'screenshot':
        icon = Icons.camera_alt;
        color = Colors.purple;
        break;
      case 'navigate':
        icon = Icons.open_in_browser;
        color = Colors.teal;
        break;
      default:
        icon = Icons.help;
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(step.description.isNotEmpty
            ? step.description
            : step.action),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('类型: ${step.action}',
                style: const TextStyle(fontSize: 12)),
            if (step.selector.isNotEmpty)
              Text('选择器: ${step.selector}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (step.value != null && step.value!.isNotEmpty)
              Text('值: ${step.value}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _editStep(index),
              icon: const Icon(Icons.edit, size: 18),
            ),
            IconButton(
              onPressed: () => setState(() => _steps.removeAt(index)),
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpItem(String action, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(action,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(desc, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  void _addStep() {
    _showStepDialog(null);
  }

  void _editStep(int index) {
    _showStepDialog(_steps[index], index: index);
  }

  void _showStepDialog(TemplateStep? step, {int? index}) {
    final actionController =
        TextEditingController(text: step?.action ?? 'click');
    final selectorController =
        TextEditingController(text: step?.selector ?? '');
    final valueController =
        TextEditingController(text: step?.value ?? '');
    final descController =
        TextEditingController(text: step?.description ?? '');
    final waitController =
        TextEditingController(text: step?.waitMs?.toString() ?? '1000');

    String selectedAction = step?.action ?? 'click';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(step == null ? '添加步骤' : '编辑步骤'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedAction,
                  decoration: const InputDecoration(
                    labelText: '操作类型',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'click', child: Text('点击 (click)')),
                    DropdownMenuItem(value: 'fill', child: Text('填写 (fill)')),
                    DropdownMenuItem(value: 'select', child: Text('选择 (select)')),
                    DropdownMenuItem(value: 'wait', child: Text('等待 (wait)')),
                    DropdownMenuItem(
                        value: 'screenshot', child: Text('截图 (screenshot)')),
                    DropdownMenuItem(
                        value: 'navigate', child: Text('跳转 (navigate)')),
                  ],
                  onChanged: (v) {
                    setDialogState(() => selectedAction = v!);
                    actionController.text = v!;
                  },
                ),
                const SizedBox(height: 12),
                if (selectedAction != 'screenshot' &&
                    selectedAction != 'wait')
                  TextField(
                    controller: selectorController,
                    decoration: const InputDecoration(
                      labelText: 'CSS 选择器',
                      hintText: '#input-id, .class, button[type=submit]',
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (selectedAction == 'fill' ||
                    selectedAction == 'select' ||
                    selectedAction == 'navigate') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: selectedAction == 'navigate'
                        ? TextEditingController(text: step?.value ?? '')
                        : valueController,
                    decoration: InputDecoration(
                      labelText: selectedAction == 'navigate' ? 'URL' : '值',
                      hintText: selectedAction == 'fill'
                          ? '{ai_content} 或固定值'
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                if (selectedAction == 'wait') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: waitController,
                    decoration: const InputDecoration(
                      labelText: '等待时间 (毫秒)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: '步骤说明',
                    hintText: '描述这个步骤做什么',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final newStep = TemplateStep(
                  action: actionController.text,
                  selector: selectorController.text,
                  value: valueController.text.isNotEmpty
                      ? valueController.text
                      : null,
                  description: descController.text,
                  waitMs: selectedAction == 'wait'
                      ? int.tryParse(waitController.text)
                      : null,
                );

                setState(() {
                  if (index != null) {
                    _steps[index] = newStep;
                  } else {
                    _steps.add(newStep);
                  }
                });
                Navigator.pop(context);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final template = widget.template.copyWith(
      name: _nameController.text,
      url: _urlController.text,
      enabled: _enabled,
      steps: _steps,
      aiPrompt: _aiPromptController.text.isNotEmpty
          ? _aiPromptController.text
          : null,
    );
    Navigator.pop(context, template);
  }
}
