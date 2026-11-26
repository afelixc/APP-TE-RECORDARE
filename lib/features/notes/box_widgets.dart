import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/fit.dart';
import '../../core/sheets.dart';
import 'boxes.dart';

/// Azul de la app en la maqueta (barra de arriba, botones).
const appBlue = Color(0xFF2C3A66);
const appLila = Color(0xFFDFE3F5);
const pendingRed = Color(0xFFD32F2F);
const doneGreen = Color(0xFF2E8B57);

bool _night(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// "1 pendiente" / "5 pendientes".
String pendingLabel(int n) => n == 1 ? '1 pendiente' : '$n pendientes';

/// Lo que dice abajo cada recuadro: "N pendientes" en rojo sobre rosa,
/// "Todo hecho ✓" en verde o un texto gris ("Nota", "Vacía", "3 tareas").
class BoxStatus extends StatelessWidget {
  const BoxStatus({
    super.key,
    required this.pending,
    required this.allDone,
    required this.empty,
  });

  final int pending;
  final bool allDone;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (pending > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(
          color: _night(context)
              ? const Color(0xFF5A2630)
              : const Color(0xFFFDE0E6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          pendingLabel(pending),
          maxLines: 1,
          style: TextStyle(
            color: _night(context) ? const Color(0xFFFF8A80) : pendingRed,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    if (allDone) {
      return const Text(
        'Todo hecho ✓',
        maxLines: 1,
        style: TextStyle(
          color: doneGreen,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Text(
      empty,
      maxLines: 1,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 13,
      ),
    );
  }
}

/// Recuadro de una carpeta o una nota, chico (pedido del usuario): el
/// dibujo, el nombre en un renglón y el engranaje arriba; abajo lo que falta
/// ("2 pendientes") o "Nota" / "Vacía". Las carpetas llevan una pestañita
/// arriba y el fondo de su color; las notas, una franja gruesa a la
/// izquierda, como una hoja: así no se confunden.
class BoxCard extends StatelessWidget {
  const BoxCard({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.status,
    required this.onTap,
    required this.onGear,
    this.isFolder = false,
    this.where,
    this.subfolders = 0,
    this.gearKey,
  });

  final IconData icon;
  final String color;
  final String background;
  final String title;
  final bool isFolder;

  /// En la búsqueda: "en Casa".
  final String? where;
  final int subfolders;
  final Widget status;
  final VoidCallback onTap;
  final VoidCallback onGear;
  final Key? gearKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final night = _night(context);
    final border = boxBorder(color);
    final name = night ? border : boxName(color);
    final base = night
        ? (background == 'blanco'
              ? scheme.surfaceContainer
              : Color.alphaBlend(
                  boxFill(background).withValues(alpha: 0.18),
                  scheme.surfaceContainer,
                ))
        : boxFill(background);
    // La carpeta con un toque de su color encima del fondo elegido.
    final fill = isFolder
        ? Color.alphaBlend(border.withValues(alpha: night ? 0.16 : 0.10), base)
        : base;
    final height = boxCardHeight(context);
    final card = Material(
      color: fill,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: border, width: 2),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isFolder ? 4 : 12),
          topRight: const Radius.circular(12),
          bottomLeft: const Radius.circular(12),
          bottomRight: const Radius.circular(12),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // La nota: franja gruesa a la izquierda.
              if (!isFolder) Container(width: 6, color: border),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(isFolder ? 10 : 8, 6, 0, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 20, color: border),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: name,
                                fontWeight: isFolder
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: BoxNameSize.of(context),
                                height: 1.2,
                              ),
                            ),
                          ),
                          InkWell(
                            key: gearKey,
                            onTap: onGear,
                            customBorder: const CircleBorder(),
                            child: Tooltip(
                              message: 'Ajustes',
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                child: Icon(
                                  Icons.settings,
                                  size: 20,
                                  color: border,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Lo que falta, siempre abajo y alineado.
                      SizedBox(
                        height: 20,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (subfolders > 0) ...[
                                  Icon(
                                    Icons.folder_copy_outlined,
                                    size: 15,
                                    color: border,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$subfolders  ',
                                    style: TextStyle(
                                      color: border,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                status,
                                if (where != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    where!,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!isFolder) {
      return Padding(padding: const EdgeInsets.only(top: _tab), child: card);
    }
    // La carpeta: pestañita arriba a la izquierda, como una carpeta de verdad.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: _tab,
          margin: const EdgeInsets.only(left: 0),
          decoration: BoxDecoration(
            color: border,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
        ),
        card,
      ],
    );
  }
}

const double _tab = 6;

/// Alto de cada recuadro (sin la pestañita): un renglón de nombre y uno de
/// lo que falta, sin espacio de más.
double boxCardHeight(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<BoxNameSize>()?.height ?? 64;

double _cardHeight(BuildContext context, double nameSize) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  final line = nameSize * 1.2 * scale;
  return 6 + (line > 24 ? line : 24) + 4 + 20 + 6;
}

/// La letra del nombre y el alto de los recuadros: lo mismo en todos.
class BoxNameSize extends InheritedWidget {
  const BoxNameSize({
    super.key,
    required this.size,
    required this.height,
    required super.child,
  });

  final double size;
  final double height;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BoxNameSize>()?.size ?? 16;

  @override
  bool updateShouldNotify(BoxNameSize old) =>
      old.size != size || old.height != height;
}

/// La letra más grande (hasta 16, la misma en todos los recuadros) en la
/// que cada nombre entra entero en un renglón de [width]. Si un nombre no
/// entra ni con 13, no achica a los demás: se corta con "…" y se lee entero
/// al entrar.
double boxNameSize(BuildContext context, Iterable<String> names, double width) {
  const top = 16.0;
  const bottom = 13.0;
  final scaler = MediaQuery.textScalerOf(context);
  bool fits(String name, double size) {
    final p = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final ok = p.width <= width;
    p.dispose();
    return ok;
  }

  var size = top;
  for (final n in names) {
    var s = size;
    while (s > bottom && !fits(n, s)) {
      s -= 0.5;
    }
    if (fits(n, s)) size = s;
  }
  return size;
}

/// Los recuadros de a dos, todos del mismo tamaño y con la misma letra en
/// el nombre ([titles], para calcularla).
class BoxGrid extends StatelessWidget {
  const BoxGrid({
    super.key,
    required this.children,
    required this.titles,
  });

  final List<Widget> children;
  final List<String> titles;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // Ancho del recuadro menos el dibujo, el engranaje y los márgenes.
      final size = boxNameSize(context, titles, (box.maxWidth - 10) / 2 - 72);
      return BoxNameSize(
        size: size,
        height: _cardHeight(context, size),
        child: _rows(),
      );
    },
  );

  Widget _rows() {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 10));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 10),
              Expanded(
                child: i + 1 < children.length
                    ? children[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// El buscador redondeado de arriba.
class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 15.5),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: _night(context)
              ? scheme.surfaceContainerHighest
              : const Color(0xFFE6E7EE),
          prefixIcon: const Icon(Icons.search, size: 20),
          prefixIconConstraints: const BoxConstraints(minWidth: 38),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Borrar búsqueda',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          constraints: const BoxConstraints(minHeight: 40, maxHeight: 40),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFF6D7185)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFF6D7185)),
          ),
        ),
      ),
    );
  }
}

