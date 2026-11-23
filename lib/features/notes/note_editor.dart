import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/sheets.dart';

import '../../core/settings.dart';
import 'box_widgets.dart';
import 'boxes.dart';

/// Marca invisible al principio de cada renglón: si se borra (tecla de
/// borrar al principio), el renglón se junta con el de arriba.
const _mark = '​';

/// Controlador de un renglón: muestra el texto en mayúsculas si el renglón
/// las tiene puestas (sin cambiar lo escrito).
class _LineController extends TextEditingController {
  _LineController(String text) : super(text: '$_mark$text');

  bool upper = false;

  String get content => text.replaceAll(_mark, '');

  /// Vuelve a dibujar (al prender o apagar las mayúsculas).
  void refresh() => notifyListeners();

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (upper) {
      final up = text.toUpperCase();
      if (up.length == text.length) return TextSpan(style: style, text: up);
    }
    return super.buildTextSpan(
      context: context,
      style: style,
      withComposing: withComposing,
    );
  }
}

class _Line {
  _Line(this.style)
    : controller = _LineController(style.text),
      focus = FocusNode();

  /// Todo menos el texto (casilla, colores, tamaño…).
  NoteLine style;
  final _LineController controller;
  final FocusNode focus;

  NoteLine get value => style.copyWith(text: controller.content);

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

enum _Pop { size, color, background }

/// Editor de una nota: título y renglones. La barra de abajo pone casilla
/// para tildar, mayúsculas, subrayado, negrita, color de fondo, color de
/// letra y tamaño al renglón donde está el cursor. Se guarda mientras se
/// escribe; si queda vacía, se borra al salir.
class NoteEditor extends StatefulWidget {
  const NoteEditor({
    super.key,
    required this.settings,
    required this.note,
    this.isNew = false,
  });

  final AppSettings settings;
  final NoteBox note;

  /// Nueva: el teclado se abre en el título.
  final bool isNew;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final _title = TextEditingController(text: widget.note.name);
  final _titleFocus = FocusNode();
  final _lines = <_Line>[];

  /// El último renglón donde estuvo el cursor (a ese se le aplica la barra).
  int _current = -1;
  _Pop? _pop;
  bool _fixing = false;

  /// Pantalla siempre prendida mientras se tilda (se suelta al salir).
  static const _screen = MethodChannel('recordame/pantalla');
  bool _awake = false;

  Future<void> _setAwake(bool on) async {
    try {
      await _screen.invokeMethod('prendida', {'on': on});
    } catch (_) {
      // Sin el canal (pruebas): no pasa nada.
    }
  }

  void _toggleAwake() {
    setState(() => _awake = !_awake);
    _setAwake(_awake);
    toast(
      context,
      _awake
          ? 'La pantalla se queda prendida'
          : 'La pantalla vuelve a apagarse sola',
    );
  }

  @override
  void initState() {
    super.initState();
    for (final l in widget.note.lines) {
      _add(_lines.length, l);
    }
    if (widget.isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    if (_awake) _setAwake(false);
    _title.dispose();
    _titleFocus.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  _Line _add(int at, NoteLine style) {
    final line = _Line(style)..controller.upper = style.upper;
    line.controller.addListener(() => _changed(line));
    line.focus.addListener(() {
      if (line.focus.hasFocus) {
        final i = _lines.indexOf(line);
        if (i >= 0 && i != _current) setState(() => _current = i);
      }
    });
    _lines.insert(at, line);
    return line;
  }

  void _save() {
    widget.note
      ..name = _title.text.trim()
      ..lines = [for (final l in _lines) l.value];
    widget.settings.saveNoteBoxes();
  }

  void _focusAt(_Line line, int offset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      line.focus.requestFocus();
      line.controller.selection = TextSelection.collapsed(
        offset: offset.clamp(1, line.controller.text.length),
      );
    });
  }

