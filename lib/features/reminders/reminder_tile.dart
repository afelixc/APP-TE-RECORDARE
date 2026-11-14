import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/formatting.dart';
import '../../data/reminder.dart';
import '../../core/palette.dart';
import 'reminder_editor.dart';

/// Un recordatorio en una lista: marcar como hecho, editar y borrar.
class ReminderTile extends StatelessWidget {
  const ReminderTile({
    super.key,
    required this.reminder,
    this.tint,
    this.selected,
    this.onSelect,
    this.onLongPress,
  });

  final Reminder reminder;

  /// "Elegir varios": null = no se está eligiendo; si no, si está elegido.
  final bool? selected;

  /// Al tocarlo mientras se eligen varios.
  final VoidCallback? onSelect;

  /// Mantenerlo apretado empieza a elegir varios.
  final VoidCallback? onLongPress;

  /// Color de la tarjeta (en Listado → Todos, el que eligió el usuario).
  final SoftColor? tint;

  Future<void> _delete(BuildContext context) async {
    final repo = AppScope.of(context).reminders;
    final messenger = ScaffoldMessenger.of(context);
    await repo.delete(reminder.id!);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Borrado: ${reminder.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // 5 segundos para deshacer; después se va solo y queda borrado.
        duration: const Duration(seconds: 5),
        persist: false,
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => repo.save(reminder),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final night = theme.brightness == Brightness.dark;
    final repo = AppScope.of(context).reminders;
    final overdue =
        !reminder.done &&
        !reminder.repeats &&
        reminder.dueAt.isBefore(DateTime.now());
    final next = reminder.repeats ? reminder.nextOccurrence() : null;
    // Vencido: recuadro rojo grueso y fondo rosado, en Pendientes y en
    // Todos, para que se vea que hay que reprogramarlo (pedido del usuario).
    final red = night ? const Color(0xFFFF7B7B) : const Color(0xFFC62828);
    final picking = selected != null;
    final picked = selected ?? false;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: picked
          ? theme.colorScheme.primaryContainer
          : overdue
          ? Color.alphaBlend(
              red.withValues(alpha: night ? 0.16 : 0.08),
              theme.colorScheme.surface,
            )
          : tint?.fill(night),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: picked
              ? theme.colorScheme.primary
              : overdue
              ? red
              : tint?.border(night) ?? theme.colorScheme.outlineVariant,
          width: picked || overdue ? 2.5 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      // Todas las tarjetas iguales (pedido del usuario): arriba el título a
      // lo largo, en un renglón; abajo, en otro renglón, cuándo (y "vencido"),
      // "Reprogramar" si hace falta, editar y borrar.
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: picking
            ? onSelect
            : () => showReminderEditor(context, reminder: reminder),
        onLongPress: picking ? onSelect : onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 4, 2),
          child: Row(
            children: [
              if (picking)
                // Eligiendo varios: un cuadradito para elegirlo.
                Checkbox(
                  key: Key('pick-${reminder.id}'),
                  visualDensity: VisualDensity.compact,
                  value: picked,
                  onChanged: (_) => onSelect?.call(),
                )
              else
                Checkbox(
                  // En uno que se repite, tildarlo corta la repetición.
                  shape: const CircleBorder(),
                  visualDensity: VisualDensity.compact,
                  value: reminder.done,
                  onChanged: (v) => repo.setDone(reminder.id!, v ?? false),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 4),
                      child: Text(
                        reminder.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: reminder.done
                            ? TextStyle(
                                fontSize: 15,
                                decoration: TextDecoration.lineThrough,
                                color: theme.colorScheme.onSurfaceVariant,
                              )
                            : const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                      ),
                    ),
                    SizedBox(
                      height: 34,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              [
                                describeSchedule(reminder),
                                if (overdue) 'vencido',
                                if (reminder.repeats && !reminder.done)
                                  next == null
                                      ? 'sin más fechas'
                                      : 'próximo: ${Fmt.when(next)}',
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: overdue
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (overdue && !picking)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                minimumSize: const Size(0, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                textStyle: const TextStyle(fontSize: 12.5),
                              ),
                              icon: const Icon(Icons.update, size: 16),
                              label: const Text('Reprogramar'),
                              onPressed: () => showReminderEditor(
                                context,
                                reminder: reminder,
                              ),
                            ),
                          // "Reprogramar" abre lo mismo que el lápiz: en los
                          // vencidos va en su lugar, así entra la fecha.
                          if (!overdue && !picking)
                            _SmallIcon(
                              tooltip: 'Editar',
                              icon: Icons.edit_outlined,
                              onPressed: () => showReminderEditor(
                                context,
                                reminder: reminder,
                              ),
                            ),
                          if (!picking)
                            _SmallIcon(
                              tooltip: 'Borrar',
                              icon: Icons.delete_outline,
                              onPressed: () => _delete(context),
                            ),
                        ],
                      ),
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

class _SmallIcon extends StatelessWidget {
  const _SmallIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    icon: Icon(icon, size: 20),
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 34, height: 34),
    onPressed: onPressed,
  );
}
