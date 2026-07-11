import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/settings.dart';

class AiService {
  static final AiService instance = AiService._();
  AiService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
  ));

  AiMode? _mode;
  ApiConfig? _apiConfig;
  WebAiConfig? _webConfig;

  void setApiMode(ApiConfig config) {
    _mode = AiMode.api;
    _apiConfig = config;
    _webConfig = null;
  }

  void setWebMode(WebAiConfig config) {
    _mode = AiMode.web;
    _webConfig = config;
    _apiConfig = null;
  }

  Future<AiResponse> testConnection() async {
    return sendMessage('你好');
  }

  Future<AiResponse> sendMessage(String prompt) async {
    if (_mode == null) {
      return AiResponse(
        content: '',
        success: false,
        error: '请配置相应AI',
      );
    }

    try {
      if (_mode == AiMode.api) {
        return await _sendApiRequest(prompt);
      } else {
        return await _sendWebRequest(prompt);
      }
    } catch (e) {
      return AiResponse(
        content: '',
        success: false,
        error: 'AI请求失败: ${e.toString()}',
      );
    }
  }

  Future<AiResponse> _sendApiRequest(String prompt) async {
    if (_apiConfig == null) {
      return AiResponse(content: '', success: false, error: 'API未配置');
    }

    final response = await _dio.post(
      _apiConfig!.apiUrl,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${_apiConfig!.apiKey}',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': _apiConfig!.model,
        'messages': [
          {'role': 'system', 'content': '你是一个帮助高中生填写山东省综合评价平台的AI助手。请根据要求生成简洁、真实、符合学生身份的内容。字数严格控制在25-200字之间。不要包含标题、序号或多余的格式符号。'},
          {'role': 'user', 'content': prompt},
        ],
        'temperature': _apiConfig!.temperature,
        'max_tokens': _apiConfig!.maxTokens,
        'stream': false,
      },
    );

    if (response.statusCode == 200) {
      final data = response.data;
      final content = data['choices'][0]['message']['content'] ?? '';
      return AiResponse(content: content, success: true);
    } else {
      return AiResponse(
        content: '',
        success: false,
        error: 'API请求失败: ${response.statusCode}',
      );
    }
  }

  Future<AiResponse> _sendWebRequest(String prompt) async {
    if (_webConfig == null) {
      return AiResponse(content: '', success: false, error: '网页模式未配置');
    }

    final sessionData = _webConfig!.sessionData;

    // Try to parse session data as captured request info
    Map<String, dynamic>? capturedReq;
    try {
      capturedReq = jsonDecode(sessionData);
    } catch (_) {
      // Legacy format: sessionData is just a token string
    }

    if (capturedReq != null && capturedReq.containsKey('apiUrl')) {
      // New format: replay captured request
      return await _replayCapturedRequest(prompt, capturedReq);
    }

    // Legacy fallback: try the old DeepSeek API approach
    return await _legacyWebRequest(prompt, sessionData);
  }

  /// Replay a captured web API request with the user's prompt.
  /// This uses the exact same endpoint, headers, and body format
  /// that the web app uses, so authentication works naturally.
  Future<AiResponse> _replayCapturedRequest(
      String prompt, Map<String, dynamic> captured) async {
    final apiUrl = captured['apiUrl'] as String? ?? '';
    final capturedHeaders =
        captured['headers'] as Map<String, dynamic>? ?? {};
    final bodyTemplate = captured['bodyTemplate'] as String? ?? '';

    if (apiUrl.isEmpty) {
      return AiResponse(
          content: '', success: false, error: '捕获的API URL为空');
    }

    // Build headers from captured data
    final headers = <String, String>{};
    capturedHeaders.forEach((key, value) {
      if (key.toLowerCase() != 'content-length') {
        headers[key] = value.toString();
      }
    });
    headers['content-type'] = 'application/json';

    // Try to build request body by replacing the user message in the template
    dynamic body;
    try {
      if (bodyTemplate.isNotEmpty) {
        // Parse the captured body and replace the user message
        final templateBody = jsonDecode(bodyTemplate);
        body = _replacePromptInBody(templateBody, prompt);
      }
    } catch (_) {}

    // If we couldn't build from template, try common formats
    body ??= _buildFallbackBody(prompt, apiUrl);

    try {
      final response = await _dio.post(
        apiUrl,
        options: Options(
          headers: headers,
          validateStatus: (status) => true, // Accept any status
        ),
        data: body is String ? body : jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return _parseWebResponse(response);
      } else if (response.statusCode == 401) {
        return AiResponse(
          content: '',
          success: false,
          error: '认证失败(401)，请重新登录DeepSeek并进行一次对话后再获取',
        );
      } else {
        return AiResponse(
          content: '',
          success: false,
          error: '网页API请求失败: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      return AiResponse(
        content: '',
        success: false,
        error: '网页API请求异常: $e',
      );
    }
  }

  /// Replace the user's prompt in a captured request body.
  /// Handles various API formats (OpenAI-style, DeepSeek custom, etc.)
  Map<String, dynamic> _replacePromptInBody(
      Map<String, dynamic> body, String prompt) {
    final result = Map<String, dynamic>.from(body);

    // OpenAI / DeepSeek chat format: messages array
    if (result.containsKey('messages')) {
      final messages = result['messages'];
      if (messages is List) {
        // Find last user message and replace it
        for (int i = messages.length - 1; i >= 0; i--) {
          final msg = messages[i];
          if (msg is Map && msg['role'] == 'user') {
            messages[i] = {'role': 'user', 'content': prompt};
            break;
          }
        }
        // If no user message found, add one
        if (!messages.any((m) => m is Map && m['role'] == 'user')) {
          messages.add({'role': 'user', 'content': prompt});
        }
      }
      return result;
    }

    // Other formats: try common field names
    for (final key in ['prompt', 'query', 'input', 'text', 'content', 'message']) {
      if (result.containsKey(key)) {
        result[key] = prompt;
        return result;
      }
    }

    // Fallback: add messages array
    result['messages'] = [
      {'role': 'user', 'content': prompt}
    ];
    return result;
  }

  /// Build a fallback request body for common API formats.
  dynamic _buildFallbackBody(String prompt, String url) {
    // DeepSeek-style
    if (url.contains('deepseek')) {
      return {
        'messages': [
          {'role': 'system', 'content': '你是一个帮助高中生填写山东省综合评价平台的AI助手。请根据要求生成简洁、真实、符合学生身份的内容。字数严格控制在25-200字之间。'},
          {'role': 'user', 'content': prompt}
        ],
        'model': 'deepseek-chat',
        'stream': false,
      };
    }
    // Generic OpenAI-compatible
    return {
      'messages': [
        {'role': 'system', 'content': '你是一个帮助高中生填写山东省综合评价平台的AI助手。请根据要求生成简洁、真实、符合学生身份的内容。字数严格控制在25-200字之间。'},
        {'role': 'user', 'content': prompt}
      ],
      'stream': false,
    };
  }

  /// Parse various web API response formats into AiResponse.
  AiResponse _parseWebResponse(Response response) {
    try {
      final data = response.data;

      // Handle streaming response (SSE)
      if (data is String && data.contains('data:')) {
        return _parseSSEResponse(data);
      }

      // JSON response
      if (data is Map<String, dynamic>) {
        // OpenAI-compatible: choices[0].message.content
        if (data.containsKey('choices')) {
          final choices = data['choices'];
          if (choices is List && choices.isNotEmpty) {
            final choice = choices[0];
            if (choice is Map) {
              // Chat completion format
              if (choice.containsKey('message')) {
                final msg = choice['message'];
                if (msg is Map && msg.containsKey('content')) {
                  return AiResponse(
                      content: msg['content'].toString(), success: true);
                }
              }
              // Text completion format
              if (choice.containsKey('text')) {
                return AiResponse(
                    content: choice['text'].toString(), success: true);
              }
            }
          }
        }

        // DeepSeek custom format
        if (data.containsKey('result') || data.containsKey('response')) {
          final content = data['result'] ?? data['response'];
          return AiResponse(content: content.toString(), success: true);
        }

        // Generic: try to find any content field
        for (final key in ['content', 'text', 'output', 'answer']) {
          if (data.containsKey(key)) {
            return AiResponse(
                content: data[key].toString(), success: true);
          }
        }
      }

      return AiResponse(
        content: data.toString(),
        success: true,
      );
    } catch (e) {
      return AiResponse(
        content: '',
        success: false,
        error: '解析响应失败: $e',
      );
    }
  }

  /// Parse Server-Sent Events (SSE) streaming response.
  AiResponse _parseSSEResponse(String sseData) {
    final buffer = StringBuffer();
    for (final line in sseData.split('\n')) {
      if (line.startsWith('data:')) {
        final jsonStr = line.substring(5).trim();
        if (jsonStr == '[DONE]') continue;
        try {
          final chunk = jsonDecode(jsonStr);
          // OpenAI streaming format
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
    if (buffer.isNotEmpty) {
      return AiResponse(content: buffer.toString(), success: true);
    }
    return AiResponse(
      content: '',
      success: false,
      error: '无法解析SSE响应',
    );
  }

  /// Legacy web request fallback (old approach).
  Future<AiResponse> _legacyWebRequest(
      String prompt, String sessionData) async {
    final apiUrl = 'https://api.deepseek.com/v1/chat/completions';
    try {
      final response = await _dio.post(
        apiUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (sessionData.isNotEmpty)
              'Authorization': 'Bearer $sessionData',
          },
        ),
        data: {
          'model': 'deepseek-chat',
          'messages': [
            {'role': 'system', 'content': '你是一个帮助高中生填写山东省综合评价平台的AI助手。请根据要求生成简洁、真实、符合学生身份的内容。字数严格控制在25-200字之间。不要包含标题、序号或多余的格式符号。'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
          'max_tokens': 500,
          'stream': false,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final content = data['choices'][0]['message']['content'] ?? '';
        return AiResponse(content: content, success: true);
      } else {
        return AiResponse(
          content: '',
          success: false,
          error: '网页模式AI请求失败',
        );
      }
    } catch (e) {
      return AiResponse(
        content: '',
        success: false,
        error: '网页模式AI请求失败: ${e.toString()}',
      );
    }
  }

  Future<AiResponse> generateContent(String taskType, String params) async {
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
}

enum AiMode { api, web }

class AiResponse {
  final String content;
  final bool success;
  final String? error;

  AiResponse({
    required this.content,
    required this.success,
    this.error,
  });
}
