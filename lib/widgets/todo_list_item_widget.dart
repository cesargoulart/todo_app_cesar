// lib/widgets/todo_list_item_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo_item.dart';

class ToDoListItemWidget extends StatefulWidget {
  final ToDoItem todo;
  final VoidCallback onStatusChanged;
  final VoidCallback onDismissed;
  final VoidCallback onEdit;
  final Function(ToDoItem)? onAddSubtask;
  final Function(ToDoItem, ToDoItem)? onSubtaskStatusChanged;
  final Function(ToDoItem, ToDoItem)? onSubtaskDeleted;
  final Function(ToDoItem, ToDoItem)? onSubtaskEdit;

  const ToDoListItemWidget({
    super.key,
    required this.todo,
    required this.onStatusChanged,
    required this.onDismissed,
    required this.onEdit,
    this.onAddSubtask,
    this.onSubtaskStatusChanged,
    this.onSubtaskDeleted,
    this.onSubtaskEdit,
  });

  @override
  State<ToDoListItemWidget> createState() => _ToDoListItemWidgetState();
}

class _ToDoListItemWidgetState extends State<ToDoListItemWidget> {
  bool _isExpanded = false;

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final todo = widget.todo;
    // Helper to determine if the task is overdue
    final bool isOverdue = todo.dueDate != null &&
        !todo.isDone &&
        todo.dueDate!.isBefore(DateTime.now());

    return Column(
      children: [        Dismissible(
          key: Key(todo.id ?? 'temp_${todo.hashCode}'),
          onDismissed: (direction) => widget.onDismissed(),
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
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Column(
              children: [
                ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (todo.subtasks.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            _isExpanded ? Icons.expand_less : Icons.expand_more,
                          ),
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                        ),
                      Checkbox(
                        value: todo.isDone,
                        onChanged: (bool? value) => widget.onStatusChanged(),
                      ),
                    ],
                  ),                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          todo.title,
                          style: TextStyle(
                            decoration: todo.isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: todo.isDone
                                ? Colors.grey
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      // Recurring task indicator
                      if (todo.isRecurring)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.repeat,
                            size: 16,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      // Recurring instance indicator
                      if (todo.isRecurringInstance)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.schedule,
                            size: 16,
                            color: Colors.orange,
                          ),
                        ),
                      if (todo.subtasks.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${todo.subtasks.where((s) => s.isDone).length}/${todo.subtasks.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (todo.dueDate != null)
                        Text(
                          DateFormat('MMM d, yyyy hh:mm a').format(todo.dueDate!),
                          style: TextStyle(
                            fontSize: 12,
                            color: isOverdue ? Colors.red : Colors.grey[600],
                            fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      // Show recurring information
                      if (todo.isRecurring)
                        Text(
                          'Repeats ${todo.recurrenceInterval.displayName.toLowerCase()}${todo.recurrenceEndDate != null ? ' until ${DateFormat('MMM d, yyyy').format(todo.recurrenceEndDate!)}' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).primaryColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),                      if (todo.isRecurringInstance)
                        Text(
                          'Part of recurring task',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      // Show labels
                      if (todo.labels.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: todo.labels.map((label) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _parseColor(label.color).withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  label.name,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      if (todo.subtasks.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          child: LinearProgressIndicator(
                            value: todo.completionPercentage,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              todo.completionPercentage == 1.0
                                  ? Colors.green
                                  : Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: widget.onAddSubtask != null
                            ? () => widget.onAddSubtask!(todo)
                            : null,
                        tooltip: 'Add subtask',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: widget.onEdit,
                        tooltip: 'Edit task',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: widget.onDismissed,
                        tooltip: 'Delete task',
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
                // Subtasks section
                if (_isExpanded && todo.subtasks.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                    child: Column(
                      children: todo.subtasks.map((subtask) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Checkbox(
                              value: subtask.isDone,
                              onChanged: (bool? value) {
                                if (widget.onSubtaskStatusChanged != null) {
                                  widget.onSubtaskStatusChanged!(todo, subtask);
                                }
                              },
                            ),
                            title: Text(
                              subtask.title,
                              style: TextStyle(
                                decoration: subtask.isDone
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                color: subtask.isDone
                                    ? Colors.grey
                                    : Theme.of(context).textTheme.bodyMedium?.color,
                                fontSize: 14,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: widget.onSubtaskEdit != null
                                      ? () => widget.onSubtaskEdit!(todo, subtask)
                                      : null,
                                  tooltip: 'Edit subtask',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18),
                                  onPressed: widget.onSubtaskDeleted != null
                                      ? () => widget.onSubtaskDeleted!(todo, subtask)
                                      : null,
                                  tooltip: 'Delete subtask',
                                  color: Colors.red,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
