// lib/models/todo_item.dart

class ToDoItem {
  final String id;
  String title;
  bool isDone;
  DateTime? dueDate; // <-- NEW: Optional property for the due date

  ToDoItem({
    required this.title,
    this.isDone = false,
    this.dueDate, // <-- NEW: Add to constructor
  }) : id = DateTime.now().millisecondsSinceEpoch.toString();

  // A private constructor for fromJson to use
  ToDoItem._({
    required this.id,
    required this.title,
    required this.isDone,
    this.dueDate, // <-- NEW: Add to private constructor
  });

  // Method to convert a ToDoItem instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isDone': isDone,
      // Convert DateTime to a string for JSON, or null if it doesn't exist
      'dueDate': dueDate?.toIso8601String(), // <-- NEW: Handle serialization
    };
  }

  // Factory constructor to create a ToDoItem from a JSON map.
  factory ToDoItem.fromJson(Map<String, dynamic> json) {
    return ToDoItem._(
      id: json['id'],
      title: json['title'],
      isDone: json['isDone'],
      // Parse the string back to DateTime, or set to null if it doesn't exist
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'])
          : null, // <-- NEW: Handle deserialization
    );
  }
}
