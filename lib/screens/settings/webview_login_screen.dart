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
  String? _capturedToken;
  String? _capturedCookies;

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
            _checkLoginStatus();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  /// Inject JavaScript interceptors to capture auth tokens from network requests.
  /// This bypasses the HTTP-only cookie limitation of document.cookie.
  void _injectInterceptors() {
    const js = r'''
    (function() {
      if (window.__zonewInjected) return;
      window.__zonewInjected = true;
      window.__zonewTokens = [];
      window.__zonewCookies = '';

      // Intercept XMLHttpRequest to capture Authorization headers
      var origOpen = XMLHttpRequest.prototype.open;
      var origSetHeader = XMLHttpRequest.prototype.setRequestHeader;
      XMLHttpRequest.prototype.open = function(method, url) {
        this.__zonewUrl = url;
        this.__zonewHeaders = {};
        return origOpen.apply(this, arguments);
      };
      XMLHttpRequest.prototype.setRequestHeader = function(name, value) {
        this.__zonewHeaders[name.toLowerCase()] = value;
        return origSetHeader.apply(this, arguments);
      };
      var origSend = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.send = function() {
        var auth = this.__zonewHeaders['authorization'];
        if (auth && auth.indexOf('Bearer') >= 0) {
          var token = auth.replace('Bearer ', '');
          if (window.__zonewTokens.indexOf(token) < 0) {
            window.__zonewTokens.push(token);
          }
        }
        // Also capture cookies from response
        this.addEventListener('load', function() {
          try {
            var setCookies = this.getAllResponseHeaders();
            if (setCookies.indexOf('set-cookie') >= 0) {
              window.__zonewCookies = document.cookie;
            }
          } catch(e) {}
        });
        return origSend.apply(this, arguments);
      };

      // Intercept fetch API
      var origFetch = window.fetch;
      window.fetch = function(url, opts) {
        if (opts && opts.headers) {
          var auth = null;
          if (opts.headers instanceof Headers) {
            auth = opts.headers.get('authorization');
          } else if (typeof opts.headers === 'object') {
            auth = opts.headers['authorization'] || opts.headers['Authorization'];
          }
          if (auth && auth.indexOf('Bearer') >= 0) {
            var token = auth.replace('Bearer ', '');
            if (window.__zonewTokens.indexOf(token) < 0) {
              window.__zonewTokens.push(token);
            }
          }
        }
        return origFetch.apply(this, arguments).then(function(resp) {
          return resp;
        });
      };

      console.log('[Zonew] Network interceptors injected');
    })();
    ''';
    _controller.runJavaScript(js);
  }

  Future<void> _checkLoginStatus() async {
    try {
      // Check captured tokens first
      final tokensResult = await _controller.runJavaScriptReturningResult(
        'JSON.stringify(window.__zonewTokens || [])',
      );
      final tokensStr = tokensResult.toString().replaceAll('"', '');
      if (tokensStr != '[]' && tokensStr.isNotEmpty) {
        try {
          final List<dynamic> tokens = jsonDecode(tokensStr);
          if (tokens.isNotEmpty) {
            _capturedToken = tokens.last.toString();
            setState(() {
              _status = '✅ 已捕获认证 Token';
            });
            return;
          }
        } catch (_) {}
      }

      // Fallback: check document.cookie (works for non-HttpOnly cookies)
      final cookies = await _controller.runJavaScriptReturningResult(
        'document.cookie',
      );
      final cookieStr = cookies.toString().replaceAll('"', '');
      if (cookieStr.isNotEmpty &&
          (cookieStr.contains('token') ||
              cookieStr.contains('session') ||
              cookieStr.contains('user') ||
              cookieStr.contains('ds_chat'))) {
        _capturedCookies = cookieStr;
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
    String cookies = '';
    String sessionToken = '';

    try {
      // 1. Try to get captured token from network interception
      final tokensResult = await _controller.runJavaScriptReturningResult(
        'JSON.stringify(window.__zonewTokens || [])',
      );
      final tokensStr = tokensResult.toString().replaceAll('"', '');
      if (tokensStr != '[]' && tokensStr.isNotEmpty) {
        try {
          final List<dynamic> tokens = jsonDecode(tokensStr);
          if (tokens.isNotEmpty) {
            sessionToken = tokens.last.toString();
          }
        } catch (_) {}
      }

      // 2. Get cookies (including non-HttpOnly ones)
      final cookiesResult = await _controller.runJavaScriptReturningResult(
        'document.cookie',
      );
      cookies = cookiesResult.toString().replaceAll('"', '');

      // 3. Try localStorage for tokens (DeepSeek may store auth there)
      if (sessionToken.isEmpty) {
        try {
          final lsResult = await _controller.runJavaScriptReturningResult(
            '(function(){ var keys = Object.keys(localStorage); var t = ""; for(var i=0;i<keys.length;i++){ var v=localStorage.getItem(keys[i]); if(v && v.length>20 && (keys[i].indexOf("token")>=0 || keys[i].indexOf("auth")>=0 || keys[i].indexOf("session")>=0 || keys[i].indexOf("user")>=0)) { t = v; } } return t; })()',
          );
          final lsToken = lsResult.toString().replaceAll('"', '');
          if (lsToken.isNotEmpty && lsToken.length > 20) {
            sessionToken = lsToken;
          }
        } catch (_) {}
      }

      // 4. If we have a token but no cookies, still proceed
      if (sessionToken.isEmpty && cookies.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('未获取到认证信息，请先登录，登录后进行一次对话再点击获取'),
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.pop(context, {
          'cookies': cookies,
          'sessionToken': sessionToken.isNotEmpty ? sessionToken : cookies,
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
            onPressed: () {
              _controller.reload();
              // Re-inject interceptors after reload
              Future.delayed(const Duration(seconds: 2), _injectInterceptors);
            },
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
                    '登录后请进行一次对话，然后点击右上角「获取」按钮',
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
