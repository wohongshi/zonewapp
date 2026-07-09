import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Initialize storage service
  await StorageService.instance.init();

  // Initialize notification service
  await NotificationService.instance.init();

  runApp(
    const ProviderScope(
      child: ZonewApp(),
    ),
  );
}
