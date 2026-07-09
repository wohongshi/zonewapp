import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/task_template.dart';
import '../../services/form_scraper_service.dart';
import '../../services/ai_form_filler_service.dart';
import '../../services/ai_service.dart';

/// Integrated browser for 综评 platform with visual scraping,
/// AI content generation, and auto-fill capabilities.
class ZongpingBrowserScreen extends StatefulWidget {
  final TaskTemplate template;

  const ZongpingBrowserScreen({super.key, required this.template});

  @override
  State<ZongpingBrowserScreen> createState() => _ZongpingBrowserScreenState();
}

class _ZongpingBrowserScreenState extends State<ZongpingBrowserScreen> {
  late final WebViewController _webController;
  bool _isLoading = true;
  String _currentUrl = '';
  String _pageTitle = '';

  // Scraping state
  List<ScrapedField> _scrapedFields = [];
  bool _isScraping = false;

  // AI state
  bool _isGenerating = false;
  String? _aiResponse;
  List<FieldFillPlan> _fillPlans = [];

  // Fill state
  bool _isFilling = false;
  List<String> _fillResults = [];

  // Panel state
  int _selectedTab = 0; // 0=scrape, 1=ai, 2=fill

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            setState(() => _isLoading = progress < 100);
          },
          onPageStarted: (url) {
            setState(() {
              _currentUrl = url;
              _isLoading = true;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _currentUrl = url;
              _isLoading = false;
            });
            // Auto-scrape after page loads
            _autoScrape();
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.template.url));

    FormScraperService.instance.setController(_webController);
  }

  Future<void> _autoScrape() async {
    setState(() => _isScraping = true);
    try {
      final fields = await FormScraperService.instance.scrapeFormFields();
      setState(() {
        _scrapedFields = fields;
        _isScraping = false;
      });
    } catch (e) {
      setState(() => _isScraping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Top bar with URL
          _buildTopBar(),
          // WebView
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                WebViewWidget(controller: _webController),
                if (_isLoading)
                  const LinearProgressIndicator(),
              ],
            ),
          ),
          // Bottom control panel
          _buildControlPanel(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 8,
        right: 8,
        bottom: 4,
      ),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.template.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _currentUrl,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          IconButton(
            onPressed: () => _webController.reload(),
            icon: const Icon(Icons.refresh, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.45,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tab bar
          _buildTabBar(),
          // Tab content
          Flexible(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildTab(0, Icons.search, '抓取', _scrapedFields.length),
          _buildTab(1, Icons.smart_toy, 'AI生成', _aiResponse != null ? 1 : 0),
          _buildTab(2, Icons.edit, '填写', _fillResults.length),
        ],
      ),
    );
  }

  Widget _buildTab(int index, IconData icon, String label, int badge) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildScrapeTab();
      case 1:
        return _buildAiTab();
      case 2:
        return _buildFillTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ==================== Scrape Tab ====================

  Widget _buildScrapeTab() {
    return Column(
      children: [
        // Action bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isScraping ? null : _autoScrape,
                  icon: _isScraping
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(_isScraping ? '抓取中...' : '重新抓取',
                      style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Fields list
        Flexible(
          child: _scrapedFields.isEmpty
              ? Center(
                  child: Text(
                    _isScraping ? '正在抓取表单...' : '点击"重新抓取"扫描页面表单',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _scrapedFields.length,
                  itemBuilder: (context, index) =>
                      _buildFieldCard(_scrapedFields[index], index),
                ),
        ),
      ],
    );
  }

  Widget _buildFieldCard(ScrapedField field, int index) {
    IconData icon;
    Color color;
    switch (field.tagName) {
      case 'select':
        icon = Icons.arrow_drop_down_circle;
        color = Colors.orange;
        break;
      case 'textarea':
        icon = Icons.notes;
        color = Colors.blue;
        break;
      default:
        icon = Icons.edit_outlined;
        color = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 18),
        title: Text(
          field.displayName,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${field.tagName}${field.type != "text" ? " (${field.type})" : ""} | ${field.selector}',
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: field.currentValue.isNotEmpty
            ? const Icon(Icons.check_circle, color: Colors.green, size: 14)
            : const Icon(Icons.radio_button_unchecked,
                color: Colors.grey, size: 14),
      ),
    );
  }

  // ==================== AI Tab ====================

  Widget _buildAiTab() {
    return Column(
      children: [
        // Generate button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isGenerating ? null : _generateAiContent,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(
                _isGenerating ? 'AI 生成中...' : '一键生成内容',
                style: const TextStyle(fontSize: 13),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),
        // AI response
        Flexible(
          child: _aiResponse == null
              ? const Center(
                  child: Text(
                    '先抓取表单，再点击"一键生成"',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI response text
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: SelectableText(
                          _aiResponse!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Parse result
                      if (_fillPlans.isNotEmpty) ...[
                        Text(
                          '📋 已解析 ${_fillPlans.length} 个字段',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ..._fillPlans.map((plan) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.arrow_right,
                                      size: 14, color: Colors.grey),
                                  Expanded(
                                    child: Text(
                                      '${plan.field.displayName} → ${plan.valueToFill}',
                                      style: const TextStyle(fontSize: 11),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                      const SizedBox(height: 8),
                      // Go to fill tab
                      if (_fillPlans.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _selectedTab = 2),
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            label: const Text('去填写',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // ==================== Fill Tab ====================

  Widget _buildFillTab() {
    return Column(
      children: [
        // Fill all button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _fillPlans.isEmpty || _isFilling
                      ? null
                      : _executeFill,
                  icon: _isFilling
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.done_all, size: 16),
                  label: Text(
                    _isFilling
                        ? '填写中...'
                        : '一键填写 (${_fillPlans.length}项)',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Fill results
        Flexible(
          child: _fillResults.isEmpty
              ? Center(
                  child: Text(
                    _fillPlans.isEmpty
                        ? '请先在"AI生成"标签中生成内容'
                        : '点击"一键填写"开始自动填写',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _fillResults.length,
                  itemBuilder: (context, index) {
                    final result = _fillResults[index];
                    final isSuccess = result.startsWith('✅');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            isSuccess
                                ? Icons.check_circle
                                : Icons.cancel,
                            size: 14,
                            color: isSuccess ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              result.substring(2), // Remove emoji
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==================== Actions ====================

  Future<void> _generateAiContent() async {
    if (_scrapedFields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先抓取表单字段')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _aiResponse = null;
      _fillPlans = [];
    });

    try {
      final template = widget.template;
      final prompt = template.aiPrompt ?? '请根据表单字段生成合适的内容';

      final response = await AiFormFillerService.instance.generateForPage(
        taskType: template.aiTaskType ?? template.id,
        templatePrompt: prompt,
        scrapedFields: _scrapedFields,
      );

      if (response.success) {
        final plans = AiFormFillerService.instance.parseAndMatch(
          aiResponse: response.content,
          fields: _scrapedFields,
        );

        setState(() {
          _aiResponse = response.content;
          _fillPlans = plans;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI生成失败: ${response.error}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('错误: $e')),
        );
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _executeFill() async {
    setState(() {
      _isFilling = true;
      _fillResults = [];
    });

    try {
      final results =
          await AiFormFillerService.instance.executeFillPlan(_fillPlans);
      setState(() => _fillResults = results);

      // Show summary
      if (mounted) {
        final successCount = results.where((r) => r.startsWith('✅')).length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('填写完成: $successCount/${results.length} 项成功'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('填写出错: $e')),
        );
      }
    } finally {
      setState(() => _isFilling = false);
    }
  }
}
