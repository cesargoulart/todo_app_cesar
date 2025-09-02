import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/todo_item.dart';
import '../models/label.dart';
import '../services/supabase_service.dart'; // Updated import
import '../services/label_service.dart';
import '../services/notification_service.dart';
import '../services/auto_update_service.dart';
import '../widgets/todo_list_item_widget.dart';
import '../widgets/label_picker_widget.dart';

class ToDoListScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeModeChanged;

  const ToDoListScreen({super.key, required this.onThemeModeChanged});

  @override
  State<ToDoListScreen> createState() => _ToDoListScreenState();
}

class _ToDoListScreenState extends State<ToDoListScreen> {
  final TextEditingController _textFieldController = TextEditingController();
  final SupabaseService _supabaseService = SupabaseService();
  final LabelService _labelService = LabelService();
  final NotificationService _notificationService = NotificationService();
  List<ToDoItem> _todos = [];
  List<Label> _allLabels = []; // Added to store all available labels
  bool _isLoading = true;
  bool _showCompleted = false;
  bool _hideFutureTasks = false;
  bool _hideCremesTasks = true; // Nova variável para esconder tasks com label 'Cremes' (ativado por padrão)
  Label? _filterByLabel;
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
    
    // Filter out tasks with 'Cremes' label
    if (_hideCremesTasks) {
      filtered = filtered.where((todo) => 
        !todo.labels.any((label) => label.name.toLowerCase() == 'cremes')).toList();
    }
    
