import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../notebook/notes.dart';

/// Colores de los recuadros de Notas y Tareas (nombre, borde y carpetita).
/// El segundo es el del nombre (un poco más oscuro en los claros).
const boxColors = <String, (Color, Color)>{
  'verde': (Color(0xFF2E7D4F), Color(0xFF2E7D4F)),
  'amarillo': (Color(0xFFE0B000), Color(0xFF9A7500)),
  'azul': (Color(0xFF2F6DB5), Color(0xFF2F6DB5)),
  'rojo': (Color(0xFFC62828), Color(0xFFC62828)),
  'violeta': (Color(0xFF6A4FB3), Color(0xFF6A4FB3)),
  'naranja': (Color(0xFFE07B00), Color(0xFFB86400)),
  'gris': (Color(0xFF7D8296), Color(0xFF3D4152)),
};

/// Fondos de los recuadros (aparte del color).
const boxBackgrounds = <String, Color>{
  'blanco': Color(0xFFFFFFFF),
  'amarillo': Color(0xFFFBF3DC),
  'verde': Color(0xFFE0EFE6),
  'azul': Color(0xFFE3ECF7),
  'rosa': Color(0xFFFDE4EC),
  'violeta': Color(0xFFECE6F7),
  'gris': Color(0xFFF2F3F7),
};

Color boxBorder(String color) => (boxColors[color] ?? boxColors['verde']!).$1;
Color boxName(String color) => (boxColors[color] ?? boxColors['verde']!).$2;
Color boxFill(String fondo) => boxBackgrounds[fondo] ?? Colors.white;

final _rnd = Random();

/// Un id corto para carpetas, notas y tareas.
String newBoxId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
    '${_rnd.nextInt(1 << 20).toRadixString(36)}';

// ---------------------------------------------------------------------------
// Notas
// ---------------------------------------------------------------------------

/// Tamaño de letra de un renglón.
enum LineSize { chica, normal, mediana, grande }

/// Colores de letra y de fondo del editor.
const lineColors = <String, Color>{
  'rojo': Color(0xFFD32F2F),
  'azul': Color(0xFF1E63C4),
  'verde': Color(0xFF2E7D32),
  'naranja': Color(0xFFE07B00),
  'violeta': Color(0xFF6A4FB3),
};
const lineBackgrounds = <String, Color>{
  'amarillo': Color(0xFFFFE98A),
  'verde': Color(0xFFC3EFC9),
  'rosa': Color(0xFFFFD1E1),
  'celeste': Color(0xFFCFE6FF),
};

/// Un renglón de una nota. Lo que se elige en la barra del editor (casilla,
/// mayúsculas, subrayado, negrita, colores, tamaño) va al renglón entero.
class NoteLine {
  const NoteLine(
    this.text, {
    this.check,
    this.upper = false,
    this.underline = false,
    this.bold = false,
    this.size = LineSize.normal,
    this.color,
    this.background,
  });

  final String text;

  /// null: renglón común; false/true: casilla sin tildar / tildada.
  final bool? check;
  final bool upper;
  final bool underline;
  final bool bold;
  final LineSize size;
  final String? color;
  final String? background;

  bool get isCheck => check != null;
  bool get pending => check == false;

  NoteLine copyWith({
    String? text,
    bool? check,
    bool clearCheck = false,
    bool? upper,
    bool? underline,
    bool? bold,
    LineSize? size,
    String? color,
    bool clearColor = false,
    String? background,
    bool clearBackground = false,
  }) => NoteLine(
    text ?? this.text,
    check: clearCheck ? null : (check ?? this.check),
    upper: upper ?? this.upper,
    underline: underline ?? this.underline,
    bold: bold ?? this.bold,
    size: size ?? this.size,
    color: clearColor ? null : (color ?? this.color),
    background: clearBackground ? null : (background ?? this.background),
  );

  Map<String, dynamic> toJson() => {
    't': text,
    'k': ?check,
    if (upper) 'u': true,
    if (underline) 's': true,
    if (bold) 'b': true,
    if (size != LineSize.normal) 'z': size.name,
    'c': ?color,
    'f': ?background,
  };

  static NoteLine fromJson(Map<String, dynamic> j) => NoteLine(
    '${j['t'] ?? ''}',
    check: j['k'] is bool ? j['k'] as bool : null,
    upper: j['u'] == true,
    underline: j['s'] == true,
    bold: j['b'] == true,
    size: LineSize.values.asNameMap()['${j['z']}'] ?? LineSize.normal,
    color: j['c'] is String ? j['c'] as String : null,
    background: j['f'] is String ? j['f'] as String : null,
  );
}