  void _changed(_Line line) {
    if (_fixing) return;
    final c = line.controller;
    final text = c.text;
    final i = _lines.indexOf(line);
    if (i < 0) return;
    _fixing = true;
    try {
      if (!text.startsWith(_mark)) {
        // Se borró la marca: se junta con el de arriba.
        final content = text.replaceAll(_mark, '');
        if (i > 0) {
          final prev = _lines[i - 1];
          final join = prev.controller.text.length;
          prev.controller.text = prev.controller.text + content;
          _lines.removeAt(i);
          WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
          setState(() => _current = i - 1);
          _focusAt(prev, join);
        } else if (line.style.isCheck && content.isEmpty) {
          // En el primero, borrar al principio saca la casilla.
          c.value = const TextEditingValue(
            text: _mark,
            selection: TextSelection.collapsed(offset: 1),
          );
          setState(() => line.style = line.style.copyWith(clearCheck: true));
        } else {
          c.value = TextEditingValue(
            text: '$_mark$content',
            selection: const TextSelection.collapsed(offset: 1),
          );
        }
      } else if (text.contains('\n')) {
        // Enter: lo que sigue va a un renglón nuevo, con el mismo formato.
        final parts = text.replaceAll(_mark, '').split('\n');
        if (line.style.isCheck &&
            parts.length == 2 &&
            parts[0].isEmpty &&
            parts[1].isEmpty) {
          // Enter en una casilla vacía: deja de ser casilla.
          c.value = const TextEditingValue(
            text: _mark,
            selection: TextSelection.collapsed(offset: 1),
          );
          setState(() => line.style = line.style.copyWith(clearCheck: true));
        } else {
          c.value = TextEditingValue(
            text: '$_mark${parts.first}',
            selection: TextSelection.collapsed(offset: parts.first.length + 1),
          );
          var last = line;
          for (var k = 1; k < parts.length; k++) {
            last = _add(
              i + k,
              line.style.copyWith(
                text: parts[k],
                check: line.style.isCheck ? false : null,
              ),
            );
          }
          setState(() => _current = i + parts.length - 1);
          _focusAt(last, 1);
        }
      } else if (c.selection.isValid &&
          c.selection.isCollapsed &&
          c.selection.baseOffset == 0 &&
          !c.value.composing.isValid) {
        c.selection = const TextSelection.collapsed(offset: 1);
      }
    } finally {
      _fixing = false;
    }
    _save();
  }

  /// El renglón al que se le aplica la barra (si no hay, se crea uno).
  _Line _target() {
    if (_current >= 0 && _current < _lines.length) return _lines[_current];
    final line = _add(_lines.length, const NoteLine(''));
    _current = _lines.length - 1;
    _focusAt(line, 1);
    return line;
  }

  void _apply(NoteLine Function(NoteLine) change) {
    final line = _target();
    setState(() {
      line.style = change(line.style);
      line.controller.upper = line.style.upper;
      _pop = null;
    });
    // Para que se vuelva a dibujar con mayúsculas o sin.
    line.controller.refresh();
    _save();
    if (!line.focus.hasFocus) _focusAt(line, line.controller.text.length);
  }

  /// Tildar manda el renglón abajo de su lista de casillas (queda arriba de
  /// las ya tildadas); destildar lo sube abajo de las que faltan.
  void _toggleCheck(_Line line) {
    final done = !(line.style.check ?? false);
    final cur = _current >= 0 && _current < _lines.length
        ? _lines[_current]
        : null;
    setState(() {
      line.style = line.style.copyWith(check: done);
      final i = _lines.indexOf(line);
      var a = i;
      while (a > 0 && _lines[a - 1].style.isCheck) {
        a--;
      }
      var b = i;
      while (b + 1 < _lines.length && _lines[b + 1].style.isCheck) {
        b++;
      }
      _lines.removeAt(i);
      int to;
      if (done) {
        to = b; // al final del bloque
      } else {
        // después del último sin tildar del bloque
        to = a;
        for (var k = a; k < b; k++) {
          if (_lines[k].style.check == false) to = k + 1;
        }
      }
      _lines.insert(to, line);
      _current = cur == null ? -1 : _lines.indexOf(cur);
    });
    _save();
  }

  static String _plain(String t) => t
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .trim();

