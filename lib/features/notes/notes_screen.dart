import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/settings.dart';
import '../../core/sheets.dart';
import '../home/top_bar.dart';
import 'box_widgets.dart';
import 'boxes.dart';
import 'note_editor.dart';

enum _Filter { all, folders, notes }

/// Solapa Notas: carpetas y notas mezcladas, lo último arriba. Las notas
/// pueden ir sueltas o adentro de carpetas (y las carpetas, en otras).
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, this.settings});

  /// Para las pruebas; si es null sale de [AppScope].
  final AppSettings? settings;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String? _folder;
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;

  AppSettings get _s => widget.settings ?? AppScope.of(context).settings;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  NoteBox? _find(String? id) {
    for (final n in _s.notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  void _open(String? folder) {
    setState(() {
      _folder = folder;
      _search.clear();
    });
  }

  void _up() => _open(_find(_folder)?.parent);

  Future<void> _newFolder() async {
    final r = await showNameColorSheet(context, isNew: true, folder: true);
    if (r == null) return;
    _s.notes.add(
      NoteBox(
        folder: true,
        name: r.name,
        parent: _folder,
        color: r.color,
        background: r.background,
      ),
    );
    await _s.saveNoteBoxes();
  }

  Future<void> _newNote() async {
    final n = NoteBox(folder: false, parent: _folder);
    _s.notes.add(n);
    await _s.saveNoteBoxes();
    if (mounted) await _edit(n, isNew: true);
  }

  Future<void> _edit(NoteBox n, {bool isNew = false}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NoteEditor(settings: _s, note: n, isNew: isNew),
        ),
      );

  Future<void> _gear(NoteBox n) async {
    final a = await showGearSheet(
      context,
      name: n.name,
      color: n.color,
      folder: n.folder,
      canMove: true,
      hasInside: notesInside(_s.notes, n.id).isNotEmpty,
    );
    if (!mounted || a == null) return;
    switch (a) {
      case GearAction.rename:
        final r = await showNameColorSheet(
          context,
          isNew: false,
          folder: n.folder,
          name: n.name,
          color: n.color,
          background: n.background,
        );
        if (r == null) return;
        n
          ..name = r.name
          ..color = r.color
          ..background = r.background;
        await _s.saveNoteBoxes();
      case GearAction.move:
        await _move(n);
      case GearAction.delete:
        await _s.deleteNoteBox(n);
        if (mounted) {
          toast(context, 'Borrado: ${n.name.isEmpty ? 'Sin título' : n.name}');
        }
    }
  }

  String _path(String id) {
    final parts = <String>[];
    for (NoteBox? x = _find(id); x != null; x = _find(x.parent)) {
      parts.insert(0, x.name);
    }
    return parts.join(' › ');
  }

  Future<void> _move(NoteBox n) async {
    final skip = {n.id, for (final x in notesInside(_s.notes, n.id)) x.id};
    final targets = _s.notes
        .where((x) => x.folder && !skip.contains(x.id))
        .toList();
    final picked = await showAppSheet<(String?,)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text('Mover a…', style: TextStyle(fontSize: 21)),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(
                'Notas (afuera, sola)${n.parent == null ? ' ✓' : ''}',
              ),
              onTap: () => Navigator.pop(context, (null,)),
            ),
            for (final t in targets)
              ListTile(
                leading: Icon(Icons.folder, color: boxBorder(t.color)),
                title: Text('${_path(t.id)}${n.parent == t.id ? ' ✓' : ''}'),
                onTap: () => Navigator.pop(context, (t.id,)),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    n.parent = picked.$1;
    await _s.saveNoteBoxes();
  }

  String _plainText(NoteBox n) =>
      '${n.name} ${n.lines.map((l) => l.text).join(' ')}'.toLowerCase();

  Widget _card(NoteBox n, bool searching) {
    final where = searching && n.parent != null
        ? 'en ${_find(n.parent)?.name ?? ''}'
        : null;
    if (n.folder) {
      final inside = notesInside(_s.notes, n.id);
      final notes = inside.where((x) => !x.folder).toList();
      final pending = notes.fold(0, (s, x) => s + x.pendingChecks);
      return BoxCard(
        key: Key('note-folder-${n.name}'),
        icon: Icons.folder,
        color: n.color,
        background: n.background,
        title: n.name,
        where: where,
        subfolders: _s.notes.where((x) => x.parent == n.id && x.folder).length,
        status: BoxStatus(
          pending: pending,
          allDone: notes.any((x) => x.checks > 0),
          empty: notes.isEmpty
              ? 'Vacía'
              : (notes.length == 1 ? '1 nota' : '${notes.length} notas'),
        ),
        onTap: () => _open(n.id),
        onGear: () => _gear(n),
      );
    }
    return BoxCard(
      key: Key('note-${n.name}'),
      icon: Icons.description,
      color: n.color,
      background: n.background,
      title: n.name.isEmpty ? 'Sin título' : n.name,
      preview: n.preview,
      where: where,
      status: BoxStatus(
        pending: n.pendingChecks,
        allDone: n.checks > 0,
        empty: 'Nota',
      ),
      onTap: () => _edit(n),
      onGear: () => _gear(n),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _s,
      builder: (context, _) {
        // La carpeta se pudo haber borrado.
        if (_folder != null && _find(_folder) == null) {
          _folder = null;
        }
        final folder = _find(_folder);
        final q = _search.text.trim().toLowerCase();
        var items = q.isEmpty
            ? _s.notes.where((n) => n.parent == _folder).toList()
            : _s.notes.where((n) {
                if (!_plainText(n).contains(q)) return false;
                if (_folder == null) return true;
                return notesInside(_s.notes, _folder!).contains(n);
              }).toList();
        items = switch (_filter) {
          _Filter.all => items,
          _Filter.folders => items.where((n) => n.folder).toList(),
          _Filter.notes => items.where((n) => !n.folder).toList(),
        };
        items.sort((a, b) => b.created.compareTo(a.created));
        final body = ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          children: [
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
                const SizedBox(width: 6),
                PopupMenuButton<_Filter>(
                  tooltip: 'Filtro',
                  onSelected: (f) => setState(() => _filter = f),
                  itemBuilder: (_) => [
                    for (final (f, t, i) in [
                      (_Filter.all, 'Todo', Icons.apps),
                      (_Filter.folders, 'Solo carpetas', Icons.folder_outlined),
                      (_Filter.notes, 'Solo notas', Icons.description_outlined),
                    ])
                      PopupMenuItem(
                        value: f,
                        child: Row(
                          children: [
                            Icon(i),
                            const SizedBox(width: 14),
                            Expanded(child: Text(t)),
                            if (_filter == f)
                              const Icon(Icons.check, color: appBlue),
                          ],
                        ),
                      ),
                  ],
                  child: IgnorePointer(
                    child: SquareButton(
                      key: const Key('notes-filter'),
                      icon: Icons.filter_list,
                      tooltip: 'Filtro',
                      on: _filter != _Filter.all,
                      onPressed: () {},
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                PopupMenuButton<bool>(
                  key: const Key('notes-add'),
                  tooltip: 'Nueva carpeta o nota',
                  onSelected: (folder) => folder ? _newFolder() : _newNote(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: true,
                      child: Row(
                        children: [
                          Icon(Icons.create_new_folder_outlined),
                          SizedBox(width: 14),
                          Text('Nueva carpeta'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: false,
                      child: Row(
                        children: [
                          Icon(Icons.note_add_outlined),
                          SizedBox(width: 14),
                          Text('Nueva nota'),
                        ],
                      ),
                    ),
                  ],
                  child: IgnorePointer(
                    child: SquareButton(
                      icon: Icons.add,
                      tooltip: 'Nueva carpeta o nota',
                      onPressed: () {},
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 10,
                ),
                child: Text(
                  q.isNotEmpty ? 'No hay nada con «${_search.text.trim()}».' : 'Acá no hay nada todavía.\nTocá + para crear una carpeta o una nota.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              BoxGrid(
                titles: [
                  for (final n in items) n.name.isEmpty ? 'Sin título' : n.name,
                ],
                children: [for (final n in items) _card(n, q.isNotEmpty)],
              ),
          ],
        );
        return PopScope(
          canPop: _folder == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _up();
          },
          child: Column(
            children: [
              if (folder == null)
                const MainTopBar()
              else
                FolderHeader(
                  name: folder.name,
                  color: folder.color,
                  onBack: _up,
                ),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}
