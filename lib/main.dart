// lib/main.dart
 
import 'package:flutter/material.dart';
import 'app/app_initializer.dart';
import 'app/app_widget.dart';
 
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInitializer.initialize();
  runApp(const MyApp());
}
 