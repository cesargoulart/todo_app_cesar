// lib/main.dart

import 'package:flutter/material.dart';
import '../screens/todo_list_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_credentials.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnnonKey,
  );
  
  runApp(const MyApp());
}

// 1. Convert MyApp to a StatefulWidget
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 2. Add state to hold the current theme mode
  ThemeMode _themeMode = ThemeMode.system;

  // 3. Create a method to change the theme
  void _changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter To-Do App',
      
      // 4. Define the Light Theme
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),

      // 5. Define the Dark Theme
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212), // A common dark background color
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.teal,
        ),
      ),

      // 6. Set the current theme mode from our state variable
      themeMode: _themeMode,

      // 7. Pass the changeTheme function down to the home screen
      home: ToDoListScreen(onThemeModeChanged: _changeTheme),
      
      debugShowCheckedModeBanner: false,
    );
  }
}