/// Una carpeta o una nota de la solapa Notas. Las notas pueden estar sueltas
/// (afuera) o adentro de una carpeta; las carpetas, adentro de otras.
class NoteBox {
  NoteBox({
    String? id,
    required this.folder,
    this.name = '',
    this.parent,
    String? color,
    this.background = 'blanco',
    DateTime? created,
    List<NoteLine>? lines,
  }) : id = id ?? newBoxId(),
       color = color ?? (folder ? 'verde' : 'amarillo'),
       created = created ?? DateTime.now(),
       lines = lines ?? [];

  final String id;
  final bool folder;
  String name;
  String? parent;
  String color;
  String background;
  final DateTime created;
  List<NoteLine> lines;

  /// Casillas sin tildar (solo en las notas).
  int get pendingChecks => lines.where((l) => l.pending).length;
  int get checks => lines.where((l) => l.isCheck).length;

  /// Los primeros renglones, para el recuadro.
  String get preview => lines
      .map((l) => l.text.trim())
      .where((t) => t.isNotEmpty)
      .take(3)
      .join(' · ');

  /// El primer renglón escrito (para la nota sin título).
  String get firstLine => lines
      .map((l) => l.text.replaceAll('\u200B', '').trim())
      .firstWhere((t) => t.isNotEmpty, orElse: () => '');

  bool get isEmpty =>
      name.trim().isEmpty &&
      lines.every((l) => l.text.trim().isEmpty && !l.isCheck);

  Map<String, dynamic> toJson() => {
    'id': id,
    if (folder) 'carpeta': true,
    'n': name,
    'p': ?parent,
    'c': color,
    'f': background,
    'at': created.toIso8601String(),
    if (lines.isNotEmpty) 'l': [for (final l in lines) l.toJson()],
  };

  static NoteBox fromJson(Map<String, dynamic> j) => NoteBox(
    id: '${j['id']}',
    folder: j['carpeta'] == true,
    name: '${j['n'] ?? ''}',
    parent: j['p'] is String ? j['p'] as String : null,
    color: j['c'] is String ? j['c'] as String : null,
    background: j['f'] is String ? j['f'] as String : 'blanco',
    created: DateTime.tryParse('${j['at']}'),
    lines: [
      for (final e in (j['l'] as List? ?? const []))
        NoteLine.fromJson(e as Map<String, dynamic>),
    ],
  );

  static List<NoteBox> decodeAll(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    return [
      for (final e in (jsonDecode(raw) as List))
        NoteBox.fromJson(e as Map<String, dynamic>),
    ];
  }

  static String encodeAll(List<NoteBox> all) =>
      jsonEncode([for (final n in all) n.toJson()]);
}

/// Todo lo que hay adentro de una carpeta (también lo de sus subcarpetas).
List<NoteBox> notesInside(List<NoteBox> all, String id) {
  final out = <NoteBox>[];
  void walk(String p) {
    for (final n in all.where((x) => x.parent == p)) {
      out.add(n);
      if (n.folder) walk(n.id);
    }
  }

  walk(id);
  return out;
}

/// Cuántas casillas faltan en una nota o en todo lo de una carpeta.
int notePending(List<NoteBox> all, NoteBox n) => n.folder
    ? notesInside(all, n.id).fold(0, (s, x) => s + x.pendingChecks)
    : n.pendingChecks;

/// El número rojo de Notas: cuántas carpetas o notas de afuera tienen algo
/// sin tildar (no la cantidad de casillas).
int notesBadge(List<NoteBox> all) =>
    all.where((n) => n.parent == null && notePending(all, n) > 0).length;

// ---------------------------------------------------------------------------
// Tareas
// ---------------------------------------------------------------------------

/// Una carpeta de Tareas (solo afuera, sin subcarpetas).
class TaskFolder {
  TaskFolder({
    String? id,
    required this.name,
    this.color = 'verde',
    this.background = 'blanco',
    DateTime? created,
  }) : id = id ?? newBoxId(),
       created = created ?? DateTime.now();

  final String id;
  String name;
  String color;
  String background;
  final DateTime created;

  Map<String, dynamic> toJson() => {
    'id': id,
    'n': name,
    'c': color,
    'f': background,
    'at': created.toIso8601String(),
  };

  static TaskFolder fromJson(Map<String, dynamic> j) => TaskFolder(
    id: '${j['id']}',
    name: '${j['n'] ?? ''}',
    color: j['c'] is String ? j['c'] as String : 'verde',
    background: j['f'] is String ? j['f'] as String : 'blanco',
    created: DateTime.tryParse('${j['at']}'),
  );
}

/// Una tarea. "Archivar" la da por hecha y baja a Completadas.
class TaskItem {
  TaskItem({
    String? id,
    required this.name,
    required this.folder,
    this.done = false,
    this.reminderId,
    DateTime? created,
  }) : id = id ?? newBoxId(),
       created = created ?? DateTime.now();

  final String id;
  String name;
  final String folder;
  bool done;

  /// El recordatorio que la hace sonar (si se programó con la campanita).
  int? reminderId;
  final DateTime created;

