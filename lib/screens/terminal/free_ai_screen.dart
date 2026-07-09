import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../services/ai_service.dart';
import '../../models/settings.dart';
import 'terminal_screen.dart';

/// Free AI configuration screen - lets users choose between
/// Option A: Connect to external WebAI2API server
/// Option B: Local deployment via embedded terminal
class FreeAiScreen extends ConsumerStatefulWidget {
  const FreeAiScreen({super.key});

  @override
  ConsumerState<FreeAiScreen> createState() => _FreeAiScreenState();
}

class _FreeAiScreenState extends ConsumerState<FreeAiScreen> {
  // Option A: External server
  final _serverUrlController = TextEditingController();
  final _serverTokenController = TextEditingController();
  String _selectedModel = 'deepseek-chat';
  bool _isTesting = false;
  String? _testResult;

  // State
  String _mode = 'none'; // 'none', 'external', 'local'

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final settings = ref.read(settingsProvider);
    if (settings.aiMode == 'free_external') {
      _mode = 'external';
      if (settings.aiConfig != null) {
        _serverUrlController.text = settings.aiConfig!['serverUrl'] ?? '';
        _serverTokenController.text = settings.aiConfig!['serverToken'] ?? '';
        _selectedModel = settings.aiConfig!['model'] ?? 'deepseek-chat';
      }
    } else if (settings.aiMode == 'free_local') {
      _mode = 'local';
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _serverTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('免费 AI'),
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
                        Text(
                          '免费 AI 服务',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '通过 WebAI2API 免费使用 DeepSeek、ChatGPT、Gemini 等',
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

          // Option A: External server
          _buildModeCard(
            mode: 'external',
            icon: Icons.cloud,
            title: '连接外部服务',
            subtitle: '在电脑/服务器上运行 WebAI2API，手机通过网络连接',
            pros: ['不占用手机资源', '支持所有模型', '稳定性更好'],
            cons: ['需要额外设备', '需要网络配置'],
          ),
          const SizedBox(height: 12),

          // Option B: Local deployment
          _buildModeCard(
            mode: 'local',
            icon: Icons.phone_android,
            title: '本地自动部署',
            subtitle: '在手机上一键部署 WebAI2API（需要 Termux）',
            pros: ['无需额外设备', '完全免费', '离线可用'],
            cons: ['占用手机资源', '首次部署较慢'],
          ),
          const SizedBox(height: 16),

          // Mode-specific content
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
      onTap: () => setState(() => _mode = mode),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ...pros.map((p) => Chip(
                      label: Text('✓ $p',
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    )),
                ...cons.map((c) => Chip(
                      label: Text('✗ $c',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.orange)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalConfig() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('外部服务配置',
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
                prefixIcon: Icon(Icons.smart_toy),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'deepseek-chat', child: Text('DeepSeek')),
                DropdownMenuItem(
                    value: 'gpt-4o-mini', child: Text('ChatGPT (GPT-4o Mini)')),
                DropdownMenuItem(
                    value: 'gemini-2.0-flash',
                    child: Text('Gemini 2.0 Flash')),
                DropdownMenuItem(
                    value: 'doubao', child: Text('豆包')),
              ],
              onChanged: (v) => setState(() => _selectedModel = v!),
            ),
            const SizedBox(height: 16),

            // Test & Save buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow),
                    label: Text(_isTesting ? '测试中...' : '测试连接'),
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

            // Test result
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

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text('📋 部署指南',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildStep('1', '在电脑上安装 Node.js (v20+)'),
            _buildStep('2', '运行: npm install -g webai-2api'),
            _buildStep('3', '运行: webai-2api start'),
            _buildStep('4', '在 WebUI 中登录 AI 账号'),
            _buildStep('5', '将地址填入上方输入框'),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalConfig() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本地部署',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '在手机上通过内置终端部署 WebAI2API，首次使用需要安装运行环境。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            // Status check
            FutureBuilder<Map<String, bool>>(
              future: _checkLocalStatus(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                final status = snapshot.data!;
                return Column(
                  children: [
                    _buildStatusItem('Termux 环境', status['termux']!),
                    _buildStatusItem('Node.js', status['node']!),
                    _buildStatusItem('WebAI2API', status['webai']!),
                    _buildStatusItem('服务运行中', status['running']!),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Action buttons
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TerminalScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.terminal),
              label: const Text('打开终端'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                _showDeployGuide(context);
              },
              icon: const Icon(Icons.help_outline),
              label: const Text('部署指南'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(num,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, bool ok) {
    return ListTile(
      dense: true,
      leading: Icon(
        ok ? Icons.check_circle : Icons.cancel,
        color: ok ? Colors.green : Colors.red,
        size: 20,
      ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: ok
          ? null
          : TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TerminalScreen(),
                  ),
                );
              },
              child: const Text('安装'),
            ),
    );
  }

  Future<Map<String, bool>> _checkLocalStatus() async {
    // Check Termux
    final termuxExists = await _fileExists(
        '/data/data/com.termux/files/usr/bin/bash');
    // Check Node.js in Termux
    final nodeExists = await _fileExists(
        '/data/data/com.termux/files/usr/bin/node');
    // Check WebAI2API
    final webaiExists = await _fileExists(
        '/data/data/com.termux/files/home/WebAI2API/package.json');
    // Check if service is running (simplified check)
    final running = false; // TODO: implement actual check

    return {
      'termux': termuxExists,
      'node': nodeExists,
      'webai': webaiExists,
      'running': running,
    };
  }

  Future<bool> _fileExists(String path) async {
    try {
      return (await FileSystemEntity.type(path)) !=
          FileSystemEntityType.notFound;
    } catch (_) {
      return false;
    }
  }

  Future<void> _testConnection() async {
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

      // Use AI service to test
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
        if (response.success) {
          _testResult = '✅ 连接成功: ${response.content}';
        } else {
          _testResult = '❌ 连接失败: ${response.error}';
        }
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ 测试异常: $e';
      });
    } finally {
      setState(() => _isTesting = false);
    }
  }

  Future<void> _saveExternalConfig() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入服务器地址')),
      );
      return;
    }

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

  void _showDeployGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Termux 部署指南',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _deployStep('1', '安装 Termux',
                '从 F-Droid 下载安装 Termux（不要用 Play Store 版本）'),
            _deployStep('2', '安装依赖',
                'pkg update && pkg install nodejs git python'),
            _deployStep('3', '克隆项目',
                'git clone https://github.com/foxhui/WebAI2API.git\ncd WebAI2API'),
            _deployStep('4', '安装依赖',
                'npm install\nnpm run init'),
            _deployStep('5', '启动服务',
                'npm start\n\n服务启动后访问 http://localhost:3000 登录 AI 账号'),
            _deployStep('6', '连接 App',
                '回到本页面选择「连接外部服务」，地址填 http://localhost:3000'),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  '💡 提示：Termux 中首次运行 npm run init 会下载浏览器，'
                  '请确保网络通畅。建议使用 WiFi。',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deployStep(String num, String title, String code) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(num,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Colors.greenAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
