import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../models/settings.dart';
import '../../services/ai_service.dart';

class AiModeScreen extends ConsumerStatefulWidget {
  const AiModeScreen({super.key});

  @override
  ConsumerState<AiModeScreen> createState() => _AiModeScreenState();
}

class _AiModeScreenState extends ConsumerState<AiModeScreen> {
  String? _selectedMode;
  
  // API mode controllers
  final _apiNameController = TextEditingController();
  final _apiUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _apiModelController = TextEditingController();
  double _temperature = 0.7;
  int _maxTokens = 500;

  // Web mode controllers
  String _webPlatform = 'deepseek';
  final _webCookiesController = TextEditingController();
  final _webSessionController = TextEditingController();

  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _selectedMode = settings.aiMode;
    
    if (settings.aiConfig != null) {
      if (_selectedMode == 'api') {
        final config = ApiConfig.fromJson(settings.aiConfig!);
        _apiNameController.text = config.name;
        _apiUrlController.text = config.apiUrl;
        _apiKeyController.text = config.apiKey;
        _apiModelController.text = config.model;
        _temperature = config.temperature;
        _maxTokens = config.maxTokens;
      } else if (_selectedMode == 'web') {
        // WebAI2API mode
        _webCookiesController.text = settings.aiConfig!['serverUrl'] ?? '';
        _webSessionController.text = settings.aiConfig!['serverToken'] ?? '';
        _webPlatform = settings.aiConfig!['model'] ?? 'deepseek-chat';
      }
    }
  }

  @override
  void dispose() {
    _apiNameController.dispose();
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _apiModelController.dispose();
    _webCookiesController.dispose();
    _webSessionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI模式选择'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Mode selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择AI模式',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildModeOption(
                    'api',
                    'API模式',
                    '使用AI厂商提供的API接口',
                    Icons.api,
                  ),
                  const SizedBox(height: 8),
                  _buildModeOption(
                    'web',
                    'WebAI2API',
                    '通过 WebAI2API 免费使用 DeepSeek/GPT/Gemini',
                    Icons.api,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Mode specific settings
          if (_selectedMode == 'api') _buildApiSettings(),
          if (_selectedMode == 'web') _buildWebSettings(),

          const SizedBox(height: 16),

          // Test button
          FilledButton.icon(
            onPressed: _isTesting ? null : _testConnection,
            icon: _isTesting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_isTesting ? '测试中...' : '测试'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),

          // Test result
          if (_testResult != null) ...[
            const SizedBox(height: 16),
            Card(
              color: _testResult!.startsWith('成功')
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_testResult!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeOption(String value, String title, String subtitle, IconData icon) {
    final isSelected = _selectedMode == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMode = value;
        });
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
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : null),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildApiSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'API配置',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiNameController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '例如: OpenAI, Claude',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiUrlController,
              decoration: const InputDecoration(
                labelText: 'API地址',
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
                hintText: 'gpt-4, claude-3, etc.',
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
              onChanged: (value) {
                setState(() {
                  _temperature = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Text('Max Tokens: $_maxTokens'),
            Slider(
              value: _maxTokens.toDouble(),
              min: 100,
              max: 2000,
              divisions: 19,
              onChanged: (value) {
                setState(() {
                  _maxTokens = value.toInt();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WebAI2API 配置',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '需要先在电脑/服务器或 Termux 中部署 WebAI2API 服务',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _webCookiesController,
              decoration: const InputDecoration(
                labelText: 'WebAI2API 地址',
                hintText: 'http://192.168.1.100:3000',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _webSessionController,
              decoration: const InputDecoration(
                labelText: 'API Token（可选）',
                hintText: '配置文件中的 auth 值',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _webPlatform,
              decoration: const InputDecoration(
                labelText: '模型',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.smart_toy),
              ),
              items: const [
                DropdownMenuItem(value: 'deepseek-chat', child: Text('DeepSeek')),
                DropdownMenuItem(value: 'gpt-4o-mini', child: Text('ChatGPT')),
                DropdownMenuItem(value: 'gemini-2.0-flash', child: Text('Gemini')),
                DropdownMenuItem(value: 'doubao', child: Text('豆包')),
              ],
              onChanged: (value) {
                setState(() {
                  _webPlatform = value!;
                });
              },
            ),
            const SizedBox(height: 12),
            Text(
              '📋 部署指南: github.com/foxhui/WebAI2API',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    // Save current config first
    await _saveConfig();

    final response = await AiService.instance.testConnection();

    setState(() {
      _isTesting = false;
      if (response.success) {
        _testResult = '成功: ${response.content}';
      } else {
        _testResult = '失败: ${response.error ?? "未知错误"}';
      }
    });
  }

  Future<void> _saveConfig() async {
    if (_selectedMode == 'api') {
      final config = ApiConfig(
        name: _apiNameController.text,
        apiUrl: _apiUrlController.text,
        apiKey: _apiKeyController.text,
        model: _apiModelController.text,
        temperature: _temperature,
        maxTokens: _maxTokens,
      );
      AiService.instance.setApiMode(config);
      await ref.read(settingsProvider.notifier).updateAiMode('api');
      await ref.read(settingsProvider.notifier).updateAiConfig(config.toJson());
    } else if (_selectedMode == 'web') {
      // WebAI2API mode - use ApiConfig pointing to WebAI2API endpoint
      final serverUrl = _webCookiesController.text.trim();
      final token = _webSessionController.text.trim();
      final config = ApiConfig(
        name: 'WebAI2API',
        apiUrl: '$serverUrl/v1/chat/completions',
        apiKey: token,
        model: _webPlatform,
        temperature: 0.7,
        maxTokens: 500,
      );
      AiService.instance.setApiMode(config);
      await ref.read(settingsProvider.notifier).updateAiMode('web');
      await ref.read(settingsProvider.notifier).updateAiConfig({
        'serverUrl': serverUrl,
        'serverToken': token,
        'model': _webPlatform,
      });
    }
  }
}
