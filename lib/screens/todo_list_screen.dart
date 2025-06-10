import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo_item.dart';
import '../services/storage_service.dart'; // Corrected import path
import '../widgets/todo_list_item_widget.dart';

class ToDoListScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeModeChanged;

  const ToDoListScreen({super.key, required this.onThemeModeChanged});

  @override
  State<ToDoListScreen> createState() => _ToDoListScreenState();
}

class _ToDoListScreenState extends State<ToDoListScreen> {
  final TextEditingController _textFieldController = TextEditingController();
  final StorageService _storageService = StorageService();
  List<ToDoItem> _todos = [];
  bool _isLoading = true;
  bool _showCompleted = true;

  List<ToDoItem> get _filteredTodos {
    if (_showCompleted) {
      return _todos;
    } else {
      return _todos.where((todo) => !todo.isDone).toList();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTodosFromStorage();
  }

  Future<void> _loadTodosFromStorage() async {
    final loadedTodos = await _storageService.loadTodos();
    setState(() {
      _todos = loadedTodos;
      _isLoading = false;
    });
  }

  Future<void> _saveTodosToStorage() async {
    await _storageService.saveTodos(_todos);
  }

  // This method is no longer used, but kept for reference.
  // The logic is now inside the dialog's save button.
  // void _addToDoItem(String title, {DateTime? dueDate}) { ... }
  // void _editToDoItem(ToDoItem todo, String newTitle, {DateTime? dueDate}) { ... }

  void _toggleToDoStatus(ToDoItem todo) {
    setState(() {
      todo.isDone = !todo.isDone;
    });
    _saveTodosToStorage();
  }

  void _deleteToDoItem(ToDoItem todo) {
    setState(() {
      _todos.removeWhere((item) => item.id == todo.id);
    });
    _saveTodosToStorage();
  }

  void _showAddOrEditToDoDialog({ToDoItem? existingTodo}) {
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
                  child: Text(saveButtonText),
                  onPressed: () {
                    final newTitle = _textFieldController.text;
                    if (newTitle.isNotEmpty) {
                      setState(() { // Use a single setState call
                        if (isEditing) {
                          existingTodo!.title = newTitle;
                          existingTodo.dueDate = selectedDueDate;
                        } else {
                          _todos.add(ToDoItem(
                            title: newTitle,
                            dueDate: selectedDueDate,
                          ));
                        }
                      });
                      _saveTodosToStorage();
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
          ),
          IconButton(
            icon: Icon(_showCompleted ? Icons.visibility_off : Icons.visibility),
            tooltip: _showCompleted ? 'Hide completed tasks' : 'Show completed tasks',
            onPressed: () {
              setState(() {
                _showCompleted = !_showCompleted;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _filteredTodos.length,
              itemBuilder: (context, index) {
                final todo = _filteredTodos[index];
                return ToDoListItemWidget(
                  todo: todo,
                  onStatusChanged: () => _toggleToDoStatus(todo),
                  onDismissed: () => _deleteToDoItem(todo),
                  onEdit: () => _showAddOrEditToDoDialog(existingTodo: todo),
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