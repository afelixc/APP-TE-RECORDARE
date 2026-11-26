import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../data/reminder.dart';
import '../notifications/priority_config.dart';
import '../settings/priorities_page.dart' show priorityColor;

/// Prioridad del recordatorio (Normal · Media · Alta) y "Sonar aunque esté
/// en silencio", debajo de Cancelar / Modificar.
class PriorityChooser extends StatelessWidget {
  const PriorityChooser({
    super.key,
    required this.priority,
    required this.loud,
    this.divider = true,
    required this.onPriority,
    required this.onLoud,
  });

  final ReminderPriority priority;
  final bool loud;

  /// La rayita de arriba (en la tarjeta del Chat).
  final bool divider;
  final ValueChanged<ReminderPriority> onPriority;
  final ValueChanged<bool> onLoud;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final config =
        AppScope.of(context).notifications?.priorities ??
        const PriorityConfig();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (divider) const Divider(height: 14),
        // "PRIORIDAD" y los tres puntitos: el elegido se agranda y queda
        // marcado en negro (pedido del usuario).
        Row(
          children: [
            Text(
              'PRIORIDAD',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            for (final p in ReminderPriority.values)
              PriorityDot(
                key: Key('priority-${p.name}'),
                label: p.label,
                color: priorityColor(p),
                selected: priority == p,
                onTap: () => onPriority(p),
              ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '${priority.label}: ${config.sentence(priority.index)}',
            maxLines: 1,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        InkWell(
          key: const Key('priority-loud'),
          onTap: () => onLoud(!loud),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: Checkbox(
                  value: loud,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) => onLoud(v ?? false),
                ),
              ),
              const Icon(Icons.notifications_off_outlined, size: 16),
              const SizedBox(width: 4),
              // En un solo renglón, a la altura de la casilla (pedido del
              // usuario): si no entra, se achica la letra.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sonar aunque esté en silencio',
                    maxLines: 1,
                    softWrap: false,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Un puntito de prioridad. Elegido: más grande y con un anillo negro.
class PriorityDot extends StatelessWidget {
  const PriorityDot({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1D1D23);
    final size = selected ? 32.0 : 24.0;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Prioridad ${label.toLowerCase()}',
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 46,
          height: 42,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: selected ? Border.all(color: ring, width: 3) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
