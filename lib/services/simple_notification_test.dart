import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SimpleNotificationTest {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();

  static Future<void> initializeSimple() async {
    print('🔔 Simple notification test - initializing...');
    
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    try {
      final result = await _notifications.initialize(initSettings);
      print('🔔 Simple init result: $result');
      
      // Request permission
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final permission = await androidPlugin.requestNotificationsPermission();
        print('🔔 Permission result: $permission');
      }
      
    } catch (e) {
      print('❌ Simple init error: $e');
    }
  }

  static Future<void> showSimpleNotification() async {
    print('🔔 Showing simple notification...');
    
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
      print('✅ Simple notification sent!');
    } catch (e) {
      print('❌ Simple notification error: $e');
    }
  }
}
