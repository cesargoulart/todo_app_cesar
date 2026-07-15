import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/todo_item.dart';

class NotificationDebugStatus {
  final int pendingCount;
  final bool? notificationsEnabled;
  final bool? exactAlarmsAllowed;

  const NotificationDebugStatus({
    required this.pendingCount,
    required this.notificationsEnabled,
    required this.exactAlarmsAllowed,
  });

  String get notificationsText {
    if (notificationsEnabled == null) return 'Unknown';
    return notificationsEnabled! ? 'Allowed' : 'Blocked';
  }

  String get exactAlarmsText {
    if (exactAlarmsAllowed == null) return 'Unknown';
    return exactAlarmsAllowed! ? 'Allowed' : 'Blocked';
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _dueChannelId = 'todo_due_alerts_v2';
  static const String _dueChannelName = 'Task Due Alerts';
  static const String _dueChannelDescription =
      'High priority alerts shown exactly when a task is due';

  static const String _reminderChannelId = 'todo_reminders';
  static const String _reminderChannelName = 'Task Reminders';
  static const String _reminderChannelDescription =
      'Advance reminders before a task is due';

  static const String _generalChannelId = 'todo_notifications';
  static const String _generalChannelName = 'Todo Notifications';
  static const String _generalChannelDescription =
      'General Todo app notifications';

  // â”€â”€ Action buttons â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const String snoozeActionId = 'snooze_action';
  static const String doneActionId = 'done_action';
  static const Duration snoozeDuration = Duration(minutes: 10);

  // Separator used inside payloads to carry the task title alongside its id.
  static const String _payloadSeparator = '~|~';

  // Action buttons attached to "due"/"overdue" notifications so the user can
  // snooze or complete the task straight from the heads-up notification.
  static const List<AndroidNotificationAction> _dueActions =
      <AndroidNotificationAction>[
        // showsUserInterface: true routes the tap to the foreground handler
        // (onDidReceiveNotificationResponse) where the UI callbacks are wired,
        // so "Done" can update the task/DB and "Snooze" can reschedule.
        AndroidNotificationAction(
          snoozeActionId,
          'Snooze 10 min',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          doneActionId,
          'Done',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ];

  /// Registered by the UI so notification action buttons can update task state
  /// while the app is running. (Taps handled in the background isolate cannot
  /// reach these; they are reconciled when the app is reopened.)
  void Function(String taskId)? onTaskDone;
  void Function(String taskId)? onTaskSnoozed;

  String _buildPayload(String type, String taskId, String taskTitle) =>
      '$type:$taskId$_payloadSeparator$taskTitle';

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  // On Windows every plugin call (cancel/zonedSchedule/pending…) is a
  // synchronous FFI call that blocks the UI isolate (see
  // https://github.com/MaikuB/flutter_local_notifications/issues/2730), so
  // the number of native calls must be kept to a strict minimum there.
  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
    try {
      if (!_isSupportedPlatform) {
        debugPrint(
          'Local notifications are not supported on $defaultTargetPlatform.',
        );
        return;
      }

      tz.initializeTimeZones();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestSoundPermission: true,
            requestBadgePermission: true,
            requestAlertPermission: true,
          );

      const WindowsInitializationSettings windowsSettings =
          WindowsInitializationSettings(
            appName: 'Todo App Cesar',
            appUserModelId: 'com.cesar.todoappcesar',
            // Fixed GUID identifying this app to the Windows notification
            // platform. Must never change between builds.
            guid: '4f4e9a2b-8c3d-4a6e-9b1f-2d5c7e8a9f01',
          );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        windows: windowsSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse:
            notificationBackgroundHandler,
      );

      await _createNotificationChannels();
      await _requestPermissions();
    } catch (e, stackTrace) {
      debugPrint('Error initializing notifications: $e\n$stackTrace');
    }
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (androidPlugin == null) return;

