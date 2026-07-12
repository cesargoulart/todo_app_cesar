import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/todo_item.dart';
import 'notification_service.dart';

/// On Android/iOS/macOS/Linux, due/overdue alerts are handled entirely by the
/// scheduled system notification (with Snooze/Done action buttons), which
/// fires on time even when the app is closed.
///
/// flutter_local_notifications has no Windows implementation, so there is no
/// OS-level scheduling available there. This service fills that gap on
/// Windows only: it polls the in-memory task list on a timer and fires a
/// native toast (via NotificationService, backed by local_notifier) the
/// moment a task's due date is reached. This only works while the app
/// process is running — Windows has no background alarm mechanism here.
class DeadlineMonitorService {
  static final DeadlineMonitorService _instance =
      DeadlineMonitorService._internal();
  factory DeadlineMonitorService() => _instance;
  DeadlineMonitorService._internal();

  final NotificationService _notificationService = NotificationService();

  // Retained for API compatibility; no longer invoked.
  void Function(ToDoItem task)? onMarkDone;

  static const Duration _pollInterval = Duration(seconds: 20);
  static const Duration _overdueThreshold = Duration(minutes: 1);

  Timer? _timer;
  List<ToDoItem> _tasks = [];
  // Tracks the due date already alerted for each task, so editing a task to a
  // new future due date automatically re-arms the alert without extra hooks.
  final Map<String, DateTime> _alertedDueDates = {};

  bool get _isActive =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  void initialize(BuildContext context) {}

  void updateContext(BuildContext context) {}

  void startMonitoring(List<ToDoItem> tasks) {
    if (!_isActive) return;
    _tasks = tasks;
    _checkDeadlines();
    _timer ??= Timer.periodic(_pollInterval, (_) => _checkDeadlines());
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }

  void updateTasks(List<ToDoItem> tasks) {
    _tasks = tasks;
    if (_isActive) _checkDeadlines();
  }

  void clearTaskAlert(String taskId) {
    _alertedDueDates.remove(taskId);
  }

  void clearAllAlerts() {
    _alertedDueDates.clear();
  }

  void dispose() {
    stopMonitoring();
  }

  void _checkDeadlines() {
    final now = DateTime.now();
    for (final task in _flattenTasks(_tasks)) {
      final taskId = task.id;
      final dueDate = task.dueDate;
      if (taskId == null || task.isDone || dueDate == null) continue;
      if (dueDate.isAfter(now)) continue;
      if (_alertedDueDates[taskId] == dueDate) continue;

      _alertedDueDates[taskId] = dueDate;
      _notificationService.showImmediateDeadlineAlert(
        taskId: taskId,
        taskTitle: task.title,
        isOverdue: now.isAfter(dueDate.add(_overdueThreshold)),
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
}
