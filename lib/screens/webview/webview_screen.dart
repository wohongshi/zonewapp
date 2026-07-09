import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;
  final Function(String)? onPageFinished;
  final Function(String)? onJavaScriptMessage;

  const WebViewScreen({
    super.key,
    required this.url,
    required this.title,
    this.onPageFinished,
    this.onJavaScriptMessage,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _currentUrl = '';

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
            setState(() {
              _isLoading = progress < 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _currentUrl = url;
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _currentUrl = url;
              _isLoading = false;
            });
            widget.onPageFinished?.call(url);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    // Add JavaScript channel for communication
    _controller.addJavaScriptChannel(
      'Flutter',
      onMessageReceived: (JavaScriptMessage message) {
        widget.onJavaScriptMessage?.call(message.message);
      },
    );
  }

  /// Escape a string for safe embedding in JavaScript source code.
  /// Uses JSON encoding to produce a properly quoted JS string literal.
  String _escapeJs(String value) {
    return jsonEncode(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
          IconButton(
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh),
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

  // JavaScript execution methods
  Future<String> runJavaScript(String js) async {
    try {
      final result = await _controller.runJavaScriptReturningResult(js);
      return result.toString();
    } catch (e) {
      return '';
    }
  }

  Future<void> fillInput(String selector, String value) async {
    final safeSelector = _escapeJs(selector);
    final safeValue = _escapeJs(value);
    await runJavaScript('''
      var element = document.querySelector($safeSelector);
      if (element) {
        element.value = $safeValue;
        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
      }
    ''');
  }

  Future<void> clickElement(String selector) async {
    final safeSelector = _escapeJs(selector);
    await runJavaScript('''
      var element = document.querySelector($safeSelector);
      if (element) {
        element.click();
      }
    ''');
  }

  Future<void> selectOption(String selector, String value) async {
    final safeSelector = _escapeJs(selector);
    final safeValue = _escapeJs(value);
    await runJavaScript('''
      var element = document.querySelector($safeSelector);
      if (element) {
        element.value = $safeValue;
        element.dispatchEvent(new Event('change', { bubbles: true }));
      }
    ''');
  }

  Future<String> getElementText(String selector) async {
    final safeSelector = _escapeJs(selector);
    final result = await runJavaScript('''
      var element = document.querySelector($safeSelector);
      element ? element.innerText : '';
    ''');
    return result.replaceAll('"', '');
  }

  Future<void> submitForm(String selector) async {
    final safeSelector = _escapeJs(selector);
    await runJavaScript('''
      var form = document.querySelector($safeSelector);
      if (form) {
        form.submit();
      }
    ''');
  }
}