    const dueChannel = AndroidNotificationChannel(
      _dueChannelId,
      _dueChannelName,
      description: _dueChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const reminderChannel = AndroidNotificationChannel(
      _reminderChannelId,
      _reminderChannelName,
      description: _reminderChannelDescription,
      importance: Importance.defaultImportance,
      playSound: true,
    );

    const generalChannel = AndroidNotificationChannel(
      _generalChannelId,
      _generalChannelName,
      description: _generalChannelDescription,
      importance: Importance.defaultImportance,
      playSound: true,
    );

    await androidPlugin.createNotificationChannel(dueChannel);
    await androidPlugin.createNotificationChannel(reminderChannel);
    await androidPlugin.createNotificationChannel(generalChannel);
  }

  Future<void> _requestPermissions() async {
    try {
      final androidPlugin =
          _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      final iosPlugin =
          _notifications
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();

      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
        final exactAllowed =
            await androidPlugin.canScheduleExactNotifications() ?? false;
        if (!exactAllowed) {
          await androidPlugin.requestExactAlarmsPermission();
        }
        await androidPlugin.requestFullScreenIntentPermission();
      }

      if (iosPlugin != null) {
        await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
      'Notification tapped: ${response.payload} action=${response.actionId}',
    );
    _handleNotificationResponse(response);
  }

  /// Handle a tap on a notification body or one of its action buttons.
  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    final payload = response.payload;
    if (payload == null) return;

    final colonIndex = payload.indexOf(':');
    if (colonIndex < 0) return;
    final rest = payload.substring(colonIndex + 1);
    final parts = rest.split(_payloadSeparator);
    final taskId = parts.first;
    final taskTitle = parts.length > 1 ? parts.sublist(1).join(_payloadSeparator) : '';
    if (taskId.isEmpty) return;

