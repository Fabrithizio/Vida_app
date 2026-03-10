import 'package:flutter/material.dart';
import '../pages/login_page.dart';

class VidaApp extends StatelessWidget {
  const VidaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Axyo',
      theme: ThemeData(useMaterial3: true),
      home: const LoginPage(),
    );
  }
}
