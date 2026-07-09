import 'dart:convert';
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
            _injectInterceptors();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  /// Inject interceptors that capture the FULL request details from DeepSeek's
  /// web chat API calls. We capture: URL, all headers (including cookies),
  /// and the request body format. This allows us to replay requests later.
  void _injectInterceptors() {
    const js = r'''
    (function() {
      if (window.__zonewInjected) return;
      window.__zonewInjected = true;
      window.__zonewCapturedRequests = [];

      // Intercept fetch API - capture full request details
      var origFetch = window.fetch;
      window.fetch = function(input, init) {
        var url = typeof input === 'string' ? input : (input && input.url ? input.url : '');
        var method = (init && init.method) || 'GET';

        // Only capture chat/completion API calls
        if (url.indexOf('/api/') >= 0 || url.indexOf('/chat') >= 0 ||
            url.indexOf('completions') >= 0 || url.indexOf('conversation') >= 0) {
          var headers = {};
          if (init && init.headers) {
            if (init.headers instanceof Headers) {
              init.headers.forEach(function(value, key) { headers[key] = value; });
            } else if (typeof init.headers === 'object') {
              for (var k in init.headers) { headers[k] = init.headers[k]; }
            }
          }
          // Always capture cookies
          headers['cookie'] = document.cookie;

          var body = null;
          if (init && init.body) {
            try { body = typeof init.body === 'string' ? init.body : JSON.stringify(init.body); } catch(e) {}
          }

          var captured = {
            url: url,
            method: method,
            headers: headers,
            body: body,
            timestamp: Date.now()
          };
          window.__zonewCapturedRequests.push(captured);
          console.log('[Zonew] Captured API request: ' + method + ' ' + url);
        }
        return origFetch.apply(this, arguments);
      };

      // Also intercept XMLHttpRequest
      var origOpen = XMLHttpRequest.prototype.open;
      var origSetHeader = XMLHttpRequest.prototype.setRequestHeader;
      var origSend = XMLHttpRequest.prototype.send;

      XMLHttpRequest.prototype.open = function(method, url) {
        this.__zonewMethod = method;
        this.__zonewUrl = url;
        this.__zonewHeaders = {};
        return origOpen.apply(this, arguments);
      };
      XMLHttpRequest.prototype.setRequestHeader = function(name, value) {
        this.__zonewHeaders[name] = value;
        return origSetHeader.apply(this, arguments);
      };
      XMLHttpRequest.prototype.send = function(body) {
        var url = this.__zonewUrl || '';
        if (url.indexOf('/api/') >= 0 || url.indexOf('/chat') >= 0 ||
            url.indexOf('completions') >= 0 || url.indexOf('conversation') >= 0) {
          var headers = Object.assign({}, this.__zonewHeaders);
          headers['cookie'] = document.cookie;
          var captured = {
            url: url,
            method: this.__zonewMethod || 'POST',
            headers: headers,
            body: body,
            timestamp: Date.now()
          };
          window.__zonewCapturedRequests.push(captured);
          console.log('[Zonew] Captured XHR request: ' + this.__zonewMethod + ' ' + url);
        }
        return origSend.apply(this, arguments);
      };

      console.log('[Zonew] API interceptors injected');
    })();
    ''';
    _controller.runJavaScript(js);
  }

  Future<void> _extractAndReturn() async {
    try {
      // Get captured requests
      final result = await _controller.runJavaScriptReturningResult(
        'JSON.stringify(window.__zonewCapturedRequests || [])',
      );
      final resultStr = result.toString();
      // Remove surrounding quotes that JS toString adds
      final cleanStr = resultStr.startsWith('"')
          ? resultStr.substring(1, resultStr.length - 1)
          : resultStr;
      // Unescape JSON string escaping
      final unescaped = cleanStr.replaceAll('\\"', '"').replaceAll('\\\\', '\\');

      if (unescaped == '[]' || unescaped.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('未捕获到API请求。请先登录，然后在对话框发送一条消息，再点击「获取」'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final List<dynamic> requests = jsonDecode(unescaped);
      if (requests.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未捕获到API请求，请先进行一次对话')),
          );
        }
        return;
      }

      // Use the last captured request as the template
      final lastReq = requests.last as Map<String, dynamic>;
      final apiUrl = lastReq['url']?.toString() ?? '';
      final headers = lastReq['headers'] as Map<String, dynamic>? ?? {};
      final bodyTemplate = lastReq['body']?.toString() ?? '';

      // Extract cookies from headers
      final cookies = headers['cookie']?.toString() ?? '';

      if (apiUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('捕获的请求URL为空，请重试')),
          );
        }
        return;
      }

      // Build session data with full request info
      final sessionData = jsonEncode({
        'apiUrl': apiUrl,
        'headers': headers,
        'bodyTemplate': bodyTemplate,
      });

      if (mounted) {
        Navigator.pop(context, {
          'cookies': cookies,
          'sessionToken': sessionData,
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
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _status,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              _controller.reload();
              Future.delayed(const Duration(seconds: 2), _injectInterceptors);
            },
            icon: const Icon(Icons.refresh),
          ),
          TextButton.icon(
            onPressed: _extractAndReturn,
            icon: const Icon(Icons.check),
            label: const Text('获取'),
          ),
        ],
      ),
      body: Column(
        children: [
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
          Expanded(
            child: WebViewWidget(controller: _controller),
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
                    '登录后发送一条消息，然后点击右上角「获取」',
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