    // Filter by label
    if (_filterByLabel != null) {
      filtered = filtered.where((todo) => 
        todo.labels.any((label) => label.id == _filterByLabel!.id)).toList();
    }
    
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _loadTodosFromStorage();
    _loadAllLabels();
  }

  Future<void> _loadAllLabels() async {
    try {
      final labels = await _labelService.getAllLabels();
      setState(() {
        _allLabels = labels;
      });
    } catch (e) {
      print('Error loading labels: $e');
    }
  }

  bool _isServiceReady() {
    try {
      // Test if Supabase client is available
      Supabase.instance.client;
      return true;
    } catch (e) {
      print('⚠️ Service not ready: $e');
      return false;
    }
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

  void _toggleToDoStatus(ToDoItem todo) async {
    // Check if services are ready before proceeding
    if (!_isServiceReady()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Services are still initializing. Please wait a moment and try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final originalStatus = todo.isDone;
    
    // Optimistically update the UI
    setState(() {
      todo.isDone = !todo.isDone;
    });

    try {
      print('🔄 Toggling status for task: ${todo.title} (ID: ${todo.id})');
      
      // Update notifications based on the new status
      if (todo.isDone) {
        // Task is now complete, cancel any pending notifications
        if (todo.id != null) {
          try {
            await _notificationService.cancelTaskNotifications(todo.id!);
            print('✅ Cancelled notifications for completed task: ${todo.title}');
          } catch (notifError) {
            print('⚠️ Warning: Could not cancel notifications: $notifError');
            // Don't fail the whole operation if notification cancellation fails
          }
        }
      } else {
        // Task is now incomplete, re-schedule notification if it has a future due date
        if (todo.id != null && todo.dueDate != null && todo.dueDate!.isAfter(DateTime.now())) {
          try {
            await _notificationService.scheduleTaskDueNotification(
              taskId: todo.id!,
              taskTitle: todo.title,
              dueDate: todo.dueDate!,
            );
            print('🔄 Re-scheduled notification for incomplete task: ${todo.title}');
          } catch (notifError) {
            print('⚠️ Warning: Could not schedule notifications: $notifError');
            // Don't fail the whole operation if notification scheduling fails
          }
        }
      }

      // Persist the change to the database
      print('💾 Saving todo to database...');
      await _supabaseService.saveTodo(todo);
      print('✅ Todo saved successfully');

    } catch (e, stackTrace) {
      // If anything fails, revert the change in the UI
      setState(() {
        todo.isDone = originalStatus;
      });
      print('❌ Error updating todo status: $e');
      print('📍 Stack trace: $stackTrace');
      
      if (mounted) {
        String errorMessage = 'Error updating task';
        if (e.toString().contains('Supabase client not initialized')) {
          errorMessage = 'Database not ready. Please try again.';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Check your connection.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$errorMessage: ${e.toString()}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _toggleToDoStatus(todo),
            ),
          ),
        );
      }
    }
  }

  void _deleteToDoItem(ToDoItem todo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete "${todo.title}"?'),
              if (todo.isRecurring) ...[
                const SizedBox(height: 10),
                const Text(
                  'This is a recurring task. What would you like to do?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              child: const Text('CANCEL'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            if (todo.isRecurring) ...[
              TextButton(
                child: const Text('DELETE ONLY THIS'),
                onPressed: () async {
                  try {
                    if (todo.id != null) {
                      // First, cancel any pending notifications for this task
                      await _notificationService.cancelTaskNotifications(todo.id!);
                      await _supabaseService.deleteTodo(todo.id!);
                    }
                    setState(() {
                      _todos.removeWhere((item) => item.id == todo.id);
                    });
                    Navigator.of(context).pop();
                    
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
              TextButton(
                child: const Text('DELETE ALL INSTANCES'),
                onPressed: () async {
                  try {
                    if (todo.id != null) {
                      await _supabaseService.deleteRecurringTask(todo.id!, deleteInstances: true);
                    }
                    setState(() {
                      // Remove the original task and all its instances
                      _todos.removeWhere((item) => 
                        item.id == todo.id || item.originalRecurringTaskId == todo.id);
                    });
                    Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Recurring task "${todo.title}" and all instances deleted'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } catch (e) {
                    Navigator.of(context).pop();
                    print('Error deleting recurring task: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting recurring task: $e')),
                    );
                  }
                },
              ),
            ] else
              TextButton(
                child: const Text('DELETE'),
                onPressed: () async {
                  try {
                    if (todo.id != null) {
                      // First, cancel any pending notifications for this task
                      await _notificationService.cancelTaskNotifications(todo.id!);
                      await _supabaseService.deleteTodo(todo.id!);
                    }
                    setState(() {
                      _todos.removeWhere((item) => item.id == todo.id);
                    });
                    Navigator.of(context).pop();
                    
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
    bool isRecurring = existingTodo?.isRecurring ?? false;
    RecurrenceInterval recurrenceInterval = existingTodo?.recurrenceInterval ?? RecurrenceInterval.none;
    DateTime? recurrenceEndDate = existingTodo?.recurrenceEndDate;
    List<Label> selectedLabels = List.from(existingTodo?.labels ?? []);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(dialogTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        Flexible(
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
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
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
                    
                    // Recurring task options (only for main tasks, not subtasks)
                    if (!isSubtask) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Checkbox(
                            value: isRecurring,
                            onChanged: (value) {
                              setDialogState(() {
                                isRecurring = value ?? false;
                                if (!isRecurring) {
                                  recurrenceInterval = RecurrenceInterval.none;
                                  recurrenceEndDate = null;
                                } else {
                                  // Set default interval when enabling recurring
                                  if (recurrenceInterval == RecurrenceInterval.none) {
                                    recurrenceInterval = RecurrenceInterval.weekly;
                                  }
                                  // Auto-set due date to now if not already set
                                  if (selectedDueDate == null) {
                                    selectedDueDate = DateTime.now();
                                  }
                                }
                              });
                            },
                          ),
                          const Text('Make this a recurring task'),
                        ],
                      ),
                      
                      if (isRecurring) ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<RecurrenceInterval>(
                          value: recurrenceInterval == RecurrenceInterval.none ? RecurrenceInterval.weekly : recurrenceInterval,
                          decoration: const InputDecoration(
                            labelText: 'Repeat every',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            RecurrenceInterval.daily,
                            RecurrenceInterval.weekly,
                            RecurrenceInterval.monthly,
                            RecurrenceInterval.yearly,
                          ].map((interval) {
                            return DropdownMenuItem(
                              value: interval,
                              child: Text(interval.displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              recurrenceInterval = value ?? RecurrenceInterval.weekly;
                            });
                          },
                        ),
                        
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                recurrenceEndDate == null
                                    ? 'No end date (repeats forever)'
                                    : 'Ends: ${DateFormat('MMM d, yyyy').format(recurrenceEndDate!)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            TextButton(
                              child: const Text('SET END DATE'),
                              onPressed: () async {
                                final DateTime? pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: recurrenceEndDate ?? DateTime.now().add(const Duration(days: 365)),
                                  firstDate: selectedDueDate ?? DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                                );
                                if (pickedDate != null) {
                                  setDialogState(() {
                                    recurrenceEndDate = pickedDate;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        
                        if (recurrenceEndDate != null)
                          TextButton(
                            child: const Text('REMOVE END DATE'),
                            onPressed: () {
                              setDialogState(() {
                                recurrenceEndDate = null;
                              });
                            },
                          ),
                      ],
                    ],
                    
                    // Label picker (for all tasks)
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),
                    LabelPickerWidget(
                      selectedLabels: selectedLabels,
                      onLabelsChanged: (labels) {
                        setDialogState(() {
                          selectedLabels = labels;
                        });
                      },
                    ),
                  ],
                ),
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
                  onPressed: () async {
                    final newTitle = _textFieldController.text;
                    if (newTitle.isNotEmpty) {
                      try {
                        if (isEditing) {
                          // Update existing todo
                          existingTodo.title = newTitle;
                          existingTodo.dueDate = selectedDueDate;
                          existingTodo.isRecurring = isRecurring;
                          existingTodo.recurrenceInterval = isRecurring ? recurrenceInterval : RecurrenceInterval.none;
                          existingTodo.recurrenceEndDate = recurrenceEndDate;
                          existingTodo.labels = selectedLabels;
                          // Set next_occurrence_date if recurring
                          if (isRecurring && existingTodo.dueDate != null) {
                            existingTodo.nextOccurrenceDate = existingTodo.calculateNextOccurrence();
                          } else {
                            existingTodo.nextOccurrenceDate = null;
                          }
                          
                          final updatedTodo = await _supabaseService.saveTodo(existingTodo);
                          
                          // Update task labels in database
                          await _updateTaskLabels(updatedTodo.id!, selectedLabels);

                          // Schedule notification if due date is set
                          if (updatedTodo.id != null && updatedTodo.dueDate != null) {
                            await _notificationService.scheduleTaskDueNotification(
                              taskId: updatedTodo.id!,
                              taskTitle: updatedTodo.title,
                              dueDate: updatedTodo.dueDate!,
                            );
                          }
                          
                          setState(() {
                            final index = _todos.indexWhere((t) => t.id == updatedTodo.id);
                            if (index != -1) {
                              _todos[index] = updatedTodo;
                              _todos[index].labels = selectedLabels;
                            }
                          });
                        } else {
                          // Create new todo
                          final newTodo = ToDoItem(
                            title: newTitle,
                            dueDate: selectedDueDate,
                            isRecurring: isRecurring,
                            recurrenceInterval: isRecurring ? recurrenceInterval : RecurrenceInterval.none,
                            recurrenceEndDate: recurrenceEndDate,
                          );
                          
                          // Debug: Always print the task creation details
                          print('UI: Creating new task:');
                          print('  title: $newTitle');
                          print('  isRecurring: $isRecurring');
                          print('  recurrenceInterval: ${isRecurring ? recurrenceInterval.value : 'none'}');
                          print('  selectedDueDate: $selectedDueDate');
                          print('  newTodo.dueDate: ${newTodo.dueDate}');
                          
                          // Set next_occurrence_date if recurring
                          if (isRecurring) {
                            if (newTodo.dueDate != null) {
                              newTodo.nextOccurrenceDate = newTodo.calculateNextOccurrence();
                              print('  calculated nextOccurrenceDate: ${newTodo.nextOccurrenceDate}');
                            } else {
                              print('  WARNING: Cannot calculate next occurrence - no due date set!');
                            }
                          }
                          if (isSubtask && parentTodo != null) {
                            newTodo.parentId = parentTodo.id;
                            final savedSubtask = await _supabaseService.saveTodo(newTodo);
                            setState(() {
                              parentTodo.addSubtask(savedSubtask);
                            });
                          } else {
                            final savedTodo = await _supabaseService.saveTodo(newTodo);
                            // Update task labels in database
                            await _updateTaskLabels(savedTodo.id!, selectedLabels);
                            savedTodo.labels = selectedLabels;  // Set the labels on the todo item

                            // Schedule notification if due date is set
                            if (savedTodo.id != null && savedTodo.dueDate != null) {
                              await _notificationService.scheduleTaskDueNotification(
                                taskId: savedTodo.id!,
                                taskTitle: savedTodo.title,
                                dueDate: savedTodo.dueDate!,
                              );
                            }

                            setState(() {
                              _todos.add(savedTodo);
                            });
                          }
                        }
                      } catch (e) {
                        print('Error saving todo: $e');
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
              child: const Text('DELETE'),
              onPressed: () {
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

  // Update task labels in database
  Future<void> _updateTaskLabels(String taskId, List<Label> labels) async {
    try {
      // Get current labels for the task
      final currentLabels = await _labelService.getLabelsForTask(taskId);
      
      // Remove labels that are no longer selected
      for (Label currentLabel in currentLabels) {
        if (!labels.any((l) => l.id == currentLabel.id)) {
          await _labelService.removeLabelFromTask(taskId, currentLabel.id!);
        }
      }
      
      // Add new labels
      for (Label label in labels) {
        if (!currentLabels.any((l) => l.id == label.id)) {
          await _labelService.addLabelToTask(taskId, label.id!);
        }
      }
    } catch (e) {
      print('Error updating task labels: $e');
    }
  }

  void _showDebugDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Notification Debug Menu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Schedule Test (10s)'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _notificationService.scheduleTestNotification(secondsFromNow: 10);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Test notification scheduled for 10 seconds!')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_10),
                title: const Text('Quick Test (5s)'),
                subtitle: const Text('Fast test notification'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _notificationService.scheduleTestNotification(secondsFromNow: 5);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Quick test notification scheduled for 5 seconds!')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active),
                title: const Text('Show Immediate Test'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _notificationService.showTestNotification();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Immediate test notification sent!')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.plumbing),
                title: const Text('Check Status'),
                subtitle: const Text('Prints pending notifications to console'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _notificationService.debugNotificationStatus();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Check debug console for status')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep),
                title: const Text('Cancel All Notifications'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _notificationService.cancelAllNotifications();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All pending notifications cancelled')),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('CLOSE'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  Widget _buildLabelsDrawer() {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.blueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                'Labels',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.clear_all),
            title: const Text('Show All Tasks'),
            onTap: () {
              setState(() {
                _filterByLabel = null;
              });
              Navigator.pop(context);
            },
            selected: _filterByLabel == null,
          ),
          const Divider(),
          Expanded(
            child: _allLabels.isEmpty
                ? const Center(
                    child: Text(
                      'No labels available',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _allLabels.length,
                    itemBuilder: (context, index) {
                      final label = _allLabels[index];
                      final isSelected = _filterByLabel?.id == label.id;
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _parseColor(label.color),
                          radius: 12,
                        ),
                        title: Text(label.name),
                        onTap: () {
                          setState(() {
                            // If user taps the 'Cremes' label, ensure Cremes tasks are visible
                            if ((label.name).toLowerCase() == 'cremes') {
                              _hideCremesTasks = false;
                            }
                            _filterByLabel = isSelected ? null : label;
                          });
                          Navigator.pop(context);
                        },
                        selected: isSelected,
                        trailing: isSelected ? const Icon(Icons.check) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: _buildLabelsDrawer(), // Added the drawer here
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
          IconButton(
            icon: Icon(_hideFutureTasks ? Icons.event_available : Icons.event_busy),
            tooltip: _hideFutureTasks ? 'Show future tasks' : 'Hide tasks due in 3+ days',
            onPressed: () {
              setState(() {
                _hideFutureTasks = !_hideFutureTasks;
              });
            },
         ),
         IconButton(
           icon: Icon(_hideCremesTasks ? Icons.spa : Icons.spa_outlined),
           tooltip: _hideCremesTasks ? 'Show Cremes tasks' : 'Hide Cremes tasks',
           onPressed: () {
             setState(() {
               _hideCremesTasks = !_hideCremesTasks;
             });
           },
         ),
         IconButton(
           icon: const Icon(Icons.system_update),
           tooltip: 'Check for updates',
           onPressed: () async {
             final autoUpdateService = AutoUpdateService();
             await autoUpdateService.manualUpdateCheck();
           },
         ),
          IconButton(
            icon: const Icon(Icons.science_outlined),
            tooltip: 'Debug Notifications',
            onPressed: () => _showDebugDialog(),
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
    );
  }
}
