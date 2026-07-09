import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../providers/settings_provider.dart';
import '../../services/ai_service.dart';
import '../../services/webview_ai_service.dart';
import '../../models/settings.dart';
import 'terminal_screen.dart';

/// Free AI configuration screen with three modes:
/// - WebView: Direct WebView-based AI (like WebAI2API but in-app)
/// - External: Connect to external WebAI2API server
/// - Local: Deploy WebAI2API locally via terminal
class FreeAiScreen extends ConsumerStatefulWidget {
  const FreeAiScreen({super.key});

  @override
  ConsumerState<FreeAiScreen> createState() => _FreeAiScreenState();
}

class _FreeAiScreenState extends ConsumerState<FreeAiScreen> {
  // Mode: 'webview', 'external', 'local'
  String _mode = 'webview';

  // WebView mode
  String _webViewPlatform = 'deepseek';
  bool _webViewReady = false;
  String _webViewStatus = '未初始化';
  StreamSubscription<String>? _statusSub;

  // External mode
  final _serverUrlController = TextEditingController();
  final _serverTokenController = TextEditingController();
  String _selectedModel = 'deepseek-chat';
  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final settings = ref.read(settingsProvider);
    if (settings.aiMode == 'free_webview') {
      _mode = 'webview';
      _webViewPlatform = settings.aiConfig?['platform'] ?? 'deepseek';
    } else if (settings.aiMode == 'free_external') {
      _mode = 'external';
      _serverUrlController.text = settings.aiConfig?['serverUrl'] ?? '';
      _serverTokenController.text = settings.aiConfig?['serverToken'] ?? '';
      _selectedModel = settings.aiConfig?['model'] ?? 'deepseek-chat';
    } else if (settings.aiMode == 'free_local') {
      _mode = 'local';
    }

