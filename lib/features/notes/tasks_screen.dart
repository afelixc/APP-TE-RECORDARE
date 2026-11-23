import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/formatting.dart';
import '../../core/settings.dart';
import '../../core/sheets.dart';
import '../../data/reminder.dart';
import '../../data/reminder_repository.dart';
import '../home/top_bar.dart';
import '../notebook/note_input_bar.dart';
import '../notebook/notes.dart' show splitNotes;
import 'box_widgets.dart';
import 'boxes.dart';

/// Solapa Tareas: afuera solo carpetas (la más nueva arriba); adentro, "Para
/// hacer" numerada y "Completadas" (lo archivado), con un engranaje por tarea.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, this.settings, this.reminders});

  /// Para las pruebas; si son null salen de [AppScope].
  final AppSettings? settings;
  final ReminderRepository? reminders;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String? _folder;
  final _search = TextEditingController();
  String? _open;
  String? _editing;
  bool _sureDelete = false;
  bool _sureFolder = false;
  bool _showDone = true;
  final _edit = TextEditingController();

  AppSettings get _s => widget.settings ?? AppScope.of(context).settings;
  ReminderRepository get _repo =>
      widget.reminders ?? AppScope.of(context).reminders;

  @override
  void dispose() {
    _search.dispose();
    _edit.dispose();
    super.dispose();
  }

  TaskFolder? _find(String? id) {
    for (final f in _s.taskFolders) {
      if (f.id == id) return f;
    }
    return null;
  }

  void _enter(String? id) => setState(() {
    _folder = id;
    _search.clear();
    _open = null;
    _editing = null;
    _sureFolder = false;
  });

  Future<void> _newFolder() async {
    final r = await showNameColorSheet(context, isNew: true, folder: true);
    if (r == null) return;
    _s.taskFolders.add(
      TaskFolder(name: r.name, color: r.color, background: r.background),
    );
    await _s.saveTasks();
  }

  Future<void> _rename(TaskFolder f) async {
    final r = await showNameColorSheet(
      context,
      isNew: false,
      folder: true,
      name: f.name,
      color: f.color,
      background: f.background,
    );
    if (r == null) return;
    f
      ..name = r.name
      ..color = r.color
      ..background = r.background;
    await _s.saveTasks();
  }

  /// Borra la carpeta con "Deshacer" 5 segundos. Si tiene tareas, antes
  /// pide una confirmación más. Los recordatorios de sus tareas se borran
  /// recién cuando se va el cartel sin deshacer.
  Future<bool> _deleteFolder(TaskFolder f) async {
    final count = _s.tasks.where((t) => t.folder == f.id).length;
    // Siempre un cartel en el medio, aunque esté vacía (pedido del usuario).
    final ok = await confirmFolderDelete(
      context,
      name: f.name,
      count: count,
      one: 'tarea',
      many: 'tareas',
    );
    if (!ok || !mounted) return false;
    final at = _s.taskFolders.indexOf(f);
    final gone = [
      for (var i = 0; i < _s.tasks.length; i++)
        if (_s.tasks[i].folder == f.id) (i, _s.tasks[i]),
    ];
    final rems = await _s.deleteTaskFolder(f);
    if (!mounted) return true;
    final repo = _repo;
    undoToast(
      context,
      'Borrada la carpeta: ${f.name}',
      onUndo: () {
        _s.taskFolders.insert(at.clamp(0, _s.taskFolders.length), f);
        for (final (i, t) in gone) {
          _s.tasks.insert(i.clamp(0, _s.tasks.length), t);
        }
        _s.saveTasks();
      },
      onGone: () async {
        for (final id in rems) {
          await _quiet(() => repo.delete(id));
        }
      },
    );
    return true;
  }

  Future<void> _gearFolder(TaskFolder f) async {
    final a = await showGearSheet(
      context,
      name: f.name,
      color: f.color,
      folder: true,
      canMove: false,
      hasInside: _s.tasks.any((t) => t.folder == f.id),
    );
    if (!mounted || a == null) return;
    if (a == GearAction.rename) await _rename(f);
    if (a == GearAction.delete) await _deleteFolder(f);
  }

  /// Los recordatorios pueden no estar (borrados desde el Listado).
  Future<void> _quiet(Future<void> Function() f) async {
    try {
      await f();
    } catch (_) {}
  }

  Future<void> _setDone(TaskItem t, bool done, {bool archived = false}) async {
    t.done = done;
    setState(() {
      _open = null;
      _sureDelete = false;
    });
    await _s.saveTasks();
    final id = t.reminderId;
    if (id != null) await _quiet(() => _repo.setDone(id, done));
    if (archived && mounted) {
      toast(
        context,
        done ? 'Archivada: quedó abajo, en Completadas' : 'Volvió a Para hacer',
      );
    }
  }

  Future<void> _delete(TaskItem t) async {
    if (!_sureDelete) {
      setState(() => _sureDelete = true);
      toast(context, 'Tocá otra vez el tacho para borrarla');
      return;
    }
    final at = _s.tasks.indexOf(t);
    _s.tasks.remove(t);
    setState(() {
      _open = null;
      _sureDelete = false;
    });
    await _s.saveTasks();
    if (!mounted) return;
    final id = t.reminderId;
    final repo = _repo;
    undoToast(
      context,
      'Borrada: ${t.name}',
      onUndo: () {
        _s.tasks.insert(at.clamp(0, _s.tasks.length), t);
        _s.saveTasks();
      },
      onGone: id == null ? null : () => _quiet(() => repo.delete(id)),
    );
  }

  Future<void> _saveEdit(TaskItem t) async {
    final v = _edit.text.trim();
    setState(() {
      _editing = null;
      _open = null;
    });
    if (v.isEmpty || v == t.name) return;
    t.name = v;
    await _s.saveTasks();
    final id = t.reminderId;
    if (id != null) {
      final r = await _repo.getById(id);
      if (r != null) await _repo.save(r.copyWith(title: v));
    }
  }

  Future<void> _ring(TaskItem t) async {
    final existing = t.reminderId == null
        ? null
        : await _repo.getById(t.reminderId!);
    if (!mounted) return;
    final tomorrow9 = DateTime.now().add(const Duration(days: 1));
    var at =
        existing?.dueAt ??
        DateTime(tomorrow9.year, tomorrow9.month, tomorrow9.day, 9);
    final result = await showAppSheet<(DateTime?,)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final now = DateTime.now();
          Widget quick(String label, DateTime when) => OutlinedButton(
            onPressed: () => setState(() => at = when),
            style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(label),
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '¿Qué día y hora te aviso?',
                  style: TextStyle(fontSize: 21),
                ),
                const SizedBox(height: 4),
                Text('«${t.name}»', style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    quick('En 1 hora', now.add(const Duration(hours: 1))),
                    quick(
                      'Hoy 18:00',
                      DateTime(now.year, now.month, now.day, 18),
                    ),
                    quick(
                      'Mañana 9:00',
                      DateTime(now.year, now.month, now.day + 1, 9),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 16,
                      child: OutlinedButton.icon(
                        key: const Key('ring-day'),
                        icon: const Icon(Icons.calendar_today, size: 18),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        label: Text(Fmt.shortDay(at)),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 5),
                            initialDate: at,
                          );
                          if (d != null) {
                            setState(
                              () => at = DateTime(
                                d.year,
                                d.month,
                                d.day,
                                at.hour,
                                at.minute,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 10,
                      child: OutlinedButton.icon(
                        key: const Key('ring-time'),
                        icon: const Icon(Icons.schedule, size: 18),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        label: Text(Fmt.time(at)),
                        onPressed: () async {
                          final h = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(at),
                          );
                          if (h != null) {
                            setState(
                              () => at = DateTime(
                                at.year,
                                at.month,
                                at.day,
                                h.hour,
                                h.minute,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: existing != null
                          ? OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: pendingRed,
                                minimumSize: const Size.fromHeight(46),
                              ),
                              onPressed: () => Navigator.pop(context, (null,)),
                              child: const Text('Que no suene'),
                            )
                          : OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const Key('ring-save'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                        ),
                        onPressed: () => Navigator.pop(context, (at,)),
                        child: const Text('Programar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    final when = result.$1;
    if (when == null) {
      final id = t.reminderId;
      t.reminderId = null;
      await _s.saveTasks();
      if (id != null) await _quiet(() => _repo.delete(id));
      if (mounted) toast(context, 'Ya no suena');
      return;
    }
    final saved = await _repo.save(
      existing != null
          ? existing.copyWith(title: t.name, dueAt: when, done: false)
          : Reminder(title: t.name, dueAt: when),
    );
    t.reminderId = saved.id;
    setState(() => _open = null);
    await _s.saveTasks();
    if (mounted) toast(context, 'Va a sonar ${Fmt.when(when)}');
  }

  Widget _folderCard(TaskFolder f) {
    final inside = _s.tasks.where((t) => t.folder == f.id).toList();
    final pending = inside.where((t) => !t.done).length;
    return BoxCard(
      key: Key('task-folder-${f.name}'),
      icon: Icons.folder,
      color: f.color,
      background: f.background,
      title: f.name,
      status: BoxStatus(
        pending: pending,
        allDone: inside.isNotEmpty,
        empty: inside.isEmpty ? 'Vacía' : '${inside.length} tareas',
      ),
      onTap: () => _enter(f.id),
      onGear: () => _gearFolder(f),
    );
  }

  Widget _action(
    String key,
    IconData icon,
    Color fg,
    Color border,
    Color bg,
    VoidCallback? tap,
    String tip,
  ) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: Tooltip(
      message: tip,
      child: Opacity(
        opacity: tap == null ? 0.4 : 1,
        child: Material(
          key: Key(key),
          color: bg,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: border, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: tap,
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(icon, color: fg, size: 22),
            ),
          ),
        ),
      ),
    ),
  );

  /// Abre la tarea con el texto entero (se puede cambiar ahí mismo).
  Future<void> _openTask(TaskItem t) async {
    final changed = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => TaskPage(task: t)));
    if (changed == null || changed.trim().isEmpty || changed == t.name) return;
    _edit.text = changed.trim();
    await _saveEdit(t);
  }

  Widget _row(
    TaskItem t,
    int i,
    int n,
    Map<int, Reminder> rems,
    bool searching,
  ) {
    final open = _open == t.id;
    final scheme = Theme.of(context).colorScheme;
    final r = t.reminderId == null ? null : rems[t.reminderId];
    final night = Theme.of(context).brightness == Brightness.dark;
    final text = _editing == t.id
        ? TextField(
            key: const Key('task-edit'),
            controller: _edit,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _saveEdit(t),
            onTapOutside: (_) => _saveEdit(t),
          )
        : GestureDetector(
            key: Key('task-open-${t.name}'),
            behavior: HitTestBehavior.opaque,
            // Todas del mismo alto: lo largo se corta con "…" y al tocarla
            // se abre con el texto entero (pedido del usuario).
            onTap: () => _openTask(t),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.name,
                  maxLines:
                      (r != null && !r.done && !t.done) ||
                          (searching && _folder == null)
                      ? 1
                      : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    decoration: t.done ? TextDecoration.lineThrough : null,
                    color: t.done ? const Color(0xFF888888) : scheme.onSurface,
                  ),
                ),
                if (r != null && !r.done && !t.done)
                  Row(
                    children: [
                      const Icon(
                        Icons.notifications_active,
                        size: 15,
                        color: Color(0xFFB26A00),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        Fmt.when(r.dueAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB26A00),
                        ),
                      ),
                    ],
                  ),
                if (searching && _folder == null)
                  Text(
                    'en ${_find(t.folder)?.name ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          );
    final actions = t.done
        ? [
            _action(
              'task-unarchive',
              Icons.unarchive,
              const Color(0xFF5B6585),
              const Color(0xFF9AA0B4),
              const Color(0xFFECEEF3),
              () => _setDone(t, false, archived: true),
              'Volver a Para hacer',
            ),
            _deleteButton(t),
          ]
        : [
            _action(
              'task-up',
              Icons.arrow_upward,
              const Color(0xFF4A8BD6),
              const Color(0xFF9CC0EA),
              const Color(0xFFE7F0FB),
              i == 0 ? null : () => _s.moveTask(t, -1),
              'Subir',
            ),
            _action(
              'task-down',
              Icons.arrow_downward,
              const Color(0xFF1E63C4),
              const Color(0xFF4A8BD6),
              const Color(0xFFDCE9F9),
              i == n - 1 ? null : () => _s.moveTask(t, 1),
              'Bajar',
            ),
            _action(
              'task-edit-btn',
              Icons.edit,
              const Color(0xFF2E7D32),
              const Color(0xFF4CAF50),
              const Color(0xFFE3F2E4),
              () {
                _edit.text = t.name;
                setState(() => _editing = t.id);
              },
              'Editar',
            ),
            _action(
              'task-ring',
              Icons.notifications_active,
              const Color(0xFFF08C00),
              const Color(0xFFFFB74D),
              const Color(0xFFFFF0DC),
              () => _ring(t),
              'Programar para que suene',
            ),
            _action(
              'task-archive',
              Icons.archive,
              const Color(0xFF5B6585),
              const Color(0xFF9AA0B4),
              const Color(0xFFECEEF3),
              () => _setDone(t, true, archived: true),
              'Archivar (completada)',
            ),
            _deleteButton(t),
          ];
    return Container(
      key: Key('task-${t.name}'),
      color: open
          ? (night ? const Color(0xFF353B52) : const Color(0xFFDFE3EF))
          : null,
      // La rayita de arriba no suma alto: todas miden lo mismo.
      foregroundDecoration: i == 0
          ? null
          : const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1E8C8))),
            ),
      child: Column(
        children: [
          SizedBox(
            height: taskRowHeight(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}.',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  Checkbox(
                    key: Key('task-check-${t.name}'),
                    value: t.done,
                    activeColor: appBlue,
                    onChanged: (v) => _setDone(t, v ?? false),
                  ),
                  Expanded(child: text),
                  const SizedBox(width: 6),
                  Material(
                    color: open
                        ? appBlue
                        : (night
                              ? const Color(0xFF3A4060)
                              : const Color(0xFFECECF2)),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      key: Key('task-gear-${t.name}'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() {
                        _open = open ? null : t.id;
                        _editing = null;
                        _sureDelete = false;
                      }),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.settings,
                          size: 20,
                          color: open || night ? Colors.white : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 10, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _deleteButton(TaskItem t) => _action(
    'task-delete',
    Icons.delete,
    _sureDelete ? Colors.white : const Color(0xFFC62828),
    const Color(0xFFE57373),
    _sureDelete ? const Color(0xFFC62828) : const Color(0xFFFBE4E4),
    () => _delete(t),
    'Borrar',
  );

  Widget _list(
    List<TaskItem> items,
    Map<int, Reminder> rems,
    bool searching, {
    bool done = false,
  }) => Container(
    decoration: BoxDecoration(
      border: Border.all(
        color: done ? const Color(0xFFDCDFE8) : const Color(0xFFEFE1B0),
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (final (i, t) in items.indexed)
          _row(t, i, items.length, rems, searching),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _s,
      builder: (context, _) => StreamBuilder<List<Reminder>>(
        stream: _repo.watchAll(),
        builder: (context, snap) {
          final rems = {
            for (final r in snap.data ?? const <Reminder>[]) r.id!: r,
          };
          if (_folder != null && _find(_folder) == null) _folder = null;
          final folder = _find(_folder);
          final q = _search.text.trim().toLowerCase();
          final scheme = Theme.of(context).colorScheme;
          final children = <Widget>[
            Row(
              children: [
                Expanded(
                  child: SearchPill(
                    controller: _search,
                    hint: folder == null
                        ? 'Buscar…'
                        : 'Buscar en ${folder.name}…',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (folder == null) ...[
                  const SizedBox(width: 6),
                  SquareButton(
                    key: const Key('tasks-new-folder'),
                    icon: Icons.create_new_folder_outlined,
                    tooltip: 'Carpeta nueva',
                    width: 86,
                    onPressed: _newFolder,
                  ),
                ],
              ],
            ),
          ];
          if (folder == null && q.isEmpty) {
            final fs = [..._s.taskFolders]
              ..sort((a, b) => b.created.compareTo(a.created));
            children.add(const SizedBox(height: 12));
            children.add(
              fs.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'Todavía no hay carpetas.\nTocá el botón de la carpetita para crear la primera.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : BoxGrid(
                      titles: [for (final f in fs) f.name],
                      children: [for (final f in fs) _folderCard(f)],
                    ),
            );
          } else {
            if (folder == null) {
              final fs = _s.taskFolders
                  .where((f) => f.name.toLowerCase().contains(q))
                  .toList();
              if (fs.isNotEmpty) {
                children
                  ..add(const SizedBox(height: 12))
                  ..add(
                    BoxGrid(
                      titles: [for (final f in fs) f.name],
                      children: [for (final f in fs) _folderCard(f)],
                    ),
                  );
              }
            }
            final ts = _s.tasks.where((t) {
              if (folder != null && t.folder != folder.id) return false;
              return q.isEmpty || t.name.toLowerCase().contains(q);
            }).toList();
            final pending = ts.where((t) => !t.done).toList();
            final done = ts.where((t) => t.done).toList();
            children
              ..add(const SizedBox(height: 14))
              ..add(SectionLabel('Para hacer (${pending.length})'))
              ..add(const SizedBox(height: 8))
              ..add(
                pending.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          q.isNotEmpty ? 'No hay tareas con eso.' : 'No hay nada para hacer. Escribila o dictala abajo.',
                          style: TextStyle(
                            fontSize: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : _list(pending, rems, q.isNotEmpty),
              );
            if (done.isNotEmpty) {
              children
                ..add(const SizedBox(height: 8))
                ..add(
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('tasks-show-done'),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onSurfaceVariant,
                        padding: EdgeInsets.zero,
                      ),
                      icon: Icon(
                        _showDone ? Icons.expand_less : Icons.expand_more,
                      ),
                      label: SectionLabel('Completadas (${done.length})'),
                      onPressed: () => setState(() => _showDone = !_showDone),
                    ),
                  ),
                );
              if (_showDone) {
                children.add(_list(done, rems, q.isNotEmpty, done: true));
              }
            }
          }
          return PopScope(
            canPop: _folder == null,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _enter(null);
            },
            child: Column(
              children: [
                if (folder == null)
                  const MainTopBar()
                else
                  FolderHeader(
                    name: folder.name,
                    color: folder.color,
                    onBack: () => _enter(null),
                    actions: [
                      const KeepAwakeButton(buttonKey: Key('task-awake')),
                      IconButton(
                        key: const Key('task-folder-gear'),
                        tooltip: 'Nombre y color',
                        icon: const Icon(Icons.settings),
                        onPressed: () => _rename(folder),
                      ),
                      IconButton(
                        key: const Key('task-folder-delete'),
                        tooltip: 'Borrar carpeta',
                        style: _sureFolder
                            ? IconButton.styleFrom(
                                backgroundColor: pendingRed,
                                foregroundColor: Colors.white,
                              )
                            : null,
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          if (!_sureFolder) {
                            setState(() => _sureFolder = true);
                            toast(
                              context,
                              'Tocá otra vez para borrar «${folder.name}» con todo lo de adentro',
                            );
                            return;
                          }
                          setState(() => _sureFolder = false);
                          _deleteFolder(folder).then((done) {
                            if (done && mounted) _enter(null);
                          });
                        },
                      ),
                    ],
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                    children: children,
                  ),
                ),
                if (folder != null)
                  NoteInputBar(
                    language: _s.language,
                    hint: 'Escribí o dictá tareas para hacer…',
                    onSubmit: (text) {
                      final parts = splitNotes(text);
                      if (parts.isNotEmpty) _s.addTasks(folder, parts);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Alto de cada tarea: dos renglones, igual en todas (crece un poco con la
/// letra grande del teléfono).
double taskRowHeight(BuildContext context) =>
    64 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);

/// Una tarea con el texto entero. Se puede cambiar; se guarda al volver.
class TaskPage extends StatefulWidget {
  const TaskPage({super.key, required this.task});

  final TaskItem task;

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  late final _text = TextEditingController(text: widget.task.name);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) Navigator.of(context).pop(_text.text);
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Tarea')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('task-full'),
            controller: _text,
            minLines: 3,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
              fontSize: 18,
              decoration: widget.task.done ? TextDecoration.lineThrough : null,
            ),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Text(
            widget.task.done
                ? 'Está en Completadas.'
                : 'Se guarda al volver. Para tildarla, subirla o borrarla usá '
                      'el engranaje de la lista.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
