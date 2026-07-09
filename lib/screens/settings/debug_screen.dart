import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../providers/settings_provider.dart';
import '../../providers/account_provider.dart';
import '../../services/ai_service.dart';
import '../../services/storage_service.dart';
import '../../services/web_server_service.dart';
import '../../models/settings.dart';
import '../../utils/constants.dart';

class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  final List<_DebugResult> _results = [];
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('调试'),
        actions: [
          TextButton.icon(
            onPressed: _isRunning ? null : _runAllChecks,
            icon: _isRunning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_isRunning ? '检测中...' : '全部检测'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('快速检测', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildCheckButton('AI API', Icons.smart_toy, () => _checkAiApi()),
                      _buildCheckButton('目标平台', Icons.web, () => _checkPlatform()),
                      _buildCheckButton('本地存储', Icons.storage, () => _checkStorage()),
                      _buildCheckButton('Web服务', Icons.language, () => _checkWebServer()),
                      _buildCheckButton('DeepSeek', Icons.chat, () => _checkDeepSeek()),
                      _buildCheckButton('网络连接', Icons.wifi, () => _checkNetwork()),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // App info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('应用信息', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildInfoRow('版本', 'v1.0.0+1'),
                  _buildInfoRow('AI模式', ref.read(settingsProvider).aiMode ?? '未配置'),
                  _buildInfoRow('账号数量', '${ref.read(accountProvider).length}'),
                  _buildInfoRow('Web服务', WebServerService.instance.isRunning ? '运行中' : '未运行'),
                  _buildInfoRow('目标平台', AppConstants.baseUrl),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Results
          if (_results.isNotEmpty) ...[
            Text('检测结果', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._results.map((r) => _buildResultCard(r)),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckButton(String label, IconData icon, VoidCallback onPressed) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: _isRunning ? null : onPressed,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontFamily: 'monospace'))),
        ],
      ),
    );
  }

  Widget _buildResultCard(_DebugResult result) {
    Color color;
    IconData icon;
    switch (result.status) {
      case _Status.success:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case _Status.error:
        color = Colors.red;
        icon = Icons.error;
        break;
      case _Status.warning:
        color = Colors.orange;
        icon = Icons.warning;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(result.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(result.detail),
        trailing: result.duration != null
            ? Text('${result.duration}ms', style: TextStyle(color: Colors.grey[500], fontSize: 12))
            : null,
      ),
    );
  }

  void _addResult(String name, _Status status, String detail, {int? duration}) {
    setState(() {
      _results.removeWhere((r) => r.name == name);
      _results.insert(0, _DebugResult(name, status, detail, duration));
    });
  }

  Future<void> _runAllChecks() async {
    setState(() {
      _isRunning = true;
      _results.clear();
    });

    await _checkNetwork();
    await _checkPlatform();
    await _checkAiApi();
    await _checkDeepSeek();
    await _checkStorage();
    await _checkWebServer();

    setState(() => _isRunning = false);
  }

  Future<void> _checkNetwork() async {
    final sw = Stopwatch()..start();
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));
      final resp = await dio.get('https://www.baidu.com');
      sw.stop();
      if (resp.statusCode == 200) {
        _addResult('网络连接', _Status.success, '外网连通正常 (baidu.com)', duration: sw.elapsedMilliseconds);
      } else {
        _addResult('网络连接', _Status.warning, '状态码: ${resp.statusCode}');
      }
    } catch (e) {
      sw.stop();
      _addResult('网络连接', _Status.error, '无法连接外网: $e', duration: sw.elapsedMilliseconds);
    }
  }

  Future<void> _checkPlatform() async {
    final sw = Stopwatch()..start();
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
      final resp = await dio.get(AppConstants.loginUrl);
      sw.stop();
      _addResult('目标平台', _Status.success, '可访问 (${resp.statusCode})', duration: sw.elapsedMilliseconds);
    } catch (e) {
      sw.stop();
      _addResult('目标平台', _Status.error, '无法访问: ${_extractError(e)}', duration: sw.elapsedMilliseconds);
    }
  }

  Future<void> _checkAiApi() async {
    final settings = ref.read(settingsProvider);
    if (settings.aiMode == null || settings.aiConfig == null) {
      _addResult('AI API', _Status.warning, '未配置');
      return;
    }

    // Load config into service
    if (settings.aiMode == 'api') {
      final config = ApiConfig.fromJson(settings.aiConfig!);
      AiService.instance.setApiMode(config);
    } else if (settings.aiMode == 'web') {
      final config = WebAiConfig.fromJson(settings.aiConfig!);
      AiService.instance.setWebMode(config);
    }

    final sw = Stopwatch()..start();
    final response = await AiService.instance.testConnection();
    sw.stop();

    if (response.success) {
      _addResult('AI API', _Status.success, '连接成功: ${response.content.substring(0, response.content.length.clamp(0, 50))}', duration: sw.elapsedMilliseconds);
    } else {
      _addResult('AI API', _Status.error, '连接失败: ${response.error}', duration: sw.elapsedMilliseconds);
    }
  }

  Future<void> _checkDeepSeek() async {
    final sw = Stopwatch()..start();
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
      final resp = await dio.get('https://chat.deepseek.com/');
      sw.stop();
      _addResult('DeepSeek', _Status.success, '可访问 (${resp.statusCode})', duration: sw.elapsedMilliseconds);
    } catch (e) {
      sw.stop();
      _addResult('DeepSeek', _Status.error, '无法访问: ${_extractError(e)}', duration: sw.elapsedMilliseconds);
    }
  }

  Future<void> _checkStorage() async {
    try {
      final accounts = await StorageService.instance.loadAccounts();
      final settings = await StorageService.instance.loadSettings();
      _addResult('本地存储', _Status.success, '正常 - ${accounts.length} 个账号, AI模式: ${settings.aiMode ?? "未配置"}');
    } catch (e) {
      _addResult('本地存储', _Status.error, '读取失败: $e');
    }
  }

  Future<void> _checkWebServer() async {
    final isRunning = WebServerService.instance.isRunning;
    if (!isRunning) {
      _addResult('Web服务', _Status.warning, '未运行');
      return;
    }

    final sw = Stopwatch()..start();
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));
      final resp = await dio.get('http://127.0.0.1:35535/api/status');
      sw.stop();
      if (resp.statusCode == 200) {
        _addResult('Web服务', _Status.success, '运行中, API正常', duration: sw.elapsedMilliseconds);
      } else {
        _addResult('Web服务', _Status.warning, '状态码: ${resp.statusCode}');
      }
    } catch (e) {
      sw.stop();
      _addResult('Web服务', _Status.error, 'API不可达: ${_extractError(e)}', duration: sw.elapsedMilliseconds);
    }
  }

  String _extractError(dynamic e) {
    if (e is DioException) {
      return e.message ?? e.type.toString();
    }
    return e.toString();
  }
}

enum _Status { success, error, warning }

class _DebugResult {
  final String name;
  final _Status status;
  final String detail;
  final int? duration;

  _DebugResult(this.name, this.status, this.detail, this.duration);
}
