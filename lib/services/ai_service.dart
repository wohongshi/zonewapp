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

    // For web mode, we use DeepSeek API as fallback
    final apiUrl = 'https://api.deepseek.com/v1/chat/completions';

    try {
      final response = await _dio.post(
        apiUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (_webConfig!.sessionData.isNotEmpty)
              'Authorization': 'Bearer ${_webConfig!.sessionData}',
          },
        ),
        data: {
          'model': 'deepseek-chat',
          'messages': [
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
