import 'package:flutter/material.dart';
import '../models/account.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/web_automation_service.dart';
import '../services/form_scraper_service.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AutomationService {
  static final AutomationService instance = AutomationService._();
  AutomationService._();

  bool _isRunning = false;
  bool _shouldStop = false;
  WebViewController? _webController;

  // Callbacks for UI updates
  Function(double, String?)? onProgressUpdate;
  Function(String)? onTaskComplete;
  Function(String)? onError;
  Function(String)? onLog;

  // Base URLs for the platform
  static const String _baseUrl = 'https://szpj.sdei.edu.cn/zhszpj/web';
  static const String _loginUrl = '$_baseUrl/login.htm';
  static const String _indexUrl = '$_baseUrl/index/xsIndex.htm';

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

  /// Set the WebView controller for browser-based automation.
  void setWebViewController(WebViewController controller) {
    _webController = controller;
    WebAutomationService.instance.setController(controller);
    FormScraperService.instance.setController(controller);
  }

  void _log(String msg) {
    debugPrint('[Automation] $msg');
    onLog?.call(msg);
  }

  Future<void> startAutomation(Account account) async {
    if (_isRunning) return;
    _isRunning = true;
    _shouldStop = false;

    try {
      _log('开始自动化: ${account.username}');

      // Step 1: Login
      onProgressUpdate?.call(0, '登录中...');
      await _login(account);
      if (_shouldStop) return;

      // Step 2: Execute each task
      final totalTasks = _taskNames.length;
      for (int i = 0; i < totalTasks; i++) {
        if (_shouldStop) break;

        final taskName = _taskNames[i];
        final progress = (i / totalTasks) * 100;
        onProgressUpdate?.call(progress, taskName);
        _log('执行任务 ${i + 1}/$totalTasks: $taskName');

        await _executeTask(account, i);
        onTaskComplete?.call(taskName);

        // Wait between tasks to avoid detection
        if (i < totalTasks - 1) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }

      // Done
      onProgressUpdate?.call(100, '完成');
      _log('所有任务完成');

      await StorageService.instance.updateAccount(
        account.copyWith(
          status: '已完成',
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
    } catch (e) {
      _log('错误: $e');
      onError?.call(e.toString());

      await StorageService.instance.updateAccount(
        account.copyWith(
          status: '状态异常',
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
    } finally {
      _isRunning = false;
    }
  }

  Future<void> stopAutomation() async {
    _shouldStop = true;
    _isRunning = false;
    _log('用户停止自动化');
  }

  /// Login to the platform.
  Future<void> _login(Account account) async {
    if (_webController == null) {
      throw Exception('WebView 未初始化，请先进入 WebView 页面');
    }

    _log('导航到登录页...');
    WebAutomationService.instance.navigateTo(_loginUrl);
    await Future.delayed(const Duration(seconds: 3));

    // Try to find and fill login form
    _log('填写账号密码...');
    await WebAutomationService.instance.fillInputByName('username', account.username);
    await Future.delayed(const Duration(milliseconds: 500));
    await WebAutomationService.instance.fillInputByName('password', account.password);
    await Future.delayed(const Duration(milliseconds: 500));

    // Click login button
    _log('点击登录...');
    await WebAutomationService.instance.clickBySelector(
      'button[type="submit"], input[type="submit"], .login-btn, #loginBtn, .btn-login',
    );

    // Wait for navigation
    await Future.delayed(const Duration(seconds: 3));

    // Verify login success by checking if we're on the index page
    _log('验证登录状态...');
    WebAutomationService.instance.navigateTo(_indexUrl);
    await Future.delayed(const Duration(seconds: 2));
    _log('登录完成');
  }

  /// Execute a specific task by index.
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

  // ==================== Task Implementations ====================

  /// Task 1: 材料排序 - Select "无" and screenshot
  Future<void> _taskMaterialSort(Account account) async {
    _log('  材料排序: 导航到页面...');
    WebAutomationService.instance.navigateTo(
      '$_baseUrl/../index/xsCltbIndex.htm',
    );
    await Future.delayed(const Duration(seconds: 3));

    // Try to click "无" option or the "无" button
    _log('  材料排序: 选择"无"...');
    await WebAutomationService.instance.clickBySelector(
      'input[value="无"], button:contains("无"), a:contains("无"), .no-option, [data-value="无"]',
    );
    await Future.delayed(const Duration(seconds: 1));

    // Also try by text content
    await _clickElementByText('无');
    await Future.delayed(const Duration(seconds: 1));
  }

  /// Task 2: 任职情况 - AI generate and fill
  Future<void> _taskPosition(Account account) async {
    if (account.positions.isEmpty) {
      _log('  任职情况: 无职务，选择"无"');
      await _navigateToAndSelectNone(
        '$_baseUrl/jbqk/xsRzqk.htm',
      );
      return;
    }

    _log('  任职情况: 导航到页面...');
    WebAutomationService.instance.navigateTo('$_baseUrl/jbqk/xsRzqk.htm');
    await Future.delayed(const Duration(seconds: 3));

    for (final position in account.positions) {
      if (_shouldStop) break;
      _log('  任职情况: 处理 ${position.title}...');

      final response = await AiService.instance.generateContent(
        'position',
        position.title,
      );

      if (response.success) {
        _log('  AI生成成功，长度: ${response.content.length}');
        await _fillTextAreaWithContent(response.content);
      } else {
        _log('  AI生成失败: ${response.error}');
        onError?.call('任职情况AI生成失败: ${response.error}');
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  /// Task 3: 奖惩情况 - AI generate and fill
  Future<void> _taskReward(Account account) async {
    if (account.rewards.isEmpty) {
      _log('  奖惩情况: 无奖惩，选择"无"');
      await _navigateToAndSelectNone(
        '$_baseUrl/jbqk/xsJcxx.htm',
      );
      return;
    }

    _log('  奖惩情况: 导航到页面...');
    WebAutomationService.instance.navigateTo('$_baseUrl/jbqk/xsJcxx.htm');
    await Future.delayed(const Duration(seconds: 3));

    for (final reward in account.rewards) {
      if (_shouldStop) break;
      _log('  奖惩情况: 处理 ${reward.title}...');

      final response = await AiService.instance.generateContent(
        'reward',
        reward.title,
      );

      if (response.success) {
        _log('  AI生成成功');
        await _fillTextAreaWithContent(response.content);
      } else {
        _log('  AI生成失败: ${response.error}');
        onError?.call('奖惩情况AI生成失败: ${response.error}');
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  /// Task 4: 日常体育锻炼 - Fill attendance 100%
  Future<void> _taskPhysicalEducation(Account account) async {
    _log('  日常体育锻炼: 导航到页面...');
    WebAutomationService.instance.navigateTo('$_baseUrl/sxjk/xsTydl.htm');
    await Future.delayed(const Duration(seconds: 3));

    _log('  日常体育锻炼: 填写出勤率100%...');
    // Try common field selectors for attendance rate
    await FormScraperService.instance.fillField(
      'input[name*="attendance"], input[name*="cql"], input[id*="attendance"], input[id*="cql"]',
      '100',
    );
    await FormScraperService.instance.fillField(
      'input[name*="exercise"], input[name*="tydl"], input[id*="exercise"]',
      '100',
    );

    // Fallback: scrape the form and fill any number input with 100
    final fields = await FormScraperService.instance.scrapeFormFields();
    for (final field in fields) {
      if (field.type == 'number' && !field.isClickable) {
        await FormScraperService.instance.fillField(field.selector, '100');
      }
    }
    await Future.delayed(const Duration(seconds: 1));
  }

  /// Task 5: 心理素质展示 - AI generate
  Future<void> _taskPsychology(Account account) async {
    _log('  心理素质展示: 导航到页面...');
    WebAutomationService.instance.navigateTo('$_baseUrl/sxjk/xsSxjk.htm');
    await Future.delayed(const Duration(seconds: 3));

    _log('  心理素质展示: AI生成内容...');
    final response = await AiService.instance.generateContent('psychology', '');
    if (response.success) {
      _log('  AI生成成功，长度: ${response.content.length}');
      await _fillTextAreaWithContent(response.content);
    } else {
      _log('  AI生成失败: ${response.error}');
      onError?.call('心理素质AI生成失败: ${response.error}');
    }
  }

  /// Task 6: 陈述报告 - AI generate
  Future<void> _taskStatement(Account account) async {
    _log('  陈述报告: 导航到页面...');
    WebAutomationService.instance.navigateTo('$_baseUrl/csbg/xsCsbg.htm');
    await Future.delayed(const Duration(seconds: 3));

    _log('  陈述报告: AI生成内容...');
    final response = await AiService.instance.generateContent('statement', '');
    if (response.success) {
      _log('  AI生成成功，长度: ${response.content.length}');
      await _fillTextAreaWithContent(response.content);
    } else {
      _log('  AI生成失败: ${response.error}');
      onError?.call('陈述报告AI生成失败: ${response.error}');
    }
  }

  /// Task 7: 党团活动 - AI generate
  Future<void> _taskPartyActivity(Account account) async {
    _log('  党团活动: 导航到页面...');
    WebAutomationService.instance.navigateTo('$_baseUrl/sxpd/xsDxsl.htm');
    await Future.delayed(const Duration(seconds: 3));

    _log('  党团活动: AI生成内容...');
    final response = await AiService.instance.generateContent('party_activity', '');
    if (response.success) {
      _log('  AI生成成功，长度: ${response.content.length}');
      await _fillTextAreaWithContent(response.content);
    } else {
      _log('  AI生成失败: ${response.error}');
      onError?.call('党团活动AI生成失败: ${response.error}');
    }
  }

  /// Task 8: 志愿服务 - AI generate
  Future<void> _taskVolunteer(Account account) async {
    _log('  志愿服务: 导航到页面...');
    WebAutomationService.instance.navigateTo('$_baseUrl/sxpd/xsDxsl.htm');
    await Future.delayed(const Duration(seconds: 3));

    _log('  志愿服务: AI生成内容...');
    final response = await AiService.instance.generateContent('volunteer', '');
    if (response.success) {
      _log('  AI生成成功，长度: ${response.content.length}');
      await _fillTextAreaWithContent(response.content);
    } else {
      _log('  AI生成失败: ${response.error}');
      onError?.call('志愿服务AI生成失败: ${response.error}');
    }
  }

  /// Task 9: 艺术素养 - AI generate
  Future<void> _taskArt(Account account) async {
    _log('  艺术素养: 导航到页面...');
    WebAutomationService.instance.navigateTo('$_baseUrl/yssy/xsYssy.htm');
    await Future.delayed(const Duration(seconds: 3));

    _log('  艺术素养: AI生成内容...');
    final response = await AiService.instance.generateContent('art', '');
    if (response.success) {
      _log('  AI生成成功，长度: ${response.content.length}');
      await _fillTextAreaWithContent(response.content);
    } else {
      _log('  AI生成失败: ${response.error}');
      onError?.call('艺术素养AI生成失败: ${response.error}');
    }
  }

  /// Task 10: 劳动与实践 - AI generate
  Future<void> _taskLabor(Account account) async {
    _log('  劳动与实践: 导航到页面...');
    WebAutomationService.instance.navigateTo('$_baseUrl/shsj/xsShsj.htm');
    await Future.delayed(const Duration(seconds: 3));

    _log('  劳动与实践: AI生成内容...');
    final response = await AiService.instance.generateContent('labor', '');
    if (response.success) {
      _log('  AI生成成功，长度: ${response.content.length}');
      await _fillTextAreaWithContent(response.content);
    } else {
      _log('  AI生成失败: ${response.error}');
      onError?.call('劳动实践AI生成失败: ${response.error}');
    }
  }

  /// Task 11: 课题研究 - AI generate
  Future<void> _taskResearch(Account account) async {
    _log('  课题研究: 导航到页面...');
    WebAutomationService.instance.navigateTo('$_baseUrl/xysp/xsYjxxxjcxcg.htm');
    await Future.delayed(const Duration(seconds: 3));

    _log('  课题研究: AI生成内容...');
    final response = await AiService.instance.generateContent('research', '');
    if (response.success) {
      _log('  AI生成成功，长度: ${response.content.length}');
      await _fillTextAreaWithContent(response.content);
    } else {
      _log('  AI生成失败: ${response.error}');
      onError?.call('课题研究AI生成失败: ${response.error}');
    }
  }

  /// Task 12: 项目设计 - AI generate
  Future<void> _taskProjectDesign(Account account) async {
    _log('  项目设计: 导航到页面...');
    WebAutomationService.instance.navigateTo('$_baseUrl/xysp/xsYjxxxjcxcg.htm');
    await Future.delayed(const Duration(seconds: 3));

    _log('  项目设计: AI生成内容...');
    final response = await AiService.instance.generateContent('project_design', '');
    if (response.success) {
      _log('  AI生成成功，长度: ${response.content.length}');
      await _fillTextAreaWithContent(response.content);
    } else {
      _log('  AI生成失败: ${response.error}');
      onError?.call('项目设计AI生成失败: ${response.error}');
    }
  }

  // ==================== Helper Methods ====================

  /// Navigate to a page and select "无" option.
  Future<void> _navigateToAndSelectNone(String url) async {
    WebAutomationService.instance.navigateTo(url);
    await Future.delayed(const Duration(seconds: 3));

    // Try clicking "无" by various methods
    await WebAutomationService.instance.clickBySelector(
      'input[value="无"], button:contains("无"), a:contains("无")',
    );
    await _clickElementByText('无');
    await Future.delayed(const Duration(seconds: 1));
  }

  /// Fill the main textarea on a page with AI-generated content.
  /// Automatically finds textarea fields and fills the first one.
  Future<void> _fillTextAreaWithContent(String content) async {
    final fields = await FormScraperService.instance.scrapeFormFields();

    // Find textarea first, then text inputs
    final textareas = fields.where((f) => f.tagName == 'textarea' && !f.isClickable).toList();
    final textInputs = fields.where(
      (f) => f.tagName == 'input' && (f.type == 'text' || f.type == '') && !f.isClickable,
    ).toList();

    if (textareas.isNotEmpty) {
      // Fill textarea
      await FormScraperService.instance.fillField(textareas.first.selector, content);
      _log('  已填写到 textarea: ${textareas.first.displayName}');
    } else if (textInputs.isNotEmpty) {
      // Fill first text input
      await FormScraperService.instance.fillField(textInputs.first.selector, content);
      _log('  已填写到 input: ${textInputs.first.displayName}');
    } else {
      // Fallback: try common selectors
      await FormScraperService.instance.fillField('textarea', content);
      _log('  已填写到 textarea (fallback selector)');
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Try to click an element by its visible text content.
  Future<void> _clickElementByText(String text) async {
    if (_webController == null) return;
    try {
      final safeText = text.replaceAll("'", "\\'");
      await _webController!.runJavaScript('''
        (function() {
          var elements = document.querySelectorAll('a, button, input[type="button"], input[type="submit"], span, div, label, li');
          for (var i = 0; i < elements.length; i++) {
            var el = elements[i];
            var txt = (el.innerText || el.value || '').trim();
            if (txt === '$safeText' || txt.indexOf('$safeText') >= 0) {
              el.click();
              return true;
            }
          }
          return false;
        })();
      ''');
    } catch (e) {
      _log('  点击元素失败: $e');
    }
  }
}
