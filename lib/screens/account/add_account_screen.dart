import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/account_provider.dart';
import '../../models/account.dart';

class AddAccountScreen extends ConsumerStatefulWidget {
  final Account? account;

  const AddAccountScreen({super.key, this.account});

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _teacherController = TextEditingController();
  
  final List<String> _selectedSubjects = [];
  final List<PositionEntry> _positions = [];
  final List<RewardEntry> _rewards = [];

  final List<String> _availableSubjects = [
    '物理', '化学', '生物', '政治', '历史', '地理',
  ];

  final List<String> _rewardLevels = [
    '校级_学校',
    '县级_行政部门',
    '市级_行政部门',
    '省级_行政部门',
    '国家级_行政部门',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      _usernameController.text = widget.account!.username;
      _passwordController.text = widget.account!.password;
      _teacherController.text = widget.account!.teacherName;
      _selectedSubjects.addAll(widget.account!.subjects);
      _positions.addAll(widget.account!.positions);
      _rewards.addAll(widget.account!.rewards);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _teacherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account != null ? '编辑账号' : '添加账号'),
        actions: [
          TextButton(
            onPressed: _saveAccount,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Account field
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '账号',
                hintText: '请输入账号',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入账号';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password field
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '密码',
                hintText: '请输入密码',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入密码';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Subject selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '选科 (必须选择3项)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _availableSubjects.map((subject) {
                        final isSelected = _selectedSubjects.contains(subject);
                        return FilterChip(
                          label: Text(subject),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                if (_selectedSubjects.length < 3) {
                                  _selectedSubjects.add(subject);
                                }
                              } else {
                                _selectedSubjects.remove(subject);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    if (_selectedSubjects.length != 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '请选择3个科目',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Teacher name
            TextFormField(
              controller: _teacherController,
              decoration: const InputDecoration(
                labelText: '班主任姓名',
                hintText: '请输入班主任姓名',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.school),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入班主任姓名';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Positions section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '任职情况',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        IconButton(
                          onPressed: _addPosition,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    ..._positions.asMap().entries.map((entry) {
                      return ListTile(
                        title: Text(entry.value.title),
                        subtitle: Text(entry.value.description),
                        trailing: IconButton(
                          onPressed: () {
                            setState(() {
                              _positions.removeAt(entry.key);
                            });
                          },
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Rewards section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '奖惩情况',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        IconButton(
                          onPressed: _addReward,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    ..._rewards.asMap().entries.map((entry) {
                      return ListTile(
                        title: Text(entry.value.title),
                        subtitle: Text('${entry.value.level} - ${entry.value.department}'),
                        trailing: IconButton(
                          onPressed: () {
                            setState(() {
                              _rewards.removeAt(entry.key);
                            });
                          },
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            FilledButton(
              onPressed: _saveAccount,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _addPosition() {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加任职'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '职务',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: '职务描述',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                setState(() {
                  _positions.add(PositionEntry(
                    id: const Uuid().v4(),
                    title: titleController.text,
                    description: descController.text,
                  ));
                });
              }
              Navigator.pop(context);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _addReward() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedLevel = _rewardLevels.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加奖惩'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '奖惩名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedLevel,
                decoration: const InputDecoration(
                  labelText: '奖励等级',
                  border: OutlineInputBorder(),
                ),
                items: _rewardLevels.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedLevel = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: '描述',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  setState(() {
                    _rewards.add(RewardEntry(
                      id: const Uuid().v4(),
                      title: titleController.text,
                      level: selectedLevel,
                      department: selectedLevel,
                      imagePath: null,
                    ));
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveAccount() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubjects.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择3个科目')),
      );
      return;
    }

    final account = Account(
      id: widget.account?.id ?? const Uuid().v4(),
      username: _usernameController.text,
      password: _passwordController.text,
      subjects: _selectedSubjects,
      teacherName: _teacherController.text,
      positions: _positions,
      rewards: _rewards,
      status: widget.account?.status ?? '未完成',
      createdAt: widget.account?.createdAt ?? DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    if (widget.account != null) {
      ref.read(accountProvider.notifier).updateAccount(account);
    } else {
      ref.read(accountProvider.notifier).addAccount(account);
    }

    Navigator.pop(context, true);
  }
}
