import 'package:flutter/material.dart';

import '../../core/settings.dart';
import '../../core/sheets.dart';
import '../chat/dictation.dart';
import 'marquee_text.dart';
import 'note_input_bar.dart';
import 'notebook_page.dart';
import 'notes.dart';

/// Color de la libreta (amarillo): la solapa de abajo, el botón del Chat y
/// los botones de la hoja para elegir carpeta.
const notebookColor = Color(0xFFC98A00);

/// Abajo de la pantalla de inicio de la Libreta (pedido del usuario: la
/// libreta pasó a ser una solapa de abajo y ya no flota): "Anotar en:
/// carpeta" (al tocarlo se elige la carpeta o se crea una), Tarea / Nota y el
/// campo para escribir o dictar.
class QuickNoteBar extends StatefulWidget {
  const QuickNoteBar({super.key, required this.settings, this.speech});

  final AppSettings settings;

  /// Para las pruebas.
  final Dictation? speech;

  @override
  State<QuickNoteBar> createState() => _QuickNoteBarState();
}

class _QuickNoteBarState extends State<QuickNoteBar> {
  AppSettings get _s => widget.settings;
  NoteFolder? _picked;
  bool _memo = false;
  String? _done;

  /// La carpeta elegida, si todavía existe; si no, la primera.
  NoteFolder? get _folder {
    final p = _picked;
    if (p != null && _s.folders.any((f) => identical(f, p))) return p;
    return _s.folders.isEmpty ? null : _s.folders.first;
  }

  Future<void> _save(String text) async {
    var f = _folder;
    if (f == null) {
      f = await _s.addFolder('General', folderColors.first);
      _picked = f;
    }
    if (_memo) {
      await _s.saveMemo(f, null, Memo(text: text.trim(), at: DateTime.now()));
      if (mounted) setState(() => _done = 'Guardé la nota en ${f!.name}.');
    } else {
      final parts = splitNotes(text);
      if (parts.isEmpty) return;
      await _s.addNotes(f, parts);
      if (mounted) {
        setState(
          () => _done = parts.length == 1
              ? 'Anoté 1 cosa en ${f!.name}.'
              : 'Anoté ${parts.length} cosas en ${f!.name}.',
        );
      }
    }
  }

  Future<void> _choose() async {
    final f = await showAppSheet<NoteFolder>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FolderChooser(settings: _s, selected: _folder),
    );
    if (f != null && mounted) setState(() => _picked = f);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: _s,
      builder: (context, _) {
        final folder = _folder;
        final folderColor = folder == null
            ? notebookColor
            : Color(folder.color);
        return Material(
          color: scheme.surfaceContainer,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      // En qué carpeta se anota; al tocarlo se cambia.
                      Expanded(
                        child: Material(
                          color: Color.alphaBlend(
                            folderColor.withValues(alpha: 0.14),
                            scheme.surface,
                          ),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: folderColor, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            key: const Key('quick-folder-now'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: _choose,
                            child: SizedBox(
                              height: 40,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.folder,
                                      color: folderColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: MarqueeText(
                                        'Anotar en: ${folder?.name ?? 'General'}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: const [
                          ButtonSegment(value: false, label: Text('Tarea')),
                          ButtonSegment(value: true, label: Text('Nota')),
                        ],
                        selected: {_memo},
                        onSelectionChanged: (v) =>
                            setState(() => _memo = v.first),
                      ),
                    ],
                  ),
                ),
                if (_done != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                    child: Text(
                      '✓ $_done',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
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
          ),
        );
      },
    );
  }
}

/// Hoja para elegir en qué carpeta se anota: las carpetas en botones parejos
/// y "Crear carpeta nueva". Devuelve la carpeta elegida.
class _FolderChooser extends StatelessWidget {
  const _FolderChooser({required this.settings, required this.selected});

  final AppSettings settings;
  final NoteFolder? selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '¿En qué carpeta anoto?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (settings.folders.isNotEmpty) ...[
            const SizedBox(height: 10),
            _FolderGrid(
              folders: settings.folders,
              selected: selected,
              onPick: (f) => Navigator.of(context).pop(f),
            ),
          ],
          const SizedBox(height: 8),
          _SheetButton(
            key: const Key('quick-new-folder'),
            label: 'Crear carpeta nueva',
            icon: Icons.create_new_folder_outlined,
            onTap: () async {
              final nav = Navigator.of(context);
              final r = await editFolder(context);
              if (r == null) return;
              final f = await settings.addFolder(r.$1, r.$2);
              nav.pop(f);
            },
          ),
        ],
      ),
    );
  }
}

/// Botón de la hoja de la libreta (alto, letra, recuadro y un fondo sutil).
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
        notebookColor.withValues(alpha: 0.12),
        scheme.surface,
      ),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: notebookColor.withValues(alpha: 0.6),
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
