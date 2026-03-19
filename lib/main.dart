// ============================================================================
// FILE: lib/main.dart
//
// Modo imersivo (esconde barra de status e barra de navegação):
// - Remove hora/wifi/bateria do topo dentro do app
// - Ideal para telas “game/dashboard”
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'presentation/app/app.dart';
import 'services/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Esconde status bar + navigation bar
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // (Opcional) força estilo de status bar (quando aparecer por gesture)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await Firebase.initializeApp();
  await Hive.initFlutter();
  await NotificationService.instance.init();

  runApp(const VidaApp());
}