  Map<String, dynamic> toJson() => {
    'id': id,
    'n': name,
    'p': folder,
    if (done) 'd': true,
    'r': ?reminderId,
    'at': created.toIso8601String(),
  };

  static TaskItem fromJson(Map<String, dynamic> j) => TaskItem(
    id: '${j['id']}',
    name: '${j['n'] ?? ''}',
    folder: '${j['p']}',
    done: j['d'] == true,
    reminderId: (j['r'] as num?)?.toInt(),
    created: DateTime.tryParse('${j['at']}'),
  );
}

/// Lo guardado de Tareas: `{"carpetas": [...], "tareas": [...]}`.
(List<TaskFolder>, List<TaskItem>) decodeTasks(String? raw) {
  if (raw == null || raw.isEmpty) return ([], []);
  final j = jsonDecode(raw) as Map<String, dynamic>;
  return (
    [
      for (final e in (j['carpetas'] as List? ?? const []))
        TaskFolder.fromJson(e as Map<String, dynamic>),
    ],
    [
      for (final e in (j['tareas'] as List? ?? const []))
        TaskItem.fromJson(e as Map<String, dynamic>),
    ],
  );
}

String encodeTasks(List<TaskFolder> folders, List<TaskItem> tasks) =>
    jsonEncode({
      'carpetas': [for (final f in folders) f.toJson()],
      'tareas': [for (final t in tasks) t.toJson()],
    });

// ---------------------------------------------------------------------------
// De la Libreta vieja a Notas y Tareas
// ---------------------------------------------------------------------------

String _colorName(int argb) => switch (argb) {
  0xFFE0A800 => 'amarillo',
  0xFF2F6FB3 => 'azul',
  0xFF2E8B57 => 'verde',
  0xFFD9534F => 'rojo',
  0xFF8E5CC2 => 'violeta',
  0xFFE67E22 => 'naranja',
  0xFF16A2B8 => 'azul',
  0xFF7F8C8D => 'gris',
  _ => 'verde',
};

/// Pasa la Libreta a Notas y Tareas sin perder nada: cada carpeta va a
/// Tareas con sus cosas; las que tenían lista adentro y las notas de texto
/// van a Notas, en una carpeta con el mismo nombre.
(List<NoteBox>, List<TaskFolder>, List<TaskItem>) migrateNotebook(
  List<NoteFolder> old,
) {
  final notes = <NoteBox>[];
  final folders = <TaskFolder>[];
  final tasks = <TaskItem>[];
  final base = DateTime.now();
  for (final (i, f) in old.indexed) {
    final color = _colorName(f.color);
    // Para que queden en el mismo orden (la primera, arriba).
    final when = base.subtract(Duration(minutes: i));
    final simple = f.items.where((n) => n.sub.isEmpty).toList();
    final lists = f.items.where((n) => n.sub.isNotEmpty).toList();
    if (simple.isNotEmpty || (lists.isEmpty && f.memos.isEmpty)) {
      final tf = TaskFolder(name: f.name, color: color, created: when);
      folders.add(tf);
      for (final n in simple) {
        tasks.add(
          TaskItem(name: n.text, folder: tf.id, done: n.done, created: n.at),
        );
      }
    }
    if (lists.isEmpty && f.memos.isEmpty) continue;
    final nf = NoteBox(folder: true, name: f.name, color: color, created: when);
    notes.add(nf);
    for (final n in lists) {
      notes.add(
        NoteBox(
          folder: false,
          name: n.text,
          parent: nf.id,
          created: n.at,
          lines: [
            for (final s in n.sub)
              NoteLine(s.text, check: n.done ? true : s.done),
          ],
        ),
      );
    }
    for (final m in f.memos) {
      notes.add(
        NoteBox(
          folder: false,
          name: m.title.trim().isEmpty ? m.heading : m.title.trim(),
          parent: nf.id,
          created: m.at,
          lines: [for (final t in m.text.split('\n')) NoteLine(t)],
        ),
      );
    }
  }
  return (notes, folders, tasks);
}

/// Lo que dice abajo el recuadro de una nota sin casillas (pedido del
/// usuario): el primer renglón escrito, para tener una idea; si la nota no
/// tiene título (ya se ve arriba), el segundo. Sin nada escrito: "Vacía".
String noteHint(NoteBox n) {
  final written = n.lines
      .map((l) => l.text.replaceAll('\u200B', '').trim())
      .where((t) => t.isNotEmpty)
      .toList();
  if (written.isEmpty) return 'Vacía';
  if (n.name.trim().isNotEmpty) return written.first;
  return written.length > 1 ? written[1] : 'Nota';
}

/// El nombre del recuadro de una nota: su título; si no tiene, lo primero
/// que dice adentro.
String boxTitle(NoteBox n) {
  if (n.name.trim().isNotEmpty) return n.name;
  final first = n.firstLine;
  return first.isEmpty ? 'Sin título' : first;
}
