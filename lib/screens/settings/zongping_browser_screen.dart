import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/task_template.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/form_scraper_service.dart';
import '../../services/ai_form_filler_service.dart';

class ZongpingBrowserScreen extends ConsumerStatefulWidget {
  final TaskTemplate template;
  final String? loginUrl;
  final ValueChanged<TaskTemplate>? onStepsChanged;

  const ZongpingBrowserScreen({
    super.key,
    required this.template,
    this.loginUrl,
    this.onStepsChanged,
  });

  @override
  ConsumerState<ZongpingBrowserScreen> createState() =>
      _ZongpingBrowserScreenState();
}

class _ZongpingBrowserScreenState
    extends ConsumerState<ZongpingBrowserScreen> {
  late WebViewController _webController;
  late TaskTemplate _template;
  bool _isLoading = true;
  String _currentUrl = '';

  List<ScrapedField> _scrapedFields = [];
  bool _isScraping = false;

  bool _isGenerating = false;
  String? _aiResponse;
  List<FieldFillPlan> _fillPlans = [];

  bool _isFilling = false;
  List<String> _fillResults = [];

  int _selectedTab = 0; // 0=抓取, 1=步骤, 2=AI/填写

  @override
  void initState() {
    super.initState();
    _template = widget.template;
    _initWebView();
  }

  void _initWebView() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _isLoading = p < 100),
          onPageStarted: (url) =>
              setState(() { _currentUrl = url; _isLoading = true; }),
          onPageFinished: (url) {
            setState(() { _currentUrl = url; _isLoading = false; });
            _autoScrape();
          },
          onWebResourceError: (e) => debugPrint('WebView error: ${e.description}'),
        ),
      )
      ..loadRequest(Uri.parse(_template.url));

    FormScraperService.instance.setController(_webController);
  }

  Future<void> _autoScrape() async {
    setState(() => _isScraping = true);
    try {
      final fields = await FormScraperService.instance.scrapeFormFields();
      setState(() { _scrapedFields = fields; _isScraping = false; });
    } catch (_) {
      setState(() => _isScraping = false);
    }
  }

  /// Save template changes and notify parent.
  void _saveAndNotify() {
    widget.onStepsChanged?.call(_template);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        _buildTopBar(),
        Expanded(
          flex: 3,
          child: Stack(children: [
            WebViewWidget(controller: _webController),
            if (_isLoading) const LinearProgressIndicator(),
          ]),
        ),
        _buildControlPanel(),
      ]),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 8, right: 8, bottom: 4,
      ),
      color: Theme.of(context).colorScheme.surface,
      child: Row(children: [
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
              Row(children: [
                Text(_template.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: _template.useAi
                        ? Colors.blue.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _template.useAi ? 'AI模式' : '直接填写',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: _template.useAi
                          ? Colors.blue.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ),
              ]),
              Text(_currentUrl,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (_isLoading)
          const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
        IconButton(
          onPressed: () => _webController.reload(),
          icon: const Icon(Icons.refresh, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildTabBar(),
        Flexible(child: _buildTabContent()),
      ]),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: Row(children: [
        _buildTab(0, Icons.search, '抓取', _scrapedFields.length),
        _buildTab(1, Icons.list_alt, '步骤', _template.steps.length),
      ]),
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
              Icon(icon, size: 16,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  )),
              if (badge > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$badge',
                      style: TextStyle(
                          fontSize: 9,
                          color: Theme.of(context).colorScheme.onPrimary)),
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
        return _buildStepsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ==================== 抓取 Tab ====================

  Widget _buildScrapeTab() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isScraping ? null : _autoScrape,
              icon: _isScraping
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 16),
              label: Text(_isScraping ? '抓取中...' : '重新抓取',
                  style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6)),
            ),
          ),
          const SizedBox(width: 8),
          // 一键用抓取的字段填充步骤选择器
          if (_scrapedFields.isNotEmpty)
            Expanded(
              child: FilledButton.icon(
                onPressed: _autoFillStepSelectors,
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: const Text('自动匹配步骤',
                    style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6)),
              ),
            ),
        ]),
      ),
      Flexible(
        child: _scrapedFields.isEmpty
            ? Center(
                child: Text(
                    _isScraping ? '正在抓取...' : '点击"重新抓取"扫描页面',
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 13)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _scrapedFields.length,
                itemBuilder: (context, i) =>
                    _buildFieldCard(_scrapedFields[i]),
              ),
      ),
    ]);
  }

  Widget _buildFieldCard(ScrapedField field) {
    final isClickable = field.isClickable;
    IconData icon;
    Color color;
    if (isClickable) {
      icon = Icons.touch_app; color = Colors.purple;
    } else if (field.tagName == 'select') {
      icon = Icons.arrow_drop_down_circle; color = Colors.orange;
    } else if (field.type == 'date') {
      icon = Icons.calendar_today; color = Colors.teal;
    } else if (field.tagName == 'textarea') {
      icon = Icons.notes; color = Colors.blue;
    } else {
      icon = Icons.edit_outlined; color = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 3),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: Icon(icon, color: color, size: 18),
        title: Text(field.displayName,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${field.tagName}${field.type != "text" ? " (${field.type})" : ""} | ${field.selector}',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: isClickable
            ? const Icon(Icons.open_in_new, size: 14, color: Colors.purple)
            : field.currentValue.isNotEmpty
                ? const Icon(Icons.check_circle, color: Colors.green, size: 14)
                : const Icon(Icons.radio_button_unchecked,
                    color: Colors.grey, size: 14),
        onTap: () => _onFieldTap(field),
      ),
    );
  }

  void _onFieldTap(ScrapedField field) {
    if (field.isClickable) {
      _showClickConfirm(field);
    } else if (field.tagName == 'select') {
      _showSelectDialog(field);
    } else if (field.type == 'date') {
      _showDatePicker(field);
    } else {
      _showTextInput(field);
    }
  }

  void _showClickConfirm(ScrapedField field) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('点击元素', style: TextStyle(fontSize: 14)),
        content: Text('确定点击 "${field.displayName}" ?',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FormScraperService.instance
                  .clickElement(field.selector);
              await Future.delayed(const Duration(seconds: 1));
              _autoScrape();
            },
            child: const Text('点击'),
          ),
        ],
      ),
    );
  }

  void _showSelectDialog(ScrapedField field) {
    if (field.options == null || field.options!.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(field.displayName,
            style: const TextStyle(fontSize: 14)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: field.options!.length,
            itemBuilder: (ctx, i) {
              final opt = field.options![i];
              final sel = opt.value == field.currentValue;
              return ListTile(
                dense: true,
                title: Text(opt.text,
                    style: const TextStyle(fontSize: 13)),
                trailing: sel
                    ? const Icon(Icons.check,
                        color: Colors.green, size: 18)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  await FormScraperService.instance
                      .selectOptionByText(field.selector, opt.text);
                  _autoScrape();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showDatePicker(ScrapedField field) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      final d =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      await FormScraperService.instance.setDateField(field.selector, d);
      _autoScrape();
    }
  }

  void _showTextInput(ScrapedField field) {
    final ctrl = TextEditingController(text: field.currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(field.displayName,
            style: const TextStyle(fontSize: 14)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: field.tagName == 'textarea' ? 5 : 1,
          decoration: InputDecoration(
            hintText: field.placeholder ?? '输入内容',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FormScraperService.instance
                  .fillField(field.selector, ctrl.text);
              _autoScrape();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // ==================== 步骤 Tab ====================

  Widget _buildStepsTab() {
    return Column(children: [
      // 操作栏
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _addStep,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() => _template = _template.copyWith(useAi: !_template.useAi));
                _saveAndNotify();
              },
              icon: Icon(_template.useAi ? Icons.smart_toy : Icons.edit, size: 16),
              label: Text(_template.useAi ? 'AI模式' : '直接模式',
                  style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: FilledButton.icon(
              onPressed: _isFilling ? null : _executeSteps,
              icon: _isFilling
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow, size: 16),
              label: Text(_isFilling ? '执行中...' : '执行',
                  style: const TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
        ]),
      ),
      // 步骤列表
      Flexible(
        child: _template.steps.isEmpty
            ? const Center(
                child: Text('暂无步骤，点击"添加"',
                    style: TextStyle(color: Colors.grey, fontSize: 13)))
            : ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _template.steps.length,
                onReorder: (oldIdx, newIdx) {
                  setState(() {
                    if (newIdx > oldIdx) newIdx--;
                    final steps = List<TemplateStep>.from(_template.steps);
                    final item = steps.removeAt(oldIdx);
                    steps.insert(newIdx, item);
                    _template = _template.copyWith(steps: steps);
                  });
                  _saveAndNotify();
                },
                itemBuilder: (context, i) => _buildStepCard(i, _template.steps[i]),
              ),
      ),
      // 执行结果
      if (_fillResults.isNotEmpty)
        Container(
          constraints: const BoxConstraints(maxHeight: 150),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: _fillResults.length,
            itemBuilder: (context, i) {
              final r = _fillResults[i];
              final ok = r.startsWith('✅');
              final skip = r.startsWith('⏭️');
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(children: [
                  Icon(
                      ok ? Icons.check_circle
                          : skip ? Icons.skip_next
                          : Icons.cancel,
                      size: 12,
                      color: ok ? Colors.green : skip ? Colors.grey : Colors.red),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(r.substring(2),
                          style: const TextStyle(fontSize: 11))),
                ]),
              );
            },
          ),
        ),
    ]);
  }

  Widget _buildStepCard(int index, TemplateStep step) {
    IconData icon;
    Color color;
    switch (step.action) {
      case 'click':
        icon = Icons.touch_app; color = Colors.blue; break;
      case 'fill':
        icon = Icons.edit; color = Colors.green; break;
      case 'select':
        icon = Icons.arrow_drop_down; color = Colors.orange; break;
      case 'if':
        icon = Icons.call_split; color = Colors.amber; break;
      case 'wait':
        icon = Icons.timer; color = Colors.grey; break;
      case 'screenshot':
        icon = Icons.camera_alt; color = Colors.purple; break;
      case 'navigate':
        icon = Icons.open_in_browser; color = Colors.teal; break;
      default:
        icon = Icons.help; color = Colors.grey;
    }

    return Card(
      key: ValueKey('step_$index'),
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: Icon(icon, color: color, size: 18),
        title: Text(
            step.description.isNotEmpty ? step.description : step.action,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        subtitle: Text(
            '${step.action}${step.selector.isNotEmpty ? " | ${step.selector}" : ""}${step.value != null ? " | ${step.value}" : ""}',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          // 从抓取结果选择选择器
          if (step.action != 'screenshot' && step.action != 'wait')
            IconButton(
              onPressed: () => _pickSelectorForStep(index),
              icon: const Icon(Icons.auto_fix_high, size: 16),
              tooltip: '从抓取结果选择',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          IconButton(
            onPressed: () => _editStep(index),
            icon: const Icon(Icons.edit, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                final steps = List<TemplateStep>.from(_template.steps);
                steps.removeAt(index);
                _template = _template.copyWith(steps: steps);
              });
              _saveAndNotify();
            },
            icon: const Icon(Icons.delete, size: 16, color: Colors.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
      ),
    );
  }

  /// Pick a selector from scraped fields for a step.
  void _pickSelectorForStep(int stepIndex) {
    if (_scrapedFields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先在"抓取"标签中抓取表单')));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择字段', style: TextStyle(fontSize: 14)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _scrapedFields.length,
            itemBuilder: (ctx, i) {
              final f = _scrapedFields[i];
              return ListTile(
                dense: true,
                title: Text(f.displayName,
                    style: const TextStyle(fontSize: 12)),
                subtitle: Text(f.selector,
                    style: const TextStyle(
                        fontSize: 10, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    final steps =
                        List<TemplateStep>.from(_template.steps);
                    steps[stepIndex] =
                        steps[stepIndex].copyWith(selector: f.selector);
                    _template = _template.copyWith(steps: steps);
                  });
                  _saveAndNotify();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _addStep() {
    _showStepDialog(null);
  }

  void _editStep(int index) {
    _showStepDialog(_template.steps[index], index: index);
  }

  void _showStepDialog(TemplateStep? step, {int? index}) {
    String selectedAction = step?.action ?? 'fill';
    final selectorCtrl = TextEditingController(text: step?.selector ?? '');
    final valueCtrl = TextEditingController(text: step?.value ?? '');
    final descCtrl = TextEditingController(text: step?.description ?? '');
    final waitCtrl =
        TextEditingController(text: step?.waitMs?.toString() ?? '1000');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(step == null ? '添加步骤' : '编辑步骤',
              style: const TextStyle(fontSize: 14)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: selectedAction,
                decoration: const InputDecoration(
                    labelText: '操作类型',
                    border: OutlineInputBorder(),
                    isDense: true),
                items: const [
                  DropdownMenuItem(value: 'fill', child: Text('填写输入框')),
                  DropdownMenuItem(value: 'click', child: Text('点击元素')),
                  DropdownMenuItem(value: 'select', child: Text('下拉选择')),
                  DropdownMenuItem(value: 'if', child: Text('条件判断(if)')),
                  DropdownMenuItem(value: 'wait', child: Text('等待')),
                  DropdownMenuItem(value: 'screenshot', child: Text('截图')),
                  DropdownMenuItem(value: 'navigate', child: Text('跳转页面')),
                ],
                onChanged: (v) => setDState(() => selectedAction = v!),
              ),
              const SizedBox(height: 10),
              if (selectedAction != 'screenshot' && selectedAction != 'wait')
                _pickerField('选择器', selectorCtrl, '点击右侧按钮从抓取结果选择', () {
                  if (_scrapedFields.isNotEmpty) {
                    _showSelectorPicker(selectorCtrl);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请先抓取页面')));
                  }
                }),
              if (selectedAction == 'fill' || selectedAction == 'select') ...[
                const SizedBox(height: 10),
                _pickerField('填写值', valueCtrl, '固定值或 {ai_content}', null),
                // 账号数据快捷填充
                _buildAccountQuickFill(valueCtrl),
              ],
              if (selectedAction == 'if') ...[
                const SizedBox(height: 10),
                _pickerField('条件变量', selectorCtrl, '{position} / {reward} / {position:1}', null),
                const SizedBox(height: 4),
                Text('如果变量不为空则继续执行后续步骤，否则跳到下一个 if 或结束',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ],
              if (selectedAction == 'wait') ...[
                const SizedBox(height: 10),
                TextField(
                    controller: waitCtrl,
                    decoration: const InputDecoration(
                        labelText: '等待时间(毫秒)',
                        border: OutlineInputBorder(),
                        isDense: true),
                    keyboardType: TextInputType.number),
              ],
              if (selectedAction == 'navigate') ...[
                const SizedBox(height: 10),
                TextField(
                    controller: valueCtrl,
                    decoration: const InputDecoration(
                        labelText: '目标URL',
                        border: OutlineInputBorder(),
                        isDense: true)),
              ],
              const SizedBox(height: 10),
              TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                      labelText: '步骤说明',
                      hintText: '描述这个步骤做什么',
                      border: OutlineInputBorder(),
                      isDense: true)),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final newStep = TemplateStep(
                  action: selectedAction,
                  selector: selectorCtrl.text,
                  value: valueCtrl.text.isNotEmpty
                      ? valueCtrl.text
                      : null,
                  description: descCtrl.text,
                  waitMs: selectedAction == 'wait'
                      ? int.tryParse(waitCtrl.text)
                      : null,
                );
                setState(() {
                  final steps =
                      List<TemplateStep>.from(_template.steps);
                  if (index != null) {
                    steps[index] = newStep;
                  } else {
                    steps.add(newStep);
                  }
                  _template = _template.copyWith(steps: steps);
                });
                _saveAndNotify();
                Navigator.pop(ctx);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerField(String label, TextEditingController ctrl,
      String hint, VoidCallback? onPick) {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: ctrl,
          decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: const OutlineInputBorder(),
              isDense: true),
        ),
      ),
      if (onPick != null) ...[
        const SizedBox(width: 4),
        IconButton(
          onPressed: onPick,
          icon: const Icon(Icons.auto_fix_high, size: 20),
          tooltip: '从抓取结果选择',
        ),
      ],
    ]);
  }

  void _showSelectorPicker(TextEditingController ctrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择字段', style: TextStyle(fontSize: 14)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _scrapedFields.length,
            itemBuilder: (ctx, i) {
              final f = _scrapedFields[i];
              return ListTile(
                dense: true,
                title: Text(f.displayName,
                    style: const TextStyle(fontSize: 12)),
                subtitle: Text(f.selector,
                    style: const TextStyle(
                        fontSize: 10, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  ctrl.text = f.selector;
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// 账号数据 + 创新探究内容快捷填充
  Widget _buildAccountQuickFill(TextEditingController ctrl) {
    final accounts = ref.watch(accountProvider);
    final settings = ref.watch(settingsProvider);
    final subjectContents = settings.subjectContents;

    final hasAccounts = accounts.isNotEmpty;
    final hasSubjects = subjectContents.isNotEmpty &&
        subjectContents.values.any((v) => v.isNotEmpty);

    if (!hasAccounts && !hasSubjects) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 变量快捷按钮
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _quickBtn('{ai_content}', ctrl, Colors.blue),
              if (hasAccounts) ...[
                _quickBtn('{username}', ctrl, Colors.indigo),
                _quickBtn('{password}', ctrl, Colors.indigo),
                _quickBtn('{teacher}', ctrl, Colors.indigo),
                _quickBtn('{subjects}', ctrl, Colors.indigo),
                // 职务
                for (int i = 0; i < (accounts.first.positions.length > 3 ? 3 : accounts.first.positions.length); i++)
                  _quickBtn('{position:$i}', ctrl, Colors.green),
                // 奖惩+等级
                for (int i = 0; i < (accounts.first.rewards.length > 3 ? 3 : accounts.first.rewards.length); i++) ...[
                  _quickBtn('{reward:$i}', ctrl, Colors.orange),
                  _quickBtn('{reward_level:$i}', ctrl, Colors.orange),
                ],
              ],
            ],
          ),
          // 创新探究
          if (hasSubjects) ...[
            const SizedBox(height: 4),
            Text('创新探究:',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            const SizedBox(height: 2),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final entry in subjectContents.entries)
                  if (entry.value.isNotEmpty)
                    _quickBtn('{subject:${entry.key}}', ctrl, Colors.teal),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickBtn(String text, TextEditingController ctrl, Color color) {
    return ActionChip(
      label: Text(text,
          style: TextStyle(fontSize: 10, color: color)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: () {
        ctrl.text = text;
      },
    );
  }

  /// Auto-fill step selectors from scraped fields.
  void _autoFillStepSelectors() {
    if (_scrapedFields.isEmpty) return;

    final steps = List<TemplateStep>.from(_template.steps);
    bool changed = false;

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (step.selector.isNotEmpty) continue;
      if (step.action == 'screenshot' || step.action == 'wait') continue;

      // Try to match by description keywords
      ScrapedField? match;
      final desc = step.description.toLowerCase();
      for (final f in _scrapedFields) {
        final name = f.displayName.toLowerCase();
        if (desc.contains(name) || name.contains(desc.split('按钮')[0])) {
          match = f;
          break;
        }
      }

      if (match != null) {
        steps[i] = step.copyWith(selector: match.selector);
        changed = true;
      }
    }

    if (changed) {
      setState(() => _template = _template.copyWith(steps: steps));
      _saveAndNotify();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 已自动匹配步骤选择器')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可以自动匹配的步骤')));
    }
  }

  Future<void> _executeSteps() async {
    setState(() { _isFilling = true; _fillResults = []; });
    final results = <String>[];
    final accounts = ref.read(accountProvider);
    final settings = ref.read(settingsProvider);

    bool skipMode = false; // true = skipping until next if

    for (final step in _template.steps) {
      if (!_isFilling) break;

      // If in skip mode, skip non-if steps
      if (skipMode && step.action != 'if') {
        results.add('⏭️ 跳过: ${step.description}');
        continue;
      }
      if (skipMode && step.action == 'if') {
        skipMode = false; // Reset skip mode at next if
      }

      try {
        switch (step.action) {
          case 'fill':
            String value = step.value ?? '';
            value = _replaceVariables(value, accounts, settings);
            if (step.selector.isNotEmpty && value.isNotEmpty) {
              await FormScraperService.instance
                  .fillField(step.selector, value);
              results.add('✅ 填写: ${step.description}');
            } else {
              results.add('⚠️ 跳过: ${step.description} (缺少选择器或值)');
            }
            break;
          case 'click':
            if (step.selector.isNotEmpty) {
              await FormScraperService.instance
                  .clickElement(step.selector);
              results.add('✅ 点击: ${step.description}');
            } else {
              results.add('⚠️ 跳过: ${step.description} (缺少选择器)');
            }
            break;
          case 'select':
            if (step.selector.isNotEmpty && step.value != null) {
              final resolvedValue = _replaceVariables(step.value!, accounts, settings);
              await FormScraperService.instance
                  .selectOptionByText(step.selector, resolvedValue);
              results.add('✅ 选择: ${step.description}');
            } else {
              results.add('⚠️ 跳过: ${step.description}');
            }
            break;
          case 'if':
            final condition = step.selector ?? '';
            final resolved = _replaceVariables(condition, accounts, settings);
            if (resolved.isNotEmpty) {
              results.add('✅ 条件成立: $condition');
            } else {
              results.add('⏭️ 条件不成立: $condition，跳过后续');
              skipMode = true;
            }
            break;
          case 'wait':
            final ms = step.waitMs ?? 1000;
            await Future.delayed(Duration(milliseconds: ms));
            results.add('✅ 等待 ${ms}ms');
            break;
          case 'screenshot':
            results.add('✅ 截图: ${step.description}');
            break;
          case 'navigate':
            if (step.value != null && step.value!.isNotEmpty) {
              await _webController.loadRequest(Uri.parse(step.value!));
              results.add('✅ 跳转: ${step.value}');
            }
            break;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        results.add('❌ ${step.description}: $e');
      }
    }

    setState(() => _fillResults = results);
    if (mounted) {
      final ok = results.where((r) => r.startsWith('✅')).length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('执行完成: $ok/${results.length} 步成功'),
          duration: const Duration(seconds: 3)));
    }
    setState(() => _isFilling = false);
  }

  /// Replace variables in a value string with actual data.
  String _replaceVariables(
      String value, List accounts, dynamic settings) {
    // {ai_content} -> directValue
    if (value == '{ai_content}' && _template.directValue != null) {
      value = _template.directValue!;
    }

    if (accounts.isNotEmpty) {
      final acc = accounts.first;
      value = value.replaceAll('{username}', acc.username);
      value = value.replaceAll('{password}', acc.password);
      value = value.replaceAll('{teacher}', acc.teacherName);
      value = value.replaceAll('{subjects}', acc.subjects.join('、'));

      // {position} or {position:0} -> first position title
      // {position:1} -> second position title
      // {position_desc} or {position_desc:0} -> first position description
      final posPattern = RegExp(r'\{position(?:_desc)?(?::(\d+))?\}');
      value = value.replaceAllMapped(posPattern, (match) {
        final isDesc = match.group(0)!.contains('_desc');
        final idx = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (acc.positions.length > idx) {
          return isDesc
              ? acc.positions[idx].description
              : acc.positions[idx].title;
        }
        return '';
      });

      // {reward} or {reward:0} -> first reward title
      // {reward:1} -> second reward title
      // {reward_level} or {reward_level:0} -> first reward level
      final rewPattern = RegExp(r'\{reward(?:_level)?(?::(\d+))?\}');
      value = value.replaceAllMapped(rewPattern, (match) {
        final isLevel = match.group(0)!.contains('_level');
        final idx = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (acc.rewards.length > idx) {
          return isLevel ? acc.rewards[idx].level : acc.rewards[idx].title;
        }
        return '';
      });
    }

    // {subject:物理} -> subject content
    final subjectPattern = RegExp(r'\{subject:(.+?)\}');
    value = value.replaceAllMapped(subjectPattern, (match) {
      final subject = match.group(1)!;
      return settings.subjectContents[subject] ?? '';
    });

    return value;
  }
}
