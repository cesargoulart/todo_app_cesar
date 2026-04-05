// lib/screens/todo_list_screen.dart
//
// Ecrã principal redesenhado com o novo visual moderno escuro.
// Toda a lógica de negócio é preservada — apenas a UI foi renovada.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/todo_item.dart';
import '../models/label.dart';
import '../services/supabase_service.dart';
import '../services/label_service.dart';
import '../services/notification_service.dart';
import '../services/auto_update_service.dart';
import '../services/database_sync_service.dart';
import '../services/deadline_monitor_service.dart';
import '../widgets/label_picker_widget.dart';
import '../theme/app_theme.dart';
import '../widgets/todo_filter_chips_widget.dart';
import '../widgets/todo_task_card_widget.dart';

class ToDoListScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeModeChanged;

  const ToDoListScreen({super.key, required this.onThemeModeChanged});

  @override
  State<ToDoListScreen> createState() => _ToDoListScreenState();
}

class _ToDoListScreenState extends State<ToDoListScreen>
    with SingleTickerProviderStateMixin {
  // ── Services ────────────────────────────────────────────────────────────────
  final TextEditingController _textFieldController = TextEditingController();
  final SupabaseService _supabaseService = SupabaseService();
  final LabelService _labelService = LabelService();
  final NotificationService _notificationService = NotificationService();
  final DatabaseSyncService _syncService = DatabaseSyncService();
  final DeadlineMonitorService _deadlineMonitor = DeadlineMonitorService();

  // ── State ───────────────────────────────────────────────────────────────────
  List<ToDoItem> _todos = [];
  List<Label> _allLabels = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  // Filters
  bool _showCompleted = false;
  bool _hideFutureTasks = true;
  bool _showOnlyTasksWithShowOnDueDate = false;
  bool _hideCremesTasks = true;
  Label? _filterByLabel;
  TodoFilter _activeFilter = TodoFilter.all;

  // Header animation
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;

  List<ToDoItem> get _filteredTodos {
    List<ToDoItem> filtered = List.from(_todos);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Tab filter
    switch (_activeFilter) {
      case TodoFilter.today:
        filtered =
            filtered.where((t) {
              if (t.dueDate == null) return false;
              final d = DateTime(
                t.dueDate!.year,
                t.dueDate!.month,
                t.dueDate!.day,
              );
              return d.isAtSameMomentAs(today);
            }).toList();
        break;
      case TodoFilter.upcoming:
        filtered =
            filtered.where((t) {
              if (t.dueDate == null) return false;
              final d = DateTime(
                t.dueDate!.year,
                t.dueDate!.month,
                t.dueDate!.day,
              );
              return d.isAfter(today);
            }).toList();
        break;
      case TodoFilter.done:
        final doneList = filtered.where((t) => t.isDone).toList();
        doneList.sort((a, b) {
          final aDate = a.completedAt;
          final bDate = b.completedAt;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
        return doneList;
      case TodoFilter.all:
        break;
    }

    // Hide completed
    if (!_showCompleted) {
      filtered = filtered.where((t) => !t.isDone).toList();
    }

    // Hide future tasks (>3 days)
    if (_hideFutureTasks) {
      final threeDays = now.add(const Duration(days: 3));
      filtered =
          filtered
              .where((t) => t.dueDate == null || t.dueDate!.isBefore(threeDays))
              .toList();
    }

    // Show only on due date
    if (_showOnlyTasksWithShowOnDueDate) {
      filtered = filtered.where((t) => t.showOnlyOnDueDate).toList();
    } else {
      filtered =
          filtered.where((t) {
            if (t.showOnlyOnDueDate && t.dueDate != null) {
              final due = DateTime(
                t.dueDate!.year,
                t.dueDate!.month,
                t.dueDate!.day,
              );
              return due.isBefore(today) || due.isAtSameMomentAs(today);
            }
            return true;
          }).toList();
    }

    // Hide Cremes
    if (_hideCremesTasks) {
      filtered =
          filtered
              .where(
                (t) => !t.labels.any((l) => l.name.toLowerCase() == 'cremes'),
              )
              .toList();
    }

    // Filter by label
    if (_filterByLabel != null) {
      filtered =
          filtered
              .where((t) => t.labels.any((l) => l.id == _filterByLabel!.id))
              .toList();
    }

    // When showing completed tasks, sort: pending first (by dueDate), then done (by completedAt desc)
    if (_showCompleted) {
      final pending = filtered.where((t) => !t.isDone).toList();
      final done = filtered.where((t) => t.isDone).toList();
      done.sort((a, b) {
        final aDate = a.completedAt;
        final bDate = b.completedAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate); // most recent first
      });
      filtered = [...pending, ...done];
    }

    return filtered;
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerCtrl.forward();
    _initializeSyncService();
    _loadAllLabels();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _deadlineMonitor.initialize(context);
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _deadlineMonitor.dispose();
    _syncService.dispose();
    _textFieldController.dispose();
    super.dispose();
  }

  // ── Init helpers ──────────────────────────────────────────────────────────────
  Future<void> _loadAllLabels() async {
    try {
      final labels = await _labelService.getAllLabels();
      if (mounted) setState(() => _allLabels = labels);
    } catch (e) {
      debugPrint('Error loading labels: $e');
    }
  }

  bool _isServiceReady() {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initializeSyncService() async {
    await _syncService.initialize(
      onDataUpdated: (todos) {
        if (mounted) {
          setState(() {
            _todos = todos;
            _isLoading = false;
          });
          _deadlineMonitor.updateTasks(_todos);
          _deadlineMonitor.startMonitoring(_todos);
        }
      },
      onSyncError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sync error: $error'),
              backgroundColor: AppColors.accentRed,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _syncService.forceSync(),
              ),
            ),
          );
        }
      },
      onSyncStatusChanged: (isSyncing) {
        if (mounted) setState(() => _isSyncing = isSyncing);
      },
    );
  }

  // ── Business logic ────────────────────────────────────────────────────────────
  Future<void> _saveTodosToStorage() async =>
      _syncService.saveTodosSafely(_todos);

  void _toggleToDoStatus(ToDoItem todo) async {
    if (!_isServiceReady()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Services initializing. Please wait.')),
      );
      return;
    }
    final originalStatus = todo.isDone;
    final originalCompletedAt = todo.completedAt;
    setState(() {
      todo.isDone = !todo.isDone;
      todo.completedAt = todo.isDone ? DateTime.now() : null;
    });
    try {
      if (todo.isDone) {
        if (todo.id != null) {
          try {
            await _notificationService.cancelTaskNotifications(todo.id!);
            _deadlineMonitor.clearTaskAlert(todo.id!);
          } catch (_) {}
        }
      } else {
        if (todo.id != null &&
            todo.dueDate != null &&
            todo.dueDate!.isAfter(DateTime.now())) {
          try {
            await _notificationService.scheduleTaskDueNotification(
              taskId: todo.id!,
              taskTitle: todo.title,
              dueDate: todo.dueDate!,
            );
          } catch (_) {}
        }
      }
      await _syncService.saveTodoSafely(todo);
    } catch (e) {
      setState(() {
        todo.isDone = originalStatus;
        todo.completedAt = originalCompletedAt;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating task: $e'),
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
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            title: const Text(
              'Delete Task',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: Text(
              'Delete "${todo.title}"?',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              if (todo.isRecurring) ...[
                TextButton(
                  child: const Text(
                    'THIS ONLY',
                    style: TextStyle(color: AppColors.accentRed),
                  ),
                  onPressed: () async {
                    if (todo.id != null) {
                      try {
                        await _notificationService.cancelTaskNotifications(
                          todo.id!,
                        );
                        _deadlineMonitor.clearTaskAlert(todo.id!);
                      } catch (_) {}
                      await _syncService.deleteTodoSafely(todo.id!);
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
                TextButton(
                  child: const Text(
                    'ALL INSTANCES',
                    style: TextStyle(color: AppColors.accentRed),
                  ),
                  onPressed: () async {
                    if (todo.id != null) {
                      await _syncService.wrapUserOperation(() async {
                        await _supabaseService.deleteRecurringTask(
                          todo.id!,
                          deleteInstances: true,
                        );
                        setState(
                          () => _todos.removeWhere(
                            (t) =>
                                t.id == todo.id ||
                                t.originalRecurringTaskId == todo.id,
                          ),
                        );
                      });
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ] else
                TextButton(
                  child: const Text(
                    'DELETE',
                    style: TextStyle(color: AppColors.accentRed),
                  ),
                  onPressed: () async {
                    if (todo.id != null) {
                      try {
                        await _notificationService.cancelTaskNotifications(
                          todo.id!,
                        );
                        _deadlineMonitor.clearTaskAlert(todo.id!);
                      } catch (_) {}
                      await _syncService.deleteTodoSafely(todo.id!);
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
            ],
          ),
    );
  }

  void _showAddOrEditToDoDialog({
    ToDoItem? existingTodo,
    bool isSubtask = false,
    ToDoItem? parentTodo,
  }) {
    final bool isEditing = existingTodo != null;
    _textFieldController.text = existingTodo?.title ?? '';
    DateTime? selectedDueDate = existingTodo?.dueDate;
    bool showOnlyOnDueDate = existingTodo?.showOnlyOnDueDate ?? false;
    bool isRecurring = existingTodo?.isRecurring ?? false;
    RecurrenceInterval recurrenceInterval =
        existingTodo?.recurrenceInterval ?? RecurrenceInterval.none;
    DateTime? recurrenceEndDate = existingTodo?.recurrenceEndDate;
    List<Label> selectedLabels = List.from(existingTodo?.labels ?? []);

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDs) => Dialog(
                  backgroundColor: AppColors.bgSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit Task' : 'New Task',
                          style: AppTextStyles.sectionLabel.copyWith(
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Title field
                        TextField(
                          controller: _textFieldController,
                          autofocus: true,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Task title…',
                            hintStyle: const TextStyle(
                              color: AppColors.textMuted,
                            ),
                            filled: true,
                            fillColor: AppColors.overlay08,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.button,
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.borderCard,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.button,
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.borderCard,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.button,
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.accentPurple,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Due date
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedDueDate == null
                                    ? 'No due date'
                                    : DateFormat(
                                      'MMM d, HH:mm',
                                    ).format(selectedDueDate!),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            TextButton(
                              child: const Text(
                                'SET DATE',
                                style: TextStyle(
                                  color: AppColors.accentPurple,
                                  fontSize: 12,
                                ),
                              ),
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      selectedDueDate ?? DateTime.now(),
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 365),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365 * 5),
                                  ),
                                );
                                if (date == null) return;
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(
                                    selectedDueDate ?? DateTime.now(),
                                  ),
                                );
                                if (time == null) return;
                                setDs(() {
                                  selectedDueDate = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                              },
                            ),
                          ],
                        ),
                        if (selectedDueDate != null)
                          _CheckRow(
                            label: 'Show only on due date',
                            value: showOnlyOnDueDate,
                            onChanged:
                                (v) => setDs(() => showOnlyOnDueDate = v),
                          ),
                        // Recurring
                        if (!isSubtask) ...[
                          const SizedBox(height: 8),
                          const Divider(color: AppColors.borderSubtle),
                          _CheckRow(
                            label: 'Recurring task',
                            value: isRecurring,
                            onChanged: (v) {
                              setDs(() {
                                isRecurring = v;
                                if (!isRecurring) {
                                  recurrenceInterval = RecurrenceInterval.none;
                                  recurrenceEndDate = null;
                                } else {
                                  if (recurrenceInterval ==
                                      RecurrenceInterval.none) {
                                    recurrenceInterval =
                                        RecurrenceInterval.weekly;
                                  }
                                  selectedDueDate ??= DateTime.now();
                                }
                              });
                            },
                          ),
                          if (isRecurring) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<RecurrenceInterval>(
                              value:
                                  recurrenceInterval == RecurrenceInterval.none
                                      ? RecurrenceInterval.weekly
                                      : recurrenceInterval,
                              dropdownColor: AppColors.bgSurface,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Repeat every',
                                labelStyle: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                                filled: true,
                                fillColor: AppColors.overlay08,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.button,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderCard,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.button,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderCard,
                                  ),
                                ),
                              ),
                              items:
                                  [
                                        RecurrenceInterval.daily,
                                        RecurrenceInterval.weekly,
                                        RecurrenceInterval.monthly,
                                        RecurrenceInterval.yearly,
                                      ]
                                      .map(
                                        (i) => DropdownMenuItem(
                                          value: i,
                                          child: Text(i.displayName),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  (v) => setDs(
                                    () =>
                                        recurrenceInterval =
                                            v ?? RecurrenceInterval.weekly,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    recurrenceEndDate == null
                                        ? 'No end date'
                                        : 'Ends: ${DateFormat('MMM d, yyyy').format(recurrenceEndDate!)}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  child: const Text(
                                    'SET END',
                                    style: TextStyle(
                                      color: AppColors.accentPurple,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onPressed: () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          recurrenceEndDate ??
                                          DateTime.now().add(
                                            const Duration(days: 365),
                                          ),
                                      firstDate:
                                          selectedDueDate ?? DateTime.now(),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365 * 10),
                                      ),
                                    );
                                    if (d != null) {
                                      setDs(() => recurrenceEndDate = d);
                                    }
                                  },
                                ),
                                if (recurrenceEndDate != null)
                                  TextButton(
                                    child: const Text(
                                      'CLEAR',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    onPressed:
                                        () => setDs(
                                          () => recurrenceEndDate = null,
                                        ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                        // Labels
                        const SizedBox(height: 8),
                        const Divider(color: AppColors.borderSubtle),
                        const SizedBox(height: 12),
                        LabelPickerWidget(
                          selectedLabels: selectedLabels,
                          onLabelsChanged:
                              (labels) => setDs(() => selectedLabels = labels),
                        ),
                        // Actions
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              child: const Text(
                                'CANCEL',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              onPressed: () {
                                _textFieldController.clear();
                                Navigator.of(context).pop();
                              },
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                gradient: AppGradients.primary,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.button,
                                ),
                              ),
                              child: TextButton(
                                child: Text(
                                  isEditing ? 'SAVE' : 'ADD',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () async {
                                  final newTitle =
                                      _textFieldController.text.trim();
                                  if (newTitle.isNotEmpty) {
                                    try {
                                      if (isEditing) {
                                        existingTodo.title = newTitle;
                                        existingTodo.dueDate = selectedDueDate;
                                        existingTodo.showOnlyOnDueDate =
                                            showOnlyOnDueDate;
                                        existingTodo.isRecurring = isRecurring;
                                        existingTodo.recurrenceInterval =
                                            isRecurring
                                                ? recurrenceInterval
                                                : RecurrenceInterval.none;
                                        existingTodo.recurrenceEndDate =
                                            recurrenceEndDate;
                                        existingTodo.labels = selectedLabels;
                                        if (isRecurring &&
                                            existingTodo.dueDate != null) {
                                          existingTodo.nextOccurrenceDate =
                                              existingTodo
                                                  .calculateNextOccurrence();
                                        } else {
                                          existingTodo.nextOccurrenceDate =
                                              null;
                                        }
                                        final updated = await _syncService
                                            .saveTodoSafely(existingTodo);
                                        await _updateTaskLabels(
                                          updated.id!,
                                          selectedLabels,
                                        );
                                        if (updated.id != null &&
                                            updated.dueDate != null) {
                                          await _notificationService
                                              .scheduleTaskDueNotification(
                                                taskId: updated.id!,
                                                taskTitle: updated.title,
                                                dueDate: updated.dueDate!,
                                              );
                                        }
                                        setState(() {
                                          final idx = _todos.indexWhere(
                                            (t) => t.id == updated.id,
                                          );
                                          if (idx != -1) {
                                            _todos[idx] = updated;
                                            _todos[idx].labels = selectedLabels;
                                          }
                                        });
                                      } else {
                                        final newTodo = ToDoItem(
                                          title: newTitle,
                                          dueDate: selectedDueDate,
                                          showOnlyOnDueDate: showOnlyOnDueDate,
                                          isRecurring: isRecurring,
                                          recurrenceInterval:
                                              isRecurring
                                                  ? recurrenceInterval
                                                  : RecurrenceInterval.none,
                                          recurrenceEndDate: recurrenceEndDate,
                                        );
                                        if (isRecurring &&
                                            newTodo.dueDate != null) {
                                          newTodo.nextOccurrenceDate =
                                              newTodo.calculateNextOccurrence();
                                        }
                                        if (isSubtask && parentTodo != null) {
                                          newTodo.parentId = parentTodo.id;
                                          final saved = await _syncService
                                              .saveTodoSafely(newTodo);
                                          setState(
                                            () => parentTodo.addSubtask(saved),
                                          );
                                        } else {
                                          final saved = await _syncService
                                              .saveTodoSafely(newTodo);
                                          await _updateTaskLabels(
                                            saved.id!,
                                            selectedLabels,
                                          );
                                          saved.labels = selectedLabels;
                                          if (saved.id != null &&
                                              saved.dueDate != null) {
                                            await _notificationService
                                                .scheduleTaskDueNotification(
                                                  taskId: saved.id!,
                                                  taskTitle: saved.title,
                                                  dueDate: saved.dueDate!,
                                                );
                                          }
                                        }
                                      }
                                    } catch (e) {
                                      debugPrint('Error saving todo: $e');
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('Error saving: $e'),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                  _textFieldController.clear();
                                  if (context.mounted)
                                    Navigator.of(context).pop();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  void _addSubtask(ToDoItem parent) =>
      _showAddOrEditToDoDialog(isSubtask: true, parentTodo: parent);

  void _toggleSubtaskStatus(ToDoItem parent, ToDoItem subtask) {
    setState(() => subtask.isDone = !subtask.isDone);
    _saveTodosToStorage();
  }

  void _deleteSubtask(ToDoItem parent, ToDoItem subtask) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.bgSurface,
            title: const Text(
              'Delete Subtask',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: Text(
              'Delete "${subtask.title}"?',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              TextButton(
                child: const Text(
                  'DELETE',
                  style: TextStyle(color: AppColors.accentRed),
                ),
                onPressed: () {
                  setState(() {
                    if (subtask.id != null) parent.removeSubtask(subtask.id!);
                  });
                  _saveTodosToStorage();
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
    );
  }

  void _editSubtask(ToDoItem parent, ToDoItem subtask) =>
      _showAddOrEditToDoDialog(
        existingTodo: subtask,
        isSubtask: true,
        parentTodo: parent,
      );

  Future<void> _uncheckAllTasksForLabel(Label label) async {
    try {
      final tasks =
          _todos
              .where((t) => t.labels.any((l) => l.id == label.id) && t.isDone)
              .toList();
      if (tasks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No completed tasks to uncheck.')),
          );
        }
        return;
      }
      await _syncService.wrapUserOperation(() async {
        for (final t in tasks) {
          t.isDone = false;
        }
        await _supabaseService.saveTodos(tasks);
      });
      await _syncService.forceSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unchecked ${tasks.length} tasks.')),
        );
      }
    } catch (e) {
      debugPrint('Error unchecking tasks: $e');
    }
  }

  Future<void> _updateTaskLabels(String taskId, List<Label> labels) async {
    try {
      final current = await _labelService.getLabelsForTask(taskId);
      for (final cl in current) {
        if (!labels.any((l) => l.id == cl.id)) {
          await _labelService.removeLabelFromTask(taskId, cl.id!);
        }
      }
      for (final l in labels) {
        if (!current.any((cl) => cl.id == l.id)) {
          await _labelService.addLabelToTask(taskId, l.id!);
        }
      }
    } catch (e) {
      debugPrint('Error updating task labels: $e');
    }
  }

  void _showDebugDialog() {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDs) {
              final s = _syncService.getStatus();
              return AlertDialog(
                backgroundColor: AppColors.bgSurface,
                title: const Text(
                  'Debug',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-sync: ${s['autoSyncActive'] ? "Active" : "Paused"}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      Text(
                        'Syncing: ${s['isSyncing'] ? "Yes" : "No"}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      Text(
                        'Tasks: ${s['currentTodosCount']}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const Divider(color: AppColors.borderSubtle),
                      ListTile(
                        textColor: AppColors.textPrimary,
                        iconColor: AppColors.accentGreen,
                        leading: const Icon(Icons.timer_outlined),
                        title: const Text('Schedule Test (10s)'),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await _notificationService.scheduleTestNotification(
                            secondsFromNow: 10,
                          );
                        },
                      ),
                      ListTile(
                        textColor: AppColors.textPrimary,
                        iconColor: AppColors.accentBlue,
                        leading: const Icon(Icons.notifications_active),
                        title: const Text('Show Immediate'),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await _notificationService.showTestNotification();
                        },
                      ),
                      ListTile(
                        textColor: AppColors.textPrimary,
                        iconColor: AppColors.accentRed,
                        leading: const Icon(Icons.delete_sweep),
                        title: const Text('Cancel All Notifications'),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await _notificationService.cancelAllNotifications();
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    child: const Text(
                      'CLOSE',
                      style: TextStyle(color: AppColors.accentPurple),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              );
            },
          ),
    );
  }

  // ── Labels drawer ────────────────────────────────────────────────────────────
  Widget _buildLabelsDrawer() {
    return Drawer(
      backgroundColor: AppColors.bgMid,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                gradient: AppGradients.header,
                border: Border(
                  bottom: BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: const Icon(
                      Icons.label_outline,
                      color: AppColors.accentPurple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Labels',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.clear_all,
                color: AppColors.textSecondary,
              ),
              title: const Text(
                'Show All',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                setState(() {
                  _filterByLabel = null;
                  _hideCremesTasks = true;
                });
                Navigator.pop(context);
              },
              selected: _filterByLabel == null,
              selectedTileColor: AppColors.overlay05,
            ),
            const Divider(color: AppColors.borderSubtle, height: 1),
            Expanded(
              child:
                  _allLabels.isEmpty
                      ? const Center(
                        child: Text(
                          'No labels yet',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _allLabels.length,
                        itemBuilder: (ctx, i) {
                          final label = _allLabels[i];
                          final isSelected = _filterByLabel?.id == label.id;
                          Color lc;
                          try {
                            lc = Color(
                              int.parse(label.color.replaceFirst('#', '0xFF')),
                            );
                          } catch (_) {
                            lc = AppColors.accentPurple;
                          }
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: lc,
                              radius: 10,
                            ),
                            title: Text(
                              label.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                if (label.name.toLowerCase() == 'cremes') {
                                  _hideCremesTasks = false;
                                }
                                _filterByLabel = isSelected ? null : label;
                              });
                              Navigator.pop(context);
                            },
                            selected: isSelected,
                            selectedTileColor: AppColors.overlay05,
                            trailing:
                                isSelected
                                    ? Icon(Icons.check, color: lc, size: 18)
                                    : null,
                          );
                        },
                      ),
            ),
            if (_filterByLabel != null &&
                _filterByLabel!.name.toLowerCase() == 'cremes')
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    icon: const Icon(
                      Icons.check_box_outline_blank,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Uncheck all Cremes',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder:
                            (ctx) => AlertDialog(
                              backgroundColor: AppColors.bgSurface,
                              title: const Text(
                                'Confirm',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                              content: const Text(
                                'Uncheck all Cremes tasks?',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('CANCEL'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                      );
                      if (ok == true) {
                        await _uncheckAllTasksForLabel(_filterByLabel!);
                        if (mounted) Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        drawer: _buildLabelsDrawer(),
        floatingActionButton: _buildFAB(),
        body: Container(
          decoration: const BoxDecoration(gradient: AppGradients.screenBg),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                if (_isSyncing) _buildSyncBanner(),
                _buildFilterChips(),
                _buildSectionHeader(),
                Expanded(child: _buildTaskList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _headerFade,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Builder(
                  builder:
                      (ctx) => GestureDetector(
                        onTap: () => Scaffold.of(ctx).openDrawer(),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.overlay08,
                            borderRadius: BorderRadius.circular(
                              AppRadius.small,
                            ),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: const Icon(
                            Icons.menu_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                ),
                const Spacer(),
                _IconAction(
                  icon:
                      _hideFutureTasks
                          ? Icons.event_available
                          : Icons.event_busy,
                  active: _hideFutureTasks,
                  onTap:
                      () =>
                          setState(() => _hideFutureTasks = !_hideFutureTasks),
                ),
                const SizedBox(width: 8),
                _IconAction(
                  icon:
                      _showOnlyTasksWithShowOnDueDate
                          ? Icons.visibility
                          : Icons.visibility_off,
                  active: _showOnlyTasksWithShowOnDueDate,
                  onTap:
                      () => setState(
                        () =>
                            _showOnlyTasksWithShowOnDueDate =
                                !_showOnlyTasksWithShowOnDueDate,
                      ),
                ),
                const SizedBox(width: 8),
                _IconAction(
                  icon: _hideCremesTasks ? Icons.spa : Icons.spa_outlined,
                  active: _hideCremesTasks,
                  onTap:
                      () =>
                          setState(() => _hideCremesTasks = !_hideCremesTasks),
                ),
                const SizedBox(width: 8),
                _IconAction(
                  icon: Icons.system_update_outlined,
                  onTap:
                      () async => await AutoUpdateService().manualUpdateCheck(),
                ),
                const SizedBox(width: 8),
            
                _IconAction(
                  icon: Icons.brightness_6_outlined,
                  onTap: () {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    widget.onThemeModeChanged(
                      isDark ? ThemeMode.light : ThemeMode.dark,
                    );
                  },
                ),
                const SizedBox(width: 8),
                _IconAction(
                  icon:
                      _showCompleted
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                  active: _showCompleted,
                  onTap: () => setState(() => _showCompleted = !_showCompleted),
                ),
                const SizedBox(width: 8),
                _IconAction(
                  icon: Icons.sync_rounded,
                  loading: _isSyncing,
                  onTap: _isSyncing ? null : () => _syncService.forceSync(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('My Tasks', style: AppTextStyles.screenTitle),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, MMM d').format(DateTime.now()),
              style: AppTextStyles.greeting,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: AppColors.accentPurple.withOpacity(0.12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.accentPurple.withOpacity(0.8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Syncing…',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: TodoFilterChipsWidget(
        selected: _activeFilter,
        onSelected: (f) => setState(() => _activeFilter = f),
      ),
    );
  }

  Widget _buildSectionHeader() {
    final count = _filteredTodos.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Text(
            _activeFilter == TodoFilter.all
                ? "Today's Tasks"
                : _activeFilter.label,
            style: AppTextStyles.sectionLabel,
          ),
          const SizedBox(width: 8),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentPurple.withOpacity(0.25),
                borderRadius: BorderRadius.circular(AppRadius.badge),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: AppColors.accentPurple,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const Spacer(),
          if (_filterByLabel != null)
            GestureDetector(
              onTap: () => setState(() => _filterByLabel = null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                ),
                child: Row(
                  children: [
                    Text(
                      _filterByLabel!.name,
                      style: const TextStyle(
                        color: AppColors.accentBlue,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: AppColors.accentBlue,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.accentPurple.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading your tasks…',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _syncService.forceSync(),
      color: AppColors.accentPurple,
      backgroundColor: AppColors.bgSurface,
      child:
          _filteredTodos.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                physics: const BouncingScrollPhysics(),
                itemCount: _filteredTodos.length,
                itemBuilder: (context, index) {
                  final todo = _filteredTodos[index];
                  return TodoTaskCardWidget(
                    key: ValueKey(todo.id ?? todo.title),
                    todo: todo,
                    onToggle: () => _toggleToDoStatus(todo),
                    onEdit: () => _showAddOrEditToDoDialog(existingTodo: todo),
                    onDelete: () => _deleteToDoItem(todo),
                    onAddSubtask: _addSubtask,
                    onSubtaskStatusChanged: _toggleSubtaskStatus,
                    onSubtaskDeleted: _deleteSubtask,
                    onSubtaskEdit: _editSubtask,
                  );
                },
              ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.35,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.accentPurple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.task_alt_rounded,
                  size: 40,
                  color: AppColors.accentPurple.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'All clear!',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap + to add a new task',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.fabGlow,
      ),
      child: FloatingActionButton(
        onPressed: () => _showAddOrEditToDoDialog(),
        tooltip: 'Add Task',
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
      ),
    );
  }
}

// ── Reusable small widgets ─────────────────────────────────────────────────────

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final bool loading;

  const _IconAction({
    required this.icon,
    this.onTap,
    this.active = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color:
              active
                  ? AppColors.accentPurple.withOpacity(0.2)
                  : AppColors.overlay08,
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(
            color: active ? AppColors.accentPurple : AppColors.borderSubtle,
          ),
        ),
        child:
            loading
                ? Padding(
                  padding: const EdgeInsets.all(9),
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.accentPurple.withOpacity(0.8),
                    ),
                  ),
                )
                : Icon(
                  icon,
                  size: 18,
                  color:
                      active ? AppColors.accentPurple : AppColors.textSecondary,
                ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppColors.accentPurple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
