// lib/models/todo_item.dart

class ToDoItem {
  // ID is now nullable. It will be null for a new task
  // and will have a value after being saved to the database.
  String? id;
  String title;
  bool isDone;
  DateTime? dueDate;
  String? parentId; // For subtasks
  List<ToDoItem> subtasks = []; // For subtasks

  ToDoItem({
    this.id, // Allow ID to be passed in
    required this.title,
    this.isDone = false,
    this.dueDate,
    this.parentId,
  });

  // Method to convert a ToDoItem instance to a JSON map.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'title': title,
      'is_done': isDone,
      'due_date': dueDate?.toIso8601String(),
      'parent_id': parentId,
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
}
