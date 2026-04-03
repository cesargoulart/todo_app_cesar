// lib/widgets/todo_stats_bar_widget.dart
//
// Barra de estatísticas no topo do ecrã principal.
// Mostra Total / Done / Overdue com animação de fade+slide na entrada.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TodoStatsBarWidget extends StatefulWidget {
  final int total;
  final int done;
  final int overdue;

  const TodoStatsBarWidget({
    super.key,
    required this.total,
    required this.done,
    required this.overdue,
  });

  @override
  State<TodoStatsBarWidget> createState() => _TodoStatsBarWidgetState();
}

class _TodoStatsBarWidgetState extends State<TodoStatsBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Row(
          children: [
            _StatCard(
              label: 'Total',
              value: widget.total,
              dotColor: AppColors.accentPurple,
            ),
            const SizedBox(width: 12),
            _StatCard(
              label: 'Done',
              value: widget.done,
              dotColor: AppColors.accentGreen,
            ),
            const SizedBox(width: 12),
            _StatCard(
              label: 'Overdue',
              value: widget.overdue,
              dotColor: AppColors.accentRed,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single stat card ──────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color dotColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.overlay05,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderSubtle, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coloured dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 4),
            // Value
            Text(
              '$value',
              style: AppTextStyles.statValue,
            ),
            const Spacer(),
            // Label
            Text(
              label,
              style: AppTextStyles.statLabel,
            ),
          ],
        ),
      ),
    );
  }
}