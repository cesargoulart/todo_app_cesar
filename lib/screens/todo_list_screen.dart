import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo_item.dart';
import '../services/supabase_service.dart'; // Updated import
import '../widgets/todo_list_item_widget.dart';

class ToDoListScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeModeChanged;

  const ToDoListScreen({super.key, required this.onThemeModeChanged});

  @override
  State<ToDoListScreen> createState() => _ToDoListScreenState();
}

class _ToDoListScreenState extends State<ToDoListScreen> {
  final TextEditingController _textFieldController = TextEditingController();
  final SupabaseService _supabaseService = SupabaseService();
  List<ToDoItem> _todos = [];
  bool _isLoading = true;
  bool _showCompleted = true;
  bool _hideFutureTasks = false;

  List<ToDoItem> get _filteredTodos {
    List<ToDoItem> filtered = _todos;
    
    // Filter by completion status
    if (!_showCompleted) {
      filtered = filtered.where((todo) => !todo.isDone).toList();
    }
    
    // Filter by future deadlines (more than 3 days away)
    if (_hideFutureTasks) {
      final threeDaysFromNow = DateTime.now().add(const Duration(days: 3));
      filtered = filtered.where((todo) {
        // Keep tasks without due dates or tasks due within 3 days
        return todo.dueDate == null || todo.dueDate!.isBefore(threeDaysFromNow);
      }).toList();
    }
    
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _loadTodosFromStorage();
  }
  Future<void> _loadTodosFromStorage() async {
    final loadedTodos = await _supabaseService.loadTodos();
    setState(() {
      _todos = loadedTodos;
      _isLoading = false;
    });
  }

  Future<void> _saveTodosToStorage() async {
    await _supabaseService.saveTodos(_todos);
  }

