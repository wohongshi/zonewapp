// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_template.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskTemplate _$TaskTemplateFromJson(Map<String, dynamic> json) =>
    TaskTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      enabled: json['enabled'] as bool? ?? true,
      useAi: json['useAi'] as bool? ?? true,
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => TemplateStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      aiPrompt: json['aiPrompt'] as String?,
      aiTaskType: json['aiTaskType'] as String?,
      directValue: json['directValue'] as String?,
    );

Map<String, dynamic> _$TaskTemplateToJson(TaskTemplate instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'url': instance.url,
      'enabled': instance.enabled,
      'useAi': instance.useAi,
      'steps': instance.steps,
      'aiPrompt': instance.aiPrompt,
      'aiTaskType': instance.aiTaskType,
      'directValue': instance.directValue,
    };

TemplateStep _$TemplateStepFromJson(Map<String, dynamic> json) =>
    TemplateStep(
      action: json['action'] as String,
      selector: json['selector'] as String? ?? '',
      value: json['value'] as String?,
      description: json['description'] as String,
      waitMs: (json['waitMs'] as num?)?.toInt(),
    );

Map<String, dynamic> _$TemplateStepToJson(TemplateStep instance) =>
    <String, dynamic>{
      'action': instance.action,
      'selector': instance.selector,
      'value': instance.value,
      'description': instance.description,
      'waitMs': instance.waitMs,
    };
