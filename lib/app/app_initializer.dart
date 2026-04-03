// lib/app/app_initializer.dart
//
// Responsável por inicializar todos os serviços antes do app arrancar.
// Mantém o main.dart limpo.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_credentials.dart';
import '../services/notification_service.dart';
import '../services/auto_update_service.dart';

class AppInitializer {
  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnnonKey,
      );
      print('✅ Supabase initialized');

      await NotificationService().initialize();
      print('✅ NotificationService initialized');

      await AutoUpdateService().initialize();
      print('✅ AutoUpdateService initialized');
    } catch (e) {
      print('❌ Initialization error: $e');
      // App continua mesmo que algum serviço falhe
    }
  }
}