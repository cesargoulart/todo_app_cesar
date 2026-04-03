// lib/app/app_widget.dart
//
// Widget raiz da aplicação.
// Gere apenas o ThemeMode — toda a restante lógica está nos ecrãs e serviços.

import 'package:flutter/material.dart';
import '../screens/todo_list_screen.dart';
import 'app_theme_data.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _onThemeModeChanged(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Tasks',
      debugShowCheckedModeBanner: false,
      theme: AppThemeData.light,
      darkTheme: AppThemeData.dark,
      themeMode: _themeMode,
      home: ToDoListScreen(onThemeModeChanged: _onThemeModeChanged),
    );
  }
}