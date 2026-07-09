// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Account _$AccountFromJson(Map<String, dynamic> json) => Account(
      id: json['id'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      subjects: (json['subjects'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      teacherName: json['teacher_name'] as String,
      positions: (json['positions'] as List<dynamic>)
          .map((e) => PositionEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      rewards: (json['rewards'] as List<dynamic>)
          .map((e) => RewardEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: json['status'] as String? ?? '未完成',
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );

Map<String, dynamic> _$AccountToJson(Account instance) => <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'password': instance.password,
      'subjects': instance.subjects,
      'teacher_name': instance.teacherName,
      'positions': instance.positions.map((e) => e.toJson()).toList(),
      'rewards': instance.rewards.map((e) => e.toJson()).toList(),
      'status': instance.status,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };

PositionEntry _$PositionEntryFromJson(Map<String, dynamic> json) =>
    PositionEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
    );

Map<String, dynamic> _$PositionEntryToJson(PositionEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
    };

RewardEntry _$RewardEntryFromJson(Map<String, dynamic> json) => RewardEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      level: json['level'] as String,
      department: json['department'] as String,
      imagePath: json['image_path'] as String?,
    );

Map<String, dynamic> _$RewardEntryToJson(RewardEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'level': instance.level,
      'department': instance.department,
      'image_path': instance.imagePath,
    };

ProjectItem _$ProjectItemFromJson(Map<String, dynamic> json) => ProjectItem(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String? ?? '未开始',
      aiContent: json['ai_content'] as String?,
      screenshotPath: json['screenshot_path'] as String?,
    );

Map<String, dynamic> _$ProjectItemToJson(ProjectItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'status': instance.status,
      'ai_content': instance.aiContent,
      'screenshot_path': instance.screenshotPath,
    };

TaskProgress _$TaskProgressFromJson(Map<String, dynamic> json) => TaskProgress(
      total: (json['total'] as num).toInt(),
      completed: (json['completed'] as num).toInt(),
      running: (json['running'] as num).toInt(),
      failed: (json['failed'] as num).toInt(),
      currentTask: json['current_task'] as String?,
      percentage: (json['percentage'] as num).toDouble(),
    );

Map<String, dynamic> _$TaskProgressToJson(TaskProgress instance) =>
    <String, dynamic>{
      'total': instance.total,
      'completed': instance.completed,
      'running': instance.running,
      'failed': instance.failed,
      'current_task': instance.currentTask,
      'percentage': instance.percentage,
    };
