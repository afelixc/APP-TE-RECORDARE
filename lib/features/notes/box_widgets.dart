import 'package:flutter/material.dart';

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
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 30,
                      child: Row(
                        children: [
                          Icon(icon, size: 30, color: border),
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
                    const SizedBox(height: 8),
                    // El nombre en un solo renglón, con la misma letra en
                    // todos los recuadros: la más grande en la que entran.
                    Text(
                      title,
                      maxLines: 1,
                      softWrap: false,
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
                            if (preview != null && preview!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                preview!,
                                maxLines: 2,
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
                      height: 24,
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
                top: 6,
                right: 4,
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

/// Alto de cada recuadro (crece un poco con la letra grande del teléfono).
double boxCardHeight(BuildContext context) =>
    150 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);

/// La letra del nombre de los recuadros: la misma en todos.
class BoxNameSize extends InheritedWidget {
  const BoxNameSize({super.key, required this.size, required super.child});

  final double size;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BoxNameSize>()?.size ?? 17;

  @override
  bool updateShouldNotify(BoxNameSize old) => old.size != size;
}

/// La letra más grande (hasta 20) en la que cada nombre entra entero en un
/// renglón de [width]. Los larguísimos (que necesitarían menos de 15) no
/// achican a los demás: se cortan con "…" y se leen enteros al entrar.
double boxNameSize(BuildContext context, Iterable<String> names, double width) {
  const top = 20.0;
  const bottom = 15.0;
  final scaler = MediaQuery.textScalerOf(context);
  var size = top;
  for (final n in names) {
    final painter = TextPainter(
      text: TextSpan(
        text: n,
        style: const TextStyle(fontSize: top, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    if (w <= width) continue;
    final fit = top * width / w;
    if (fit >= bottom && fit < size) size = fit;
  }
  return size.floorToDouble();
}

/// Los recuadros de a dos, todos del mismo tamaño y con la misma letra en
/// el nombre ([titles], para calcularla).
class BoxGrid extends StatelessWidget {
  const BoxGrid({super.key, required this.children, required this.titles});

  final List<Widget> children;
  final List<String> titles;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => BoxNameSize(
      // Ancho del recuadro menos los márgenes de adentro.
      size: boxNameSize(context, titles, (box.maxWidth - 10) / 2 - 28),
      child: _rows(),
    ),
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
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(color: edge, width: 3),
                boxShadow: on
                    ? const [
                        BoxShadow(color: Colors.white, spreadRadius: 3),
                        BoxShadow(color: appBlue, spreadRadius: 5),
                      ]
                    : null,
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
                  onSubmitted: (_) => ok(),
                ),
                const SizedBox(height: 14),
                const SectionLabel('Color (nombre, borde y carpetita)'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
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
                  spacing: 12,
                  runSpacing: 12,
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