  // This method is no longer used, but kept for reference.
  // The logic is now inside the dialog's save button.
  // void _addToDoItem(String title, {DateTime? dueDate}) { ... }
  // void _editToDoItem(ToDoItem todo, String newTitle, {DateTime? dueDate}) { ... }
  void _toggleToDoStatus(ToDoItem todo) async {
    try {
      setState(() {
        todo.isDone = !todo.isDone;
      });
      await _supabaseService.saveTodo(todo);
    } catch (e) {
      // Revert the change if save fails
      setState(() {
        todo.isDone = !todo.isDone;
      });
      print('Error updating todo status: $e');
    }
  }
  void _deleteToDoItem(ToDoItem todo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: Text('Are you sure you want to delete "${todo.title}"?'),
          actions: [
            TextButton(
              child: const Text('CANCEL'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),            TextButton(
              child: const Text('DELETE'),              onPressed: () async {
                try {
                  if (todo.id != null) {
                    await _supabaseService.deleteTodo(todo.id!);
                  }
                  setState(() {
                    _todos.removeWhere((item) => item.id == todo.id);
                  });
                  Navigator.of(context).pop();
                  
                  // Show a snackbar confirmation
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Task "${todo.title}" deleted'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  print('Error deleting todo: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting task: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddOrEditToDoDialog({ToDoItem? existingTodo, bool isSubtask = false, ToDoItem? parentTodo}) {
    final bool isEditing = existingTodo != null;
    final String dialogTitle = isEditing ? 'Edit To-Do' : 'Add a new To-Do';
    final String saveButtonText = isEditing ? 'SAVE' : 'ADD';

    _textFieldController.text = existingTodo?.title ?? '';
    DateTime? selectedDueDate = existingTodo?.dueDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(dialogTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _textFieldController,
                    decoration: const InputDecoration(hintText: "Enter task here"),
                    autofocus: true,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible( // Added Flexible to prevent overflow
                        child: Text(
                          selectedDueDate == null
                              ? 'No due date'
                              : DateFormat('MMM d, hh:mm a').format(selectedDueDate!),
                        ),
                      ),
                      TextButton(
                        child: const Text('SET DATE'),
                        onPressed: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDueDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)), // Allow past dates
                            lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                          );
                          if (pickedDate == null) return;
                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedDueDate ?? DateTime.now()),
                          );
                          if (pickedTime == null) return;
                          setDialogState(() {
                            selectedDueDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        },
                      )
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('CANCEL'),
                  onPressed: () {
                    _textFieldController.clear();
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text(saveButtonText),                  onPressed: () async {
                    final newTitle = _textFieldController.text;
                    if (newTitle.isNotEmpty) {
                      try {
                        if (isEditing) {
                          // Update existing todo
                          existingTodo.title = newTitle;
                          existingTodo.dueDate = selectedDueDate;
                          final updatedTodo = await _supabaseService.saveTodo(existingTodo);
                          setState(() {
                            // Update the todo in the list with the updated data
                            final index = _todos.indexWhere((t) => t.id == updatedTodo.id);
                            if (index != -1) {
                              _todos[index] = updatedTodo;
                            }
                          });
                        } else {
                          // Create new todo
                          final newTodo = ToDoItem(
                            title: newTitle,
                            dueDate: selectedDueDate,
                          );
                          
                          if (isSubtask && parentTodo != null) {
                            newTodo.parentId = parentTodo.id;
                            final savedSubtask = await _supabaseService.saveTodo(newTodo);
                            setState(() {
                              parentTodo.addSubtask(savedSubtask);
                            });
                          } else {
                            final savedTodo = await _supabaseService.saveTodo(newTodo);
                            setState(() {
                              _todos.add(savedTodo);
                            });
                          }
                        }
                      } catch (e) {
                        print('Error saving todo: $e');
                        // Show error message to user
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error saving task: $e')),
                        );
                      }
                    }
                    _textFieldController.clear();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Subtask management methods
  void _addSubtask(ToDoItem parentTodo) {
    _showAddOrEditToDoDialog(isSubtask: true, parentTodo: parentTodo);
  }

  void _toggleSubtaskStatus(ToDoItem parentTodo, ToDoItem subtask) {
    setState(() {
      subtask.isDone = !subtask.isDone;
    });
    _saveTodosToStorage();
  }

  void _deleteSubtask(ToDoItem parentTodo, ToDoItem subtask) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Subtask'),
          content: Text('Are you sure you want to delete "${subtask.title}"?'),
          actions: [
            TextButton(
              child: const Text('CANCEL'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('DELETE'),              onPressed: () {
                setState(() {
                  if (subtask.id != null) {
                    parentTodo.removeSubtask(subtask.id!);
                  }
                });
                _saveTodosToStorage();
                Navigator.of(context).pop();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Subtask "${subtask.title}" deleted'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _editSubtask(ToDoItem parentTodo, ToDoItem subtask) {
    _showAddOrEditToDoDialog(existingTodo: subtask, isSubtask: true, parentTodo: parentTodo);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter To-Do List'),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              final newThemeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
              widget.onThemeModeChanged(newThemeMode);
            },
          ),          IconButton(
            icon: Icon(_showCompleted ? Icons.visibility_off : Icons.visibility),
            tooltip: _showCompleted ? 'Hide completed tasks' : 'Show completed tasks',
            onPressed: () {
              setState(() {
                _showCompleted = !_showCompleted;
              });
            },
          ),
          IconButton(
            icon: Icon(_hideFutureTasks ? Icons.event_available : Icons.event_busy),
            tooltip: _hideFutureTasks ? 'Show future tasks' : 'Hide tasks due in 3+ days',
            onPressed: () {
              setState(() {
                _hideFutureTasks = !_hideFutureTasks;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _filteredTodos.length,              itemBuilder: (context, index) {
                final todo = _filteredTodos[index];
                return ToDoListItemWidget(
                  todo: todo,
                  onStatusChanged: () => _toggleToDoStatus(todo),
                  onDismissed: () => _deleteToDoItem(todo),
                  onEdit: () => _showAddOrEditToDoDialog(existingTodo: todo),
                  onAddSubtask: _addSubtask,
                  onSubtaskStatusChanged: _toggleSubtaskStatus,
                  onSubtaskDeleted: _deleteSubtask,
                  onSubtaskEdit: _editSubtask,
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOrEditToDoDialog(),
        tooltip: 'Add To-Do',
        child: const Icon(Icons.add),
      ),
      // The BottomAppBar has been removed from here.
    );
  }
}
