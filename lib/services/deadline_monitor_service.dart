import 'dart:async';
import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import 'notification_service.dart';

class DeadlineMonitorService {
  static final DeadlineMonitorService _instance = DeadlineMonitorService._internal();
  factory DeadlineMonitorService() => _instance;
  DeadlineMonitorService._internal();

  final NotificationService _notificationService = NotificationService();

  Timer? _monitorTimer;
  List<ToDoItem> _tasks = [];
  BuildContext? _context;

  // Track which tasks have already been alerted to avoid duplicate alerts
  final Set<String> _alertedTaskIds = {};

  // Configuration
  static const Duration _checkInterval = Duration(minutes: 1);
  static const Duration _alertThreshold = Duration(seconds: 30); // Alert if within 30 seconds of due time

  /// Initialize the monitor with a context for showing dialogs
  void initialize(BuildContext context) {
    _context = context;
    print('📅 DeadlineMonitorService initialized');
  }

  /// Update the context (call this when context changes)
  void updateContext(BuildContext context) {
    _context = context;
  }

  /// Start monitoring tasks for deadlines
  void startMonitoring(List<ToDoItem> tasks) {
    _tasks = tasks;

    // Cancel existing timer if any
    _monitorTimer?.cancel();

    // Start periodic monitoring
    _monitorTimer = Timer.periodic(_checkInterval, (timer) {
      _checkDeadlines();
    });

    // Also check immediately
    _checkDeadlines();

    print('📅 Deadline monitoring started for ${tasks.length} tasks');
  }

  /// Stop monitoring
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    print('📅 Deadline monitoring stopped');
  }

  /// Update the task list being monitored
  void updateTasks(List<ToDoItem> tasks) {
    _tasks = tasks;
  }

  /// Check all tasks for deadlines
  void _checkDeadlines() {
    final now = DateTime.now();

    for (final task in _tasks) {
      // Skip completed tasks or tasks without due dates
      if (task.isDone || task.dueDate == null || task.id == null) {
        continue;
      }

      // Skip if already alerted
      if (_alertedTaskIds.contains(task.id)) {
        continue;
      }

      final dueDate = task.dueDate!;
      final timeDifference = dueDate.difference(now);

      // Check if task is due (within threshold or overdue)
      if (timeDifference.isNegative || timeDifference <= _alertThreshold) {
        _handleDeadlineReached(task, timeDifference.isNegative);
      }
    }
  }

  /// Handle when a deadline is reached
  void _handleDeadlineReached(ToDoItem task, bool isOverdue) {
    print('🔔 Deadline reached for task: ${task.title} (${isOverdue ? 'OVERDUE' : 'DUE NOW'})');

    // Mark as alerted
    _alertedTaskIds.add(task.id!);

    // Show in-app alert if context is available
    if (_context != null && _context!.mounted) {
      _showInAppAlert(task, isOverdue);
    }

    // Also show system notification as backup
    _showSystemNotification(task, isOverdue);
  }

  /// Show an in-app alert dialog
  void _showInAppAlert(ToDoItem task, bool isOverdue) {
    if (_context == null || !_context!.mounted) return;

    showDialog(
      context: _context!,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isOverdue ? Icons.warning_amber_rounded : Icons.alarm,
                color: isOverdue ? Colors.red : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isOverdue ? 'Task Overdue!' : 'Task Due Now!',
                  style: TextStyle(
                    color: isOverdue ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    _formatDueDate(task.dueDate!),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              if (task.labels.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: task.labels.map((label) {
                    return Chip(
                      label: Text(
                        label.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: _parseColor(label.color).withOpacity(0.2),
                      padding: const EdgeInsets.all(0),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.snooze),
              label: const Text('Snooze 10m'),
              onPressed: () {
                _snoozeTask(task, const Duration(minutes: 10));
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Mark Done'),
              onPressed: () {
                _markTaskDone(task);
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Show system notification
  void _showSystemNotification(ToDoItem task, bool isOverdue) {
    _notificationService.showImmediateDeadlineAlert(
      taskId: task.id!,
      taskTitle: task.title,
      isOverdue: isOverdue,
    );
  }

  /// Snooze a task (reschedule alert)
  void _snoozeTask(ToDoItem task, Duration snoozeDuration) {
    print('😴 Snoozing task: ${task.title} for ${snoozeDuration.inMinutes} minutes');

    // Remove from alerted set so it can alert again
    _alertedTaskIds.remove(task.id!);

    // Schedule a notification for after the snooze duration
    final snoozeTime = DateTime.now().add(snoozeDuration);
    _notificationService.scheduleTaskDueNotification(
      taskId: '${task.id}_snooze',
      taskTitle: task.title,
      dueDate: snoozeTime,
    );

    if (_context != null && _context!.mounted) {
      ScaffoldMessenger.of(_context!).showSnackBar(
        SnackBar(
          content: Text('Snoozed "${task.title}" for ${snoozeDuration.inMinutes} minutes'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Mark task as done (callback for the alert dialog)
  void _markTaskDone(ToDoItem task) {
    print('✅ Marking task as done from alert: ${task.title}');

    // This will be handled by the calling screen
    // We just trigger a notification that the user wants to mark it done
    if (_context != null && _context!.mounted) {
      ScaffoldMessenger.of(_context!).showSnackBar(
        SnackBar(
          content: Text('Please mark "${task.title}" as complete in the task list'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Clear alert status for a task (call this when task is completed or deleted)
  void clearTaskAlert(String taskId) {
    _alertedTaskIds.remove(taskId);
  }

  /// Clear all alert statuses
  void clearAllAlerts() {
    _alertedTaskIds.clear();
  }

  /// Format due date for display
  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.isNegative) {
      final absDiff = difference.abs();
      if (absDiff.inMinutes < 60) {
        return '${absDiff.inMinutes} minutes ago';
      } else if (absDiff.inHours < 24) {
        return '${absDiff.inHours} hours ago';
      } else {
        return '${absDiff.inDays} days ago';
      }
    } else {
      return 'Due ${_formatDateTime(date)}';
    }
  }

  /// Format date and time
  String _formatDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} at $hour:$minute';
  }

  /// Parse color from string
  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  /// Dispose the service
  void dispose() {
    stopMonitoring();
    _context = null;
    _tasks.clear();
    _alertedTaskIds.clear();
  }
}
