import 'package:json_annotation/json_annotation.dart';

part 'account.g.dart';

@JsonSerializable()
class Account {
  final String id;
  final String username;
  final String password;
  final List<String> subjects;
  final String teacherName;
  final List<PositionEntry> positions;
  final List<RewardEntry> rewards;
  final String status;
  final String createdAt;
  final String updatedAt;

  Account({
    required this.id,
    required this.username,
    required this.password,
    required this.subjects,
    required this.teacherName,
    required this.positions,
    required this.rewards,
    this.status = '未完成',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Account.fromJson(Map<String, dynamic> json) => _$AccountFromJson(json);
  Map<String, dynamic> toJson() => _$AccountToJson(this);

  Account copyWith({
    String? id,
    String? username,
    String? password,
    List<String>? subjects,
    String? teacherName,
    List<PositionEntry>? positions,
    List<RewardEntry>? rewards,
    String? status,
    String? createdAt,
    String? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      subjects: subjects ?? this.subjects,
      teacherName: teacherName ?? this.teacherName,
      positions: positions ?? this.positions,
      rewards: rewards ?? this.rewards,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@JsonSerializable()
class PositionEntry {
  final String id;
  final String title;
  final String description;

  PositionEntry({
    required this.id,
    required this.title,
    required this.description,
  });

  factory PositionEntry.fromJson(Map<String, dynamic> json) => _$PositionEntryFromJson(json);
  Map<String, dynamic> toJson() => _$PositionEntryToJson(this);
}

@JsonSerializable()
class RewardEntry {
  final String id;
  final String title;
  final String level;
  final String department;
  final String? imagePath;

  RewardEntry({
    required this.id,
    required this.title,
    required this.level,
    required this.department,
    this.imagePath,
  });

  factory RewardEntry.fromJson(Map<String, dynamic> json) => _$RewardEntryFromJson(json);
  Map<String, dynamic> toJson() => _$RewardEntryToJson(this);
}

@JsonSerializable()
class ProjectItem {
  final String id;
  final String name;
  final String status;
  final String? aiContent;
  final String? screenshotPath;

  ProjectItem({
    required this.id,
    required this.name,
    this.status = '未开始',
    this.aiContent,
    this.screenshotPath,
  });

  factory ProjectItem.fromJson(Map<String, dynamic> json) => _$ProjectItemFromJson(json);
  Map<String, dynamic> toJson() => _$ProjectItemToJson(this);

  ProjectItem copyWith({
    String? id,
    String? name,
    String? status,
    String? aiContent,
    String? screenshotPath,
  }) {
    return ProjectItem(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      aiContent: aiContent ?? this.aiContent,
      screenshotPath: screenshotPath ?? this.screenshotPath,
    );
  }
}

@JsonSerializable()
class TaskProgress {
  final int total;
  final int completed;
  final int running;
  final int failed;
  final String? currentTask;
  final double percentage;

  TaskProgress({
    required this.total,
    required this.completed,
    required this.running,
    required this.failed,
    this.currentTask,
    required this.percentage,
  });

  factory TaskProgress.fromJson(Map<String, dynamic> json) => _$TaskProgressFromJson(json);
  Map<String, dynamic> toJson() => _$TaskProgressToJson(this);
}
