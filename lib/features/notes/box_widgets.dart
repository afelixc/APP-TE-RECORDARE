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

/// Recuadro de una carpeta o una nota: borde, dibujo y nombre del color
/// elegido, fondo aparte y engranaje en el rincón.
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
    this.preview,
    this.where,
    this.subfolders = 0,
    this.gearKey,
  });

  final IconData icon;
  final String color;
  final String background;
  final String title;
  final String? preview;

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
    final fill = night
        ? (background == 'blanco'
              ? scheme.surfaceContainer
              : Color.alphaBlend(
                  boxFill(background).withValues(alpha: 0.18),
                  scheme.surfaceContainer,
                ))
        : boxFill(background);
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: border, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          // Todos del mismo alto (pedido del usuario): lo largo se corta con
          // "…" y se lee entero al entrar.
          height: boxCardHeight(context),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 26,
                      child: Row(
                        children: [
                          Icon(icon, size: 26, color: border),
                          if (subfolders > 0) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.folder_copy_outlined,
                              size: 18,
                              color: border,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$subfolders',
                              style: TextStyle(
                                color: border,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // El nombre en hasta 2 renglones con las palabras
                    // enteras, con la misma letra en todos los recuadros.
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: name,
                        fontWeight: FontWeight.w500,
                        fontSize: BoxNameSize.of(context),
                        height: 1.2,
                      ),
                    ),
                    Expanded(
                      child: ClipRect(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (where == null &&
                                preview != null &&
                                preview!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                preview!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                            if (where != null)
                              Text(
                                where!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Lo que falta, siempre abajo de todo y alineado.
                    SizedBox(
                      height: 22,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: status,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  key: gearKey,
                  tooltip: 'Ajustes',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.settings, color: border),
                  onPressed: onGear,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alto de cada recuadro: el justo para la carpetita, dos renglones de
/// nombre (y uno de texto en las notas) y lo que falta, sin espacio de más.
double boxCardHeight(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<BoxNameSize>()?.height ?? 130;

double _cardHeight(BuildContext context, double nameSize, bool extraLine) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  return 10 +
      26 +
      4 +
      2 * nameSize * 1.2 * scale +
      (extraLine ? 4 + 12.5 * 1.4 * scale : 0) +
      4 +
      22 +
      10;
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
      context.dependOnInheritedWidgetOfExactType<BoxNameSize>()?.size ?? 17;

  @override
  bool updateShouldNotify(BoxNameSize old) =>
      old.size != size || old.height != height;
}

/// La letra más grande (hasta 19, la misma en todos los recuadros) en la
/// que cada nombre entra entero en hasta 2 renglones de [width], sin partir
/// ninguna palabra. Si un nombre no entra ni con 12, no achica a los demás:
/// se corta con "…" y se lee entero al entrar.
double boxNameSize(BuildContext context, Iterable<String> names, double width) {
  const top = 19.0;
  const bottom = 12.0;
  final scaler = MediaQuery.textScalerOf(context);
  bool fits(String name, double size) {
    final style = TextStyle(fontSize: size, fontWeight: FontWeight.w500);
    // Ninguna palabra más ancha que el recuadro (no se parte).
    for (final w in name.split(RegExp(r'\s+'))) {
      final p = TextPainter(
        text: TextSpan(text: w, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final too = p.width > width;
      p.dispose();
      if (too) return false;
    }
    final p = TextPainter(
      text: TextSpan(text: name, style: style.copyWith(height: 1.2)),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: width);
    final lines = p.computeLineMetrics().length;
    p.dispose();
    return lines <= 2;
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
    this.extraLine = false,
  });

  final List<Widget> children;
  final List<String> titles;

  /// Algún recuadro lleva un renglón más (el comienzo de la nota).
  final bool extraLine;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // Ancho del recuadro menos los márgenes de adentro.
      final size = boxNameSize(context, titles, (box.maxWidth - 10) / 2 - 28);
      return BoxNameSize(
        size: size,
        height: _cardHeight(context, size, extraLine),
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
