import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../models/settings.dart';
import '../../services/ai_service.dart';
import '../../services/webai2api_service.dart';
import '../terminal/terminal_screen.dart';

class AiModeScreen extends ConsumerStatefulWidget {
  const AiModeScreen({super.key});

  @override
  ConsumerState<AiModeScreen> createState() => _AiModeScreenState();
}

class _AiModeScreenState extends ConsumerState<AiModeScreen> {
  String? _selectedMode;

  // API mode
  final _apiUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _apiModelController = TextEditingController();
  double _temperature = 0.7;
  int _maxTokens = 500;

  // WebAI2API mode
  String _webaiSubMode = 'external'; // 'external' or 'local'
  final _webaiUrlController = TextEditingController();
  final _webaiTokenController = TextEditingController();
  String _webaiModel = 'deepseek-chat';
  bool _webaiTesting = false;
  String? _webaiTestResult;



  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadConfig();

  }

  void _loadConfig() {
    final settings = ref.read(settingsProvider);
    _selectedMode = settings.aiMode ?? 'api';

    if (settings.aiConfig != null) {
      final config = settings.aiConfig!;
      if (_selectedMode == 'api') {
        _apiUrlController.text = config['apiUrl'] ?? '';
        _apiKeyController.text = config['apiKey'] ?? '';
        _apiModelController.text = config['model'] ?? '';
        _temperature = (config['temperature'] ?? 0.7).toDouble();
        _maxTokens = config['maxTokens'] ?? 500;
      } else if (_selectedMode == 'webai2api') {
        _webaiSubMode = config['subMode'] ?? 'external';
        _webaiUrlController.text = config['serverUrl'] ?? '';
        _webaiTokenController.text = config['serverToken'] ?? '';
        _webaiModel = config['model'] ?? 'deepseek-chat';
      }
    }
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _apiModelController.dispose();
    _webaiUrlController.dispose();
    _webaiTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 模式选择')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Mode selection
          Text('选择 AI 模式',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _buildModeCard(
            mode: 'api',
            icon: Icons.api,
            title: 'API 模式',
            subtitle: '使用 OpenAI 兼容的 API 接口',
            tag: '付费',
            tagColor: Colors.orange,
          ),
          const SizedBox(height: 8),
          _buildModeCard(
            mode: 'webai2api',
            icon: Icons.cloud_sync,
            title: 'WebAI2API 模式',
            subtitle: '免费使用 DeepSeek / ChatGPT / Gemini',
            tag: '免费',
            tagColor: Colors.green,
          ),

          const SizedBox(height: 16),

          // Mode content
          if (_selectedMode == 'api') _buildApiSettings(),
          if (_selectedMode == 'webai2api') _buildWebaiSettings(),

        ],
      ),
    );
  }

  // ==================== Mode Card ====================

  Widget _buildModeCard({
    required String mode,
    required IconData icon,
    required String title,
    required String subtitle,
    String? tag,
    Color? tagColor,
  }) {
    final isSelected = _selectedMode == mode;
    return InkWell(
      onTap: () {
        setState(() => _selectedMode = mode);
        _saveConfig();
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
                  Row(
                    children: [
                      Text(title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          )),
                      if (tag != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: tagColor?.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(tag,
                              style: TextStyle(
                                  fontSize: 10, color: tagColor)),
                        ),
                      ],
                    ],
                  ),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall),
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

  // ==================== API Mode ====================

  Widget _buildApiSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('API 配置',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _apiUrlController,
              decoration: const InputDecoration(
                labelText: 'API 地址',
                hintText: 'https://api.openai.com/v1/chat/completions',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiModelController,
              decoration: const InputDecoration(
                labelText: '模型',
                hintText: 'gpt-4, deepseek-chat, etc.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text('Temperature: ${_temperature.toStringAsFixed(1)}'),
            Slider(
              value: _temperature,
              min: 0,
              max: 2,
              divisions: 20,
              onChanged: (v) => setState(() => _temperature = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testApi,
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
                    onPressed: _saveConfig,
                    icon: const Icon(Icons.save),
                    label: const Text('保存'),
                  ),
                ),
              ],
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 8),
              Text(_testResult!,
                  style: TextStyle(
                      color: _testResult!.startsWith('✅')
                          ? Colors.green
                          : Colors.red,
                      fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _testApi() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });
    final config = ApiConfig(
      name: 'Custom',
      apiUrl: _apiUrlController.text,
      apiKey: _apiKeyController.text,
      model: _apiModelController.text,
      temperature: _temperature,
      maxTokens: _maxTokens,
    );
    AiService.instance.setApiMode(config);
    final resp = await AiService.instance.testConnection();
    setState(() {
      _isTesting = false;
      _testResult = resp.success ? '✅ ${resp.content}' : '❌ ${resp.error}';
    });
  }

  // ==================== WebAI2API Mode ====================

  Widget _buildWebaiSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WebAI2API 配置',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('免费使用 DeepSeek / ChatGPT / Gemini 等',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),

            // Sub-mode toggle
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _webaiSubMode = 'external'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _webaiSubMode == 'external'
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '外部服务',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _webaiSubMode == 'external'
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _webaiSubMode = 'local'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _webaiSubMode == 'local'
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '本地部署',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _webaiSubMode == 'local'
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_webaiSubMode == 'external') _buildWebaiExternal(),
            if (_webaiSubMode == 'local') _buildWebaiLocal(),
          ],
        ),
      ),
    );
  }

  Widget _buildWebaiExternal() {
    return Column(
      children: [
        TextField(
          controller: _webaiUrlController,
          decoration: const InputDecoration(
            labelText: 'WebAI2API 地址',
            hintText: 'http://192.168.1.100:3000',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _webaiTokenController,
          decoration: const InputDecoration(
            labelText: 'API Token（可选）',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.key),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _webaiModel,
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
            DropdownMenuItem(value: 'doubao', child: Text('豆包')),
          ],
          onChanged: (v) => setState(() => _webaiModel = v!),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _webaiTesting ? null : _testWebai,
                icon: _webaiTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow),
                label: Text(_webaiTesting ? '测试中...' : '测试连接'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _saveConfig,
                icon: const Icon(Icons.save),
                label: const Text('保存'),
              ),
            ),
          ],
        ),
        if (_webaiTestResult != null) ...[
          const SizedBox(height: 8),
          Text(_webaiTestResult!,
              style: TextStyle(
                  color: _webaiTestResult!.startsWith('✅')
                      ? Colors.green
                      : Colors.red,
                  fontSize: 13)),
        ],
      ],
    );
  }

  Widget _buildWebaiLocal() {
    final svc = WebAi2ApiService.instance;
    return Column(
      children: [
        // Service status with address
        FutureBuilder<Map<String, dynamic>>(
          future: _checkLocalFullStatus(),
          builder: (context, snapshot) {
            final status = snapshot.data ?? {};
            final installed = status['installed'] ?? false;
            final running = status['running'] ?? false;
            final token = status['token'] as String?;

            return Card(
              color: running
                  ? Colors.green.shade50
                  : installed
                      ? Colors.orange.shade50
                      : Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          running
                              ? Icons.check_circle
                              : installed
                                  ? Icons.pause_circle
                                  : Icons.cancel,
                          color: running
                              ? Colors.green
                              : installed
                                  ? Colors.orange
                                  : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          running
                              ? '服务运行中'
                              : installed
                                  ? '已安装，未启动'
                                  : '未安装',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (running) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('📡 服务地址',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            SelectableText(
                              svc.lanUrl,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                color: Colors.blue,
                              ),
                            ),
                            if (token != null) ...[
                              const SizedBox(height: 4),
                              Text('Token: $token',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                            const SizedBox(height: 4),
                            const Text(
                              '在 WebAI2API 外部模式中填入上方地址',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // One-click deploy
        FilledButton.icon(
          onPressed: _oneClickDeploy,
          icon: const Icon(Icons.rocket_launch),
          label: const Text('一键部署'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 8),

        // One-click start / stop
        if (WebAi2ApiService.instance.isRunning)
          OutlinedButton.icon(
            onPressed: _oneClickStop,
            icon: const Icon(Icons.stop, color: Colors.red),
            label: const Text('停止服务', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: Colors.red),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: _oneClickStart,
            icon: const Icon(Icons.play_circle),
            label: const Text('一键启动'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        const SizedBox(height: 8),

        // Auto-start toggle
        SwitchListTile(
          title: const Text('App 启动时自动运行'),
          subtitle: const Text('打开 App 自动启动 WebAI2API 服务'),
          value: true,
          onChanged: (v) {
            // TODO: save auto-start preference
          },
        ),
        const SizedBox(height: 8),

        // Open terminal
        TextButton.icon(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TerminalScreen())),
          icon: const Icon(Icons.terminal),
          label: const Text('打开终端（高级操作）'),
        ),
        const SizedBox(height: 12),

        // Save
        FilledButton.icon(
          onPressed: _saveConfig,
          icon: const Icon(Icons.save),
          label: const Text('保存配置'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }

  Widget _statusRow(String label, bool ok) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(
        ok ? Icons.check_circle : Icons.cancel,
        color: ok ? Colors.green : Colors.red,
        size: 20,
      ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }

  Future<Map<String, dynamic>> _checkLocalFullStatus() async {
    final svc = WebAi2ApiService.instance;
    final installed = await _fileExists(
        '/data/data/com.termux/files/home/WebAI2API/package.json');
    final running = installed ? await svc.healthCheck() : false;
    final token = installed ? await svc.getApiToken() : null;
    return {
      'installed': installed,
      'running': running,
      'token': token,
    };
  }

  Future<Map<String, bool>> _checkLocalStatus() async {
    return {
      'termux': await _fileExists(
          '/data/data/com.termux/files/usr/bin/bash'),
      'node': await _fileExists(
          '/data/data/com.termux/files/usr/bin/node'),
      'webai': await _fileExists(
          '/data/data/com.termux/files/home/WebAI2API/package.json'),
      'running': await WebAi2ApiService.instance.healthCheck(),
    };
  }

  Future<bool> _fileExists(String path) async {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<void> _testWebai() async {
    setState(() {
      _webaiTesting = true;
      _webaiTestResult = null;
    });
    try {
      final url = _webaiUrlController.text.trim();
      if (url.isEmpty) {
        setState(() {
          _webaiTestResult = '❌ 请输入地址';
          _webaiTesting = false;
        });
        return;
      }
      final config = ApiConfig(
        name: 'WebAI2API',
        apiUrl: '$url/v1/chat/completions',
        apiKey: _webaiTokenController.text.trim(),
        model: _webaiModel,
        temperature: 0.7,
        maxTokens: 100,
      );
      AiService.instance.setApiMode(config);
      final resp = await AiService.instance.testConnection();
      setState(() {
        _webaiTestResult =
            resp.success ? '✅ ${resp.content}' : '❌ ${resp.error}';
      });
    } catch (e) {
      setState(() => _webaiTestResult = '❌ $e');
    } finally {
      setState(() => _webaiTesting = false);
    }
  }

  void _oneClickDeploy() {
    final deployScript = '''
echo "=============================="
echo " WebAI2API 一键部署"
echo "=============================="
echo ""

if [ ! -d "/data/data/com.termux" ]; then
  echo "❌ 未检测到 Termux，请先安装 Termux"
  echo "   下载地址: https://f-droid.org/packages/com.termux/"
  exit 1
fi

echo "[1/4] 更新软件包..."
pkg update -y && pkg upgrade -y

echo "[2/4] 安装依赖..."
pkg install -y nodejs git python

echo "[3/4] 克隆 WebAI2API..."
cd ~
if [ -d "WebAI2API" ]; then
  echo "   已存在，更新中..."
  cd WebAI2API && git pull
else
  git clone https://github.com/foxhui/WebAI2API.git
  cd WebAI2API
fi

echo "[4/4] 安装依赖..."
npm install

echo ""
echo "=============================="
echo " ✅ 部署完成！"
echo "=============================="
echo ""
echo "📡 服务地址: http://localhost:3000"
echo ""
echo "正在自动启动服务..."
echo ""

npm start
''';

    TerminalService.instance.start();
    Future.delayed(const Duration(seconds: 1), () {
      TerminalService.instance.write(deployScript);
    });

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TerminalScreen()),
    );
  }

  void _oneClickStart() async {
    final svc = WebAi2ApiService.instance;
    final started = await svc.start();
    if (started) {
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 服务已启动\n地址: ${svc.lanUrl}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } else {
      // Fallback: open terminal
      final startScript = '''
echo "启动 WebAI2API..."
cd ~/WebAI2API
npm start
''';
      TerminalService.instance.start();
      Future.delayed(const Duration(seconds: 1), () {
        TerminalService.instance.write(startScript);
      });
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TerminalScreen()),
      );
    }
  }

  void _oneClickStop() async {
    await WebAi2ApiService.instance.stop();
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('服务已停止')),
      );
    }
  }

  // ==================== Save ====================

  Future<void> _saveConfig() async {
    final notifier = ref.read(settingsProvider.notifier);

    if (_selectedMode == 'api') {
      await notifier.updateAiMode('api');
      await notifier.updateAiConfig({
        'apiUrl': _apiUrlController.text,
        'apiKey': _apiKeyController.text,
        'model': _apiModelController.text,
        'temperature': _temperature,
        'maxTokens': _maxTokens,
      });
    } else if (_selectedMode == 'webai2api') {
      await notifier.updateAiMode('webai2api');
      await notifier.updateAiConfig({
        'subMode': _webaiSubMode,
        'serverUrl': _webaiUrlController.text,
        'serverToken': _webaiTokenController.text,
        'model': _webaiModel,
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 配置已保存')),
      );
    }
  }
}
