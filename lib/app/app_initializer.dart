// lib/app/app_initializer.dart
//
// Responsável por inicializar todos os serviços antes do app arrancar.
// Mantém o main.dart limpo.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_credentials_web.dart'
    if (dart.library.io) '../supabase_credentials.dart';
import '../services/notification_service.dart';
import '../services/auto_update_service_web.dart'
    if (dart.library.io) '../services/auto_update_service.dart';

class AppInitializer {
  static Future<void> initialize() async {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnnonKey);
      debugPrint('✅ Supabase initialized');

      await NotificationService().initialize();
      debugPrint('✅ NotificationService initialized');

      await AutoUpdateService().initialize();
      debugPrint('✅ AutoUpdateService initialized');
    } catch (e) {
      debugPrint('❌ Initialization error: $e');
      // App continua mesmo que algum serviço falhe
    }
  }
}
