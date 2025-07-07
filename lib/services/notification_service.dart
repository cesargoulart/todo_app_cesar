import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static const String _channelId = 'todo_notifications';
  static const String _channelName = 'Todo Notifications';
  static const String _channelDescription = 'Notifications for todo tasks and deadlines';

  Future<void> initialize() async {
    try {
      print('🔔 Initializing NotificationService...');
      
      // Initialize timezone data
      tz.initializeTimeZones();
      print('✅ Timezone initialized');

      // Android initialization
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization  
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      print('🔔 Plugin initialized: $initialized');

      // Create notification channel for Android
      await _createNotificationChannel();
      print('✅ Notification channel created');

      // Request permissions
      await _requestPermissions();
      print('✅ Permissions requested');
      
      print('🎉 NotificationService initialization completed successfully!');
    } catch (e, stackTrace) {
      print('❌ Error initializing notifications: $e');
      print('📍 Stack trace: $stackTrace');
    }
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
    );

    await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _requestPermissions() async {
    try {
      print('🔑 Requesting notification permissions...');
      
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

      // Request Android permissions (for Android 13+)
      if (androidPlugin != null) {
        print('📱 Requesting Android permissions...');
        final permission = await androidPlugin.requestNotificationsPermission();
        print('📱 Android notification permission granted: $permission');
        
        // Also request exact alarm permission
        final exactAlarmPermission = await androidPlugin.requestExactAlarmsPermission();
        print('⏰ Exact alarm permission granted: $exactAlarmPermission');
      } else {
        print('❌ Android plugin not available');
      }

      // Request iOS permissions
      if (iosPlugin != null) {
        print('🍎 Requesting iOS permissions...');
        final permission = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        print('🍎 iOS permission granted: $permission');
      } else {
        print('❌ iOS plugin not available');
      }
    } catch (e, stackTrace) {
      print('❌ Error requesting permissions: $e');
      print('📍 Stack trace: $stackTrace');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');
    // You can add navigation logic here if needed
  }

  /// Schedule a notification for when a task is due
  Future<void> scheduleTaskDueNotification({
    required String taskId,
    required String taskTitle,
    required DateTime dueDate,
  }) async {
    try {
      // Create TZDateTime from local DateTime properly
      final scheduledDate = tz.TZDateTime(
        tz.local,
        dueDate.year,
        dueDate.month,
        dueDate.day,
        dueDate.hour,
        dueDate.minute,
        dueDate.second,
      );
      
      print('📅 Scheduling due notification for task: $taskTitle');
      print('📅 Due date (input): $dueDate');
      print('📅 Scheduled for (TZDateTime): $scheduledDate');
      print('📅 Current time: ${tz.TZDateTime.now(tz.local)}');
      print('📅 Time until due: ${scheduledDate.difference(tz.TZDateTime.now(tz.local))}');
      print('📅 Is in future: ${scheduledDate.isAfter(tz.TZDateTime.now(tz.local))}');
      
      // Only schedule if the due date is in the future
      if (scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {        await _notifications.zonedSchedule(
          taskId.hashCode, // Use task ID hash as notification ID
          'Task Due! 🔔',
          'Task "$taskTitle" is due now',
          scheduledDate,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.max, // Use max importance to ensure it shows
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              ticker: 'Task Due', // Ticker text for older Android versions
              showWhen: true,
              when: null,
              usesChronometer: false,
              timeoutAfter: null,
              category: AndroidNotificationCategory.reminder,
              fullScreenIntent: true,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
        payload: 'task_due:$taskId',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('✅ Due notification scheduled successfully for: $taskTitle');
    } else {
      print('❌ Due notification NOT scheduled (date is in the past): $taskTitle');
    }
    } catch (e, stackTrace) {
      print('❌ Error scheduling due notification: $e');
      print('📍 Stack trace: $stackTrace');
    }
  }

  /// Schedule a reminder notification before the task is due
  Future<void> scheduleTaskReminderNotification({
    required String taskId,
    required String taskTitle,
    required DateTime dueDate,
    required Duration reminderBefore,
  }) async {
    final reminderDate = dueDate.subtract(reminderBefore);
    final scheduledDate = tz.TZDateTime.from(reminderDate, tz.local);
    
    // Only schedule if the reminder date is in the future
    if (scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
      await _notifications.zonedSchedule(
        '${taskId}_reminder'.hashCode, // Use task ID + reminder as notification ID
        'Task Reminder',
        'Task "$taskTitle" is due ${_formatReminderTime(reminderBefore)}',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'task_reminder:$taskId',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Show an immediate notification when a task is completed
  Future<void> showTaskCompletedNotification({
    required String taskTitle,
  }) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Use timestamp as ID
      'Task Completed!',
      'Great job! You completed "$taskTitle"',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'task_completed',
    );
  }

  /// Cancel all notifications for a specific task
  Future<void> cancelTaskNotifications(String taskId) async {
    await _notifications.cancel(taskId.hashCode);
    await _notifications.cancel('${taskId}_reminder'.hashCode);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Show a test notification
  Future<void> showTestNotification() async {
    try {
      print('🔔 Attempting to show test notification...');
      
      await _notifications.show(
        999999, // Test notification ID
        'Test Notification',
        'This is a test notification from your Todo app!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max, // Use max importance to ensure it shows
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            ticker: 'ticker', // Ticker text for older Android versions
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'test_notification',
      );
      print('✅ Test notification sent successfully!');
    } catch (e, stackTrace) {
      print('❌ Error showing test notification: $e');
      print('📍 Stack trace: $stackTrace');
    }
  }

  /// Schedule a test notification for a few seconds from now
  Future<void> scheduleTestNotification({int secondsFromNow = 5}) async {
    final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(seconds: secondsFromNow));
    
    print('📅 Scheduling test notification for: $scheduledDate');
    
    await _notifications.zonedSchedule(
      888888, // Test scheduled notification ID
      'Scheduled Test',
      'This scheduled notification worked! 🎉',
      scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max, // Use max importance to ensure it shows
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            ticker: 'ticker', // Ticker text for older Android versions
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      payload: 'test_scheduled',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
    print('✅ Test notification scheduled for $secondsFromNow seconds from now');
  }

  String _formatReminderTime(Duration duration) {
    if (duration.inDays > 0) {
      return 'in ${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return 'in ${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else if (duration.inMinutes > 0) {
      return 'in ${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'soon';
    }
  }

  /// Get all pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    final pending = await _notifications.pendingNotificationRequests();
    print('📋 Pending notifications: ${pending.length}');
    for (var notification in pending) {
      print('  - ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}');
    }
    return pending;
  }

  /// Debug method to print notification status
  Future<void> debugNotificationStatus() async {
    print('🔍 === NOTIFICATION DEBUG INFO ===');
    final pending = await getPendingNotifications();
    print('📅 Current timezone: ${tz.local}');
    print('⏰ Current time: ${tz.TZDateTime.now(tz.local)}');
    print('🔔 Total pending notifications: ${pending.length}');
    print('===============================');
  }
}
