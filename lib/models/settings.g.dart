// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => AppSettings(
      themeMode: json['themeMode'] as String? ?? 'system',
      aiMode: json['aiMode'] as String?,
      aiConfig: json['aiConfig'] as Map<String, dynamic>?,
      subjectContents: (json['subjectContents'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          {},
      notificationEnabled: json['notificationEnabled'] as bool? ?? true,
      webServiceEnabled: json['webServiceEnabled'] as bool? ?? false,
      predictiveBackEnabled: json['predictiveBackEnabled'] as bool? ?? false,
    );

Map<String, dynamic> _$AppSettingsToJson(AppSettings instance) =>
    <String, dynamic>{
      'themeMode': instance.themeMode,
      'aiMode': instance.aiMode,
      'aiConfig': instance.aiConfig,
      'subjectContents': instance.subjectContents,
      'notificationEnabled': instance.notificationEnabled,
      'webServiceEnabled': instance.webServiceEnabled,
      'predictiveBackEnabled': instance.predictiveBackEnabled,
    };

ApiConfig _$ApiConfigFromJson(Map<String, dynamic> json) => ApiConfig(
      name: json['name'] as String? ?? '',
      apiUrl: json['apiUrl'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      model: json['model'] as String? ?? '',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: (json['maxTokens'] as num?)?.toInt() ?? 500,
    );

Map<String, dynamic> _$ApiConfigToJson(ApiConfig instance) => <String, dynamic>{
      'name': instance.name,
      'apiUrl': instance.apiUrl,
      'apiKey': instance.apiKey,
      'model': instance.model,
      'temperature': instance.temperature,
      'maxTokens': instance.maxTokens,
    };

WebAiConfig _$WebAiConfigFromJson(Map<String, dynamic> json) => WebAiConfig(
      platform: json['platform'] as String? ?? 'deepseek',
      loginUrl: json['loginUrl'] as String? ?? 'https://www.deepseek.com/',
      cookies: json['cookies'] as String? ?? '',
      sessionData: json['sessionData'] as String? ?? '',
    );

Map<String, dynamic> _$WebAiConfigToJson(WebAiConfig instance) =>
    <String, dynamic>{
      'platform': instance.platform,
      'loginUrl': instance.loginUrl,
      'cookies': instance.cookies,
      'sessionData': instance.sessionData,
    };