/// Botón cuadrado lila (filtro, +, carpeta nueva).
class SquareButton extends StatelessWidget {
  const SquareButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.on = false,
    this.width = 44,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool on;
  final double width;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final night = _night(context);
    final bg = on ? appBlue : (night ? const Color(0xFF3A4060) : appLila);
    final fg = on ? Colors.white : (night ? Colors.white : appBlue);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(width > 50 ? 20 : 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(width > 50 ? 20 : 12),
          onTap: onPressed,
          child: SizedBox(
            width: width,
            height: 40,
            child: Icon(icon, color: fg),
          ),
        ),
      ),
    );
  }
}

/// La barra de arriba adentro de una carpeta: volver, carpetita y nombre en
/// su color, y a la derecha lo que haga falta.
class FolderHeader extends StatelessWidget implements PreferredSizeWidget {
  const FolderHeader({
    super.key,
    required this.name,
    required this.color,
    required this.onBack,
    this.actions = const [],
  });

  final String name;
  final String color;
  final VoidCallback onBack;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    final c = _night(context) ? boxBorder(color) : boxName(color);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              const SizedBox(width: 4),
              IconButton(
                key: const Key('folder-back'),
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
              Icon(Icons.folder, color: boxBorder(color)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 21,
                    color: c,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ...actions,
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Título chico en mayúsculas ("PARA HACER (3)", "COLOR…").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 13,
      letterSpacing: 0.8,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

/// Lo elegido en el cartel de nombre y color.
typedef NameColor = ({String name, String color, String background});

/// Cartel para crear una carpeta o cambiarle el nombre y los colores. El
/// color (nombre, borde y carpetita) y el fondo se eligen por separado.
Future<NameColor?> showNameColorSheet(
  BuildContext context, {
  required bool isNew,
  required bool folder,
  String name = '',
  String color = 'verde',
  String background = 'blanco',
}) {
  final input = TextEditingController(text: name);
  var c = color;
  var b = background;
  return showAppSheet<NameColor>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void ok() => Navigator.pop(context, (
          name: input.text.trim().isEmpty
              ? (folder ? 'Carpeta nueva' : name)
              : input.text.trim(),
          color: c,
          background: b,
        ));
        Widget dot(
          Color fill,
          Color edge,
          bool on,
          VoidCallback tap,
          String label,
        ) => Semantics(
          label: label,
          selected: on,
          button: true,
          child: GestureDetector(
            onTap: tap,
            // El anillo del elegido va por dentro de los 48: no se corta.
            child: Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: on ? appBlue : Colors.transparent,
                  width: 3,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(color: edge, width: 3),
                ),
              ),
            ),
          ),
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            0,
            18,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isNew ? 'Carpeta nueva' : 'Nombre y color',
                  style: const TextStyle(fontSize: 21),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('box-name'),
                  controller: input,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    hintText: folder ? 'Ej: Casa' : 'Título',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => ok(),
                ),
                const SizedBox(height: 12),
                // Así va a quedar: cambia en vivo con el nombre y los colores.
                Row(
                  children: [
                    Text(
                      'Así queda:',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: _Sample(
                        key: const Key('box-sample'),
                        folder: folder,
                        name: input.text.trim().isEmpty
                            ? (folder ? 'Carpeta nueva' : 'Sin título')
                            : input.text.trim(),
                        color: c,
                        background: b,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const SectionLabel('Color (nombre, borde y carpetita)'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final k in boxColors.keys)
                      dot(
                        Colors.white,
                        boxBorder(k),
                        k == c,
                        () => setState(() => c = k),
                        k,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const SectionLabel('Fondo'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final k in boxBackgrounds.keys)
                      dot(
                        boxFill(k),
                        const Color(0xFFC9CCD8),
                        k == b,
                        () => setState(() => b = k),
                        'fondo $k',
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: _bigButton,
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const Key('box-save'),
                        style: _bigButton,
                        onPressed: ok,
                        child: Text(isNew ? 'Crear' : 'Guardar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

final _bigButton = ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size.fromHeight(46)),
  textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 16)),
);

/// Muestra chica de cómo queda el recuadro.
class _Sample extends StatelessWidget {
  const _Sample({
    super.key,
    required this.folder,
    required this.name,
    required this.color,
    required this.background,
  });

  final bool folder;
  final String name;
  final String color;
  final String background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: boxFill(background),
      border: Border.all(color: boxBorder(color), width: 2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          folder ? Icons.folder : Icons.description,
          color: boxBorder(color),
          size: 24,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: boxName(color),
              fontWeight: FontWeight.w500,
              fontSize: 17,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Lo que se eligió en el engranaje de un recuadro.
enum GearAction { rename, move, delete }

/// El engranaje de un recuadro: cambiar nombre y color, mover a otra
/// carpeta (solo en Notas) y borrar (hay que tocar dos veces).
Future<GearAction?> showGearSheet(
  BuildContext context, {
  required String name,
  required String color,
  required bool folder,
  required bool canMove,
  required bool hasInside,
}) {
  var sure = false;
  return showAppSheet<GearAction>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(
                folder ? Icons.folder : Icons.description,
                color: boxBorder(color),
              ),
              title: Text(
                name.isEmpty ? 'Sin título' : name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              key: const Key('gear-rename'),
              leading: const Icon(Icons.edit),
              title: const Text('Cambiar nombre y color'),
              onTap: () => Navigator.pop(context, GearAction.rename),
            ),
            if (canMove)
              ListTile(
                key: const Key('gear-move'),
                leading: const Icon(Icons.drive_file_move_outline),
                title: const Text('Mover a otra carpeta'),
                onTap: () => Navigator.pop(context, GearAction.move),
              ),
            ListTile(
              key: const Key('gear-delete'),
              tileColor: sure ? pendingRed : null,
              textColor: sure ? Colors.white : null,
              iconColor: sure ? Colors.white : pendingRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              leading: const Icon(Icons.delete),
              title: Text(
                sure
                    ? (folder && hasInside
                          ? '¿Seguro? Se borra con todo lo de adentro'
                          : '¿Seguro? Tocá otra vez')
                    : (folder ? 'Borrar carpeta' : 'Borrar nota'),
              ),
              onTap: () {
                if (!sure) {
                  setState(() => sure = true);
                  return;
                }
                Navigator.pop(context, GearAction.delete);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Cartelito de abajo.
void toast(BuildContext context, String text) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(content: Text(text), duration: const Duration(milliseconds: 2600)),
  );
}

/// Cartelito de abajo con "Deshacer" (en el medio) durante 5 segundos
/// (pedido del usuario). [onGone] corre cuando se va sin deshacer (p. ej.
/// para borrar recién ahí los recordatorios de las tareas).
void undoToast(
  BuildContext context,
  String text, {
  required VoidCallback onUndo,
  VoidCallback? onGone,
}) => undoToastOn(
  ScaffoldMessenger.of(context),
  text,
  onUndo: onUndo,
  onGone: onGone,
);

void undoToastOn(
  ScaffoldMessengerState m,
  String text, {
  required VoidCallback onUndo,
  VoidCallback? onGone,
}) {
  m.hideCurrentSnackBar();
  final c = m.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 5),
      persist: false,
      content: Builder(
        builder: (context) {
          final accent = Theme.of(context).colorScheme.inversePrimary;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                key: const Key('undo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent, width: 1.5),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.undo, size: 18),
                label: const Text(
                  'Deshacer',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  onUndo();
                  m.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
                },
              ),
            ],
          );
        },
      ),
    ),
  );
  if (onGone != null) {
    c.closed.then((r) {
      if (r != SnackBarClosedReason.action) onGone();
    });
  }
}

/// Lamparita: mantiene la pantalla prendida mientras está a la vista (en
/// una nota o en una carpeta de Tareas). Se suelta sola al salir.
class KeepAwakeButton extends StatefulWidget {
  const KeepAwakeButton({super.key, this.buttonKey});

  final Key? buttonKey;

  @override
  State<KeepAwakeButton> createState() => _KeepAwakeButtonState();
}

class _KeepAwakeButtonState extends State<KeepAwakeButton> {
  static const _screen = MethodChannel('recordame/pantalla');
  bool _on = false;

  Future<void> _set(bool on) async {
    try {
      await _screen.invokeMethod('prendida', {'on': on});
    } catch (_) {
      // Sin el canal (pruebas, vista web): no pasa nada.
    }
  }

  @override
  void dispose() {
    if (_on) _set(false);
    super.dispose();
  }

  void _toggle() {
    setState(() => _on = !_on);
    _set(_on);
    toast(
      context,
      _on
          ? '💡 Pantalla prendida: no se va a apagar sola'
          : 'Listo: la pantalla vuelve a apagarse sola',
    );
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: widget.buttonKey,
    tooltip: _on
        ? 'Dejar que la pantalla se apague'
        : 'Mantener la pantalla prendida',
    style: _on
        ? IconButton.styleFrom(
            backgroundColor: const Color(0xFFF2B705),
            foregroundColor: Colors.black,
          )
        : null,
    icon: Icon(_on ? Icons.lightbulb : Icons.lightbulb_outline),
    onPressed: _toggle,
  );
}

/// Tercer paso para borrar una carpeta que tiene cosas adentro: avisa
/// cuántas notas o tareas se van con ella.
Future<bool> confirmFolderDelete(
  BuildContext context, {
  required String name,
  required int count,
  required String one,
  required String many,
}) => confirmDelete(
  context,
  title: '¿Borrar «$name»?',
  text: count == 0
      ? 'La carpeta está vacía.'
      : 'Mirá que adentro tenés ${count == 1 ? '1 $one' : '$count $many'}. '
            'Se borra${count == 1 ? '' : 'n'} con la carpeta.',
  ok: 'Borrar todo',
);

/// Cartel en el medio de la pantalla para confirmar un borrado: Cancelar y
/// el botón rojo del mismo tamaño, con el texto en el medio.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String text,
  required String ok,
}) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('folder-delete-confirm'),
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: pendingRed,
        size: 40,
      ),
      title: Text(title),
      content: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16),
      ),
      // Los dos del mismo tamaño, uno al lado del otro, con la palabra
      // entera en un renglón y en el medio (pedido del usuario: con letra
      // grande "Cancelar" no se puede partir). Si no entra, se achica la
      // letra de los dos por igual.
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      actions: [
        Builder(
          builder: (context) {
            const pad = 8.0;
            // Ancho del cartel: la pantalla menos sus márgenes (40 de cada
            // lado, máximo 560) y los 16 de cada lado de los botones.
            final screen = MediaQuery.sizeOf(context).width;
            final inner = (screen - 80).clamp(200.0, 560.0) - 32;
            final w = (inner - 10) / 2 - pad * 2 - 6;
            final size = sameFontSize(context, ['Cancelar', ok], w);
            Widget label(String t, Color? color) => Text(
              t,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            );
            final shape = RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            );
            return Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('folder-delete-cancel'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(horizontal: pad),
                      shape: shape,
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: label('Cancelar', null),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('folder-delete-ok'),
                    style: FilledButton.styleFrom(
                      backgroundColor: pendingRed,
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(horizontal: pad),
                      shape: shape,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: label(ok, Colors.white),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
  return yes ?? false;
}
