import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/todo_item.dart';
import '../models/label.dart';
import '../services/supabase_service.dart'; // Updated import
import '../services/label_service.dart';
import '../services/notification_service.dart';
import '../services/auto_update_service.dart';
import '../services/database_sync_service.dart'; // Novo serviço de sincronização
import '../services/deadline_monitor_service.dart';
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
  final DatabaseSyncService _syncService = DatabaseSyncService(); // Novo serviço
  final DeadlineMonitorService _deadlineMonitor = DeadlineMonitorService();
  List<ToDoItem> _todos = [];
  List<Label> _allLabels = []; // Added to store all available labels
  bool _isLoading = true;
  bool _isSyncing = false; // Indicador de sincronização
  bool _showCompleted = false;
  bool _hideFutureTasks = false;
  bool _showOnlyTasksWithShowOnDueDate = false; // New filter state
  bool _hideCremesTasks = true; // Nova variável para esconder tasks com label 'Cremes' (ativado por padrão)
  Label? _filterByLabel;
  List<ToDoItem> get _filteredTodos {
    List<ToDoItem> filtered = _todos;

    // When the "show only on due date" filter is active, we start with just those tasks.
    if (_showOnlyTasksWithShowOnDueDate) {
      filtered = filtered.where((todo) => todo.showOnlyOnDueDate).toList();
    }

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

    // Filter tasks that should only show on due date, but only if the specific filter for them is NOT active.
    if (!_showOnlyTasksWithShowOnDueDate) {
      final now = DateTime.now();
      filtered = filtered.where((todo) {
        // If showOnlyOnDueDate is true and has a due date, only show if due date is today or past
        if (todo.showOnlyOnDueDate && todo.dueDate != null) {
          final dueDate = DateTime(todo.dueDate!.year, todo.dueDate!.month, todo.dueDate!.day);
          final today = DateTime(now.year, now.month, now.day);
          return dueDate.isBefore(today) || dueDate.isAtSameMomentAs(today);
        }
        // Otherwise, show the task normally
        return true;
      }).toList();
    }

    // The logic to filter for _showOnlyTasksWithShowOnDueDate has been moved to the top.

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
    _initializeSyncService();
    _loadAllLabels();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize deadline monitor with context
    _deadlineMonitor.initialize(context);
  }

  @override
  void dispose() {
    _deadlineMonitor.dispose();
    _syncService.dispose();
    _textFieldController.dispose();
    super.dispose();
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

  /// Inicializa o serviço de sincronização com callbacks
  Future<void> _initializeSyncService() async {
    await _syncService.initialize(
      onDataUpdated: (todos) {
        if (mounted) {
          setState(() {
            _todos = todos;
            _isLoading = false;
          });
          // Update deadline monitor with latest tasks and start monitoring
          _deadlineMonitor.updateTasks(_todos);
          _deadlineMonitor.startMonitoring(_todos);
        }
      },
      onSyncError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro na sincronização: $error'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Tentar novamente',
                onPressed: () => _syncService.forceSync(),
              ),
            ),
          );
        }
      },
      onSyncStatusChanged: (isSyncing) {
        if (mounted) {
          setState(() {
            _isSyncing = isSyncing;
          });
        }
      },
    );
  }

  Future<void> _saveTodosToStorage() async {
    // Usa o serviço de sincronização com proteção
    await _syncService.saveTodosSafely(_todos);
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
            _deadlineMonitor.clearTaskAlert(todo.id!);
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

      // Persist the change to the database with protection
      print('💾 Saving todo to database with protection...');
      await _syncService.saveTodoSafely(todo);
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
                      try {
                        await _notificationService.cancelTaskNotifications(todo.id!);
                        _deadlineMonitor.clearTaskAlert(todo.id!);
                      } catch (notifError) {
                        print('Warning: Could not cancel notifications: $notifError');
                        // Continue with deletion even if notification cancellation fails
                      }
                      await _syncService.deleteTodoSafely(todo.id!);
                    }
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
                      await _syncService.wrapUserOperation(() async {
                        await _supabaseService.deleteRecurringTask(todo.id!, deleteInstances: true);
                        // Remove the original task and all its instances from local state
                        setState(() {
                          _todos.removeWhere((item) => 
                            item.id == todo.id || item.originalRecurringTaskId == todo.id);
                        });
                      });
                    }
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
                      try {
                        await _notificationService.cancelTaskNotifications(todo.id!);
                        _deadlineMonitor.clearTaskAlert(todo.id!);
                      } catch (notifError) {
                        print('Warning: Could not cancel notifications: $notifError');
                        // Continue with deletion even if notification cancellation fails
                      }
                      await _syncService.deleteTodoSafely(todo.id!);
                    }
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
    final String dialogTitle = isEditing
        ? (isSubtask ? 'Edit Subtask' : 'Edit Task')
        : (isSubtask ? 'Add Subtask' : 'New Task');
    final String saveButtonText = isEditing ? 'Save changes' : 'Add task';

    _textFieldController.text = existingTodo?.title ?? '';
    DateTime? selectedDueDate = existingTodo?.dueDate;
    bool showOnlyOnDueDate = existingTodo?.showOnlyOnDueDate ?? false;
    bool isRecurring = existingTodo?.isRecurring ?? false;
    RecurrenceInterval recurrenceInterval = existingTodo?.recurrenceInterval ?? RecurrenceInterval.none;
    DateTime? recurrenceEndDate = existingTodo?.recurrenceEndDate;
    List<Label> selectedLabels = List.from(existingTodo?.labels ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primary = Theme.of(context).colorScheme.primary;
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Cabeçalho ────────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isEditing ? Icons.edit_rounded : Icons.add_task_rounded,
                            color: primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          dialogTitle,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: isDark ? const Color(0xFFEDE9FF) : const Color(0xFF1A1A2E),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: isDark ? const Color(0xFF6B6080) : const Color(0xFFAA99CC)),
                          onPressed: () {
                            _textFieldController.clear();
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Campo de texto ────────────────────────────────────
                    TextField(
                      controller: _textFieldController,
                      autofocus: true,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: isSubtask ? 'Subtask description…' : 'What needs to be done?',
                        prefixIcon: Icon(Icons.task_alt_rounded, color: primary.withOpacity(0.6)),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {},
                    ),
                    const SizedBox(height: 16),

                    // ── Due date ──────────────────────────────────────────
                    _buildSheetSection(
                      icon: Icons.calendar_today_rounded,
                      label: selectedDueDate == null
                          ? 'No due date'
                          : DateFormat('MMM d, yyyy · hh:mm a').format(selectedDueDate!),
                      isDark: isDark,
                      primary: primary,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selectedDueDate != null)
                            TextButton(
                              onPressed: () => setDialogState(() => selectedDueDate = null),
                              child: const Text('Clear'),
                            ),
                          TextButton(
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
                                  pickedDate.year, pickedDate.month, pickedDate.day,
                                  pickedTime.hour, pickedTime.minute,
                                );
                              });
                            },
                            child: const Text('Set date'),
                          ),
                        ],
                      ),
                    ),

                    // ── Show only on due date ─────────────────────────────
                    if (selectedDueDate != null) ...[
                      const SizedBox(height: 8),
                      _buildToggleRow(
                        icon: Icons.visibility_rounded,
                        label: 'Show only on due date',
                        value: showOnlyOnDueDate,
                        onChanged: (v) => setDialogState(() => showOnlyOnDueDate = v ?? false),
                        isDark: isDark,
                        primary: primary,
                      ),
                    ],

                    // ── Recurring ─────────────────────────────────────────
                    if (!isSubtask) ...[
                      const SizedBox(height: 8),
                      _buildToggleRow(
                        icon: Icons.repeat_rounded,
                        label: 'Recurring task',
                        value: isRecurring,
                        onChanged: (v) {
                          setDialogState(() {
                            isRecurring = v ?? false;
                            if (!isRecurring) {
                              recurrenceInterval = RecurrenceInterval.none;
                              recurrenceEndDate = null;
                            } else {
                              if (recurrenceInterval == RecurrenceInterval.none) {
                                recurrenceInterval = RecurrenceInterval.weekly;
                              }
                              if (selectedDueDate == null) {
                                selectedDueDate = DateTime.now();
                              }
                            }
                          });
                        },
                        isDark: isDark,
                        primary: primary,
                      ),

                      if (isRecurring) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<RecurrenceInterval>(
                          value: recurrenceInterval == RecurrenceInterval.none
                              ? RecurrenceInterval.weekly
                              : recurrenceInterval,
                          decoration: const InputDecoration(
                            labelText: 'Repeat every',
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
                    // ── Labels ───────────────────────────────────────────
                    const SizedBox(height: 16),
                    Divider(
                      color: isDark ? const Color(0xFF2D2844) : const Color(0xFFEEE8FF),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.label_rounded, size: 16, color: primary.withOpacity(0.7)),
                        const SizedBox(width: 8),
                        Text(
                          'Labels',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primary.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LabelPickerWidget(
                      selectedLabels: selectedLabels,
                      onLabelsChanged: (labels) {
                        setDialogState(() {
                          selectedLabels = labels;
                        });
                      },
                    ),

                    const SizedBox(height: 28),

                    // ── Botão guardar ─────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final newTitle = _textFieldController.text;
                          if (newTitle.isNotEmpty) {
                            HapticFeedback.mediumImpact();
                            try {
                              if (isEditing) {
                                existingTodo.title = newTitle;
                                existingTodo.dueDate = selectedDueDate;
                                existingTodo.showOnlyOnDueDate = showOnlyOnDueDate;
                                existingTodo.isRecurring = isRecurring;
                                existingTodo.recurrenceInterval = isRecurring ? recurrenceInterval : RecurrenceInterval.none;
                                existingTodo.recurrenceEndDate = recurrenceEndDate;
                                existingTodo.labels = selectedLabels;
                                if (isRecurring && existingTodo.dueDate != null) {
                                  existingTodo.nextOccurrenceDate = existingTodo.calculateNextOccurrence();
                                } else {
                                  existingTodo.nextOccurrenceDate = null;
                                }
                                final updatedTodo = await _syncService.saveTodoSafely(existingTodo);
                                await _updateTaskLabels(updatedTodo.id!, selectedLabels);
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
                                final newTodo = ToDoItem(
                                  title: newTitle,
                                  dueDate: selectedDueDate,
                                  showOnlyOnDueDate: showOnlyOnDueDate,
                                  isRecurring: isRecurring,
                                  recurrenceInterval: isRecurring ? recurrenceInterval : RecurrenceInterval.none,
                                  recurrenceEndDate: recurrenceEndDate,
                                );
                                print('UI: Creating new task: $newTitle');
                                if (isRecurring && newTodo.dueDate != null) {
                                  newTodo.nextOccurrenceDate = newTodo.calculateNextOccurrence();
                                }
                                if (isSubtask && parentTodo != null) {
                                  newTodo.parentId = parentTodo.id;
                                  final savedSubtask = await _syncService.saveTodoSafely(newTodo);
                                  setState(() {
                                    parentTodo.addSubtask(savedSubtask);
                                  });
                                } else {
                                  final savedTodo = await _syncService.saveTodoSafely(newTodo);
                                  await _updateTaskLabels(savedTodo.id!, selectedLabels);
                                  savedTodo.labels = selectedLabels;
                                  if (savedTodo.id != null && savedTodo.dueDate != null) {
                                    await _notificationService.scheduleTaskDueNotification(
                                      taskId: savedTodo.id!,
                                      taskTitle: savedTodo.title,
                                      dueDate: savedTodo.dueDate!,
                                    );
                                  }
                                }
                              }
                            } catch (e) {
                              print('Error saving todo: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error saving task: $e')),
                                );
                              }
                            }
                          }
                          _textFieldController.clear();
                          Navigator.of(context).pop();
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isEditing ? Icons.check_rounded : Icons.add_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(saveButtonText),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Helpers para o bottom sheet ────────────────────────────────────────────

  Widget _buildSheetSection({
    required IconData icon,
    required String label,
    required bool isDark,
    required Color primary,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1C30) : const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2844) : const Color(0xFFE0D7FF),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primary.withOpacity(0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFFAA99CC) : const Color(0xFF6B5B95),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required bool isDark,
    required Color primary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: value
            ? primary.withOpacity(0.08)
            : (isDark ? const Color(0xFF1F1C30) : const Color(0xFFF3F0FF)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? primary.withOpacity(0.3) : (isDark ? const Color(0xFF2D2844) : const Color(0xFFE0D7FF)),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: value ? primary : primary.withOpacity(0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: value
                    ? (isDark ? const Color(0xFFEDE9FF) : const Color(0xFF1A1A2E))
                    : (isDark ? const Color(0xFFAA99CC) : const Color(0xFF6B5B95)),
                fontWeight: value ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          Checkbox(value: value, onChanged: onChanged),
        ],
      ),
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

  // Uncheck all tasks that contain a specific label
  Future<void> _uncheckAllTasksForLabel(Label label) async {
    try {
      // Find tasks currently loaded in memory with this label
      final tasksToUncheck = _todos.where((t) => t.labels.any((l) => l.id == label.id) && t.isDone).toList();

      if (tasksToUncheck.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No completed Cremes tasks to uncheck.')));
        }
        return;
      }

      // Update each task locally and in the database with protection
      await _syncService.wrapUserOperation(() async {
        for (final task in tasksToUncheck) {
          task.isDone = false;
        }
        
        // Persist changes in batch
        await _supabaseService.saveTodos(tasksToUncheck);
      });

      // Força uma sincronização para atualizar a UI
      await _syncService.forceSync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unchecked ${tasksToUncheck.length} tasks.')));
      }
    } catch (e) {
      print('Error unchecking tasks: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error unchecking tasks: $e')));
      }
    }
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
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final syncStatus = _syncService.getStatus();
            return AlertDialog(
              title: const Text('Debug Menu'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Seção de Status de Sincronização
                    const Text(
                      'Status de Sincronização',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• Sincronização automática: ${syncStatus['autoSyncActive'] ? "Ativa" : "Pausada"}'),
                            Text('• Sincronizando agora: ${syncStatus['isSyncing'] ? "Sim" : "Não"}'),
                            Text('• Operação em andamento: ${syncStatus['isUserOperating'] ? "Sim" : "Não"}'),
                            Text('• Total de tarefas: ${syncStatus['currentTodosCount']}'),
                            if (syncStatus['lastSyncTime'] != null)
                              Text('• Última sync: ${DateTime.parse(syncStatus['lastSyncTime']).toLocal().toString().substring(11, 16)}'),
                            if (syncStatus['pendingSyncQueue'] > 0)
                              Text('• Filas pendentes: ${syncStatus['pendingSyncQueue']}', 
                                style: const TextStyle(color: Colors.orange)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: Icon(
                        syncStatus['autoSyncActive'] ? Icons.pause : Icons.play_arrow,
                        color: syncStatus['autoSyncActive'] ? Colors.orange : Colors.green,
                      ),
                      title: Text(syncStatus['autoSyncActive'] ? 'Pausar Sincronização' : 'Retomar Sincronização'),
                      subtitle: const Text('Controla a atualização automática'),
                      onTap: () {
                        if (syncStatus['autoSyncActive']) {
                          _syncService.stopAutoSync();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sincronização automática pausada')),
                          );
                        } else {
                          _syncService.startAutoSync();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sincronização automática retomada')),
                          );
                        }
                        Navigator.of(context).pop();
                        // Reabrir o diálogo para mostrar o novo status
                        Future.delayed(const Duration(milliseconds: 100), () {
                          _showDebugDialog();
                        });
                      },
                    ),
                    const Divider(),
                    const Text(
                      'Testes de Notificação',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
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
              ),
              actions: [
                TextButton(
                  child: const Text('FECHAR'),
                  onPressed: () {
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
                // Also reset the 'Cremes' filter to its default (hidden)
                _hideCremesTasks = true;
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
          // Show an action button at the bottom when the 'Cremes' label is selected
          if (_filterByLabel != null && _filterByLabel!.name.toLowerCase() == 'cremes')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                icon: const Icon(Icons.check_box_outline_blank),
                label: const Text('Uncheck all Cremes tasks'),
                onPressed: () async {
                  // Confirm before running
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) {
                      return AlertDialog(
                        title: const Text('Confirm'),
                        content: const Text('Uncheck all tasks with label "Cremes"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('CANCEL')),
                          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('OK')),
                        ],
                      );
                    },
                  );

                  if (confirm == true) {
                    await _uncheckAllTasksForLabel(_filterByLabel!);
                    Navigator.pop(context); // close drawer after action
                  }
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
    final primary = Theme.of(context).colorScheme.primary;
    final taskCount = _filteredTodos.length;

    return Scaffold(
      drawer: _buildLabelsDrawer(),

      // ── AppBar ────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF0D0B17) : const Color(0xFFF5F3FF),
        leading: Builder(builder: (ctx) {
          return IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.menu_rounded, color: primary, size: 20),
            ),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          );
        }),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'My Tasks',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.5,
                    color: isDarkMode ? const Color(0xFFEDE9FF) : const Color(0xFF1A1A2E),
                  ),
                ),
                if (_isSyncing) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                ],
                if (!_isSyncing && _syncService.timeSinceLastSync != null) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Synced ${_syncService.timeSinceLastSync!.inMinutes}m ago',
                    child: Icon(
                      _syncService.needsSync ? Icons.sync_problem_rounded : Icons.cloud_done_rounded,
                      size: 16,
                      color: _syncService.needsSync
                          ? Colors.orange
                          : (isDarkMode ? const Color(0xFF4ADE80) : Colors.green),
                    ),
                  ),
                ],
              ],
            ),
            if (!_isLoading)
              Text(
                '$taskCount task${taskCount == 1 ? '' : 's'}${_filterByLabel != null ? ' · ${_filterByLabel!.name}' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? const Color(0xFF6B6080) : const Color(0xFFAA99CC),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          // Botão tema
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  RotationTransition(turns: anim, child: FadeTransition(opacity: anim, child: child)),
              child: Icon(
                isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey(isDarkMode),
                color: isDarkMode ? const Color(0xFFEDE9FF) : const Color(0xFF1A1A2E),
              ),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              widget.onThemeModeChanged(isDarkMode ? ThemeMode.light : ThemeMode.dark);
            },
          ),
          // Botão refresh
          IconButton(
            icon: AnimatedRotation(
              turns: _isSyncing ? 1 : 0,
              duration: const Duration(milliseconds: 600),
              child: Icon(
                Icons.refresh_rounded,
                color: isDarkMode ? const Color(0xFFEDE9FF) : const Color(0xFF1A1A2E),
              ),
            ),
            tooltip: 'Sync now',
            onPressed: _isSyncing ? null : () {
              HapticFeedback.lightImpact();
              _syncService.forceSync();
            },
          ),
          // Popup menu com filtros e opções extra
          PopupMenuButton<String>(
            icon: Icon(
              Icons.tune_rounded,
              color: isDarkMode ? const Color(0xFFEDE9FF) : const Color(0xFF1A1A2E),
            ),
            tooltip: 'Filters & options',
            onSelected: (value) async {
              switch (value) {
                case 'show_completed':
                  setState(() => _showCompleted = !_showCompleted);
                  break;
                case 'hide_future':
                  setState(() => _hideFutureTasks = !_hideFutureTasks);
                  break;
                case 'show_due_date_only':
                  setState(() => _showOnlyTasksWithShowOnDueDate = !_showOnlyTasksWithShowOnDueDate);
                  break;
                case 'hide_cremes':
                  setState(() => _hideCremesTasks = !_hideCremesTasks);
                  break;
                case 'update':
                  await AutoUpdateService().manualUpdateCheck();
                  break;
                case 'debug':
                  _showDebugDialog();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'show_completed',
                child: Row(children: [
                  Icon(_showCompleted ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 18, color: primary),
                  const SizedBox(width: 12),
                  Text(_showCompleted ? 'Hide completed' : 'Show completed'),
                ]),
              ),
              PopupMenuItem(
                value: 'hide_future',
                child: Row(children: [
                  Icon(_hideFutureTasks ? Icons.event_available_rounded : Icons.event_busy_rounded,
                      size: 18, color: primary),
                  const SizedBox(width: 12),
                  Text(_hideFutureTasks ? 'Show future tasks' : 'Hide 3+ day tasks'),
                ]),
              ),
              PopupMenuItem(
                value: 'show_due_date_only',
                child: Row(children: [
                  Icon(_showOnlyTasksWithShowOnDueDate ? Icons.calendar_view_day_rounded : Icons.calendar_today_rounded,
                      size: 18, color: primary),
                  const SizedBox(width: 12),
                  Text(_showOnlyTasksWithShowOnDueDate ? 'Show all tasks' : 'Only due-date tasks'),
                ]),
              ),
              PopupMenuItem(
                value: 'hide_cremes',
                child: Row(children: [
                  Icon(_hideCremesTasks ? Icons.spa_rounded : Icons.spa_outlined,
                      size: 18, color: primary),
                  const SizedBox(width: 12),
                  Text(_hideCremesTasks ? 'Show Cremes' : 'Hide Cremes'),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'update',
                child: Row(children: [
                  Icon(Icons.system_update_rounded, size: 18, color: Colors.blue),
                  SizedBox(width: 12),
                  Text('Check for updates'),
                ]),
              ),
              const PopupMenuItem(
                value: 'debug',
                child: Row(children: [
                  Icon(Icons.science_outlined, size: 18, color: Colors.orange),
                  SizedBox(width: 12),
                  Text('Debug / Notifications'),
                ]),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ── Body ──────────────────────────────────────────────────────────────
      body: Column(
        children: [
          // Faixa de sincronização animada
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isSyncing
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(isDarkMode ? 0.15 : 0.08),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Syncing…',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Conteúdo principal
          Expanded(
            child: _isLoading
                ? _buildLoadingState(primary, isDarkMode)
                : RefreshIndicator(
                    onRefresh: () => _syncService.forceSync(),
                    color: primary,
                    child: _filteredTodos.isEmpty
                        ? _buildEmptyState(primary, isDarkMode)
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 8, bottom: 100),
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
                  ),
          ),
        ],
      ),

      // ── Bottom bar Cremes ─────────────────────────────────────────────────
      bottomNavigationBar: (_filterByLabel != null && _filterByLabel!.name.toLowerCase() == 'cremes')
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_box_outline_blank_rounded),
                  label: const Text('Uncheck all Cremes tasks'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Confirm'),
                        content: const Text('Uncheck all tasks with label "Cremes"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirm')),
                        ],
                      ),
                    );
                    if (confirm == true) await _uncheckAllTasksForLabel(_filterByLabel!);
                  },
                ),
              ),
            )
          : null,

      // ── FAB animado ───────────────────────────────────────────────────────
      floatingActionButton: _AnimatedFab(
        onPressed: () {
          HapticFeedback.mediumImpact();
          _showAddOrEditToDoDialog();
        },
        primary: primary,
      ),
    );
  }

  Widget _buildLoadingState(Color primary, bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            builder: (_, val, child) => Transform.scale(scale: val, child: child),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: CircularProgressIndicator(strokeWidth: 3, color: primary),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading your tasks…',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? const Color(0xFF6B6080) : const Color(0xFFAA99CC),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color primary, bool isDarkMode) {
    return ListView(
      children: [
        SizedBox(
          height: 500,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (_, val, child) =>
                  Transform.scale(scale: val, child: Opacity(opacity: val.clamp(0, 1), child: child)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: primary.withOpacity(0.15),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      size: 48,
                      color: primary.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _filterByLabel != null ? 'No tasks in this label' : 'All clear!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: isDarkMode ? const Color(0xFFEDE9FF) : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _filterByLabel != null
                        ? 'No tasks found for "${_filterByLabel!.name}"'
                        : 'Tap + to add your first task',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? const Color(0xFF6B6080) : const Color(0xFFAA99CC),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── FAB com animação pulsante ──────────────────────────────────────────────────

class _AnimatedFab extends StatefulWidget {
  final VoidCallback onPressed;
  final Color primary;

  const _AnimatedFab({required this.onPressed, required this.primary});

  @override
  State<_AnimatedFab> createState() => _AnimatedFabState();
}

class _AnimatedFabState extends State<_AnimatedFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulse,
      child: FloatingActionButton.extended(
        onPressed: widget.onPressed,
        backgroundColor: widget.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        label: const Text(
          'New Task',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
        icon: const Icon(Icons.add_rounded, size: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