    // Listen to WebView status
    _statusSub = WebViewAiService.instance.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _webViewStatus = status;
          _webViewReady = status == '就绪';
        });
      }
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _serverUrlController.dispose();
    _serverTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('免费 AI'),
        actions: [
          if (_mode == 'webview' && WebViewAiService.instance.controller != null)
            IconButton(
              onPressed: () => _showWebViewDialog(),
              icon: const Icon(Icons.open_in_browser),
              tooltip: '打开浏览器',
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
              child: Row(
                children: [
                  Icon(Icons.auto_awesome,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('免费 AI 服务',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          '通过网页自动化免费使用 DeepSeek/ChatGPT/Gemini',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Mode selection
          Text('选择模式',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _buildModeCard(
            mode: 'webview',
            icon: Icons.phone_android,
            title: 'WebView 模式（推荐）',
            subtitle: '在 App 内直接打开 AI 网页，自动拦截响应',
            pros: ['无需额外设备', '一键使用', '零部署'],
            cons: ['可能被网站检测'],
          ),
          const SizedBox(height: 12),

          _buildModeCard(
            mode: 'external',
            icon: Icons.cloud,
            title: '外部 WebAI2API',
            subtitle: '连接电脑/服务器上的 WebAI2API 服务',
            pros: ['稳定性最好', '支持所有模型'],
            cons: ['需要额外设备'],
          ),
          const SizedBox(height: 12),

          _buildModeCard(
            mode: 'local',
            icon: Icons.terminal,
            title: '本地部署',
            subtitle: '通过内置终端在手机上部署 WebAI2API',
            pros: ['无需额外设备', '完全体方案'],
            cons: ['需要 Termux', '部署复杂'],
          ),
          const SizedBox(height: 16),

          // Mode content
          if (_mode == 'webview') _buildWebViewConfig(),
          if (_mode == 'external') _buildExternalConfig(),
          if (_mode == 'local') _buildLocalConfig(),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String mode,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> pros,
    required List<String> cons,
  }) {
    final isSelected = _mode == mode;
    return InkWell(
      onTap: () {
        setState(() => _mode = mode);
        _saveMode();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity(0.3)
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : null),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      )),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: [
                      ...pros.map((p) => Text('✓ $p',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.green))),
                      ...cons.map((c) => Text('✗ $c',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.orange))),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  // ==================== WebView Mode ====================

  Widget _buildWebViewConfig() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WebView 配置',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Platform selection
            DropdownButtonFormField<String>(
              value: _webViewPlatform,
              decoration: const InputDecoration(
                labelText: 'AI 平台',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.smart_toy),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'deepseek', child: Text('DeepSeek')),
                DropdownMenuItem(
                    value: 'chatgpt', child: Text('ChatGPT')),
                DropdownMenuItem(
                    value: 'gemini', child: Text('Gemini')),
              ],
              onChanged: (v) {
                setState(() => _webViewPlatform = v!});
                _saveMode();
              },
            ),
            const SizedBox(height: 12),

            // Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _webViewReady
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _webViewReady ? Icons.check_circle : Icons.info,
                    color: _webViewReady ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(_webViewStatus,
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            FilledButton.icon(
              onPressed: () => _initWebView(),
              icon: const Icon(Icons.open_in_browser),
              label: const Text('打开 AI 网页并登录'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 8),

            if (_webViewReady) ...[
              OutlinedButton.icon(
                onPressed: () => _testWebView(),
                icon: const Icon(Icons.play_arrow),
                label: const Text('测试发送'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '💡 使用流程：\n'
                  '1. 点击上方按钮打开 AI 网页\n'
                  '2. 在网页中登录你的账号\n'
                  '3. 登录成功后状态会变为「就绪」\n'
                  '4. 之后综评填写会自动使用此 AI',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _initWebView() async {
    await WebViewAiService.instance.init(_webViewPlatform);
    _saveMode();

    if (mounted) {
      _showWebViewDialog();
    }
  }

  void _showWebViewDialog() {
    final controller = WebViewAiService.instance.controller;
    if (controller == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: Column(
          children: [
            AppBar(
              title: Text('$_webViewPlatform 登录'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: WebViewWidget(controller: controller),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _webViewReady
                          ? '✅ 已就绪，可以关闭此窗口'
                          : '请登录后等待状态变为「就绪」',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testWebView() async {
    setState(() => _isTesting = true);

    final response =
        await WebViewAiService.instance.sendMessage('你好，请用一句话介绍自己');

    if (mounted) {
      setState(() => _isTesting = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(response.success ? '✅ 测试成功' : '❌ 测试失败'),
          content: Text(response.success
              ? response.content ?? ''
              : response.error ?? '未知错误'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  // ==================== External Mode ====================

  Widget _buildExternalConfig() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('外部 WebAI2API 配置',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: 'WebAI2API 地址',
                hintText: 'http://192.168.1.100:3000',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _serverTokenController,
              decoration: const InputDecoration(
                labelText: 'API Token（可选）',
                hintText: '配置文件中的 auth 值',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedModel,
              decoration: const InputDecoration(
                labelText: '模型',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'deepseek-chat', child: Text('DeepSeek')),
                DropdownMenuItem(
                    value: 'gpt-4o-mini', child: Text('ChatGPT')),
                DropdownMenuItem(
                    value: 'gemini-2.0-flash', child: Text('Gemini')),
                DropdownMenuItem(
                    value: 'doubao', child: Text('豆包')),
              ],
              onChanged: (v) => setState(() => _selectedModel = v!),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testExternal,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow),
                    label: Text(_isTesting ? '测试中...' : '测试'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saveExternalConfig,
                    icon: const Icon(Icons.save),
                    label: const Text('保存'),
                  ),
                ),
              ],
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 12),
              Card(
                color: _testResult!.startsWith('✅')
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_testResult!,
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _testExternal() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final url = _serverUrlController.text.trim();
      if (url.isEmpty) {
        setState(() {
          _testResult = '❌ 请输入服务器地址';
          _isTesting = false;
        });
        return;
      }

      final config = ApiConfig(
        name: 'WebAI2API',
        apiUrl: '$url/v1/chat/completions',
        apiKey: _serverTokenController.text.trim(),
        model: _selectedModel,
        temperature: 0.7,
        maxTokens: 100,
      );

      AiService.instance.setApiMode(config);
      final response = await AiService.instance.testConnection();

      setState(() {
        _testResult = response.success
            ? '✅ 连接成功: ${response.content}'
            : '❌ 连接失败: ${response.error}';
      });
    } catch (e) {
      setState(() => _testResult = '❌ 测试异常: $e');
    } finally {
      setState(() => _isTesting = false);
    }
  }

  Future<void> _saveExternalConfig() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) return;

    final config = ApiConfig(
      name: 'WebAI2API',
      apiUrl: '$url/v1/chat/completions',
      apiKey: _serverTokenController.text.trim(),
      model: _selectedModel,
      temperature: 0.7,
      maxTokens: 500,
    );

    AiService.instance.setApiMode(config);
    await ref.read(settingsProvider.notifier).updateAiMode('free_external');
    await ref.read(settingsProvider.notifier).updateAiConfig({
      'serverUrl': url,
      'serverToken': _serverTokenController.text.trim(),
      'model': _selectedModel,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 配置已保存')),
      );
    }
  }

  // ==================== Local Mode ====================

  Widget _buildLocalConfig() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本地部署（Termux）',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('通过内置终端在手机上部署 WebAI2API，需要安装 Termux。',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TerminalScreen())),
              icon: const Icon(Icons.terminal),
              label: const Text('打开终端'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Helpers ====================

  void _saveMode() {
    ref.read(settingsProvider.notifier).updateAiMode('free_$_mode');
    if (_mode == 'webview') {
      ref.read(settingsProvider.notifier).updateAiConfig({
        'platform': _webViewPlatform,
      });
    }
  }
}
