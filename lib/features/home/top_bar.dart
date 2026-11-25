import 'package:flutter/material.dart';

import '../chat/examples_sheet.dart';
import '../settings/settings_screen.dart';
import 'home_shell.dart';

/// Abre Configuración (está en el menú ⋮ de arriba).
Future<void> openSettings(BuildContext context) async {
  settingsOpen++;
  try {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Configuración')),
          body: const SettingsScreen(),
        ),
      ),
    );
  } finally {
    settingsOpen--;
  }
}

/// Cuántas Configuraciones hay abiertas. Desde ahí se abren pantallas de
/// Android (elegir sonido, carpeta de la copia, ajustes de batería…): al
/// volver de esas no hay que llevar al usuario a Mensaje.
int settingsOpen = 0;

/// La barra azul de arriba: el micrófono naranja a la izquierda (menos en
/// Mensaje, que tiene el suyo grande), ALERTA YA en el medio y el menú ⋮
/// (Configuración, Ejemplos) a la derecha.
class MainTopBar extends StatelessWidget implements PreferredSizeWidget {
  const MainTopBar({super.key, this.showMic = true});

  final bool showMic;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final night = Theme.of(context).brightness == Brightness.dark;
    // De noche, fondo oscuro y letras del color de la app (no encandila).
    final bg = night ? scheme.surfaceContainer : scheme.primary;
    final fg = night ? scheme.primary : scheme.onPrimary;
    return Material(
      color: bg,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                height: 40,
                child: showMic
                    ? IconButton.filled(
                        key: const Key('top-mic'),
                        tooltip: 'Hablar para cargar un recordatorio',
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.secondary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.mic),
                        onPressed: () => HomeShell.talk(context),
                      )
                    : null,
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'ALERTA YA',
                    maxLines: 1,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              PopupMenuButton<int>(
                key: const Key('top-menu'),
                tooltip: 'Más opciones',
                icon: Icon(Icons.more_vert, color: fg),
                onSelected: (v) =>
                    v == 0 ? openSettings(context) : showExamples(context),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    key: Key('menu-settings'),
                    value: 0,
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined),
                        SizedBox(width: 14),
                        Text('Configuración'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    key: Key('menu-examples'),
                    value: 1,
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline),
                        SizedBox(width: 14),
                        Text('Ejemplos'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
