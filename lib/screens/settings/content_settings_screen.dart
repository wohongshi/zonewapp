import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';

class ContentSettingsScreen extends ConsumerStatefulWidget {
  const ContentSettingsScreen({super.key});

  @override
  ConsumerState<ContentSettingsScreen> createState() => _ContentSettingsScreenState();
}

class _ContentSettingsScreenState extends ConsumerState<ContentSettingsScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _expanded = {};
  bool _hasChanges = false;

  final List<String> _subjects = const [
    '语文', '物理', '化学', '生物', '地理', '历史', '政治',
  ];

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    for (final subject in _subjects) {
      _controllers[subject] = TextEditingController(
        text: settings.subjectContents[subject] ?? '',
      );
      _expanded[subject] = false;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges) {
          final shouldSave = await _showSaveDialog();
          if (shouldSave == true) {
            await _saveAll();
          }
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('创新探究内容设置'),
          actions: [
            IconButton(
              onPressed: _saveAll,
              icon: const Icon(Icons.save),
              tooltip: '保存',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '每个科目的探究内容以逗号分隔，每一项为一个探究内容。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ..._subjects.map((subject) => _buildSubjectCard(subject)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectCard(String subject) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(subject),
        initiallyExpanded: _expanded[subject] ?? false,
        onExpansionChanged: (expanded) {
          setState(() {
            _expanded[subject] = expanded;
          });
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controllers[subject],
                  decoration: const InputDecoration(
                    hintText: '输入探究内容，以逗号分隔',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  onChanged: (value) {
                    setState(() {
                      _hasChanges = true;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '当前内容: ${_controllers[subject]!.text.isEmpty ? "无" : _controllers[subject]!.text}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showSaveDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存修改'),
        content: const Text('是否保存当前修改的内容？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('不保存'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAll() async {
    for (final subject in _subjects) {
      await ref.read(settingsProvider.notifier).updateSubjectContent(
        subject,
        _controllers[subject]!.text,
      );
    }
    setState(() {
      _hasChanges = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功')),
      );
    }
  }
}
