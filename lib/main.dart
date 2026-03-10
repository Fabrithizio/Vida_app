import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'presentation/app/app.dart';
import 'services/notifications/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await Hive.initFlutter();
  tz.initializeTimeZones();
  await NotificationService.instance.init();

  runApp(const VidaApp());
}
