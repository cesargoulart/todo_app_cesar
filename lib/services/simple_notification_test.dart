import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SimpleNotificationTest {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initializeSimple() async {
    debugPrint('🔔 Simple notification test - initializing...');

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    try {
      final result = await _notifications.initialize(initSettings);
      debugPrint('🔔 Simple init result: $result');

      // Request permission
      final androidPlugin =
          _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (androidPlugin != null) {
        final permission = await androidPlugin.requestNotificationsPermission();
        debugPrint('🔔 Permission result: $permission');
      }
    } catch (e) {
      debugPrint('❌ Simple init error: $e');
    }
  }

  static Future<void> showSimpleNotification() async {
    debugPrint('🔔 Showing simple notification...');

    try {
      await _notifications.show(
        123456,
        'Simple Test',
        'This is a super simple notification test!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'simple_channel',
            'Simple Channel',
            channelDescription: 'Simple notification channel',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
      debugPrint('✅ Simple notification sent!');
    } catch (e) {
      debugPrint('❌ Simple notification error: $e');
    }
  }
}
