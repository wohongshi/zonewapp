import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

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

  factory ProjectItem.fromJson(Map<String, dynamic> json) {
    return ProjectItem(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String? ?? '未开始',
      aiContent: json['ai_content'] as String?,
      screenshotPath: json['screenshot_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'ai_content': aiContent,
      'screenshot_path': screenshotPath,
    };
  }

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
