import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// WebView-based AI service that borrows from WebAI2API's approach:
/// 1. Load AI chat page in WebView
/// 2. Inject JS to send messages and capture responses
/// 3. Expose as a simple API for the app
class WebViewAiService {
  static final WebViewAiService instance = WebViewAiService._();
  WebViewAiService._();

  WebViewController? _controller;
  bool _isReady = false;
  String _platform = 'deepseek';
  final StreamController<String> _statusController = StreamController.broadcast();

  Stream<String> get statusStream => _statusController.stream;
  bool get isReady => _isReady;
  String get platform => _platform;

  /// Platform configurations
  static const Map<String, _PlatformConfig> _configs = {
    'deepseek': _PlatformConfig(
      url: 'https://chat.deepseek.com/',
      chatInputSelector: 'textarea',
      sendButtonSelector: 'button[class*="send"]',
      responseSelector: '.markdown',
      loginCheckJs: 'document.querySelector("textarea") !== null',
    ),
    'chatgpt': _PlatformConfig(
      url: 'https://chatgpt.com/',
      chatInputSelector: '#prompt-textarea',
      sendButtonSelector: 'button[data-testid="send-button"]',
      responseSelector: '.markdown',
      loginCheckJs: 'document.querySelector("#prompt-textarea") !== null',
    ),
    'gemini': _PlatformConfig(
      url: 'https://gemini.google.com/app',
      chatInputSelector: '.ql-editor',
      sendButtonSelector: 'button[aria-label="Send message"]',
      responseSelector: '.model-response-text',
      loginCheckJs: 'document.querySelector(".ql-editor") !== null',
    ),
  };