  /// Ordena de la A a la Z cada lista de casillas: primero las que faltan,
  /// después las tildadas (también de la A a la Z).
  void _sortAlpha() {
    final out = <_Line>[];
    var i = 0;
    while (i < _lines.length) {
      if (!_lines[i].style.isCheck) {
        out.add(_lines[i++]);
        continue;
      }
      final block = <_Line>[];
      while (i < _lines.length && _lines[i].style.isCheck) {
        block.add(_lines[i++]);
      }
      int cmp(_Line x, _Line y) =>
          _plain(x.controller.content).compareTo(_plain(y.controller.content));
      out.addAll([
        ...block.where((l) => l.style.check == false).toList()..sort(cmp),
        ...block.where((l) => l.style.check == true).toList()..sort(cmp),
      ]);
    }
    final cur = _current >= 0 && _current < _lines.length
        ? _lines[_current]
        : null;
    setState(() {
      _lines
        ..clear()
        ..addAll(out);
      _current = cur == null ? -1 : _lines.indexOf(cur);
    });
    _save();
    toast(context, 'Ordenadas de la A a la Z');
  }

  void _titleSubmitted() {
    final line = _lines.isEmpty ? _add(0, const NoteLine('')) : _lines.first;
    setState(() => _current = 0);
    _focusAt(line, 1);
  }

  bool get _empty =>
      _title.text.trim().isEmpty &&
      _lines.every(
        (l) => l.controller.content.trim().isEmpty && !l.style.isCheck,
      );

  void _leave() {
    _save();
    if (_empty) widget.settings.deleteNoteBox(widget.note);
  }

  /// El tacho despliega dos opciones: borrar solo las tildadas o la nota
  /// entera (esta con dos toques). Las dos dejan "Deshacer" 5 segundos.
  Future<void> _delete() async {
    final done = _lines.where((l) => l.style.check == true).length;
    final what = await showAppSheet<String>(
      context: context,
      builder: (context) {
        var sure = false;
        return StatefulBuilder(
          builder: (context, setSheet) => Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    '¿Qué querés borrar?',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                  ),
                ),
                ListTile(
                  key: const Key('note-delete-checked'),
                  enabled: done > 0,
                  leading: const Icon(Icons.playlist_remove, color: appBlue),
                  title: Text(
                    done == 0
                        ? 'Borrar solo las tildadas (no hay)'
                        : 'Borrar solo las tildadas ($done)',
                  ),
                  onTap: () => Navigator.pop(context, 'tildadas'),
                ),
                ListTile(
                  key: const Key('note-delete-all'),
                  tileColor: sure ? pendingRed : null,
                  textColor: sure ? Colors.white : null,
                  iconColor: sure ? Colors.white : pendingRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: const Icon(Icons.delete),
                  title: Text(
                    sure ? '¿Seguro? Tocá otra vez' : 'Borrar la nota entera',
                  ),
                  onTap: () {
                    if (!sure) {
                      setSheet(() => sure = true);
                      return;
                    }
                    Navigator.pop(context, 'nota');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || what == null) return;
    if (what == 'tildadas') {
      _deleteChecked();
      return;
    }
    final s = widget.settings;
    final note = widget.note;
    final messenger = ScaffoldMessenger.of(context);
    _save();
    s.deleteNoteBox(note);
    Navigator.pop(context);
    final name = note.name.isEmpty ? 'Sin título' : note.name;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Borrada: $name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        duration: const Duration(seconds: 5),
        persist: false,
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () {
            if (!s.notes.contains(note)) s.notes.add(note);
            s.saveNoteBoxes();
          },
        ),
      ),
    );
  }

  /// Saca los renglones tildados (se pueden volver a poner con Deshacer).
  void _deleteChecked() {
    final gone = [
      for (var i = 0; i < _lines.length; i++)
        if (_lines[i].style.check == true) (i, _lines[i]),
    ];
    if (gone.isEmpty) return;
    final cur = _current >= 0 && _current < _lines.length
        ? _lines[_current]
        : null;
    setState(() {
      for (final (_, l) in gone) {
        _lines.remove(l);
      }
      _current = cur == null ? -1 : _lines.indexOf(cur);
    });
    _save();
    undoToast(
      context,
      gone.length == 1
          ? 'Borrada 1 tildada'
          : 'Borradas ${gone.length} tildadas',
      onUndo: () {
        if (!mounted) {
          // Ya salió de la nota: se vuelven a poner en lo guardado.
          final lines = [...widget.note.lines];
          for (final (i, l) in gone) {
            lines.insert(i.clamp(0, lines.length), l.value);
            l.dispose();
          }
          widget.note.lines = lines;
          widget.settings.saveNoteBoxes();
          return;
        }
        setState(() {
          for (final (i, l) in gone) {
            _lines.insert(i.clamp(0, _lines.length), l);
          }
        });
        _save();
      },
      onGone: () {
        for (final (_, l) in gone) {
          l.dispose();
        }
      },
    );
  }

