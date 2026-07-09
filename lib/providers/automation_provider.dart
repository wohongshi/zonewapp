import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account.dart';

class AutomationState {
  final bool isRunning;
  final double progress;
  final String? currentAccount;
  final String? currentTask;
  final List<TaskItem> tasks;
  final String? error;

  AutomationState({
    this.isRunning = false,
    this.progress = 0.0,
    this.currentAccount,
    this.currentTask,
    this.tasks = const [],
    this.error,
  });

  AutomationState copyWith({
    bool? isRunning,
    double? progress,
    String? currentAccount,
    String? currentTask,
    List<TaskItem>? tasks,
    String? error,
  }) {
    return AutomationState(
      isRunning: isRunning ?? this.isRunning,
      progress: progress ?? this.progress,
      currentAccount: currentAccount ?? this.currentAccount,
      currentTask: currentTask ?? this.currentTask,
      tasks: tasks ?? this.tasks,
      error: error ?? this.error,
    );
  }
}

class TaskItem {
  final String id;
  final String name;
  final String status;
  final String? error;

  TaskItem({
    required this.id,
    required this.name,
    this.status = 'pending',
    this.error,
  });
}

class AutomationNotifier extends StateNotifier<AutomationState> {
  AutomationNotifier() : super(AutomationState());

  void startAutomation(Account account) {
    state = state.copyWith(
      isRunning: true,
      currentAccount: account.username,
      progress: 0.0,
      tasks: _createTasks(),
    );
  }

  void stopAutomation() {
    state = state.copyWith(
      isRunning: false,
      currentAccount: null,
      currentTask: null,
    );
  }

  void updateProgress(double progress, String? currentTask) {
    state = state.copyWith(
      progress: progress,
      currentTask: currentTask,
    );
  }

  void setError(String error) {
    state = state.copyWith(error: error);
  }

  void completeTask(String taskId) {
    final tasks = state.tasks.map((t) {
      if (t.id == taskId) {
        return TaskItem(id: t.id, name: t.name, status: 'completed');
      }
      return t;
    }).toList();
    state = state.copyWith(tasks: tasks);
  }

  List<TaskItem> _createTasks() {
    return [
      TaskItem(id: '1', name: '材料排序'),
      TaskItem(id: '2', name: '任职情况'),
      TaskItem(id: '3', name: '奖惩情况'),
      TaskItem(id: '4', name: '日常体育锻炼'),
      TaskItem(id: '5', name: '心理素质展示'),
      TaskItem(id: '6', name: '陈述报告'),
      TaskItem(id: '7', name: '党团活动'),
      TaskItem(id: '8', name: '志愿服务'),
      TaskItem(id: '9', name: '艺术素养'),
      TaskItem(id: '10', name: '劳动与实践'),
      TaskItem(id: '11', name: '课题研究'),
      TaskItem(id: '12', name: '项目设计'),
    ];
  }
}

final automationProvider = StateNotifierProvider<AutomationNotifier, AutomationState>((ref) {
  return AutomationNotifier();
});
