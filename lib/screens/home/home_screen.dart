import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../providers/account_provider.dart';
import '../../providers/automation_provider.dart';
import '../../services/automation_service.dart';
import '../../services/notification_service.dart';
import '../../models/account.dart';
import '../../screens/webview/automation_webview_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountProvider);
    final automation = ref.watch(automationProvider);
    final incompleteAccounts = ref.watch(incompleteAccountsProvider);

    final currentAccount = incompleteAccounts.isNotEmpty ? incompleteAccounts.first : null;
    final totalAccounts = accounts.length;
    final completedAccounts = accounts.where((a) => a.status == '已完成').length;
    final progress = totalAccounts > 0 ? completedAccounts / totalAccounts : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Account info card
          if (currentAccount != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentAccount.username,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '班主任: ${currentAccount.teacherName}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        currentAccount.status,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Progress card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircularPercentIndicator(
                    radius: 60,
                    lineWidth: 8,
                    percent: progress,
                    center: Text(
                      '${(progress * 100).toInt()}%',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    progressColor: Theme.of(context).colorScheme.primary,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    circularStrokeCap: CircularStrokeCap.round,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '完成进度',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '$completedAccounts / $totalAccounts 账号已完成',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Progress grid
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
                        '项目进度',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: automation.isRunning
                            ? () {
                                AutomationService.instance.stopAutomation();
                                ref.read(automationProvider.notifier).stopAutomation();
                              }
                            : () {
                                if (currentAccount != null) {
                                  _startAutomation(context, ref, currentAccount);
                                }
                              },
                        icon: Icon(automation.isRunning ? Icons.stop : Icons.play_arrow),
                        label: Text(automation.isRunning ? '结束' : '开始'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.5,
                    children: [
                      _buildProgressItem('材料排序', 'green', context),
                      _buildProgressItem('任职情况', 'blue', context),
                      _buildProgressItem('奖惩情况', 'blue', context),
                      _buildProgressItem('体育锻炼', 'red', context),
                      _buildProgressItem('心理素质', 'red', context),
                      _buildProgressItem('陈述报告', 'red', context),
                      _buildProgressItem('党团活动', 'red', context),
                      _buildProgressItem('志愿服务', 'red', context),
                      _buildProgressItem('艺术素养', 'red', context),
                      _buildProgressItem('劳动实践', 'red', context),
                      _buildProgressItem('课题研究', 'red', context),
                      _buildProgressItem('项目设计', 'red', context),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Current task info
          if (automation.isRunning) ...[
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '正在执行: ${automation.currentTask ?? "..."}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: automation.progress / 100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${automation.progress.toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressItem(String name, String color, BuildContext context) {
    Color bgColor;
    Color textColor;
    switch (color) {
      case 'green':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      case 'blue':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        break;
      default:
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Center(
        child: Text(
          name,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _startAutomation(BuildContext context, WidgetRef ref, Account account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('开始自动化'),
        content: Text('确定要开始为账号 ${account.username} 执行自动化任务吗？\n\n将打开 WebView 页面进行自动化操作。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);

              // Set up callbacks
              ref.read(automationProvider.notifier).startAutomation(account);
              AutomationService.instance.onProgressUpdate = (progress, task) {
                ref.read(automationProvider.notifier).updateProgress(progress, task);
                NotificationService.instance.showProgressNotification(
                  progress: progress.toInt(),
                  account: account.username,
                  currentTask: task ?? '',
                );
              };
              AutomationService.instance.onTaskComplete = (task) {
                ref.read(automationProvider.notifier).completeTask(task);
              };
              AutomationService.instance.onError = (error) {
                ref.read(automationProvider.notifier).setError(error);
                NotificationService.instance.showErrorNotification(
                  account: account.username,
                  error: error,
                );
              };

              // Navigate to WebView screen for automation
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AutomationWebViewScreen(
                    account: account,
                  ),
                ),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
