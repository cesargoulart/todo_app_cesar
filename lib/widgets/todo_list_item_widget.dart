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

class _ToDoListItemWidgetState extends State<ToDoListItemWidget> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          children: [
            Dismissible(
              key: Key(todo.id ?? 'temp_${todo.hashCode}'),
              onDismissed: (direction) => widget.onDismissed(),
              background: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: const Icon(
                  Icons.delete_sweep,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              secondaryBackground: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: const Icon(
                  Icons.delete_sweep,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            elevation: widget.todo.isDone ? 1 : 3,
            shadowColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.5)
                : Theme.of(context).primaryColor.withOpacity(0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: widget.todo.isDone
                    ? Colors.transparent
                    : Theme.of(context).primaryColor.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: widget.todo.isDone
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: Theme.of(context).brightness == Brightness.dark
                            ? [
                                const Color(0xFF1E293B),
                                const Color(0xFF1E293B).withOpacity(0.95),
                              ]
                            : [
                                Colors.white,
                                Colors.white.withOpacity(0.95),
                              ],
                      ),
              ),
              child: Column(
              children: [
                ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (todo.subtasks.isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isExpanded ? Icons.expand_less : Icons.expand_more,
                              color: Theme.of(context).primaryColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _isExpanded = !_isExpanded;
                              });
                            },
                          ),
                        ),
                      Transform.scale(
                        scale: 1.1,
                        child: Checkbox(
                          value: todo.isDone,
                          onChanged: (bool? value) => widget.onStatusChanged(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
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
                      // Recurring task indicator with animation
                      if (todo.isRecurring)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 600),
                          builder: (context, value, child) {
                            return Transform.rotate(
                              angle: value * 3.14159 * 2,
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                child: Icon(
                                  Icons.repeat,
                                  size: 16,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            );
                          },
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
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
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
                      // Show labels with animation
                      if (todo.labels.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: todo.labels.asMap().entries.map((entry) {
                              final index = entry.key;
                              final label = entry.value;
                              return TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: Duration(milliseconds: 300 + (index * 100)),
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: Opacity(
                                      opacity: value,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              _parseColor(label.color).withValues(alpha: 0.9),
                                              _parseColor(label.color).withValues(alpha: 0.7),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _parseColor(label.color).withValues(alpha: 0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          label.name,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      if (todo.subtasks.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: todo.completionPercentage),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  value == 1.0
                                      ? Colors.green
                                      : Theme.of(context).primaryColor,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.add, color: Theme.of(context).primaryColor),
                          onPressed: widget.onAddSubtask != null
                              ? () => widget.onAddSubtask!(todo)
                              : null,
                          tooltip: 'Add subtask',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: widget.onEdit,
                          tooltip: 'Edit task',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: widget.onDismissed,
                          tooltip: 'Delete task',
                        ),
                      ),
                    ],
                  ),
                ),
                // Subtasks section with animation
                if (_isExpanded && todo.subtasks.isNotEmpty)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Container(
                      padding: const EdgeInsets.only(left: 40, right: 16, bottom: 8),
                      child: Column(
                        children: todo.subtasks.asMap().entries.map((entry) {
                          final index = entry.key;
                          final subtask = entry.value;
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(milliseconds: 200 + (index * 50)),
                            builder: (context, value, child) {
                              return Transform.translate(
                                offset: Offset(20 * (1 - value), 0),
                                child: Opacity(
                                  opacity: value,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.grey[800]?.withValues(alpha: 0.3)
                                          : Colors.grey[100]?.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.grey.withValues(alpha: 0.2),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      minLeadingWidth: 32,
                                      leading: Transform.scale(
                                        scale: 0.8,
                                        child: Checkbox(
                                          value: subtask.isDone,
                                          onChanged: (bool? value) {
                                            if (widget.onSubtaskStatusChanged != null) {
                                              widget.onSubtaskStatusChanged!(todo, subtask);
                                            }
                                          },
                                        ),
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
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 14),
                                            onPressed: widget.onSubtaskEdit != null
                                                ? () => widget.onSubtaskEdit!(todo, subtask)
                                                : null,
                                            tooltip: 'Edit subtask',
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(
                                              minWidth: 28,
                                              minHeight: 28,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 14),
                                            onPressed: widget.onSubtaskDeleted != null
                                                ? () => widget.onSubtaskDeleted!(todo, subtask)
                                                : null,
                                            tooltip: 'Delete subtask',
                                            color: Colors.red,
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(
                                              minWidth: 28,
                                              minHeight: 28,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
              ),
            ),
              ),
          ],
        ),
      ),
    );
  }
}
