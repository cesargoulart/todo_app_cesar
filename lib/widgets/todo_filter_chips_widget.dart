// lib/widgets/todo_filter_chips_widget.dart
//
// Barra de filtros horizontal: All / Today / Upcoming / Done.
// O chip activo tem um gradiente roxo→azul (igual ao Figma).
// O chip inactivo tem fundo semi-transparente com borda subtil.
// Inclui animação de escala + fade ao mudar de selecção.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum TodoFilter { all, today, upcoming, done, personal }

extension TodoFilterLabel on TodoFilter {
  String get label {
    switch (this) {
      case TodoFilter.all:      return 'All';
      case TodoFilter.today:    return 'Today';
      case TodoFilter.upcoming: return 'Upcoming';
      case TodoFilter.done:     return 'Done';
      case TodoFilter.personal: return 'Personal';
    }
  }
}

class TodoFilterChipsWidget extends StatelessWidget {
  final TodoFilter selected;
  final ValueChanged<TodoFilter> onSelected;

  const TodoFilterChipsWidget({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: TodoFilter.values.map((filter) {
          final isActive = filter == selected;
          return Padding(
            padding: EdgeInsets.only(
              right: filter == TodoFilter.values.last ? 0 : 8,
            ),
            child: _FilterChip(
              label: filter.label,
              isActive: isActive,
              onTap: () => onSelected(filter),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Single chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.93,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _ctrl.reverse();
  void _onTapUp(_) {
    _ctrl.forward();
    widget.onTap();
  }
  void _onTapCancel() => _ctrl.forward();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: widget.isActive
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  gradient: AppGradients.primary,
                )
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  color: AppColors.overlay08,
                  border: Border.all(
                    color: AppColors.borderCard,
                    width: 1,
                  ),
                ),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: widget.isActive
                ? AppTextStyles.filterChipActive
                : AppTextStyles.filterChipInactive,
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}