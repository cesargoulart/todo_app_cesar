// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/todo_list_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_credentials.dart';
import 'services/notification_service.dart';
import 'services/auto_update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnnonKey,
    );
    print('✅ Supabase initialized successfully');

    await NotificationService().initialize();
    print('✅ NotificationService initialized successfully');

    await AutoUpdateService().initialize();
    print('✅ AutoUpdateService initialized successfully');
  } catch (e) {
    print('❌ Error during initialization: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Paleta principal: violeta/índigo moderno
    const seedColor = Color(0xFF7C3AED);
    const seedColorDark = Color(0xFF8B5CF6);

    return MaterialApp(
      title: 'My Tasks',

      // ── TEMA CLARO ──────────────────────────────────────────────────────
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
          surface: const Color(0xFFF8F7FF),
          onSurface: const Color(0xFF1A1A2E),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F3FF),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF1A1A2E),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A2E),
            letterSpacing: -0.5,
          ),
        ),

        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: const Color(0x1A7C3AED),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: seedColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: seedColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: seedColor,
            side: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF3F0FF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE0D7FF), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: seedColor, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          hintStyle: const TextStyle(color: Color(0xFFAA99CC)),
          labelStyle: const TextStyle(color: Color(0xFF7C3AED)),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),

        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 12,
          shadowColor: const Color(0x337C3AED),
        ),

        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          modalBackgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          showDragHandle: true,
          dragHandleColor: Color(0xFFD0C8F0),
          dragHandleSize: Size(40, 4),
          elevation: 16,
        ),

        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1A1730),
          contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 8,
        ),

        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return seedColor;
            return Colors.transparent;
          }),
          side: const BorderSide(color: Color(0xFFBBAEE8), width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),

        dividerTheme: const DividerThemeData(
          space: 1,
          thickness: 1,
          color: Color(0xFFEEE8FF),
        ),

        drawerTheme: const DrawerThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
          ),
        ),

        listTileTheme: const ListTileThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        ),

        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: seedColor,
          linearTrackColor: Color(0xFFEEE8FF),
          circularTrackColor: Color(0xFFEEE8FF),
        ),

        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: const Color(0x1A7C3AED),
        ),
      ),

      // ── TEMA ESCURO ─────────────────────────────────────────────────────
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColorDark,
          brightness: Brightness.dark,
          surface: const Color(0xFF13111F),
          onSurface: const Color(0xFFEDE9FF),
          primary: seedColorDark,
          primaryContainer: const Color(0xFF2D1F5E),
          secondary: const Color(0xFF6366F1),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0D0B17),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFFEDE9FF),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFFEDE9FF),
            letterSpacing: -0.5,
          ),
        ),

        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: const Color(0xFF1C1830),
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black38,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: seedColorDark,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFA78BFA),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFA78BFA),
            side: const BorderSide(color: Color(0xFF4A3A8A), width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1F1C30),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2D2844), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: seedColorDark, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          hintStyle: const TextStyle(color: Color(0xFF5A5070)),
          labelStyle: const TextStyle(color: Color(0xFFA78BFA)),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: seedColorDark,
          foregroundColor: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),

        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF1C1830),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 12,
          shadowColor: Colors.black54,
        ),

        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF1C1830),
          surfaceTintColor: Colors.transparent,
          modalBackgroundColor: Color(0xFF1C1830),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          showDragHandle: true,
          dragHandleColor: Color(0xFF3D3460),
          dragHandleSize: Size(40, 4),
          elevation: 16,
        ),

        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF2D2844),
          contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 8,
        ),

        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return seedColorDark;
            return Colors.transparent;
          }),
          side: const BorderSide(color: Color(0xFF4A4065), width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),

        dividerTheme: const DividerThemeData(
          space: 1,
          thickness: 1,
          color: Color(0xFF2D2844),
        ),

        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF13111F),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
          ),
        ),

        listTileTheme: const ListTileThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        ),

        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: seedColorDark,
          linearTrackColor: Color(0xFF2D2844),
          circularTrackColor: Color(0xFF2D2844),
        ),

        popupMenuTheme: PopupMenuThemeData(
          color: const Color(0xFF1C1830),
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: Colors.black54,
          textStyle: const TextStyle(color: Color(0xFFEDE9FF), fontSize: 14),
        ),
      ),

      themeMode: _themeMode,
      home: ToDoListScreen(onThemeModeChanged: _changeTheme),
      debugShowCheckedModeBanner: false,
    );
  }
}
