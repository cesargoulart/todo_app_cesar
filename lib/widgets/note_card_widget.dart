// lib/widgets/note_card_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo_item.dart';
import '../theme/app_theme.dart';

class NoteCardWidget extends StatelessWidget {
  final ToDoItem note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const NoteCardWidget({
    super.key,
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(note.id ?? note.title),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.accentRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.35)),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.accentRed, size: 24),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.overlay08,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderCard, width: 1),
          ),
          child: Stack(
            children: [
              // Left accent bar
              Positioned(
                left: 0,
                top: 16,
                bottom: 16,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.accentPurple,
                        Color(0xFF4A90D9),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row + delete button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            note.title,
                            style: AppTextStyles.taskTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _PressableDeleteButton(onDelete: onDelete),
                      ],
                    ),
                    // Body text
                    if (note.body != null && note.body!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        note.body!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Creation date
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 11, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          note.createdAt != null
                              ? DateFormat('dd MMM yyyy').format(note.createdAt!)
                              : '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PressableDeleteButton extends StatefulWidget {
  final VoidCallback onDelete;
  const _PressableDeleteButton({required this.onDelete});

  @override
  State<_PressableDeleteButton> createState() =>
      _PressableDeleteButtonState();
}

class _PressableDeleteButtonState extends State<_PressableDeleteButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onDelete,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.accentRed.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: _hovered
                ? AppColors.accentRed
                : AppColors.accentRed.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
