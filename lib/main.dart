import 'dart:io';

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) await Background.start();
  runApp(const NoSwanApp());
}

class NoSwanApp extends StatelessWidget {
  const NoSwanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'No Swan',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
