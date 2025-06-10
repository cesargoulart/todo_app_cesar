// lib/models/todo_item.dart

class ToDoItem {
  final String id;
  String title;
  bool isDone;
  DateTime? dueDate;
  String? parentId; // ID of parent task (null for main tasks)
  List<ToDoItem> subtasks; // List of subtasks

  ToDoItem({
    required this.title,
    this.isDone = false,
    this.dueDate,
    this.parentId,
    List<ToDoItem>? subtasks,
  }) : id = DateTime.now().millisecondsSinceEpoch.toString(),
       subtasks = subtasks ?? [];

  // A private constructor for fromJson to use
  ToDoItem._({
    required this.id,
    required this.title,
    required this.isDone,
    this.dueDate,
    this.parentId,
    required this.subtasks,
  });
  // Method to convert a ToDoItem instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isDone': isDone,
      'dueDate': dueDate?.toIso8601String(),
      'parentId': parentId,
      'subtasks': subtasks.map((subtask) => subtask.toJson()).toList(),
    };
  }

  // Factory constructor to create a ToDoItem from a JSON map.
  factory ToDoItem.fromJson(Map<String, dynamic> json) {
    return ToDoItem._(
      id: json['id'],
      title: json['title'],
      isDone: json['isDone'],
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'])
          : null,
      parentId: json['parentId'],
      subtasks: json['subtasks'] != null
          ? (json['subtasks'] as List)
              .map((subtaskJson) => ToDoItem.fromJson(subtaskJson))
              .toList()
          : [],
    );
  }

  // Helper methods for subtask management
  void addSubtask(ToDoItem subtask) {
    subtask.parentId = id;
    subtasks.add(subtask);
  }

  void removeSubtask(String subtaskId) {
    subtasks.removeWhere((subtask) => subtask.id == subtaskId);
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
