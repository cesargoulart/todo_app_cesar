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

  // Called when the user taps "Mark Done" in the deadline alert dialog.
  // Set this from the screen so the dialog can actually toggle the task.
  void Function(ToDoItem task)? onMarkDone;

  static const Duration _checkInterval = Duration(minutes: 1);
  // Alert if within 30 seconds of due time
  static const Duration _alertThreshold = Duration(seconds: 30);

  void initialize(BuildContext context) {
    _context = context;
  }

  void updateContext(BuildContext context) {
    _context = context;
  }

  void startMonitoring(List<ToDoItem> tasks) {
    _tasks = tasks;
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(_checkInterval, (_) => _checkDeadlines());
    _checkDeadlines();
  }

  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  void updateTasks(List<ToDoItem> tasks) {
    _tasks = tasks;
  }

  void _checkDeadlines() {
    final now = DateTime.now();

    for (final task in _tasks) {
      if (task.isDone || task.dueDate == null || task.id == null) continue;
      if (_alertedTaskIds.contains(task.id)) continue;

      final timeDifference = task.dueDate!.difference(now);
      if (timeDifference.isNegative || timeDifference <= _alertThreshold) {
        _handleDeadlineReached(task, timeDifference.isNegative);
      }
    }
  }

  void _handleDeadlineReached(ToDoItem task, bool isOverdue) {
    _alertedTaskIds.add(task.id!);

    if (_context != null && _context!.mounted) {
      _showInAppAlert(task, isOverdue);
    }

    _notificationService.showImmediateDeadlineAlert(
      taskId: task.id!,
      taskTitle: task.title,
      isOverdue: isOverdue,
    );
  }

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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      label: Text(label.name, style: const TextStyle(fontSize: 12)),
                      backgroundColor: _parseColor(label.color).withValues(alpha: 0.2),
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
                Navigator.of(dialogContext).pop();
                _snoozeTask(task, const Duration(minutes: 10));
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Mark Done'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _markTaskDone(task);
              },
            ),
            ElevatedButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  void _snoozeTask(ToDoItem task, Duration snoozeDuration) {
    // Remove from alerted set so it can alert again after the snooze
    _alertedTaskIds.remove(task.id!);

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

  void _markTaskDone(ToDoItem task) {
    if (onMarkDone != null) {
      onMarkDone!(task);
    } else if (_context != null && _context!.mounted) {
      // Fallback if no callback was registered
      ScaffoldMessenger.of(_context!).showSnackBar(
        SnackBar(
          content: Text('Please mark "${task.title}" as complete in the task list'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void clearTaskAlert(String taskId) {
    _alertedTaskIds.remove(taskId);
  }

  void clearAllAlerts() {
    _alertedTaskIds.clear();
  }

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

  String _formatDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} at $hour:$minute';
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  void dispose() {
    stopMonitoring();
    _context = null;
    _tasks.clear();
    _alertedTaskIds.clear();
  }
}