  TextStyle _styleOf(NoteLine s, ColorScheme scheme) {
    final checked = s.check == true;
    return TextStyle(
      fontSize: switch (s.size) {
        LineSize.chica => 13.5,
        LineSize.normal => 16.5,
        LineSize.mediana => 20,
        LineSize.grande => 25,
      },
      height: 1.45,
      fontWeight: s.bold
          ? FontWeight.w700
          : (s.size == LineSize.grande ? FontWeight.w500 : FontWeight.w400),
      decoration: TextDecoration.combine([
        if (s.underline) TextDecoration.underline,
        if (checked) TextDecoration.lineThrough,
      ]),
      color: checked
          ? const Color(0xFF777777)
          : (lineColors[s.color] ?? scheme.onSurface),
      backgroundColor: lineBackgrounds[s.background],
    );
  }

  Widget _lineRow(_Line line, ColorScheme scheme) {
    final s = line.style;
    return Row(
      key: ObjectKey(line),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.isCheck)
          GestureDetector(
            key: Key('note-check-${_lines.indexOf(line)}'),
            onTap: () => _toggleCheck(line),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 10, 6),
              child: Container(
                width: 21,
                height: 21,
                decoration: BoxDecoration(
                  color: s.check == true ? appBlue : Colors.white,
                  border: Border.all(
                    color: s.check == true ? appBlue : const Color(0xFF3B3F4E),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: s.check == true
                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                    : null,
              ),
            ),
          ),
        Expanded(
          child: TextField(
            controller: line.controller,
            focusNode: line.focus,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: _styleOf(s, scheme),
            decoration: const InputDecoration(
              border: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tool(
    String key,
    Widget child, {
    bool on = false,
    required VoidCallback tap,
    required String tip,
  }) => Tooltip(
    message: tip,
    child: Material(
      key: Key('tool-$key'),
      color: on ? const Color(0xFFD5DAEA) : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        canRequestFocus: false,
        onTap: tap,
        child: SizedBox(width: 42, height: 42, child: Center(child: child)),
      ),
    ),
  );

  Widget _popPanel(NoteLine s) {
    Widget swatch(
      String key, {
      Color? bg,
      Color? fg,
      Widget? child,
      required bool on,
      required VoidCallback tap,
    }) => GestureDetector(
      key: Key('swatch-$key'),
      onTap: tap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg ?? Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: on ? appBlue : const Color(0xFFCCCCCC),
            width: on ? 3 : 2,
          ),
        ),
        child:
            child ??
            Text(
              'A',
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
      ),
    );
    final (title, items) = switch (_pop!) {
      _Pop.size => (
        'Tamaño de letra',
        [
          for (final (z, t) in [
            (LineSize.chica, 'Chica'),
            (LineSize.normal, 'Normal'),
            (LineSize.mediana, 'Mediana'),
            (LineSize.grande, 'Grande'),
          ])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: OutlinedButton(
                  key: Key('size-${z.name}'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: s.size == z ? appLila : null,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _apply((l) => l.copyWith(size: z)),
                  child: FittedBox(
                    child: Text(
                      t,
                      style: TextStyle(
                        fontWeight: s.size == z ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      _Pop.color => (
        'Color de letra',
        [
          swatch(
            'negro',
            fg: Colors.black,
            on: s.color == null,
            tap: () => _apply((l) => l.copyWith(clearColor: true)),
          ),
          for (final e in lineColors.entries)
            swatch(
              e.key,
              fg: e.value,
              on: s.color == e.key,
              tap: () => _apply((l) => l.copyWith(color: e.key)),
            ),
        ],
      ),
      _Pop.background => (
        'Color de fondo',
        [
          swatch(
            'sin-fondo',
            child: const Icon(Icons.format_color_reset, size: 20),
            on: s.background == null,
            tap: () => _apply((l) => l.copyWith(clearBackground: true)),
          ),
          for (final e in lineBackgrounds.entries)
            swatch(
              'fondo-${e.key}',
              bg: e.value,
              child: const SizedBox.shrink(),
              on: s.background == e.key,
              tap: () => _apply((l) => l.copyWith(background: e.key)),
            ),
        ],
      ),
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF555555),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _pop == _Pop.size
              ? Row(children: items)
              : Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: items,
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cur = _current >= 0 && _current < _lines.length
        ? _lines[_current].style
        : null;
    void togglePop(_Pop p) => setState(() => _pop = _pop == p ? null : p);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _leave();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('note-back'),
                      tooltip: 'Volver',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    Expanded(
                      child: TextField(
                        key: const Key('note-title-field'),
                        controller: _title,
                        focusNode: _titleFocus,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Título',
                          filled: false,
                          border: InputBorder.none,
                        ),
                        onChanged: (_) => _save(),
                        onSubmitted: (_) => _titleSubmitted(),
                      ),
                    ),
                    IconButton(
                      key: const Key('note-awake'),
                      tooltip: 'Mantener la pantalla prendida',
                      style: _awake
                          ? IconButton.styleFrom(
                              backgroundColor: appBlue,
                              foregroundColor: Colors.white,
                            )
                          : null,
                      icon: Icon(
                        _awake ? Icons.lightbulb : Icons.lightbulb_outline,
                      ),
                      onPressed: _toggleAwake,
                    ),
                    IconButton(
                      key: const Key('note-sort'),
                      tooltip: 'Ordenar de la A a la Z',
                      icon: const Icon(Icons.sort_by_alpha),
                      onPressed: _sortAlpha,
                    ),
                    IconButton(
                      key: const Key('note-delete'),
                      tooltip: 'Borrar',
                      icon: const Icon(Icons.delete),
                      onPressed: _delete,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  // Tocar abajo de todo lleva al último renglón (o crea uno).
                  onTap: () {
                    if (_lines.isEmpty ||
                        _lines.last.controller.content.isNotEmpty ||
                        _lines.last.style.isCheck) {
                      final l = _add(_lines.length, const NoteLine(''));
                      setState(() => _current = _lines.length - 1);
                      _focusAt(l, 1);
                    } else {
                      setState(() => _current = _lines.length - 1);
                      _focusAt(_lines.last, _lines.last.controller.text.length);
                    }
                  },
                  child: ListView(
                    key: const Key('note-body'),
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 80),
                    children: [
                      if (_lines.isEmpty)
                        Text(
                          'Escribí la nota…',
                          style: TextStyle(
                            fontSize: 16.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      for (final l in _lines) _lineRow(l, scheme),
                    ],
                  ),
                ),
              ),
              if (_pop != null) _popPanel(cur ?? const NoteLine('')),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? scheme.surfaceContainer
                      : const Color(0xFFF4F5F9),
                  border: Border(top: BorderSide(color: scheme.outlineVariant)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _tool(
                      'cb',
                      const Icon(Icons.check_box_outlined),
                      on: cur?.isCheck ?? false,
                      tip: 'Casilla para tildar',
                      tap: () => _apply(
                        (l) => l.isCheck
                            ? l.copyWith(clearCheck: true)
                            : l.copyWith(check: false),
                      ),
                    ),
                    _tool(
                      'sub',
                      const Icon(Icons.format_underlined),
                      on: cur?.underline ?? false,
                      tip: 'Subrayado',
                      tap: () =>
                          _apply((l) => l.copyWith(underline: !l.underline)),
                    ),
                    _tool(
                      'neg',
                      const Text(
                        'B',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      on: cur?.bold ?? false,
                      tip: 'Negrita',
                      tap: () => _apply((l) => l.copyWith(bold: !l.bold)),
                    ),
                    _tool(
                      'fondo',
                      const Icon(Icons.format_color_fill),
                      on: _pop == _Pop.background,
                      tip: 'Color de fondo',
                      tap: () => togglePop(_Pop.background),
                    ),
                    _tool(
                      'color',
                      const Icon(Icons.format_color_text),
                      on: _pop == _Pop.color,
                      tip: 'Color de letra',
                      tap: () => togglePop(_Pop.color),
                    ),
                    _tool(
                      'tam',
                      const Icon(Icons.format_size),
                      on: _pop == _Pop.size,
                      tip: 'Tamaño',
                      tap: () => togglePop(_Pop.size),
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
