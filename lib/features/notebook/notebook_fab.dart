import 'package:flutter/material.dart';

import '../../core/settings.dart';
import '../../core/sheets.dart';
import '../chat/dictation.dart';
import 'marquee_text.dart';
import 'note_input_bar.dart';
import 'notebook_page.dart';
import 'notes.dart';

/// La libreta chiquita que flota en Almanaque, Listado y Configuración, con
/// lo pendiente. Se puede arrastrar; al tocarla se anota rápido sin salir de
/// donde uno está (pedido del usuario).
class NotebookFab extends StatelessWidget {
  const NotebookFab({super.key, required this.settings, this.speech});

  final AppSettings settings;

  /// Para las pruebas.
  final Dictation? speech;

  static const libColor = Color(0xFFC98A00);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final night = Theme.of(context).brightness == Brightness.dark;
    final fg = night ? const Color(0xFFF0C04A) : libColor;
    return Material(
      color: Color.alphaBlend(libColor.withValues(alpha: 0.16), scheme.surface),
      elevation: 6,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: fg, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        key: const Key('notebook-fab'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => showQuickNote(context, settings, speech: speech),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
          child: ListenableBuilder(
            listenable: settings,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_outlined, color: fg, size: 22),
                const SizedBox(width: 6),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Libreta',
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        height: 1.1,
                      ),
                    ),
                    ToDoBadge(notebookToDo(settings.folders), size: 11),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja para anotar rápido (maqueta `docs/maqueta-libreta-flotante.html`):
/// arriba Cancelar · rayita · Abrir libreta; `Anotar en: carpeta` a lo
/// largo; las carpetas en botones parejos; "Crear carpeta nueva"; Tarea /
/// Nota y el texto (escrito o dictado).
Future<void> showQuickNote(
  BuildContext context,
  AppSettings settings, {
  Dictation? speech,
}) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: false,
  builder: (context) => _QuickNote(settings: settings, speech: speech),
);

class _QuickNote extends StatefulWidget {
  const _QuickNote({required this.settings, this.speech});

  final AppSettings settings;
  final Dictation? speech;

  @override
  State<_QuickNote> createState() => _QuickNoteState();
}

class _QuickNoteState extends State<_QuickNote> {
  AppSettings get _s => widget.settings;
  late NoteFolder? _folder = _s.folders.isEmpty ? null : _s.folders.first;
  bool _memo = false;
  String? _done;

  Future<void> _save(String text) async {
    var f = _folder;
    if (f == null) {
      f = await _s.addFolder('General', folderColors.first);
      setState(() => _folder = f);
    }
    if (_memo) {
      await _s.saveMemo(f, null, Memo(text: text.trim(), at: DateTime.now()));
      setState(() => _done = 'Guardé la nota en ${f!.name}.');
    } else {
      final parts = splitNotes(text);
      if (parts.isEmpty) return;
      await _s.addNotes(f, parts);
      setState(
        () => _done = parts.length == 1
            ? 'Anoté 1 cosa en ${f!.name}.'
            : 'Anoté ${parts.length} cosas en ${f!.name}.',
      );
    }
  }