    switch (response.actionId) {
      case snoozeActionId:
        if (onTaskSnoozed != null) {
          // Foreground: let the UI push the due date forward, persist it and
          // reschedule the notification from the up-to-date task.
          onTaskSnoozed!(taskId);
        } else {
          // Background isolate: the UI callback is unavailable, so just
          // reschedule the alert for now + snoozeDuration.
          await cancelTaskNotifications(taskId);
          await scheduleTaskDueNotification(
            taskId: taskId,
            taskTitle: taskTitle.isEmpty ? 'Task' : taskTitle,
            dueDate: DateTime.now().add(snoozeDuration),
          );
        }
        break;
      case doneActionId:
        await cancelTaskNotifications(taskId);
        onTaskDone?.call(taskId);
        break;
    }
  }

  // DateTime already represents the instant selected by the user; schedule it
  // in UTC so one-shot alerts do not depend on tz.local being configured.
  tz.TZDateTime _scheduledInstant(DateTime date) =>
      tz.TZDateTime.from(date, tz.UTC);

  tz.TZDateTime _now() => tz.TZDateTime.now(tz.UTC);

  Future<AndroidScheduleMode> _preferredScheduleMode() async {
    final androidPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (androidPlugin == null) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    try {
      final exactAllowed =
          await androidPlugin.canScheduleExactNotifications() ?? false;
      if (exactAllowed) return AndroidScheduleMode.exactAllowWhileIdle;
      debugPrint(
        'Exact alarm permission is not allowed; scheduling inexact alarm.',
      );
      return AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (e) {
      debugPrint('Could not read exact alarm permission: $e');
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  Future<void> _zonedScheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails details,
    required String payload,
  }) async {
    if (!_isSupportedPlatform) return;

    final preferredMode = await _preferredScheduleMode();
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        payload: payload,
        androidScheduleMode: preferredMode,
      );
      debugPrint(
        '🔔 Scheduled notification id=$id "$title" for $scheduledDate '
        '(now=${_now()})',
      );
      if (kDebugMode) {
        // Confirm the OS actually registered it (blocking call: debug only).
        final pending = await _notifications.pendingNotificationRequests();
        debugPrint('🔔 OS reports ${pending.length} pending notification(s)');
      }
    } catch (e) {
      if (preferredMode == AndroidScheduleMode.inexactAllowWhileIdle) {
        rethrow;
      }

      debugPrint(
        'Exact notification scheduling failed; retrying inexact. Error: $e',
      );
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// Schedule a notification for when a task is due.
  Future<void> scheduleTaskDueNotification({
    required String taskId,
    required String taskTitle,
    required DateTime dueDate,
  }) async {
    if (!_isSupportedPlatform) return;

    try {
      final scheduledDate = _scheduledInstant(dueDate);
      if (!scheduledDate.isAfter(_now())) {
        debugPrint(
          '🔔 Skipping due notification for "$taskTitle": '
          '$scheduledDate is not in the future (now=${_now()})',
        );
        return;
      }

      await _zonedScheduleWithFallback(
        id: _dueNotificationId(taskId),
        title: 'Task Due',
        body: 'Task "$taskTitle" is due now',
        scheduledDate: scheduledDate,
        details: const NotificationDetails(
          android: AndroidNotificationDetails(
            _dueChannelId,
            _dueChannelName,
            channelDescription: _dueChannelDescription,
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            ticker: 'Task Due',
            showWhen: true,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            icon: '@mipmap/ic_launcher',
            actions: _dueActions,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        payload: _buildPayload('task_due', taskId, taskTitle),
      );
    } catch (e) {
      debugPrint('Error scheduling due notification for "$taskTitle": $e');
    }
  }

  /// Schedule a reminder notification before the task is due.
  Future<void> scheduleTaskReminderNotification({
    required String taskId,
    required String taskTitle,
    required DateTime dueDate,
    required Duration reminderBefore,
  }) async {
    if (!_isSupportedPlatform) return;
    // Windows: keep only the due alert to minimise blocking native calls.
    if (_isWindows) return;

    try {
      final reminderDate = dueDate.subtract(reminderBefore);
      final scheduledDate = _scheduledInstant(reminderDate);
      if (!scheduledDate.isAfter(_now())) return;

      await _zonedScheduleWithFallback(
        id: _reminderNotificationId(taskId, reminderBefore),
        title: 'Task Reminder',
        body: 'Task "$taskTitle" is due ${_formatReminderTime(reminderBefore)}',
        scheduledDate: scheduledDate,
        details: const NotificationDetails(
          android: AndroidNotificationDetails(
            _reminderChannelId,
            _reminderChannelName,
            channelDescription: _reminderChannelDescription,
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
      );
    } catch (e) {
      debugPrint('Error scheduling reminder notification for "$taskTitle": $e');
    }
  }

  // Signature of the last rescheduled task set. Sync runs periodically and
  // calls rescheduleNotificationsForTasks each time; when nothing relevant
  // changed we skip the rebuild entirely (critical on Windows, where every
  // plugin call blocks the UI isolate).
  String? _lastScheduleSignature;

  String _scheduleSignature(List<ToDoItem> tasks) {
    final parts = <String>[];
    for (final task in _flattenTasks(tasks)) {
      final id = task.id;
      final due = task.dueDate;
      if (id == null || due == null) continue;
      parts.add('$id|${due.millisecondsSinceEpoch}|${task.isDone}');
    }
    parts.sort();
    return parts.join(';');
  }

  /// Rebuild scheduled notifications for all known tasks.
  Future<void> rescheduleNotificationsForTasks(List<ToDoItem> tasks) async {
    if (!_isSupportedPlatform) return;

    final signature = _scheduleSignature(tasks);
    if (signature == _lastScheduleSignature) return;
    _lastScheduleSignature = signature;

    if (_isWindows) {
      // Full rebuild: one cancelAll() (does not block, unlike per-id
      // cancels) and a single due alert per pending task.
      try {
        await _notifications.cancelAll();
      } catch (e) {
        debugPrint('Error cancelling notifications on Windows: $e');
      }
      final now = DateTime.now();
      for (final task in _flattenTasks(tasks)) {
        final dueDate = task.dueDate;
        if (task.id == null ||
            task.isDone ||
            dueDate == null ||
            !dueDate.isAfter(now)) {
          continue;
        }
        await scheduleTaskDueNotification(
          taskId: task.id!,
          taskTitle: task.title,
          dueDate: dueDate,
        );
      }
      return;
    }

    for (final task in _flattenTasks(tasks)) {
      if (task.id == null) continue;

      final dueDate = task.dueDate;
      if (task.isDone || dueDate == null || !dueDate.isAfter(DateTime.now())) {
        await cancelTaskNotifications(task.id!);
        continue;
      }

      await cancelTaskNotifications(task.id!);
      await scheduleTaskDueNotification(
        taskId: task.id!,
        taskTitle: task.title,
        dueDate: dueDate,
      );
      await scheduleTaskReminderNotification(
        taskId: task.id!,
        taskTitle: task.title,
        dueDate: dueDate,
        reminderBefore: const Duration(hours: 1),
      );
      await scheduleTaskReminderNotification(
        taskId: task.id!,
        taskTitle: task.title,
        dueDate: dueDate,
        reminderBefore: const Duration(days: 1),
      );
    }
  }

  Iterable<ToDoItem> _flattenTasks(List<ToDoItem> tasks) sync* {
    for (final task in tasks) {
      yield task;
      if (task.subtasks.isNotEmpty) {
        yield* _flattenTasks(task.subtasks);
      }
    }
  }

  /// Show an immediate notification when a task is completed.
  Future<void> showTaskCompletedNotification({
    required String taskTitle,
  }) async {
    if (!_isSupportedPlatform) return;

    try {
      await _notifications.show(
        _stableNotificationId(
          'completed:${DateTime.now().microsecondsSinceEpoch}',
        ),
        'Task Completed',
        'Great job! You completed "$taskTitle"',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _generalChannelId,
            _generalChannelName,
            channelDescription: _generalChannelDescription,
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
  /// Scheduled due notifications should normally handle this path on Android.
  Future<void> showImmediateDeadlineAlert({
    required String taskId,
    required String taskTitle,
    required bool isOverdue,
  }) async {
    if (!_isSupportedPlatform) return;

    try {
      await _notifications.show(
        _deadlineNotificationId(taskId, isOverdue),
        isOverdue ? 'Task Overdue' : 'Task Due Now',
        'Task "$taskTitle" ${isOverdue ? 'is overdue' : 'is due now'}',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _dueChannelId,
            _dueChannelName,
            channelDescription: _dueChannelDescription,
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            ticker: isOverdue ? 'Task Overdue' : 'Task Due',
            showWhen: true,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            icon: '@mipmap/ic_launcher',
            color:
                isOverdue ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
            actions: _dueActions,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel:
                isOverdue
                    ? InterruptionLevel.critical
                    : InterruptionLevel.timeSensitive,
          ),
        ),
        payload: _buildPayload('deadline_alert', taskId, taskTitle),
      );
    } catch (e) {
      debugPrint('Error showing deadline alert for "$taskTitle": $e');
    }
  }

  /// Cancel all notifications for a specific task.
  Future<void> cancelTaskNotifications(String taskId) async {
    if (!_isSupportedPlatform) return;

    await _notifications.cancel(_dueNotificationId(taskId));

    if (_isWindows) {
      // Only the due alert is scheduled on Windows, and every cancel() is a
      // blocking native call there — skip the rest.
      return;
    }

    await _notifications.cancel(
      _reminderNotificationId(taskId, const Duration(hours: 1)),
    );
    await _notifications.cancel(
      _reminderNotificationId(taskId, const Duration(days: 1)),
    );
    await _notifications.cancel(_deadlineNotificationId(taskId, false));
    await _notifications.cancel(_deadlineNotificationId(taskId, true));
    await _notifications.cancel(_dueNotificationId('${taskId}_snooze'));

    if (!_isAndroid) return;

    // Legacy IDs used by older Android builds. String.hashCode is not stable
    // across app versions, but cancelling the current runtime values still
    // helps avoid duplicates for users upgrading from those builds.
    await _notifications.cancel(taskId.hashCode);
    await _notifications.cancel('${taskId}_r60'.hashCode);
    await _notifications.cancel('${taskId}_r1440'.hashCode);
    await _notifications.cancel('${taskId}_reminder'.hashCode);
    await _notifications.cancel(taskId.hashCode + 1000000);
    await _notifications.cancel('${taskId}_snooze'.hashCode);
  }

  /// Cancel all notifications.
  Future<void> cancelAllNotifications() async {
    if (!_isSupportedPlatform) return;

    await _notifications.cancelAll();
  }

  /// Show a test notification immediately.
  Future<void> showTestNotification() async {
    if (!_isSupportedPlatform) return;

    try {
      await _notifications.show(
        999999,
        'Test Notification',
        'This is a test notification from your Todo app!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _dueChannelId,
            _dueChannelName,
            channelDescription: _dueChannelDescription,
            importance: Importance.max,
            priority: Priority.max,
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
    if (!_isSupportedPlatform) return;

    try {
      final scheduledDate = _now().add(Duration(seconds: secondsFromNow));
      await _zonedScheduleWithFallback(
        id: 888888,
        title: 'Scheduled Test',
        body: 'This scheduled notification worked!',
        scheduledDate: scheduledDate,
        details: const NotificationDetails(
          android: AndroidNotificationDetails(
            _dueChannelId,
            _dueChannelName,
            channelDescription: _dueChannelDescription,
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            ticker: 'Test',
            fullScreenIntent: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'test_scheduled',
      );
    } catch (e) {
      debugPrint('Error scheduling test notification: $e');
    }
  }

  /// Returns all currently pending notifications (useful for debugging).
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isSupportedPlatform) return const [];

    return _notifications.pendingNotificationRequests();
  }

  Future<NotificationDebugStatus> getDebugStatus() async {
    final pending = await getPendingNotifications();
    bool? notificationsEnabled;
    bool? exactAlarmsAllowed;

    final androidPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (androidPlugin != null) {
      try {
        notificationsEnabled = await androidPlugin.areNotificationsEnabled();
      } catch (e) {
        debugPrint('Error reading notification permission state: $e');
      }
      try {
        exactAlarmsAllowed =
            await androidPlugin.canScheduleExactNotifications();
      } catch (e) {
        debugPrint('Error reading exact alarm permission state: $e');
      }
    }

    return NotificationDebugStatus(
      pendingCount: pending.length,
      notificationsEnabled: notificationsEnabled,
      exactAlarmsAllowed: exactAlarmsAllowed,
    );
  }

  /// Prints a debug summary of pending notification state.
  Future<void> debugNotificationStatus() async {
    final pending = await getPendingNotifications();
    final status = await getDebugStatus();
    debugPrint('=== Notification status ===');
    debugPrint('Schedule zone: ${tz.UTC}  Now: ${_now()}');
    debugPrint('Pending: ${pending.length}');
    debugPrint('Notifications: ${status.notificationsText}');
    debugPrint('Exact alarms: ${status.exactAlarmsText}');
    for (final n in pending) {
      debugPrint('  id=${n.id}  title=${n.title}');
    }
    debugPrint('===========================');
  }

  int _dueNotificationId(String taskId) => _stableNotificationId('due:$taskId');

  int _reminderNotificationId(String taskId, Duration reminderBefore) {
    return _stableNotificationId(
      'reminder:$taskId:${reminderBefore.inMinutes}',
    );
  }

  int _deadlineNotificationId(String taskId, bool isOverdue) {
    return _stableNotificationId(
      'deadline:$taskId:${isOverdue ? 'overdue' : 'due'}',
    );
  }

  int _stableNotificationId(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    final id = hash & 0x7fffffff;
    return id == 0 ? 1 : id;
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

/// Entry point invoked by the OS in a background isolate when the user taps a
/// notification action while the app is not in the foreground.
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  tz.initializeTimeZones();
  // Same library, so the private handler is reachable. UI callbacks are null in
  // this isolate; "Done" is reconciled when the app is next opened.
  NotificationService()._handleNotificationResponse(response);
}
