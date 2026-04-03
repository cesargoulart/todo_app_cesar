// lib/widgets/todo_subtask_row_widget.dart
//
// Linha individual de uma subtarefa dentro do card da tarefa principal.
// Design moderno com animação de entrada slide+fade.

import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import '../theme/app_theme.dart';

class TodoSubtaskRowWidget extends StatelessWidget {
  final ToDoItem subtask;
  final int index; // usado para escalonar a animação de entrada
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TodoSubtaskRowWidget({
    super.key,
    required this.subtask,
    required this.index,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 200 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(20 * (1 - value), 0),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.overlay05,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.borderSubtle, width: 0.5),
              ),
              child: Row(
                children: [
                  // Mini checkbox
                  GestureDetector(
                    onTap: onToggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 18,
                      height: 18,
                      decoration: subtask.isDone
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              gradient: AppGradients.done,
                            )
                          : BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: AppColors.textMuted,
                                width: 1.5,
                              ),
                            ),
                      child: subtask.isDone
                          ? const Icon(Icons.check_rounded,
                              size: 11, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Title
                  Expanded(
                    child: Text(
                      subtask.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: subtask.isDone
                            ? AppColors.textMuted
                            : AppColors.textSecondary,
                        decoration: subtask.isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Edit + Delete
                  GestureDetector(
                    onTap: onEdit,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.edit_rounded,
                          size: 14, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded,
                          size: 14, color: AppColors.accentRed),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}