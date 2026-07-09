import 'package:json_annotation/json_annotation.dart';

part 'settings.g.dart';

@JsonSerializable()
class AppSettings {
  final String themeMode;
  final String? aiMode;
  final Map<String, dynamic>? aiConfig;
  final Map<String, String> subjectContents;
  final bool notificationEnabled;
  final bool webServiceEnabled;

  AppSettings({
    this.themeMode = 'system',
    this.aiMode,
    this.aiConfig,
    this.subjectContents = const {},
    this.notificationEnabled = true,
    this.webServiceEnabled = false,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => _$AppSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);

  AppSettings copyWith({
    String? themeMode,
    String? aiMode,
    Map<String, dynamic>? aiConfig,
    Map<String, String>? subjectContents,
    bool? notificationEnabled,
    bool? webServiceEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      aiMode: aiMode ?? this.aiMode,
      aiConfig: aiConfig ?? this.aiConfig,
      subjectContents: subjectContents ?? this.subjectContents,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      webServiceEnabled: webServiceEnabled ?? this.webServiceEnabled,
    );
  }
}

@JsonSerializable()
class ApiConfig {
  final String name;
  final String apiUrl;
  final String apiKey;
  final String model;
  final double temperature;
  final int maxTokens;

  ApiConfig({
    this.name = '',
    this.apiUrl = '',
    this.apiKey = '',
    this.model = '',
    this.temperature = 0.7,
    this.maxTokens = 500,
  });

  factory ApiConfig.fromJson(Map<String, dynamic> json) => _$ApiConfigFromJson(json);
  Map<String, dynamic> toJson() => _$ApiConfigToJson(this);

  ApiConfig copyWith({
    String? name,
    String? apiUrl,
    String? apiKey,
    String? model,
    double? temperature,
    int? maxTokens,
  }) {
    return ApiConfig(
      name: name ?? this.name,
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
    );
  }
}

@JsonSerializable()
class WebAiConfig {
  final String platform;
  final String loginUrl;
  final String cookies;
  final String sessionData;

  WebAiConfig({
    this.platform = 'deepseek',
    this.loginUrl = 'https://www.deepseek.com/',
    this.cookies = '',
    this.sessionData = '',
  });

  factory WebAiConfig.fromJson(Map<String, dynamic> json) => _$WebAiConfigFromJson(json);
  Map<String, dynamic> toJson() => _$WebAiConfigToJson(this);

  WebAiConfig copyWith({
    String? platform,
    String? loginUrl,
    String? cookies,
    String? sessionData,
  }) {
    return WebAiConfig(
      platform: platform ?? this.platform,
      loginUrl: loginUrl ?? this.loginUrl,
      cookies: cookies ?? this.cookies,
      sessionData: sessionData ?? this.sessionData,
    );
  }
}
