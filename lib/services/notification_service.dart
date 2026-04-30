import 'package:flutter/material.dart';
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
      tz.initializeTimeZones();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      await _createNotificationChannel();
      await _requestPermissions();
    } catch (e, stackTrace) {
      debugPrint('Error initializing notifications: $e\n$stackTrace');
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

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _requestPermissions() async {
    try {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
        await androidPlugin.requestFullScreenIntentPermission();
      }

      if (iosPlugin != null) {
        await iosPlugin.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  // DateTime already represents the instant selected by the user; schedule it
  // in UTC so one-shot alerts do not depend on tz.local being configured.
  tz.TZDateTime _scheduledInstant(DateTime date) =>
      tz.TZDateTime.from(date, tz.UTC);

  tz.TZDateTime _now() => tz.TZDateTime.now(tz.UTC);

  /// Schedule a notification for when a task is due.
  Future<void> scheduleTaskDueNotification({
    required String taskId,
    required String taskTitle,
    required DateTime dueDate,
  }) async {
    try {
      final scheduledDate = _scheduledInstant(dueDate);

      if (scheduledDate.isAfter(_now())) {
        await _notifications.zonedSchedule(
          taskId.hashCode,
          'Task Due! 🔔',
          'Task "$taskTitle" is due now',
          scheduledDate,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              ticker: 'Task Due',
              showWhen: true,
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
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      debugPrint('Error scheduling due notification for "$taskTitle": $e');
    }
  }

  /// Schedule a reminder notification before the task is due.
  /// Each duration produces a unique notification ID to avoid collisions
  /// (e.g. the 1-hour and 1-day reminders no longer overwrite each other).
  Future<void> scheduleTaskReminderNotification({
    required String taskId,
    required String taskTitle,
    required DateTime dueDate,
    required Duration reminderBefore,
  }) async {
    try {
      final reminderDate = dueDate.subtract(reminderBefore);
      final scheduledDate = _scheduledInstant(reminderDate);

      if (scheduledDate.isAfter(_now())) {
        // Encode the duration in the ID so different reminder windows don't collide
        final notifId = '${taskId}_r${reminderBefore.inMinutes}'.hashCode;
        await _notifications.zonedSchedule(
          notifId,
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
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      debugPrint('Error scheduling reminder notification for "$taskTitle": $e');
    }
  }

  /// Show an immediate notification when a task is completed.
  Future<void> showTaskCompletedNotification({
    required String taskTitle,
  }) async {
    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Task Completed! ✅',
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
    } catch (e) {
      debugPrint('Error showing task completed notification: $e');
    }
  }

  /// Show an immediate deadline alert notification.
  Future<void> showImmediateDeadlineAlert({
    required String taskId,
    required String taskTitle,
    required bool isOverdue,
  }) async {
    try {
      await _notifications.show(
        taskId.hashCode + (isOverdue ? 1000000 : 0),
        isOverdue ? 'Task Overdue! ⚠️' : 'Task Due Now! 🔔',
        'Task "$taskTitle" ${isOverdue ? 'is overdue' : 'is due now'}',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            ticker: isOverdue ? 'Task Overdue' : 'Task Due',
            showWhen: true,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            icon: '@mipmap/ic_launcher',
            color: isOverdue ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: isOverdue
                ? InterruptionLevel.critical
                : InterruptionLevel.timeSensitive,
          ),
        ),
        payload: 'deadline_alert:$taskId',
      );
    } catch (e) {
      debugPrint('Error showing deadline alert for "$taskTitle": $e');
    }
  }

  /// Cancel all notifications for a specific task.
  Future<void> cancelTaskNotifications(String taskId) async {
    await _notifications.cancel(taskId.hashCode);                   // due
    await _notifications.cancel('${taskId}_r60'.hashCode);          // 1-hour reminder
    await _notifications.cancel('${taskId}_r1440'.hashCode);        // 1-day reminder
    await _notifications.cancel('${taskId}_reminder'.hashCode);     // legacy reminder ID
    await _notifications.cancel(taskId.hashCode + 1000000);         // overdue deadline alert
    await _notifications.cancel('${taskId}_snooze'.hashCode);       // snooze
  }

  /// Cancel all notifications.
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Show a test notification immediately.
  Future<void> showTestNotification() async {
    try {
      await _notifications.show(
        999999,
        'Test Notification',
        'This is a test notification from your Todo app!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            ticker: 'Test',
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
    } catch (e) {
      debugPrint('Error showing test notification: $e');
    }
  }

  /// Schedule a test notification a few seconds from now.
  Future<void> scheduleTestNotification({int secondsFromNow = 5}) async {
    try {
      final scheduledDate = _now().add(Duration(seconds: secondsFromNow));
      await _notifications.zonedSchedule(
        888888,
        'Scheduled Test',
        'This scheduled notification worked! 🎉',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            ticker: 'Test',
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
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Error scheduling test notification: $e');
    }
  }

  /// Returns all currently pending notifications (useful for debugging).
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _notifications.pendingNotificationRequests();
  }

  /// Prints a debug summary of pending notification state.
  Future<void> debugNotificationStatus() async {
    final pending = await getPendingNotifications();
    debugPrint('=== Notification status ===');
    debugPrint('Schedule zone: ${tz.UTC}  Now: ${_now()}');
    debugPrint('Pending: ${pending.length}');
    for (final n in pending) {
      debugPrint('  id=${n.id}  title=${n.title}');
    }
    debugPrint('===========================');
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
}
