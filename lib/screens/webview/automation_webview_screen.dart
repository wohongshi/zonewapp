import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/account.dart';
import '../../services/automation_service.dart';

/// A WebView screen that hosts the automation engine.
/// Opens the target platform URL and starts automation once the page loads.
class AutomationWebViewScreen extends StatefulWidget {
  final Account account;

  const AutomationWebViewScreen({
    super.key,
    required this.account,
  });

  @override
  State<AutomationWebViewScreen> createState() => _AutomationWebViewScreenState();
}

class _AutomationWebViewScreenState extends State<AutomationWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _automationStarted = false;
  String _currentUrl = '';
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _isLoading = progress < 100;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _currentUrl = url;
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _currentUrl = url;
                _isLoading = false;
              });

              // Initialize automation service with this controller
              AutomationService.instance.setWebViewController(_controller);

              // Add log callback
              AutomationService.instance.onLog = (msg) {
                if (mounted) {
                  setState(() {
                    _logs.add(msg);
                    // Keep only last 100 logs
                    if (_logs.length > 100) _logs.removeAt(0);
                  });
                }
              };

              // Start automation on first page load
              if (!_automationStarted) {
                _automationStarted = true;
                _startAutomation();
              }
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://szpj.sdei.edu.cn/zhszpj/web/login.htm'));
  }

  Future<void> _startAutomation() async {
    // Wait a moment for the page to fully render
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      AutomationService.instance.startAutomation(widget.account);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('自动化 - ${widget.account.username}'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          // Stop button
          if (AutomationService.instance.isRunning)
            IconButton(
              onPressed: () {
                AutomationService.instance.stopAutomation();
                setState(() {});
              },
              icon: const Icon(Icons.stop, color: Colors.red),
              tooltip: '停止自动化',
            ),
          // Toggle log panel
          IconButton(
            onPressed: () => _showLogPanel(context),
            icon: const Icon(Icons.terminal),
            tooltip: '查看日志',
          ),
        ],
      ),
      body: Column(
        children: [
          // URL bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Icon(Icons.link, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentUrl,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // WebView
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }

  void _showLogPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '自动化日志',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _logs[index],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
