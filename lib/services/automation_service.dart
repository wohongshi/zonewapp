import 'dart:async';
import 'package:flutter/material.dart';
import '../models/account.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';

class AutomationService {
  static final AutomationService instance = AutomationService._();
  AutomationService._();

  bool _isRunning = false;
  Function(double, String?)? onProgressUpdate;
  Function(String)? onTaskComplete;
  Function(String)? onError;

  final List<String> _taskNames = [
    '材料排序',
    '任职情况',
    '奖惩情况',
    '日常体育锻炼',
    '心理素质展示',
    '陈述报告',
    '党团活动',
    '志愿服务',
    '艺术素养',
    '劳动与实践',
    '课题研究',
    '项目设计',
  ];

  bool get isRunning => _isRunning;

  Future<void> startAutomation(Account account) async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      final totalTasks = _taskNames.length;
      
      for (int i = 0; i < totalTasks; i++) {
        if (!_isRunning) break;

        final taskName = _taskNames[i];
        final progress = (i / totalTasks) * 100;
        onProgressUpdate?.call(progress, taskName);

        await _executeTask(account, i);
        onTaskComplete?.call(taskName);

        // Wait between tasks
        await Future.delayed(const Duration(seconds: 2));
      }

      // Final screenshot
      onProgressUpdate?.call(100, '完成');
      
      // Update account status
      await StorageService.instance.updateAccount(
        account.copyWith(
          status: '已完成',
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
    } catch (e) {
      onError?.call(e.toString());
    } finally {
      _isRunning = false;
    }
  }

  Future<void> stopAutomation() async {
    _isRunning = false;
  }

  Future<void> _executeTask(Account account, int taskIndex) async {
    switch (taskIndex) {
      case 0:
        await _taskMaterialSort(account);
        break;
      case 1:
        await _taskPosition(account);
        break;
      case 2:
        await _taskReward(account);
        break;
      case 3:
        await _taskPhysicalEducation(account);
        break;
      case 4:
        await _taskPsychology(account);
        break;
      case 5:
        await _taskStatement(account);
        break;
      case 6:
        await _taskPartyActivity(account);
        break;
      case 7:
        await _taskVolunteer(account);
        break;
      case 8:
        await _taskArt(account);
        break;
      case 9:
        await _taskLabor(account);
        break;
      case 10:
        await _taskResearch(account);
        break;
      case 11:
        await _taskProjectDesign(account);
        break;
    }
  }

  /// Navigate to a task page and select "无" (none) option.
  Future<void> _navigateAndSelectNone(String taskType) async {
    debugPrint('  → 导航到 $taskType 页面并选择"无"');
    // This will be handled by the browser-based automation
    // For now, log the action
    await Future.delayed(const Duration(seconds: 1));
  }

  /// Fill form with AI-generated content via browser.
  Future<void> _fillFormWithAiContent(String taskType, String aiContent) async {
    debugPrint('  → 填写 $taskType 表单');
    // This will be handled by the browser-based automation
    // The content needs to be split and filled into multiple fields
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> _taskMaterialSort(Account account) async {
    // Task 1: Click "无" on material sort and take screenshot
    debugPrint('Task 1: 材料排序');
    // WebView automation would go here
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> _taskPosition(Account account) async {
    debugPrint('Task 2: 任职情况');
    if (account.positions.isEmpty) {
      debugPrint('  → 账号无职务，跳过');
      // Navigate to position page and select "无"
      await _navigateAndSelectNone('position');
      return;
    }

    for (final position in account.positions) {
      if (!_isRunning) break;
      debugPrint('  → 处理职务: ${position.title}');
      final response = await AiService.instance.generateContent(
        'position',
        position.title,
      );

      if (response.success) {
        debugPrint('  → AI生成成功: ${response.content.substring(0, 50)}...');
        // Fill the form with AI response via browser
        await _fillFormWithAiContent('position', response.content);
      } else {
        onError?.call('任职情况AI生成失败: ${response.error}');
      }
    }
  }

  Future<void> _taskReward(Account account) async {
    debugPrint('Task 3: 奖惩情况');
    if (account.rewards.isEmpty) {
      debugPrint('  → 账号无奖惩，跳过');
      await _navigateAndSelectNone('reward');
      return;
    }

    for (final reward in account.rewards) {
      if (!_isRunning) break;
      debugPrint('  → 处理奖惩: ${reward.title}');
      final response = await AiService.instance.generateContent(
        'reward',
        reward.title,
      );

      if (response.success) {
        debugPrint('  → AI生成成功');
        await _fillFormWithAiContent('reward', response.content);
      } else {
        onError?.call('奖惩情况AI生成失败: ${response.error}');
      }
    }
  }

  Future<void> _taskPhysicalEducation(Account account) async {
    debugPrint('Task 4: 日常体育锻炼');
    await _fillFormWithAiContent('physical_education', '100');
  }

  Future<void> _taskPsychology(Account account) async {
    debugPrint('Task 5: 心理素质展示');
    final response = await AiService.instance.generateContent('psychology', '');
    if (response.success) {
      await _fillFormWithAiContent('psychology', response.content);
    } else {
      onError?.call('心理素质AI生成失败: ${response.error}');
    }
  }

  Future<void> _taskStatement(Account account) async {
    debugPrint('Task 6: 陈述报告');
    final response = await AiService.instance.generateContent('statement', '');
    if (response.success) {
      await _fillFormWithAiContent('statement', response.content);
    } else {
      onError?.call('陈述报告AI生成失败: ${response.error}');
    }
  }

  Future<void> _taskPartyActivity(Account account) async {
    debugPrint('Task 7: 党团活动');
    final response = await AiService.instance.generateContent('party_activity', '');
    if (response.success) {
      await _fillFormWithAiContent('party_activity', response.content);
    } else {
      onError?.call('党团活动AI生成失败: ${response.error}');
    }
  }

  Future<void> _taskVolunteer(Account account) async {
    debugPrint('Task 8: 志愿服务');
    final response = await AiService.instance.generateContent('volunteer', '');
    if (response.success) {
      await _fillFormWithAiContent('volunteer', response.content);
    } else {
      onError?.call('志愿服务AI生成失败: ${response.error}');
    }
  }

  Future<void> _taskArt(Account account) async {
    debugPrint('Task 9: 艺术素养');
    final response = await AiService.instance.generateContent('art', '');
    if (response.success) {
      await _fillFormWithAiContent('art', response.content);
    } else {
      onError?.call('艺术素养AI生成失败: ${response.error}');
    }
  }

  Future<void> _taskLabor(Account account) async {
    debugPrint('Task 10: 劳动与实践');
    final response = await AiService.instance.generateContent('labor', '');
    if (response.success) {
      await _fillFormWithAiContent('labor', response.content);
    } else {
      onError?.call('劳动实践AI生成失败: ${response.error}');
    }
  }

  Future<void> _taskResearch(Account account) async {
    debugPrint('Task 11: 课题研究');
    final response = await AiService.instance.generateContent('research', '');
    if (response.success) {
      await _fillFormWithAiContent('research', response.content);
    } else {
      onError?.call('课题研究AI生成失败: ${response.error}');
    }
  }

  Future<void> _taskProjectDesign(Account account) async {
    debugPrint('Task 12: 项目设计');
    final response = await AiService.instance.generateContent('project_design', '');
    if (response.success) {
      await _fillFormWithAiContent('project_design', response.content);
    } else {
      onError?.call('项目设计AI生成失败: ${response.error}');
    }
  }
}
