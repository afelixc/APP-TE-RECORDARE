import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../calendar/calendar_screen.dart';
import '../chat/ai_chat.dart' show talkWhenChatOpens;
import '../chat/chat_screen.dart';
import '../notes/boxes.dart';
import '../notes/notes_screen.dart';
import '../notes/tasks_screen.dart';
import '../notifications/reminder_actions_sheet.dart';
import '../reminders/reminder_editor.dart';
import '../reminders/reminders_screen.dart';
import 'top_bar.dart';

/// Una pestaña de la barra inferior.
class AppTab {
  const AppTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
    this.ownTopBar = false,
  });

  /// Arma su propia barra de arriba.
  final bool ownTopBar;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
}

/// Lista de pestañas: Mensaje · Almanaque · Listado | Notas · Tareas.
/// Notas y Tareas tienen su propia barra de arriba (adentro de una carpeta
/// muestran la de la carpeta) y su color (Configuración → Colores).
final List<AppTab> appTabs = [
  AppTab(
    label: 'Mensaje',
    icon: Icons.chat_outlined,
    selectedIcon: Icons.chat,
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
  AppTab(
    label: 'Notas',
    icon: Icons.sticky_note_2_outlined,
    selectedIcon: Icons.sticky_note_2,
    builder: (_) => const NotesScreen(),
    ownTopBar: true,
  ),
  AppTab(
    label: 'Tareas',
    icon: Icons.task_alt_outlined,
    selectedIcon: Icons.task_alt,
    builder: (_) => const TasksScreen(),
    ownTopBar: true,
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

  /// El micrófono de arriba: con IA va a Mensaje y escucha; si no, abre la
  /// carga a mano.
  static void talk(BuildContext context) {
    final state = context.findAncestorStateOfType<_HomeShellState>();
    if (state != null) {
      state._talk();
    } else {
      showReminderEditor(context);
    }
  }

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Sube cada vez que se toca una solapa: así al volver a entrar (por
  /// ejemplo a Notas) siempre arranca en su pantalla de inicio, sin la
  /// búsqueda de antes (pedido del usuario).
  int _visit = 0;

  void _select(int i) => setState(() {
    _index = i;
    _visit++;
  });

  /// El micrófono de arriba: con IA va a Mensaje y escucha; si no, abre la
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
  /// primera: hacia la izquierda, la de la derecha (Mensaje → Almanaque →
  /// Listado → Notas → Tareas → Mensaje); hacia la derecha, la anterior.
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
    return Scaffold(
      body: GestureDetector(
        key: const Key('tab-swipe'),
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: _swipe,
        child: Column(
          children: [
            if (!tab.ownTopBar) MainTopBar(showMic: _index != 0),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey((_index, _visit)),
                child: tab.builder(context),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(index: _index, onSelect: _select),
    );
  }
}

/// La barra de abajo: Mensaje, Almanaque y Listado juntos en el color de la
/// app; una rayita; Notas y Tareas con su propio color y el número rojo de
/// lo que falta. El elegido queda marcado y un poco más grande.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final scheme = Theme.of(context).colorScheme;
    final night = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final badges = [
          0,
          0,
          0,
          notesBadge(settings.notes),
          settings.tasksToDo,
        ];
        final colors = [
          scheme.primary,
          scheme.primary,
          scheme.primary,
          settings.notesColor,
          settings.tasksColor,
        ];
        Widget item(int i) {
          final t = appTabs[i];
          final selected = i == index;
          final own = i >= 3;
          final c = night && !own ? scheme.primary : colors[i];
          final plain = night
              ? scheme.onSurfaceVariant
              : const Color(0xFF3A3F52);
          return Expanded(
            child: Semantics(
              selected: selected,
              button: true,
              label: t.label,
              child: InkWell(
                key: Key('tab-${t.label}'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelect(i),
                child: AnimatedScale(
                  scale: selected ? 1.12 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Badge(
                          isLabelVisible: badges[i] > 0,
                          backgroundColor: const Color(0xFFD32F2F),
                          textColor: Colors.white,
                          label: Text(badges[i] > 99 ? '99+' : '${badges[i]}'),
                          offset: const Offset(4, -6),
                          child: Container(
                            width: 52,
                            height: 32,
                            decoration: BoxDecoration(
                              color: selected
                                  ? c.withValues(alpha: 0.26)
                                  : own
                                  ? c.withValues(alpha: 0.12)
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              border: selected
                                  ? Border.all(
                                      color: c.withValues(alpha: 0.55),
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: Icon(
                              selected ? t.selectedIcon : t.icon,
                              color: c,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            t.label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: selected || own ? c : plain,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : own
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Material(
          color: night ? scheme.surfaceContainer : const Color(0xFFECEEF3),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  item(0),
                  item(1),
                  item(2),
                  Container(
                    width: 1,
                    height: 38,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: const Color(0xFFC5C9D6),
                  ),
                  item(3),
                  item(4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