  /// Initialize WebView with a specific platform.
  Future<void> init(String platform) async {
    _platform = platform;
    _statusController.add('初始化中...');

    final config = _configs[platform];
    if (config == null) {
      _statusController.add('不支持的平台: $platform');
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          _injectInterceptors();
          _checkReady();
        },
      ))
      ..loadRequest(Uri.parse(config.url));

    _statusController.add('加载页面中...');
  }

  /// Inject JS interceptors to capture API responses (like WebAI2API).
  void _injectInterceptors() {
    const js = r'''
    (function() {
      if (window.__zwaiInjected) return;
      window.__zwaiInjected = true;
      window.__zwaiResponse = '';
      window.__zwaiStatus = 'loading';
      window.__zwaiStreamBuffer = '';

      // Intercept fetch to capture streaming responses
      var origFetch = window.fetch;
      window.fetch = function(input, init) {
        var url = typeof input === 'string' ? input : (input?.url || '');
        // Capture chat API responses
        if (url.indexOf('/api/') >= 0 || url.indexOf('/chat') >= 0 ||
            url.indexOf('conversation') >= 0 || url.indexOf('completions') >= 0) {
          return origFetch.apply(this, arguments).then(function(resp) {
            var cloned = resp.clone();
            // Read streaming response
            var reader = cloned.body.getReader();
            var decoder = new TextDecoder();
            function readChunk() {
              reader.read().then(function(result) {
                if (result.done) return;
                var chunk = decoder.decode(result.value, {stream: true});
                window.__zwaiStreamBuffer += chunk;
                // Parse SSE data
                var lines = chunk.split('\n');
                for (var i = 0; i < lines.length; i++) {
                  if (lines[i].startsWith('data:')) {
                    var jsonStr = lines[i].substring(5).trim();
                    if (jsonStr === '[DONE]') {
                      window.__zwaiStatus = 'done';
                      window.__zwaiResponse = window.__zwaiStreamBuffer;
                      continue;
                    }
                    try {
                      var data = JSON.parse(jsonStr);
                      // DeepSeek/OpenAI format
                      if (data.choices && data.choices[0]) {
                        var delta = data.choices[0].delta;
                        if (delta && delta.content) {
                          window.__zwaiResponse += delta.content;
                        }
                      }
                    } catch(e) {}
                  }
                }
                readChunk();
              });
            }
            readChunk();
            return resp;
          });
        }
        return origFetch.apply(this, arguments);
      };

      // Also intercept XHR
      var origOpen = XMLHttpRequest.prototype.open;
      var origSend = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.open = function(method, url) {
        this.__zwaiUrl = url;
        return origOpen.apply(this, arguments);
      };
      XMLHttpRequest.prototype.send = function() {
        var self = this;
        this.addEventListener('load', function() {
          var url = self.__zwaiUrl || '';
          if (url.indexOf('/api/') >= 0 || url.indexOf('/chat') >= 0) {
            window.__zwaiResponse = self.responseText;
            window.__zwaiStatus = 'done';
          }
        });
        return origSend.apply(this, arguments);
      };

      // MutationObserver to detect response in DOM
      var observer = new MutationObserver(function(mutations) {
        for (var i = 0; i < mutations.length; i++) {
          var nodes = mutations[i].addedNodes;
          for (var j = 0; j < nodes.length; j++) {
            var el = nodes[j];
            if (el.classList && el.classList.contains('markdown')) {
              window.__zwaiResponse = el.innerText;
              window.__zwaiStatus = 'done';
            }
          }
        }
      });
      observer.observe(document.body, {childList: true, subtree: true});

      window.__zwaiInjected = true;
      console.log('[ZwAI] Interceptors injected');
    })();
    ''';
    _controller?.runJavaScript(js);
  }

  /// Check if the page is ready (user is logged in).
  Future<void> _checkReady() async {
    final config = _configs[_platform];
    if (config == null) return;

    try {
      final result = await _controller?.runJavaScriptReturningResult(
        config.loginCheckJs,
      );
      final isReady = result.toString() == 'true';
      _isReady = isReady;
      _statusController.add(isReady ? '就绪' : '请先登录');
    } catch (e) {
      _statusController.add('检测失败: $e');
    }
  }

  /// Get the WebView controller for displaying in UI.
  WebViewController? get controller => _controller;

  /// Send a message through the WebView and get the response.
  Future<AiWebResponse> sendMessage(String prompt,
      {Duration timeout = const Duration(seconds: 60)}) async {
    if (!_isReady || _controller == null) {
      return AiWebResponse(
        success: false,
        error: 'WebView 未就绪，请先登录',
      );
    }

    try {
      // Reset response buffer
      await _controller!.runJavaScript('''
        window.__zwaiResponse = '';
        window.__zwaiStreamBuffer = '';
        window.__zwaiStatus = 'sending';
      ''');

      // Type the message into the chat input
      final config = _configs[_platform]!;
      await _controller!.runJavaScript('''
        (function() {
          var input = document.querySelector('${config.chatInputSelector}');
          if (!input) { window.__zwaiStatus = 'error_no_input'; return; }

          // Clear and set value
          if (input.tagName === 'TEXTAREA') {
            input.value = ${jsonEncode(prompt)};
            input.dispatchEvent(new Event('input', {bubbles: true}));
          } else {
            // contenteditable div (like Gemini)
            input.innerText = ${jsonEncode(prompt)};
            input.dispatchEvent(new Event('input', {bubbles: true}));
          }

          window.__zwaiStatus = 'typed';
        })();
      ''');

      await Future.delayed(const Duration(milliseconds: 500));

      // Click send button
      await _controller!.runJavaScript('''
        (function() {
          // Try multiple strategies to find and click send
          var btn = document.querySelector('${config.sendButtonSelector}');
          if (btn) { btn.click(); window.__zwaiStatus = 'sent'; return; }

          // Fallback: press Enter
          var input = document.querySelector('${config.chatInputSelector}');
          if (input) {
            input.dispatchEvent(new KeyboardEvent('keydown', {
              key: 'Enter', code: 'Enter', keyCode: 13, bubbles: true
            }));
            window.__zwaiStatus = 'sent_enter';
            return;
          }

          window.__zwaiStatus = 'error_no_send';
        })();
      ''');

      _statusController.add('等待响应...');

      // Poll for response
      final completer = Completer<String>();
      final startTime = DateTime.now();

      Timer.periodic(const Duration(milliseconds: 500), (timer) async {
        if (DateTime.now().difference(startTime) > timeout) {
          timer.cancel();
          if (!completer.isCompleted) {
            completer.completeError(TimeoutException('响应超时'));
          }
          return;
        }

        try {
          final status = await _controller!.runJavaScriptReturningResult(
            'window.__zwaiStatus',
          );
          final statusStr = status.toString().replaceAll('"', '');

          if (statusStr == 'done') {
            timer.cancel();
            final response = await _controller!.runJavaScriptReturningResult(
              'window.__zwaiResponse',
            );
            final responseStr = response.toString();
            // Clean up JSON string escaping
            final clean = responseStr.startsWith('"')
                ? responseStr.substring(1, responseStr.length - 1)
                : responseStr;
            if (!completer.isCompleted) {
              completer.complete(clean);
            }
          } else if (statusStr.startsWith('error')) {
            timer.cancel();
            if (!completer.isCompleted) {
              completer.completeError('发送失败: $statusStr');
            }
          }
        } catch (e) {
          // Continue polling
        }
      });

      final response = await completer.future;
      _statusController.add('就绪');

      return AiWebResponse(success: true, content: _cleanResponse(response));
    } catch (e) {
      _statusController.add('错误: $e');
      return AiWebResponse(success: false, error: e.toString());
    }
  }

  /// Clean up the response text (remove SSE formatting artifacts).
  String _cleanResponse(String raw) {
    // If it's raw SSE data, extract the final content
    if (raw.contains('data:')) {
      final buffer = StringBuffer();
      for (final line in raw.split('\n')) {
        if (line.startsWith('data:')) {
          final jsonStr = line.substring(5).trim();
          if (jsonStr == '[DONE]') continue;
          try {
            final chunk = jsonDecode(jsonStr);
            if (chunk is Map && chunk.containsKey('choices')) {
              final choices = chunk['choices'];
              if (choices is List && choices.isNotEmpty) {
                final delta = choices[0]['delta'];
                if (delta is Map && delta.containsKey('content')) {
                  buffer.write(delta['content']);
                }
              }
            }
          } catch (_) {}
        }
      }
      if (buffer.isNotEmpty) return buffer.toString();
    }

    // Try to parse as JSON response
    try {
      final data = jsonDecode(raw);
      if (data is Map && data.containsKey('choices')) {
        return data['choices'][0]['message']['content'] ?? raw;
      }
    } catch (_) {}

    return raw;
  }

  /// Generate content for a specific task type (same as AiService).
  Future<AiWebResponse> generateContent(
      String taskType, String params) async {
    String prompt;
    switch (taskType) {
      case 'position':
        prompt = '帮我生成担任职务：$params\n职务描述：\n文字最少25个，最多200个';
        break;
      case 'reward':
        prompt = '帮我生成奖惩情况：$params\n描述文字最少25个，最多200个';
        break;
      case 'psychology':
        prompt = '本学期心理素质展示\n请描述你在高中阶段克服遇到的困难或应对挫折的典型事件，也可描述在人际交往、情绪调节等方面的事件，并简要说明你是如何应对的。（25~200字）';
        break;
      case 'statement':
        prompt = '本学期陈述报告\n用自己的成长事实，来说明自己的个性、兴趣、特长、发展潜能、生涯规划（愿望），语言简明扼要。（25~200字）';
        break;
      case 'party_activity':
        prompt = '活动主题：*\n活动类型：党团活动\n开始时间：*\n结束时间：*\n活动地点：*\n典型事例描述：描述参加的典型事例活动中你承担的任务，完成情况，获得的荣誉等。（25~200字）\n$params';
        break;
      case 'volunteer':
        prompt = '活动主题：*\n活动类型：志愿服务\n开始时间：*\n结束时间：*\n活动地点：*\n典型事例描述：描述参加的典型事例活动中你承担的任务，完成情况，获得的荣誉等。（25~200字）\n$params';
        break;
      case 'art':
        prompt = '年级：高中二年级 学年：2025-2026\n学期：下学期 项目：音乐\n高中阶段参加的社团及活动的情况：\n文字最少25个，最多200个\n高中阶段取得的校级（含校级）以上主要成绩（作品、成果、荣誉等）：\n文字最少25个，最多200个\n$params';
        break;
      case 'labor':
        prompt = '学年：2025-2026 学期：下学期\n类别：职业体验活动\n实践形式：\n内容：从事劳动与实践的工作内容描述。（25~200字）\n承担任务：在劳动与实践过程中，主要承担的实践任务。（25~200字）\n实践成果：实践任务完成后获得的奖励、证书，形成的作品等。（25~200字）\n$params';
        break;
      case 'research':
        prompt = '学年：2025-2026 学期：下学期\n类型：课题研究\n课题名称：$params\n理论学习情况：\n学时总数：*\n指导老师：*\n研究内容：*\n成果概述：';
        break;
      case 'project_design':
        prompt = '学年：2025-2026 学期：下学期\n类型：项目（活动）设计\n课题名称：$params\n理论学习情况：\n学时总数：*\n指导老师：*\n研究内容：*\n成果概述：';
        break;
      default:
        prompt = params;
    }
    return sendMessage(prompt);
  }

  /// Dispose resources.
  void dispose() {
    _controller = null;
    _isReady = false;
  }
}

class _PlatformConfig {
  final String url;
  final String chatInputSelector;
  final String sendButtonSelector;
  final String responseSelector;
  final String loginCheckJs;

  const _PlatformConfig({
    required this.url,
    required this.chatInputSelector,
    required this.sendButtonSelector,
    required this.responseSelector,
    required this.loginCheckJs,
  });
}

class AiWebResponse {
  final bool success;
  final String? content;
  final String? error;

  AiWebResponse({
    required this.success,
    this.content,
    this.error,
  });
}