  Future<void> _newFolder() async {
    final r = await editFolder(context);
    if (r == null) return;
    final f = await _s.addFolder(r.$1, r.$2);
    setState(() => _folder = f);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final folder = _folder;
    final folderColor = folder == null
        ? NotebookFab.libColor
        : Color(folder.color);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Arriba: Cancelar · la rayita para bajar la hoja · Abrir libreta,
          // los dos botones iguales (pedido del usuario).
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    key: const Key('quick-cancel'),
                    label: 'Cancelar',
                    icon: Icons.close,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: _SheetButton(
                    key: const Key('quick-open-notebook'),
                    label: 'Abrir libreta',
                    icon: Icons.menu_book_outlined,
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      openNotebook(nav.context, _s);
                    },
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // En qué carpeta se anota, a lo largo.
                  Container(
                    key: const Key('quick-folder-now'),
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        folderColor.withValues(alpha: 0.14),
                        scheme.surface,
                      ),
                      border: Border.all(color: folderColor, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.folder, color: folderColor, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MarqueeText(
                            'Anotar en: ${folder?.name ?? 'General'}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_s.folders.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _FolderGrid(
                      folders: _s.folders,
                      selected: folder,
                      onPick: (f) => setState(() => _folder = f),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _SheetButton(
                    key: const Key('quick-new-folder'),
                    label: 'Crear carpeta nueva',
                    icon: Icons.create_new_folder_outlined,
                    onTap: _newFolder,
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.check_box_outlined, size: 18),
                        label: Text('Tarea'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.sticky_note_2_outlined, size: 18),
                        label: Text('Nota'),
                      ),
                    ],
                    selected: {_memo},
                    onSelectionChanged: (v) => setState(() => _memo = v.first),
                  ),
                  if (_done != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '✓ $_done',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          NoteInputBar(
            key: ValueKey(_memo),
            language: _s.language,
            speech: widget.speech,
            hint: _memo
                ? 'Escribí o dictá la nota…'
                : 'Escribí o dictá lo que tenés que hacer…',
            onSubmit: _save,
          ),
        ],
      ),
    );
  }
}

/// Botón de la hoja de la libreta: todos iguales (alto, letra, recuadro y un
/// fondo sutil), así Cancelar / Abrir libreta / Crear carpeta se ven parejos.
class _SheetButton extends StatelessWidget {
  const _SheetButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  static const height = 42.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final night = Theme.of(context).brightness == Brightness.dark;
    final fg = night ? const Color(0xFFF0C04A) : const Color(0xFF8A5E00);
    return Material(
      color: Color.alphaBlend(
        NotebookFab.libColor.withValues(alpha: 0.12),
        scheme.surface,
      ),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: NotebookFab.libColor.withValues(alpha: 0.6),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: fg,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Las carpetas en botones parejos, de a dos por renglón. Se ven hasta 6 a
/// la vez; si hay más, se desliza adentro del recuadro (pedido del usuario).
/// El nombre largo se va corriendo solo adentro del botón.
class _FolderGrid extends StatefulWidget {
  const _FolderGrid({
    required this.folders,
    required this.selected,
    required this.onPick,
  });

  final List<NoteFolder> folders;
  final NoteFolder? selected;
  final ValueChanged<NoteFolder> onPick;

  static const buttonHeight = 42.0;
  static const gap = 8.0;
  static const visibleRows = 3;

  @override
  State<_FolderGrid> createState() => _FolderGridState();
}

class _FolderGridState extends State<_FolderGrid> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const buttonHeight = _FolderGrid.buttonHeight;
    const gap = _FolderGrid.gap;
    const visibleRows = _FolderGrid.visibleRows;
    final folders = widget.folders;
    final scheme = Theme.of(context).colorScheme;
    final rows = (folders.length / 2).ceil();
    final shown = rows < visibleRows ? rows : visibleRows;
    final height = shown * buttonHeight + (shown - 1) * gap;
    final scrolls = rows > visibleRows;
    return Container(
      key: const Key('quick-folders'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SizedBox(
        height: height,
        child: Scrollbar(
          controller: _scroll,
          thumbVisibility: scrolls,
          child: GridView.builder(
            controller: _scroll,
            padding: EdgeInsets.only(right: scrolls ? 8 : 0),
            physics: scrolls
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: buttonHeight,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
            ),
            itemCount: folders.length,
            itemBuilder: (context, i) {
              final f = folders[i];
              final color = Color(f.color);
              final on = identical(f, widget.selected);
              return Material(
                color: on
                    ? Color.alphaBlend(
                        color.withValues(alpha: 0.22),
                        scheme.surface,
                      )
                    : scheme.surface,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: on ? color : scheme.outlineVariant,
                    width: on ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: InkWell(
                  key: Key('quick-folder-$i'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => widget.onPick(f),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Icon(Icons.folder, size: 18, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: MarqueeText(
                            f.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: on
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
