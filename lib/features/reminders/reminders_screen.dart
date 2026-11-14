import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../data/reminder.dart';
import '../calendar/occurrences.dart';
import '../../core/palette.dart';
import 'list_colors.dart';
import 'reminder_tile.dart';

enum _Filter { pending, done, all }

/// Dentro de Pendientes: todos, los de hoy o los que ya pasaron.
enum _Pending { overdue, today, all }

/// Texto para buscar: minúsculas y sin tildes.
String _plain(String s) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const to = 'aaaaeeeeiiiioooouuuun';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString();
}

/// ¿El título tiene todas las palabras buscadas (en cualquier orden)?
bool matchesSearch(String title, String query) {
  final t = _plain(title);
  return _plain(query)
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .every(t.contains);
}

/// Un pendiente que ya pasó y no se marcó como hecho.
bool isOverdue(Reminder r, DateTime now) =>
    !r.done && !r.repeats && r.dueAt.isBefore(now);

/// Un pendiente que toca hoy (en los que se repiten, si hoy toca una vez).
bool isToday(Reminder r, DateTime now) {
  if (r.done) return false;
  final today = dayOf(now);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return occurrencesByDay([r], today, tomorrow).isNotEmpty;
}

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  _Filter _filter = _Filter.pending;
  _Pending _pending = _Pending.today;
  final _search = TextEditingController();
  String _query = '';

  /// "Elegir varios" (para borrarlos juntos): null = no se está eligiendo.
  Set<int>? _picked;

  void _togglePick(int id) => setState(() {
    final p = _picked ??= {};
    if (!p.remove(id)) p.add(id);
  });

  /// Borra los elegidos de una vez, con un solo "Deshacer".
  Future<void> _deletePicked() async {
    final ids = _picked ?? {};
    if (ids.isEmpty) return;
    final repo = AppScope.of(context).reminders;
    final messenger = ScaffoldMessenger.of(context);
    final gone = <Reminder>[];
    for (final id in ids) {
      final r = await repo.getById(id);
      if (r == null) continue;
      await repo.delete(id);
      gone.add(r);
    }
    setState(() => _picked = null);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            gone.length == 1
                ? 'Borrado: ${gone.single.title}'
                : 'Borrados: ${gone.length}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          duration: const Duration(seconds: 5),
          persist: false,
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () async {
              for (final r in gone) {
                await repo.save(r);
              }
            },
          ),
        ),
      );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  bool _matches(Reminder r, DateTime now) => switch (_filter) {
    _Filter.pending => switch (_pending) {
      _Pending.all => !r.done,
      _Pending.today => isToday(r, now),
      _Pending.overdue => isOverdue(r, now),
    },
    _Filter.done => r.done,
    _Filter.all => true,
  };

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).reminders;
    final settings = AppScope.of(context).settings;
    final night = Theme.of(context).brightness == Brightness.dark;
    final picked = _picked;
    return Scaffold(
      body: Column(
        children: [
          if (picked != null)
            _PickBar(
              count: picked.length,
              onCancel: () => setState(() => _picked = null),
              onDelete: picked.isEmpty ? null : _deletePicked,
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<_Filter>(
                  showSelectedIcon: false,
                  // Todo en un renglón, aunque la pantalla sea angosta.
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: _Filter.pending,
                      label: Text('Pendientes', maxLines: 1, softWrap: false),
                    ),
                    ButtonSegment(value: _Filter.done, label: Text('Hechos')),
                    ButtonSegment(value: _Filter.all, label: Text('Todos')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) => setState(() => _filter = s.first),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('search'),
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Buscar…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Borrar búsqueda',
                              icon: const Icon(Icons.close),
                              onPressed: _clearSearch,
                            ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('pick-many'),
                  tooltip: 'Elegir varios (para borrar)',
                  icon: const Icon(Icons.checklist_rtl),
                  onPressed: () =>
                      setState(() => _picked = _picked == null ? {} : null),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Reminder>>(
              stream: repo.watchAll(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final now = DateTime.now();
                final all = snapshot.data!
                    .where((r) => matchesSearch(r.title, _query))
                    .toList();
                var items = all.where((r) => _matches(r, now)).toList();
                // Los hechos, del más reciente al más viejo.
                if (_filter == _Filter.done) items = items.reversed.toList();
                return Column(
                  children: [
                    if (_filter == _Filter.pending)
                      _PendingChips(
                        selected: _pending,
                        counts: {
                          _Pending.all: all.where((r) => !r.done).length,
                          _Pending.today: all
                              .where((r) => isToday(r, now))
                              .length,
                          _Pending.overdue: all
                              .where((r) => isOverdue(r, now))
                              .length,
                        },
                        onSelected: (p) => setState(() => _pending = p),
                      ),
                    if (_filter == _Filter.pending &&
                        _pending == _Pending.overdue &&
                        items.isNotEmpty)
                      const _Hint(
                        'Ya pasaron y no los marcaste como hechos. Tocá '
                        '"Reprogramar" para darles una fecha nueva.',
                      ),
                    if (_filter == _Filter.all) const ListColorsBar(),
                    if (_filter == _Filter.done && items.isNotEmpty)
                      const _Hint(
                        'Para volver a activar uno, destildá el círculo o '
                        'tocalo y cambiale la fecha.',
                      ),
                    Expanded(
                      child: items.isEmpty
                          ? (_query.isNotEmpty
                                ? _NotFound(
                                    query: _query,
                                    inAll: _filter == _Filter.all,
                                    onSearchAll: () =>
                                        setState(() => _filter = _Filter.all),
                                  )
                                : _Empty(filter: _filter, pending: _pending))
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) => ListenableBuilder(
                                listenable: settings,
                                builder: (_, _) => ReminderTile(
                                  key: ValueKey(items[i].id),
                                  reminder: items[i],
                                  selected: picked?.contains(items[i].id),
                                  onSelect: () => _togglePick(items[i].id!),
                                  onLongPress: () => _togglePick(items[i].id!),
                                  // En "Todos", con los colores elegidos.
                                  tint: _filter == _Filter.all
                                      ? softColor(
                                          items[i].done
                                              ? settings
                                                    .colorsFor(night: night)
                                                    .done
                                              : settings
                                                    .colorsFor(night: night)
                                                    .pending,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Arriba, mientras se eligen varios: cuántos, Borrar y Listo.
class _PickBar extends StatelessWidget {
  const _PickBar({
    required this.count,
    required this.onCancel,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == 0
                  ? 'Tocá los que querés borrar'
                  : count == 1
                  ? '1 elegido'
                  : '$count elegidos',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          FilledButton.icon(
            key: const Key('pick-delete'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Borrar'),
            onPressed: onDelete,
          ),
          const SizedBox(width: 4),
          TextButton(
            key: const Key('pick-cancel'),
            onPressed: onCancel,
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }
}

class _PendingChips extends StatelessWidget {
  const _PendingChips({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final _Pending selected;
  final Map<_Pending, int> counts;
  final ValueChanged<_Pending> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = {
      _Pending.overdue: 'Pasados',
      _Pending.today: 'Hoy',
      _Pending.all: 'Todos',
    };
    final scheme = Theme.of(context).colorScheme;
    // Tres partes iguales: siempre entran las tres, con cualquier número.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          for (final p in _Pending.values) ...[
            if (p != _Pending.values.first) const SizedBox(width: 6),
            Expanded(
              child: Material(
                color: selected == p
                    ? (p == _Pending.overdue
                          ? scheme.errorContainer
                          : scheme.secondaryContainer)
                    : Colors.transparent,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: selected == p
                        ? Colors.transparent
                        : scheme.outlineVariant,
                  ),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onSelected(p),
                  child: SizedBox(
                    height: 34,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${labels[p]} (${counts[p] ?? 0})',
                            maxLines: 1,
                            style: TextStyle(
                              fontWeight: selected == p
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({
    required this.query,
    required this.inAll,
    required this.onSearchAll,
  });

  final String query;
  final bool inAll;
  final VoidCallback onSearchAll;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              inAll
                  ? 'No encontré nada con "$query".'
                  : 'Acá no hay nada con "$query".',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (!inAll) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const Key('search-all'),
                icon: const Icon(Icons.search),
                label: const Text('Buscar en Todos'),
                onPressed: onSearchAll,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filter, required this.pending});

  final _Filter filter;
  final _Pending pending;

  @override
  Widget build(BuildContext context) {
    final text = switch (filter) {
      _Filter.pending when pending == _Pending.today =>
        'Hoy no tenés nada pendiente.',
      _Filter.pending when pending == _Pending.overdue =>
        'No tenés recordatorios vencidos. ¡Bien ahí!',
      _Filter.pending =>
        'No tenés recordatorios pendientes.\nTocá el micrófono de arriba '
            'para cargar uno.',
      _Filter.done => 'Todavía no marcaste ninguno como hecho.',
      _Filter.all =>
        'Todavía no cargaste recordatorios.\nTocá el micrófono de arriba '
            'para empezar.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
