// lib/widgets/todo_task_card_widget.dart
//
// Card moderno para cada tarefa — inclui suporte completo a subtarefas:
// expand/collapse animado, barra de progresso, add/edit/delete subtarefa,
// indicador de tarefa recorrente.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo_item.dart';
import '../models/label.dart';
import '../theme/app_theme.dart';
import 'todo_subtask_row_widget.dart';

class TodoTaskCardWidget extends StatefulWidget {
  final ToDoItem todo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  // Subtask callbacks (opcionais)
  final Function(ToDoItem)? onAddSubtask;
  final Function(ToDoItem, ToDoItem)? onSubtaskStatusChanged;
  final Function(ToDoItem, ToDoItem)? onSubtaskDeleted;
  final Function(ToDoItem, ToDoItem)? onSubtaskEdit;

  const TodoTaskCardWidget({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onAddSubtask,
    this.onSubtaskStatusChanged,
    this.onSubtaskDeleted,
    this.onSubtaskEdit,
  });

  @override
  State<TodoTaskCardWidget> createState() => _TodoTaskCardWidgetState();
}

class _TodoTaskCardWidgetState extends State<TodoTaskCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkCtrl;
  late Animation<double> _checkScale;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: widget.todo.isDone ? 1.0 : 0.0,
    );
    _checkScale =
        CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut);
  }

  @override
  void didUpdateWidget(TodoTaskCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.todo.isDone != oldWidget.todo.isDone) {
      widget.todo.isDone ? _checkCtrl.forward() : _checkCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  // ── Colour helpers ──────────────────────────────────────────────────────────

  Color _parseLabelColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.accentPurple;
    }
  }

  Color get _accentColor {
    if (widget.todo.labels.isNotEmpty) {
      return _parseLabelColor(widget.todo.labels.first.color);
    }
    return AppColors.accentPurple;
  }

  Color get _priorityColor {
    if (widget.todo.dueDate == null) return AppColors.priorityLow;
    final diff = widget.todo.dueDate!.difference(DateTime.now());
    if (diff.isNegative) return AppColors.priorityHigh;
    if (diff.inHours < 24) return AppColors.priorityMedium;
    return AppColors.priorityLow;
  }

  bool get _isOverdue =>
      widget.todo.dueDate != null &&
      widget.todo.dueDate!.isBefore(DateTime.now()) &&
      !widget.todo.isDone;

  bool get _hasSubtasks => widget.todo.subtasks.isNotEmpty;

  double get _completionPct => widget.todo.completionPercentage;

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(widget.todo.id ?? widget.todo.title),
      direction: DismissDirection.endToStart,
      background: _buildDismissBackground(),
      confirmDismiss: (_) async {
        widget.onDelete();
        return false;
      },
      child: GestureDetector(
        onTap: widget.onEdit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: widget.todo.isDone
                ? AppColors.overlay05
                : AppColors.overlay08,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: widget.todo.isDone
                  ? AppColors.borderSubtle
                  : AppColors.borderCard,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildMainRow(),
              if (_hasSubtasks) _buildProgressBar(),
              if (_hasSubtasks && _isExpanded) _buildSubtaskList(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Main row ─────────────────────────────────────────────────────────────────

  Widget _buildMainRow() {
    return SizedBox(
      height: 82,
      child: Stack(
        children: [
          // Left accent bar
          if (!widget.todo.isDone)
            Positioned(
              left: 0,
              top: 16,
              bottom: 16,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _accentColor,
                      _accentColor.withOpacity(0.4),
                    ],
                  ),
                ),
              ),
            ),

          // Priority dot
          Positioned(
            right: 14,
            top: 14,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _priorityColor,
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 28, 0),
            child: Row(
              children: [
                // Expand chevron (subtarefas)
                if (_hasSubtasks)
                  GestureDetector(
                    onTap: () =>
                        setState(() => _isExpanded = !_isExpanded),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: AnimatedRotation(
                        turns: _isExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),

                // Checkbox
                GestureDetector(
                  onTap: widget.onToggle,
                  child: _AnimatedCheckbox(
                    isDone: widget.todo.isDone,
                    accentColor: _accentColor,
                    scaleAnim: _checkScale,
                  ),
                ),
                const SizedBox(width: 12),

                // Title + meta
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.todo.title,
                              style: widget.todo.isDone
                                  ? AppTextStyles.taskTitleDone
                                  : AppTextStyles.taskTitle.copyWith(
                                      color: _isOverdue
                                          ? AppColors.accentRed
                                          : AppColors.textPrimary,
                                    ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Subtask counter
                          if (_hasSubtasks) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accentPurple
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(
                                    AppRadius.badge),
                              ),
                              child: Text(
                                '${widget.todo.subtasks.where((s) => s.isDone).length}/${widget.todo.subtasks.length}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.accentPurple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          // Recurring icon
                          if (widget.todo.isRecurring) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.repeat_rounded,
                                size: 13,
                                color: AppColors.accentBlue),
                          ],
                          if (widget.todo.isRecurringInstance) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.schedule_rounded,
                                size: 13,
                                color: AppColors.accentOrange),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Label chips + time + add-subtask
                      Row(
                        children: [
                          if (widget.todo.labels.isNotEmpty)
                            _LabelChip(
                                label: widget.todo.labels.first),
                          if (widget.todo.labels.length > 1) ...[
                            const SizedBox(width: 4),
                            _LabelChip(
                              label: Label(
                                name:
                                    '+${widget.todo.labels.length - 1}',
                                color: '#8C40FF',
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Add subtask mini button
                          if (widget.onAddSubtask != null)
                            GestureDetector(
                              onTap: () =>
                                  widget.onAddSubtask!(widget.todo),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.overlay08,
                                  borderRadius:
                                      BorderRadius.circular(6),
                                  border: Border.all(
                                      color: AppColors.borderSubtle),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_rounded,
                                        size: 10,
                                        color: AppColors.textMuted),
                                    SizedBox(width: 2),
                                    Text('sub',
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          // Due time
                          if (widget.todo.dueDate != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: _isOverdue
                                      ? AppColors.accentRed
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  DateFormat('HH:mm')
                                      .format(widget.todo.dueDate!),
                                  style: AppTextStyles.timeText
                                      .copyWith(
                                    color: _isOverdue
                                        ? AppColors.accentRed
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress bar ─────────────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: _completionPct),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (ctx, value, _) => LinearProgressIndicator(
            value: value,
            minHeight: 4,
            backgroundColor: AppColors.overlay08,
            valueColor: AlwaysStoppedAnimation<Color>(
              value >= 1.0
                  ? AppColors.accentGreen
                  : AppColors.accentPurple,
            ),
          ),
        ),
      ),
    );
  }

  // ── Subtask list ──────────────────────────────────────────────────────────────

  Widget _buildSubtaskList() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          children: widget.todo.subtasks.asMap().entries.map((entry) {
            final idx = entry.key;
            final subtask = entry.value;
            return TodoSubtaskRowWidget(
              key: ValueKey(subtask.id ?? subtask.title),
              subtask: subtask,
              index: idx,
              onToggle: () =>
                  widget.onSubtaskStatusChanged?.call(widget.todo, subtask),
              onEdit: () =>
                  widget.onSubtaskEdit?.call(widget.todo, subtask),
              onDelete: () =>
                  widget.onSubtaskDeleted?.call(widget.todo, subtask),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Swipe background ─────────────────────────────────────────────────────────

  Widget _buildDismissBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.accentRed.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: AppColors.accentRed.withOpacity(0.35)),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(Icons.delete_outline_rounded,
          color: AppColors.accentRed, size: 24),
    );
  }
}

// ── Animated checkbox ─────────────────────────────────────────────────────────

class _AnimatedCheckbox extends StatelessWidget {
  final bool isDone;
  final Color accentColor;
  final Animation<double> scaleAnim;

  const _AnimatedCheckbox({
    required this.isDone,
    required this.accentColor,
    required this.scaleAnim,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: scaleAnim,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 24,
        height: 24,
        decoration: isDone
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: AppGradients.done,
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.overlay08,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
        child: isDone
            ? const Icon(Icons.check_rounded,
                size: 15, color: Colors.white)
            : null,
      ),
    );
  }
}

// ── Label chip ────────────────────────────────────────────────────────────────

class _LabelChip extends StatelessWidget {
  final Label label;
  const _LabelChip({required this.label});

  Color _parseColor() {
    try {
      return Color(int.parse(label.color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.accentPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Text(
        label.name,
        style: AppTextStyles.labelChip.copyWith(color: color),
      ),
    );
  }
}