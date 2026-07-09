import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Windows initialization only on Windows platform
    InitializationSettings initSettings;
    if (Platform.isWindows) {
      // Windows not fully supported in flutter_local_notifications yet
      // Use Android-only initialization
      initSettings = const InitializationSettings(
        android: androidSettings,
      );
    } else {
      initSettings = const InitializationSettings(
        android: androidSettings,
      );
    }

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for Android
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  Future<void> showProgressNotification({
    required int progress,
    required String account,
    required String currentTask,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'automation_progress',
      '自动化进度',
      channelDescription: '显示自动化任务的进度',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      ongoing: true,
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      0,
      'ZonewApp - $progress%',
      '账号: $account\n当前: $currentTask',
      details,
      payload: 'progress',
    );
  }

  Future<void> showCompletionNotification({
    required String account,
    required int completed,
    required int total,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'automation_complete',
      '自动化完成',
      channelDescription: '自动化任务完成通知',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      1,
      'ZonewApp - 任务完成',
      '账号 $account 已完成 $completed/$total 个项目',
      details,
      payload: 'complete',
    );
  }

  Future<void> showErrorNotification({
    required String account,
    required String error,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'automation_error',
      '自动化错误',
      channelDescription: '自动化任务错误通知',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      2,
      'ZonewApp - 错误',
      '账号 $account 出错: $error',
      details,
      payload: 'error',
    );
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
