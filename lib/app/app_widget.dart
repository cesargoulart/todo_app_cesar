// lib/app/app_widget.dart
//
// Widget raiz da aplicação.
// Gere o ThemeMode e o login — toda a restante lógica está nos ecrãs e serviços.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/login_screen.dart';
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
      home: _AuthGate(
        child: ToDoListScreen(onThemeModeChanged: _onThemeModeChanged),
      ),
    );
  }
}

/// Mostra o LoginScreen enquanto não houver sessão do Supabase.
/// A sessão fica guardada localmente, por isso o login só é pedido uma vez.
class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final GoTrueClient auth;
    try {
      auth = Supabase.instance.client.auth;
    } catch (_) {
      // Supabase não inicializou (ex.: sem rede no arranque): segue em modo local.
      return child;
    }

    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) =>
          auth.currentSession != null ? child : const LoginScreen(),
    );
  }
}