import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/account_provider.dart';
import '../../models/account.dart';
import 'add_account_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incompleteAccounts = ref.watch(incompleteAccountsProvider);
    final completedAccounts = ref.watch(completedAccountsProvider);
    final errorAccounts = ref.watch(errorAccountsProvider);

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '未完成 (${incompleteAccounts.length})'),
            Tab(text: '已完成 (${completedAccounts.length})'),
            Tab(text: '状态异常 (${errorAccounts.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAccountList(incompleteAccounts, '未完成'),
              _buildAccountList(completedAccounts, '已完成'),
              _buildAccountList(errorAccounts, '状态异常'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountList(List<Account> accounts, String status) {
    return Stack(
      children: [
        if (accounts.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无$status账号',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _addAccount(context),
                  icon: const Icon(Icons.add),
                  label: const Text('添加账号'),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return _buildAccountCard(account);
            },
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _addAccount(context),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountCard(Account account) {
    Color statusColor;
    switch (account.status) {
      case '已完成':
        statusColor = Colors.green;
        break;
      case '状态异常':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showAccountDetails(account),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Icon(Icons.person, color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.username,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '班主任: ${account.teacherName}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      account.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: account.subjects.map((subject) {
                  return Chip(
                    label: Text(subject, style: const TextStyle(fontSize: 12)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _editAccount(account),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('编辑'),
                  ),
                  TextButton.icon(
                    onPressed: () => _deleteAccount(account),
                    icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                    label: const Text('删除', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addAccount(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddAccountScreen()),
    );
    if (result == true) {
      // Account added, list will update automatically
    }
  }

  void _editAccount(Account account) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAccountScreen(account: account),
      ),
    );
    if (result == true) {
      // Account updated
    }
  }

  void _deleteAccount(Account account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账号'),
        content: Text('确定要删除账号 ${account.username} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(accountProvider.notifier).deleteAccount(account.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showAccountDetails(Account account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '账号详情',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('账号', account.username),
              _buildDetailRow('班主任', account.teacherName),
              _buildDetailRow('选科', account.subjects.join(', ')),
              _buildDetailRow('状态', account.status),
              _buildDetailRow('创建时间', account.createdAt.split('T')[0]),
              if (account.positions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '任职情况',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ...account.positions.map((p) => ListTile(
                  title: Text(p.title),
                  subtitle: Text(p.description),
                  leading: const Icon(Icons.work),
                )),
              ],
              if (account.rewards.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '奖惩情况',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ...account.rewards.map((r) => ListTile(
                  title: Text(r.title),
                  subtitle: Text('${r.level} - ${r.department}'),
                  leading: const Icon(Icons.star),
                )),
              ],
              const SizedBox(height: 16),
              Text(
                '项目进度',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildProjectGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildProjectGrid() {
    final projects = [
      '材料排序', '任职情况', '奖惩情况', '体育锻炼',
      '心理素质', '陈述报告', '党团活动', '志愿服务',
      '艺术素养', '劳动实践', '课题研究', '项目设计',
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2,
      ),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              projects[index],
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
