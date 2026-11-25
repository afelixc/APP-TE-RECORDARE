import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/formatting.dart';
import '../../core/sheets.dart';
import '../../data/reminder.dart';
import '../notifications/reminder_actions.dart';
import '../notifications/snooze_options.dart';
import '../reminders/reminders_screen.dart' show isOverdue;

/// Los que ya pasaron y nunca se respondieron (Hecho, 1 hora o Mañana),
/// el más viejo primero.
List<Reminder> missedReminders(List<Reminder> all, DateTime now) =>
    all.where((r) => isOverdue(r, now)).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

Color _red(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFFF7B7B)
    : const Color(0xFFC62828);

Color _pink(BuildContext context) {
  final theme = Theme.of(context);
  final night = theme.brightness == Brightness.dark;
  return Color.alphaBlend(
    _red(context).withValues(alpha: night ? 0.16 : 0.08),
    theme.colorScheme.surface,
  );
}

/// Cartelito rojo de Mensaje: "Te quedaron N sin responder". Está mientras
/// quede alguno; al tocarlo se abre la lista para decidir cada uno
/// (pedido del usuario: que no se pase nunca ninguno).
class MissedBanner extends StatelessWidget {
  const MissedBanner({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).reminders;
    return StreamBuilder<List<Reminder>>(
      stream: repo.watchAll(),
      builder: (context, snap) {
        final missed = missedReminders(snap.data ?? const [], DateTime.now());
        if (missed.isEmpty) return const SizedBox.shrink();
        final red = _red(context);
        final n = missed.length;
        return Padding(
          padding: padding,
          child: Material(
            color: _pink(context),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: red, width: 2.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              key: const Key('missed-banner'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => showMissedSheet(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    Icon(Icons.notification_important, color: red, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              n == 1
                                  ? 'Te quedó 1 sin responder'
                                  : 'Te quedaron $n sin responder',
                              maxLines: 1,
                              style: TextStyle(
                                color: red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            n == 1
                                ? missed.first.title
                                : 'Tocá para verlos y decidir',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: red),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Hoja con los que quedaron sin responder: cada uno con Hecho · 1 hora ·
/// Mañana. Al responder se va de la lista; con el último se cierra sola.
Future<void> showMissedSheet(BuildContext context) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => const _MissedSheet(),
);

class _MissedSheet extends StatelessWidget {
  const _MissedSheet();

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).reminders;
    final actions = ReminderActions(repo);
    final messenger = ScaffoldMessenger.of(context);
    return StreamBuilder<List<Reminder>>(
      stream: repo.watchAll(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox(height: 120);
        final missed = missedReminders(snap.data!, DateTime.now());
        if (missed.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
          return const SizedBox(height: 120);
        }
        final red = _red(context);
        Future<void> answer(Reminder r, String done) async {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(content: Text('$done: ${r.title}', maxLines: 1)),
          );
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  missed.length == 1
                      ? 'Te quedó 1 sin responder'
                      : 'Te quedaron ${missed.length} sin responder',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: red,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  'Ya pasó la hora y no tocaste nada. ¿Qué hacemos?',
                  textAlign: TextAlign.center,
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: missed.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = missed[i];
                    return _MissedCard(
                      key: Key('missed-${r.id}'),
                      reminder: r,
                      onDone: () async {
                        await actions.markDone(r.id!);
                        await answer(r, 'Hecho ✓');
                      },
                      onSnooze: (o) async {
                        final at = await actions.snooze(r.id!, o);
                        if (at != null) {
                          await answer(r, 'Te aviso ${Fmt.when(at)}');
                        }
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    key: const Key('missed-later'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Ver después', maxLines: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MissedCard extends StatelessWidget {
  const _MissedCard({
    super.key,
    required this.reminder,
    required this.onDone,
    required this.onSnooze,
  });

  final Reminder reminder;
  final VoidCallback onDone;
  final ValueChanged<SnoozeOption> onSnooze;

  @override
  Widget build(BuildContext context) {
    final red = _red(context);
    final green = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF6FCF97)
        : const Color(0xFF2E7D32);
    Widget label(String t) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(t, maxLines: 1, softWrap: false),
    );
    final options = snoozeOptions.where((o) => o.showInNotification);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _pink(context),
        border: Border.all(color: red, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            reminder.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            'Era ${Fmt.when(reminder.dueAt)}',
            style: TextStyle(color: red, fontSize: 13.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: FilledButton(
                    key: Key('missed-done-${reminder.id}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: onDone,
                    child: label('Hecho'),
                  ),
                ),
              ),
              for (final o in options) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton(
                      key: Key('missed-${o.id}-${reminder.id}'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      onPressed: () => onSnooze(o),
                      child: label(o.label),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
