import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewLoginScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewLoginScreen({
    super.key,
    required this.url,
    this.title = '登录',
  });

  @override
  State<WebViewLoginScreen> createState() => _WebViewLoginScreenState();
}

class _WebViewLoginScreenState extends State<WebViewLoginScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _currentUrl = '';
  String _status = '加载中...';

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
              _status = '加载中...';
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _currentUrl = url;
              _isLoading = false;
            });
            _checkLoginStatus(url);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _checkLoginStatus(String url) async {
    // Try to get cookies via JavaScript
    try {
      final cookies = await _controller.runJavaScriptReturningResult(
        'document.cookie',
      );
      final cookieStr = cookies.toString().replaceAll('"', '');

      // Check if logged in (DeepSeek uses specific cookies when logged in)
      if (cookieStr.isNotEmpty &&
          (cookieStr.contains('token') ||
              cookieStr.contains('session') ||
              cookieStr.contains('user') ||
              cookieStr.contains('ds_chat'))) {
        setState(() {
          _status = '✅ 已检测到登录状态';
        });
      } else {
        setState(() {
          _status = '⏳ 请在页面中登录';
        });
      }
    } catch (e) {
      setState(() {
        _status = '⏳ 请在页面中登录';
      });
    }
  }

  Future<void> _extractAndReturn() async {
    try {
      // Get cookies
      final cookiesResult = await _controller.runJavaScriptReturningResult(
        'document.cookie',
      );
      final cookies = cookiesResult.toString().replaceAll('"', '');

      if (cookies.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未获取到 Cookies，请先登录')),
          );
        }
        return;
      }

      // Extract token from cookies if present
      String sessionToken = '';
      final cookieParts = cookies.split(';');
      for (final part in cookieParts) {
        final trimmed = part.trim();
        if (trimmed.startsWith('ds_chat_token=') ||
            trimmed.startsWith('token=') ||
            trimmed.startsWith('session=')) {
          sessionToken = trimmed.split('=').skip(1).join('=');
        }
      }

      if (mounted) {
        Navigator.pop(context, {
          'cookies': cookies,
          'sessionToken': sessionToken,
          'url': _currentUrl,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // Status indicator
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _status,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          // Refresh
          IconButton(
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh),
          ),
          // Confirm button
          TextButton.icon(
            onPressed: _extractAndReturn,
            icon: const Icon(Icons.check),
            label: const Text('获取'),
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
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.lock, size: 16, color: Colors.green),
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
          // Bottom bar
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
                    '登录完成后点击右上角「获取」按钮',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
