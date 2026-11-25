import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/formatting.dart';
import '../../core/settings.dart';
import '../home/top_bar.dart';
import '../reminders/reminder_form.dart';
import 'ai_chat.dart';
import 'missed_banner.dart';

/// Pestaña Mensaje. Con la IA lista muestra el chat; si no, el formulario
/// para cargar a mano (modo gratis).
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        children: [
          if (settings.mode == UsageMode.ai && !settings.aiReady)
            const _MissingKey(),
          Expanded(
            child: settings.aiReady
                ? AiChat(key: ValueKey(settings.providerId), settings: settings)
                : const _ManualEntry(),
          ),
        ],
      ),
    );
  }
}

/// Con IA elegida pero sin clave: un aviso y el botón para cargarla.
class _MissingKey extends StatelessWidget {
  const _MissingKey();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Icon(Icons.key_off, size: 18, color: scheme.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Falta tu clave de IA.',
              style: TextStyle(color: scheme.error),
            ),
          ),
          TextButton(
            onPressed: () => openSettings(context),
            child: const Text('Cargarla'),
          ),
        ],
      ),
    );
  }
}

class _ManualEntry extends StatefulWidget {
  const _ManualEntry();

  @override
  State<_ManualEntry> createState() => _ManualEntryState();
}

class _ManualEntryState extends State<_ManualEntry> {
  // Cambiar la clave reinicia el formulario después de guardar.
  int _formVersion = 0;
  String? _lastSaved;
  final _formKey = GlobalKey();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = AppScope.of(context).reminders;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      children: [
        const MissedBanner(padding: EdgeInsets.only(bottom: 10)),
        if (_lastSaved != null) ChatBubble(text: _lastSaved!),
        const SizedBox(height: 8),
        Card(
          key: _formKey,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ReminderForm(
              key: ValueKey(_formVersion),
              submitLabel: 'Guardar recordatorio',
              onSubmit: (r) async {
                await repo.save(r);
                setState(() {
                  _formVersion++;
                  _lastSaved =
                      'Guardado ✓ "${r.title}", ${describeSchedule(r)}.';
                });
                // Arriba, para que se vea el "Guardado ✓".
                if (_scroll.hasClients) {
                  await _scroll.animateTo(
                    0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Globo de mensaje del chat.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    this.mine = false,
    this.error = false,
    this.at,
  });

  final String text;
  final bool mine;
  final bool error;

  /// Hora en que se mandó (en el chat completo).
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = mine
        ? scheme.primary
        : error
        ? scheme.errorContainer
        : scheme.surfaceContainerHighest;
    final fg = mine
        ? scheme.onPrimary
        : error
        ? scheme.onErrorContainer
        : scheme.onSurface;
    const r = Radius.circular(16);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 8,
          left: mine ? 48 : 0,
          right: mine ? 0 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: mine ? r : const Radius.circular(4),
            bottomRight: mine ? const Radius.circular(4) : r,
          ),
        ),
        child: at == null
            ? Text(text, style: TextStyle(color: fg))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: Text(text, style: TextStyle(color: fg)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Fmt.time(at!),
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
