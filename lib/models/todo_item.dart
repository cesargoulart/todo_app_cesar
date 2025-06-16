// lib/models/todo_item.dart

enum RecurrenceInterval {
  none('none'),
  daily('daily'),
  weekly('weekly'),
  monthly('monthly'),
  yearly('yearly');

  const RecurrenceInterval(this.value);
  final String value;

  static RecurrenceInterval fromString(String? value) {
    switch (value) {
      case 'daily':
        return RecurrenceInterval.daily;
      case 'weekly':
        return RecurrenceInterval.weekly;
      case 'monthly':
        return RecurrenceInterval.monthly;
      case 'yearly':
        return RecurrenceInterval.yearly;
      default:
        return RecurrenceInterval.none;
    }
  }

  String get displayName {
    switch (this) {
      case RecurrenceInterval.none:
        return 'No repeat';
      case RecurrenceInterval.daily:
        return 'Daily';
      case RecurrenceInterval.weekly:
        return 'Weekly';
      case RecurrenceInterval.monthly:
        return 'Monthly';
      case RecurrenceInterval.yearly:
        return 'Yearly';
    }
  }
}

class ToDoItem {
  // ID is now nullable. It will be null for a new task
  // and will have a value after being saved to the database.
  String? id;
  String title;
  bool isDone;
  DateTime? dueDate;
  String? parentId; // For subtasks
  List<ToDoItem> subtasks = []; // For subtasks
  
  // Recurring task properties
  bool isRecurring;
  RecurrenceInterval recurrenceInterval;
  DateTime? recurrenceEndDate;
  String? originalRecurringTaskId; // For instances generated from recurring tasks
  DateTime? nextOccurrenceDate;

  ToDoItem({
    this.id, // Allow ID to be passed in
    required this.title,
    this.isDone = false,
    this.dueDate,
    this.parentId,
    this.isRecurring = false,
    this.recurrenceInterval = RecurrenceInterval.none,
    this.recurrenceEndDate,
    this.originalRecurringTaskId,
    this.nextOccurrenceDate,
  });
  // Method to convert a ToDoItem instance to a JSON map.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'title': title,
      'is_done': isDone,
      'due_date': dueDate?.toIso8601String(),
      'parent_id': parentId,
      'is_recurring': isRecurring,
      'recurrence_interval': recurrenceInterval != RecurrenceInterval.none ? recurrenceInterval.value : null,
      'recurrence_end_date': recurrenceEndDate?.toIso8601String(),
      'original_recurring_task_id': originalRecurringTaskId,
      'next_occurrence_date': nextOccurrenceDate?.toIso8601String(),
    };
    // Only include the ID if it's not null.
    // This is crucial for letting Supabase generate the ID for new items.
    if (id != null) {
      data['id'] = id;
    }
    return data;
  }
  // Factory constructor to create a ToDoItem from a JSON map.
  factory ToDoItem.fromJson(Map<String, dynamic> json) {
    final item = ToDoItem(
      id: json['id'],
      title: json['title'],
      isDone: json['is_done'] ?? false,
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      parentId: json['parent_id'],
      isRecurring: json['is_recurring'] ?? false,
      recurrenceInterval: RecurrenceInterval.fromString(json['recurrence_interval']),
      recurrenceEndDate: json['recurrence_end_date'] != null ? DateTime.parse(json['recurrence_end_date']) : null,
      originalRecurringTaskId: json['original_recurring_task_id'],
      nextOccurrenceDate: json['next_occurrence_date'] != null ? DateTime.parse(json['next_occurrence_date']) : null,
    );
    // Note: Subtasks would need to be loaded separately if stored in a related table.
    // This model assumes they are handled in-memory or via a separate query.
    return item;
  }

  // Helper methods for subtasks
  void addSubtask(ToDoItem subtask) {
    subtasks.add(subtask);
  }
  void removeSubtask(String subtaskId) {
    subtasks.removeWhere((task) => task.id == subtaskId);
  }

  // Check if all subtasks are completed
  bool get areAllSubtasksCompleted {
    if (subtasks.isEmpty) return true;
    return subtasks.every((subtask) => subtask.isDone);
  }
  // Get completion percentage
  double get completionPercentage {
    if (subtasks.isEmpty) return isDone ? 1.0 : 0.0;
    int completedSubtasks = subtasks.where((subtask) => subtask.isDone).length;
    return completedSubtasks / subtasks.length;
  }

  // Check if this task is a recurring task instance
  bool get isRecurringInstance {
    return originalRecurringTaskId != null;
  }

  // Calculate next occurrence date based on current due date and recurrence interval
  DateTime? calculateNextOccurrence() {
    if (!isRecurring || dueDate == null || recurrenceInterval == RecurrenceInterval.none) {
      return null;
    }

    final currentDate = dueDate!;
    switch (recurrenceInterval) {
      case RecurrenceInterval.daily:
        return currentDate.add(const Duration(days: 1));
      case RecurrenceInterval.weekly:
        return currentDate.add(const Duration(days: 7));
      case RecurrenceInterval.monthly:
        return DateTime(currentDate.year, currentDate.month + 1, currentDate.day);
      case RecurrenceInterval.yearly:
        return DateTime(currentDate.year + 1, currentDate.month, currentDate.day);
      case RecurrenceInterval.none:
        return null;
    }
  }

  // Check if a new instance should be generated for this recurring task
  bool shouldGenerateNewInstance() {
    if (!isRecurring || nextOccurrenceDate == null) return false;
    final now = DateTime.now();
    
    // Generate if next occurrence is due and hasn't exceeded end date
    final isDue = nextOccurrenceDate!.isBefore(now) || nextOccurrenceDate!.isAtSameMomentAs(now);
    final withinEndDate = recurrenceEndDate == null || nextOccurrenceDate!.isBefore(recurrenceEndDate!);
    
    return isDue && withinEndDate;
  }
}
