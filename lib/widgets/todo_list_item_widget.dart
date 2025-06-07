// lib/widgets/todo_list_item_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // <-- IMPORT THE PACKAGE
import '../models/todo_item.dart';

class ToDoListItemWidget extends StatelessWidget {
  final ToDoItem todo;
  final VoidCallback onStatusChanged;
  final VoidCallback onDismissed;
  final VoidCallback onEdit;

  const ToDoListItemWidget({
    super.key,
    required this.todo,
    required this.onStatusChanged,
    required this.onDismissed,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    // Helper to determine if the task is overdue
    final bool isOverdue = todo.dueDate != null &&
        !todo.isDone &&
        todo.dueDate!.isBefore(DateTime.now());

    return Dismissible(
      key: Key(todo.id),
      onDismissed: (direction) => onDismissed(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: ListTile(
        leading: Checkbox(
          value: todo.isDone,
          onChanged: (bool? value) => onStatusChanged(),
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            decoration:
                todo.isDone ? TextDecoration.lineThrough : TextDecoration.none,
            color: todo.isDone
                ? Colors.grey
                : Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: todo.dueDate != null
            ? Text(
                DateFormat('MMM d, yyyy hh:mm a').format(todo.dueDate!),
                style: TextStyle(
                  fontSize: 12,
                  color: isOverdue ? Colors.red : Colors.grey[600],
                  fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                ),
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: onEdit,
        ),
      ),
    );
  }
}
