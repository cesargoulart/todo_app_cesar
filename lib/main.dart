// lib/main.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'app/app_initializer.dart';
import 'app/app_widget.dart';
import 'services/window_tray_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInitializer.initialize();
  if (Platform.isWindows) {
    await WindowTrayService.instance.initialize();
  }
  runApp(const MyApp());
}
