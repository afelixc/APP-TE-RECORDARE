import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../calendar/calendar_screen.dart';
import '../chat/ai_chat.dart' show talkWhenChatOpens;
import '../chat/chat_screen.dart';
import '../notebook/notebook_page.dart';
import '../notebook/notes.dart';
import '../notebook/quick_note.dart';
import '../notifications/reminder_actions_sheet.dart';
import '../reminders/reminder_editor.dart';
import '../reminders/reminders_screen.dart';
import '../settings/settings_screen.dart';

/// Una pestaña de la barra inferior.
class AppTab {
  const AppTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
}

/// Lista de pestañas. Para sumar una nueva, agregala acá.
final List<AppTab> appTabs = [
  AppTab(
    label: 'Chat',
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
    builder: (_) => const ChatScreen(),
  ),
  AppTab(
    label: 'Almanaque',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
    builder: (_) => const CalendarScreen(),
  ),
  AppTab(
    label: 'Listado',
    icon: Icons.checklist_outlined,
    selectedIcon: Icons.checklist,
    builder: (_) => const RemindersScreen(),
  ),
  // La libreta como una solapa más, entre Listado y Configuración (pedido
  // del usuario; antes flotaba). En la barra va en un recuadro amarillo con
  // lo pendiente en rojo ([_NotebookTabIcon]).
  AppTab(
    label: 'Libreta',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
    builder: (context) =>
        NotebookPage(settings: AppScope.of(context).settings, inTab: true),
  ),
  AppTab(
    label: 'Configuración',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    builder: (_) => const SettingsScreen(),
  ),
];

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.openedReminders = const Stream.empty(),
    this.launchReminderId,
  });

  final Stream<int> openedReminders;
  final int? launchReminderId;

  /// Cambia de pestaña desde cualquier pantalla (por ejemplo, ir a
  /// Configuración). Devuelve false si no está la pantalla principal.
  static bool goToTab(BuildContext context, String label) {
    final state = context.findAncestorStateOfType<_HomeShellState>();
    final index = appTabs.indexWhere((t) => t.label == label);
    if (state == null || index < 0) return false;
    state._select(index);
    return true;
  }

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Sube cada vez que se toca una solapa: así al volver a entrar (por
  /// ejemplo a la Libreta) siempre arranca en su pantalla de inicio, sin la
  /// búsqueda de antes (pedido del usuario).
  int _visit = 0;

  void _select(int i) => setState(() {
    _index = i;
    _visit++;
  });

  /// El micrófono de arriba: con IA va al Chat y escucha; si no, abre la
  /// carga a mano.
  void _talk() {
    final settings = AppScope.of(context).settings;
    if (settings.aiReady) {
      talkWhenChatOpens = true;
      _select(0);
    } else {
      showReminderEditor(context);
    }
  }

  /// Deslizar el dedo cambia de solapa y al llegar a la última vuelve a la
  /// primera: hacia la izquierda, la de la derecha (Chat → Almanaque →
  /// Listado → Libreta → Configuración → Chat); hacia la derecha, la anterior.
  void _swipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 300) return;
    final n = appTabs.length;
    _select((_index + (v < 0 ? 1 : -1) + n) % n);
  }

  StreamSubscription<int>? _openedSub;

  @override
  void initState() {
    super.initState();
    // Al tocar una notificación se muestran sus opciones (Hecho / Posponer).
    _openedSub = widget.openedReminders.listen(_showReminder);
    final launchId = widget.launchReminderId;
    if (launchId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showReminder(launchId),
      );
    }
  }

  @override
  void dispose() {
    _openedSub?.cancel();
    super.dispose();
  }

  void _showReminder(int id) {
    if (mounted) showReminderActionsSheet(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final tab = appTabs[_index];
    final scheme = Theme.of(context).colorScheme;
    final night = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        // Barra con el color de la app (Configuración → Colores). De noche,
        // fondo oscuro y letras de ese color, para que no encandile.
        backgroundColor: night ? scheme.surfaceContainer : scheme.primary,
        foregroundColor: night ? scheme.primary : scheme.onPrimary,
        centerTitle: true,
        title: const Text(
          'TE RECORDARÉ',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2),
        ),
        // Fuera del Chat: un micrófono para cargar algo enseguida (pedido
        // del usuario, en lugar del botón "Nuevo").
        actions: [
          if (_index != 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton.filled(
                key: const Key('top-mic'),
                tooltip: 'Hablar para cargar un recordatorio',
                style: IconButton.styleFrom(
                  backgroundColor: scheme.secondary,
                  foregroundColor: scheme.onSecondary,
                ),
                icon: const Icon(Icons.mic),
                onPressed: _talk,
              ),
            ),
        ],
      ),
      body: GestureDetector(
        key: const Key('tab-swipe'),
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: _swipe,
        child: KeyedSubtree(
          key: ValueKey((_index, _visit)),
          child: tab.builder(context),
        ),
      ),
      // La solapa elegida se agranda y se destaca (pedido del usuario): dibujo
      // más grande, letra más grande y en negrita del color de la app.
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: scheme.primary.withValues(alpha: night ? 0.35 : 0.22),
          iconTheme: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? IconThemeData(size: 30, color: scheme.primary)
                : IconThemeData(size: 22, color: scheme.onSurfaceVariant),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: scheme.primary,
                  )
                : TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: [
            for (final t in appTabs)
              _OneLineLabel(
                label: t.label,
                child: t.label == 'Libreta'
                    ? NavigationDestination(
                        key: const Key('tab-libreta'),
                        icon: const _NotebookTabIcon(selected: false),
                        selectedIcon: const _NotebookTabIcon(selected: true),
                        label: t.label,
                      )
                    : NavigationDestination(
                        icon: Icon(t.icon),
                        selectedIcon: Icon(t.selectedIcon),
                        label: t.label,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Si el nombre de la solapa no entra en un renglón (p. ej. "Configuración"
/// con letra grande), achica solo esa palabra para que entre, y el dibujo
/// queda a la misma altura que los demás (pedido del usuario).
class _OneLineLabel extends StatelessWidget {
  const _OneLineLabel({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        (theme.navigationBarTheme.labelTextStyle?.resolve({
                  WidgetState.selected,
                }) ??
                theme.textTheme.labelMedium)!
            .copyWith(fontWeight: FontWeight.w700);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final room = box.maxWidth - 8;
        final width = painter.width;
        painter.dispose();
        if (width <= room) return child;
        final size = style.fontSize ?? 12;
        final fitted = scaler.scale(size) * room / width;
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(fitted / size)),
          child: child,
        );
      },
    );
  }
}

/// La Libreta en la barra de abajo: el dibujo en un recuadro amarillo y, si
/// hay cosas sin hacer, un botoncito rojo con cuántas (pedido del usuario).
class _NotebookTabIcon extends StatelessWidget {
  const _NotebookTabIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final night = Theme.of(context).brightness == Brightness.dark;
    final fg = night ? const Color(0xFFF0C04A) : notebookColor;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final toDo = notebookToDo(settings.folders);
        return Badge(
          key: const Key('tab-libreta-badge'),
          isLabelVisible: toDo > 0,
          backgroundColor: const Color(0xFFD32F2F),
          textColor: Colors.white,
          label: Text(toDo > 99 ? '99+' : '$toDo'),
          offset: const Offset(10, -8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: notebookColor.withValues(alpha: selected ? 0.32 : 0.16),
              border: Border.all(color: fg, width: 1.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              selected ? Icons.menu_book : Icons.menu_book_outlined,
              color: fg,
              size: selected ? 26 : 20,
            ),
          ),
        );
      },
    );
  }
}
