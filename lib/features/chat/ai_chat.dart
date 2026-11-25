import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/formatting.dart';
import '../../core/settings.dart';
import '../../data/reminder.dart';
import '../../data/usage.dart';
import '../ai/ai_provider.dart';
import '../ai/ai_providers.dart';
import '../ai/pricing.dart';
import '../ai/reminder_interpreter.dart';
import '../reminders/priority_chooser.dart';
import '../reminders/reminder_editor.dart';
import 'chat_screen.dart';
import 'dictation.dart';
import 'missed_banner.dart';
import 'talking_panel.dart';

enum _Status { thinking, saved, question, error }

/// Un recordatorio que armó la IA y si sigue activo o se canceló.
class _Item {
  const _Item(this.reminder, {this.active = true});

  final Reminder reminder;
  final bool active;
}

/// Lo último que pasó: se muestra en la solapa "Último recordatorio".
class _Last {
  const _Last(this.status, {this.said, this.items = const [], this.text});

  final _Status status;

  /// Lo que dijo o escribió el usuario.
  final String? said;

  /// Los recordatorios que se guardaron (hasta dos).
  final List<_Item> items;

  /// La pregunta o el error; con [items], la pregunta por el que faltó.
  final String? text;

  _Last withItem(int i, _Item item) =>
      _Last(status, said: said, items: [...items]..[i] = item, text: text);
}

/// Mensaje (con IA): el usuario habla o escribe, la IA arma el recordatorio y
/// queda guardado y activo enseguida; después se puede modificar o cancelar.
/// El micrófono de arriba (Almanaque, Listado, Configuración) pide hablar:
/// al abrirse el Chat empieza a escuchar solo.
bool talkWhenChatOpens = false;

class AiChat extends StatefulWidget {
  const AiChat({super.key, required this.settings, this.interpreter});

  final AppSettings settings;

  /// Para las pruebas; si es null se arma con la configuración.
  final ReminderInterpreter? interpreter;

  @override
  State<AiChat> createState() => _AiChatState();
}

class _AiChatState extends State<AiChat> {
  final _input = TextEditingController();
  final _dictation = Dictation();
  _Last? _last;

  /// "Último recordatorio" abierto (si no, la campana y el micrófono grande).
  bool _showLast = false;

  /// El micrófono chico dicta en el recuadro de texto, en vez de mandar.
  bool _dictatingIntoField = false;

  /// Si la IA hizo una pregunta, el pedido anterior para no perder contexto.
  String? _previousRequest;

  /// Los que ya se guardaron de ese pedido, para no repetirlos al completar.
  final _alreadySaved = <String>{};

  @override
  void initState() {
    super.initState();
    _dictation.addListener(_onDictation);
    if (talkWhenChatOpens) {
      talkWhenChatOpens = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startTalking();
      });
    }
  }

  @override
  void dispose() {
    _dictation.removeListener(_onDictation);
    _dictation.dispose();
    _input.dispose();
    super.dispose();
  }

  void _onDictation() {
    if (_dictatingIntoField && _dictation.active) {
      _input.text = _dictation.text;
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
    }
    setState(() {});
  }

  bool get _thinking => _last?.status == _Status.thinking;

  Future<ReminderInterpreter> _interpreter() async {
    if (widget.interpreter != null) return widget.interpreter!;
    final s = widget.settings;
    final provider =
        AppScope.of(context).aiProviderOverride ?? providerById(s.providerId);
    final key = await s.keys.read(provider.id);
    if (key == null) {
      throw const AiException('Falta la clave. Cargala en Configuración.');
    }
    return ReminderInterpreter(
      provider: provider,
      apiKey: key,
      model: s.modelFor(provider.id) ?? provider.defaultModel,
      language: s.language,
    );
  }

  Future<void> _send(String text) async {
    text = text.trim();
    if (text.isEmpty || _thinking) return;
    // Se esconde el teclado para que se vea la tarjeta entera.
    FocusManager.instance.primaryFocus?.unfocus();
    _input.clear();
    _showLast = true;
    widget.settings.addChat(ChatEntry(text, mine: true, at: DateTime.now()));
    setState(() => _last = _Last(_Status.thinking, said: text));

    final request = _previousRequest == null
        ? text
        : 'Pedido anterior: $_previousRequest\nRespuesta del usuario: $text';
    final repo = AppScope.of(context).reminders;
    try {
      final interpreter = await _interpreter();
      final result = await interpreter.interpret(request);
      if (!mounted) return;
      _recordUsage(interpreter, result.usage);
      // Los completos quedan guardados y activos enseguida; después se pueden
      // modificar o cancelar. Si a otro le faltaba algo, se pregunta.
      final saved = <Reminder>[];
      for (final r in result.reminders) {
        if (_alreadySaved.contains(r.title.toLowerCase())) continue;
        saved.add(await repo.save(r));
      }
      final question = result.ok ? result.question : result.message;
      final lines = [
        for (final r in saved)
          'Listo ✓ "${r.title}", ${describeSchedule(r)}. Quedó activo.',
        if (result.tooMany)
          'Te anoté los dos primeros: puedo hasta dos por mensaje. '
              'Mandame el resto en otro mensaje.',
        ?question,
      ];
      if (question != null && _previousRequest != null && saved.isEmpty) {
        // Otra vuelta sin entenderse: se suma lo dicho sin anidar
        // "Pedido anterior" dentro de otro (eso la confundía).
        _previousRequest = '$_previousRequest\nDespués dijo: $text';
      } else if (question != null) {
        _alreadySaved.addAll(saved.map((r) => r.title.toLowerCase()));
        _previousRequest = _alreadySaved.isEmpty
            ? request
            : '$request\nYa quedaron guardados, no los vuelvas a crear: '
                  '${_alreadySaved.join(', ')}.';
      } else {
        _previousRequest = null;
        _alreadySaved.clear();
      }
      if (lines.isEmpty) lines.add('Eso ya lo tenía anotado.');
      _show(
        saved.isEmpty
            ? _Last(_Status.question, said: text, text: lines.join('\n'))
            : _Last(
                _Status.saved,
                said: text,
                items: [for (final r in saved) _Item(r)],
                text: question,
              ),
        lines.join('\n'),
      );
    } on AiException catch (e) {
      _show(
        _Last(_Status.error, said: text, text: e.message),
        e.message,
        error: true,
      );
    } catch (_) {
      const message =
          'No me pude conectar con la IA (¿sin internet?). '
          'Lo que dijiste no se perdió: tocá "Cargarlo a mano" y lo completás vos.';
      _show(
        _Last(_Status.error, said: text, text: message),
        message,
        error: true,
      );
    }
  }

  /// Olvida la pregunta pendiente: el próximo mensaje es un pedido nuevo.
  void _startOver() {
    _previousRequest = null;
    _alreadySaved.clear();
    setState(() {
      _last = null;
      _showLast = false;
    });
    widget.settings.addChat(
      ChatEntry(
        'Listo, empezamos de nuevo. Decime qué querés que te recuerde y cuándo.',
        at: DateTime.now(),
      ),
    );
  }

  void _show(_Last last, String message, {bool error = false}) {
    if (!mounted) return;
    widget.settings.addChat(
      ChatEntry(message, error: error, at: DateTime.now()),
    );
    setState(() => _last = last);
  }

  /// Anota la consulta para la sección de consumo de Configuración.
  void _recordUsage(ReminderInterpreter interpreter, AiResult? usage) {
    if (usage == null) return;
    final price = priceFor(interpreter.model);
    AppScope.of(context).usage.record(
      UsageRecord(
        at: DateTime.now(),
        provider: interpreter.provider.id,
        model: interpreter.model,
        inputTokens: usage.inputTokens,
        outputTokens: usage.outputTokens,
        costUsd: price?.cost(usage.inputTokens, usage.outputTokens),
      ),
    );
  }

  Future<void> _modify(int i) async {
    final repo = AppScope.of(context).reminders;
    final r = _last!.items[i].reminder;
    await showReminderEditor(context, reminder: r);
    final updated = await repo.getById(r.id!);
    if (!mounted || updated == null || _last == null) return;
    setState(() => _last = _last!.withItem(i, _Item(updated)));
  }

  Future<void> _cancel(int i) async {
    final r = _last!.items[i].reminder;
    await AppScope.of(context).reminders.delete(r.id!);
    _show(
      _last!.withItem(i, _Item(r, active: false)),
      'Cancelado: "${r.title}".',
    );
  }

  /// Cambia la prioridad o el "sonar en silencio" de uno ya guardado.
  Future<void> _setPriority(
    int i, {
    ReminderPriority? priority,
    bool? loud,
  }) async {
    final r = _last!.items[i].reminder.copyWith(priority: priority, loud: loud);
    setState(() => _last = _last!.withItem(i, _Item(r)));
    await AppScope.of(context).reminders.save(r);
  }

  Future<void> _restore(int i) async {
    final r = _last!.items[i].reminder;
    final saved = await AppScope.of(context).reminders.save(r);
    _show(
      _last!.withItem(i, _Item(saved)),
      'Lo volví a activar: "${saved.title}".',
    );
  }

  /// Abre o cierra "Último recordatorio". Si en esta vuelta todavía no se
  /// pidió nada, muestra el último que se cargó.
  Future<void> _toggleLast() async {
    if (_showLast) {
      setState(() => _showLast = false);
      return;
    }
    if (_last == null) {
      final all = await AppScope.of(context).reminders.watchAll().first;
      if (!mounted) return;
      Reminder? latest;
      for (final r in all) {
        if (latest == null || (r.id ?? 0) > (latest.id ?? 0)) latest = r;
      }
      if (latest != null) {
        _last = _Last(
          _Status.saved,
          items: [_Item(latest, active: !latest.done)],
        );
      }
    }
    setState(() => _showLast = true);
  }

  Future<void> _startTalking() async {
    _dictatingIntoField = false;
    final ok = await _dictation.start(language: widget.settings.language);
    if (!ok) _micError();
  }

  Future<void> _sendTalking() async => _send(await _dictation.finish());

  Future<void> _toggleFieldDictation() async {
    if (_dictation.active) {
      await _dictation.finish();
      setState(() => _dictatingIntoField = false);
      return;
    }
    _dictatingIntoField = true;
    final ok = await _dictation.start(
      language: widget.settings.language,
      initialText: _input.text,
    );
    if (!ok) {
      _dictatingIntoField = false;
      _micError();
    }
  }

  void _micError() => _show(
    _Last(
      _Status.error,
      text:
          'No pude usar el micrófono. Permití el acceso al micrófono para Alerta Ya '
          'en los ajustes del teléfono, o escribilo.',
    ),
    'No pude usar el micrófono.',
    error: true,
  );

  @override
  Widget build(BuildContext context) {
    final talking = _dictation.active && !_dictatingIntoField;
    final scheme = Theme.of(context).colorScheme;
    final mic = _BigMic(
      small: _showLast,
      onPressed: _thinking || _dictatingIntoField || talking
          ? null
          : _startTalking,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(
            children: [
              Expanded(
                child: _TopButton(
                  key: const Key('show-last'),
                  icon: Icons.history,
                  label: 'Último recordatorio',
                  on: _showLast,
                  onPressed: _toggleLast,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TopButton(
                  key: const Key('manual-entry'),
                  icon: Icons.edit_calendar_outlined,
                  label: 'Cargar a mano',
                  onPressed: () => showReminderEditor(context),
                ),
              ),
            ],
          ),
        ),
        // Lo que pasó sin responder. Mientras se ve lo recién cargado se
        // esconde, para que entre la tarjeta entera; vuelve al cerrarla.
        if (!_showLast)
          const MissedBanner(padding: EdgeInsets.fromLTRB(14, 8, 14, 0)),
        Expanded(
          child: _showLast
              ? Column(
                  children: [
                    Expanded(
                      child: ListenableBuilder(
                        listenable: widget.settings,
                        builder: (context, _) => _LastView(
                          last: _last,
                          providerName: providerById(widget.settings.providerId)
                              .name,
                          onModify: _modify,
                          onCancel: _cancel,
                          onRestore: _restore,
                          onPriority: (i, p) => _setPriority(i, priority: p),
                          onLoud: (i, v) => _setPriority(i, loud: v),
                          onStartOver: _startOver,
                        ),
                      ),
                    ),
                    if (!talking) mic,
                  ],
                )
              : Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Icon(
                          Icons.notifications,
                          size: 96,
                          color: scheme.onSurface.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    if (!talking) mic,
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: talking
              ? TalkingPanel(
                  text: _dictation.text,
                  onCancel: _dictation.cancel,
                  onSend: _sendTalking,
                )
              : _Composer(
                  input: _input,
                  busy: _thinking,
                  dictatingIntoField: _dictatingIntoField,
                  onFieldMic: _toggleFieldDictation,
                  onSend: () async {
                    if (_dictatingIntoField) await _toggleFieldDictation();
                    _send(_input.text);
                  },
                ),
        ),
      ],
    );
  }
}

/// Botones de arriba de Mensaje ("Último recordatorio", "Cargar a mano").
class _TopButton extends StatelessWidget {
  const _TopButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.on = false,
  });

  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(38),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        backgroundColor: on ? scheme.primaryContainer : null,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
      ),
      icon: Icon(icon, size: 20),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 14.5)),
      ),
      onPressed: onPressed,
    );
  }
}

/// El micrófono naranja de Mensaje: grande al entrar y más chico con el
/// último recordatorio a la vista.
class _BigMic extends StatelessWidget {
  const _BigMic({required this.small, required this.onPressed});

  final bool small;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = small ? 64.0 : 92.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: FloatingActionButton.large(
              key: const Key('big-mic'),
              heroTag: 'mic',
              tooltip: 'Hablar',
              shape: const CircleBorder(),
              backgroundColor: scheme.secondary,
              foregroundColor: Colors.white,
              onPressed: onPressed,
              child: Icon(Icons.mic, size: small ? 30 : 40),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tocá para hablar',
            style: TextStyle(fontSize: small ? 12.5 : 15),
          ),
        ],
      ),
    );
  }
}

/// Solapa "Último recordatorio": lo último que se pidió y cómo quedó, todo
/// a la vista sin tener que deslizar.
class _LastView extends StatelessWidget {
  const _LastView({
    required this.last,
    required this.providerName,
    required this.onModify,
    required this.onCancel,
    required this.onRestore,
    required this.onPriority,
    required this.onLoud,
    required this.onStartOver,
  });

  final _Last? last;
  final String providerName;
  final ValueChanged<int> onModify;
  final ValueChanged<int> onCancel;
  final ValueChanged<int> onRestore;
  final void Function(int, ReminderPriority) onPriority;
  final void Function(int, bool) onLoud;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final last = this.last;
    final startOver = Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const Key('start-over'),
        icon: const Icon(Icons.restart_alt),
        label: const Text('Empezar de nuevo (olvidar esta pregunta)'),
        onPressed: onStartOver,
      ),
    );

    if (last == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Todavía no cargaste ningún recordatorio.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final said = last.said;
    final saidLine = said == null
        ? null
        : TapToExpand(
            'Dijiste: “$said”',
            key: const Key('said-line'),
            maxLines: 1,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          );
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      children: [
        switch (last.status) {
          _Status.thinking => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ?saidLine,
              const SizedBox(height: 10),
              Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text('Pensando con $providerName…'),
                ],
              ),
            ],
          ),
          _Status.question || _Status.error => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (saidLine != null) ...[saidLine, const SizedBox(height: 8)],
              ChatBubble(
                text: last.text ?? '',
                error: last.status == _Status.error,
              ),
              if (last.status == _Status.error &&
                  (last.said ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  key: const Key('error-manual'),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Cargarlo a mano'),
                  // Ya viene con lo que dijiste en el "Qué".
                  onPressed: () =>
                      showReminderEditor(context, initialTitle: last.said!),
                ),
              ],
              if (last.status == _Status.question) ...[
                Text(
                  'Respondeme con el micrófono o escribiendo.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                startOver,
              ],
            ],
          ),
          _Status.saved => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, item) in last.items.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                _ReminderCard(
                  reminder: item.reminder,
                  active: item.active,
                  // Lo que dijo va arriba de todo, en la primera tarjeta.
                  said: i == 0 ? saidLine : null,
                  footer: item.active
                      ? PriorityChooser(
                          priority: item.reminder.priority,
                          loud: item.reminder.loud,
                          onPriority: (p) => onPriority(i, p),
                          onLoud: (v) => onLoud(i, v),
                        )
                      : null,
                  actions: item.active
                      ? [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: _smallButton,
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Cancelar', maxLines: 1),
                              onPressed: () => onCancel(i),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              style: _smallButton,
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Modificar', maxLines: 1),
                              onPressed: () => onModify(i),
                            ),
                          ),
                        ]
                      : [
                          Expanded(
                            child: TextButton.icon(
                              icon: const Icon(Icons.undo),
                              label: const Text('Volver a activarlo'),
                              onPressed: () => onRestore(i),
                            ),
                          ),
                        ],
                ),
              ],
              // Al otro le faltaba algo: la pregunta, debajo.
              if (last.text != null) ...[
                const SizedBox(height: 8),
                ChatBubble(text: last.text!),
                Text(
                  'Respondeme con el micrófono o escribiendo.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                startOver,
              ],
            ],
          ),
        },
      ],
    );
  }
}

/// Botones chicos, en un renglón (Cancelar / Modificar).
final _smallButton = ButtonStyle(
  visualDensity: VisualDensity.compact,
  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
  textStyle: const WidgetStatePropertyAll(
    TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
  ),
);

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.active,
    required this.actions,
    this.said,
    this.footer,
  });

  final Reminder reminder;
  final bool active;
  final List<Widget> actions;
  final Widget? said;

  /// Debajo de los botones: la prioridad.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final next = reminder.repeats ? reminder.nextOccurrence() : null;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: active ? Colors.green : scheme.outlineVariant,
          width: active ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (said != null) ...[said!, const SizedBox(height: 2)],
            TapToExpand(
              reminder.title,
              key: const Key('reminder-title'),
              maxLines: 2,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                decoration: active ? null : TextDecoration.lineThrough,
              ),
            ),
            // Cuándo y, a la derecha, "Activo" (en un renglón, para que
            // entre la tarjeta entera).
            Row(
              children: [
                // Un solo renglón: si no entra, la letra se achica (así
                // siempre se ven la prioridad y el tildecito).
                Expanded(child: _OneLine(describeSchedule(reminder), size: 14)),
                const SizedBox(width: 6),
                Icon(
                  active ? Icons.check_circle : Icons.cancel,
                  color: active ? Colors.green : scheme.onSurfaceVariant,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  active ? 'Activo' : 'Cancelado',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: active ? Colors.green : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (next != null)
              _OneLine(
                'Próximo: ${Fmt.when(next)}',
                size: 12.5,
                color: scheme.onSurfaceVariant,
              ),
            const SizedBox(height: 6),
            Row(children: actions),
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// "Chat completo" (en Configuración): todo lo hablado, guardado en el
/// teléfono.
class ChatHistoryView extends StatelessWidget {
  const ChatHistoryView({
    super.key,
    required this.messages,
    required this.onClear,
  });

  final List<ChatEntry> messages;
  final VoidCallback onClear;

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar el chat?'),
        content: const Text(
          'Se borra solo la conversación. Los recordatorios quedan como están.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar chat'),
          ),
        ],
      ),
    );
    if (ok == true) onClear();
  }

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(child: Text('Todavía no hablamos.'));
    }
    final theme = Theme.of(context);
    final items = <Widget>[];
    DateTime? day;
    for (final m in messages) {
      final d = DateTime(m.at.year, m.at.month, m.at.day);
      if (d != day) {
        day = d;
        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                Fmt.day(d),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      }
      items.add(
        ChatBubble(text: m.text, mine: m.mine, error: m.error, at: m.at),
      );
    }
    items.add(
      Center(
        child: TextButton.icon(
          icon: const Icon(Icons.delete_sweep_outlined, size: 18),
          label: const Text('Borrar chat'),
          onPressed: () => _confirmClear(context),
        ),
      ),
    );
    return ListView(
      reverse: true,
      padding: const EdgeInsets.all(16),
      children: items.reversed.toList(),
    );
  }
}

/// Abajo de Mensaje: "O escribilo acá…" con el micrófono chico adentro y el
/// botón redondo para enviar.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.input,
    required this.busy,
    required this.dictatingIntoField,
    required this.onFieldMic,
    required this.onSend,
  });

  final TextEditingController input;
  final bool busy;
  final bool dictatingIntoField;
  final VoidCallback onFieldMic;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('chat-input'),
            controller: input,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            style: const TextStyle(fontSize: 15.5),
            decoration: InputDecoration(
              hintText: 'O escribilo acá…',
              isDense: true,
              filled: true,
              fillColor: theme.brightness == Brightness.dark
                  ? scheme.surfaceContainerHighest
                  : const Color(0xFFE6E7EE),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                tooltip: dictatingIntoField
                    ? 'Dejar de dictar'
                    : 'Dictar en el recuadro',
                icon: Icon(
                  dictatingIntoField ? Icons.stop_circle : Icons.mic_none,
                  color: dictatingIntoField ? scheme.error : null,
                ),
                onPressed: busy ? null : onFieldMic,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          height: 42,
          child: IconButton.filled(
            key: const Key('chat-send'),
            tooltip: 'Enviar',
            padding: EdgeInsets.zero,
            onPressed: busy ? null : onSend,
            icon: const Icon(Icons.send, size: 20),
          ),
        ),
      ],
    );
  }
}

/// Texto que, si no entra en [maxLines], termina en "…"; al tocarlo se ve
/// entero y al volver a tocarlo se cierra (pedido del usuario para los
/// mensajes largos, así la tarjeta del Chat entra siempre).
class TapToExpand extends StatefulWidget {
  const TapToExpand(this.text, {super.key, required this.maxLines, this.style});

  final String text;
  final int maxLines;
  final TextStyle? style;

  @override
  State<TapToExpand> createState() => _TapToExpandState();
}

class _TapToExpandState extends State<TapToExpand> {
  bool _open = false;

  @override
  void didUpdateWidget(TapToExpand old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _open = false;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => _open = !_open),
    child: AnimatedSize(
      duration: const Duration(milliseconds: 150),
      alignment: Alignment.topLeft,
      child: Text(
        widget.text,
        maxLines: _open ? null : widget.maxLines,
        overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
        style: widget.style,
      ),
    ),
  );
}

/// Un renglón de texto: si no entra, se achica la letra (hasta donde haga
/// falta) en vez de pasar al renglón de abajo.
class _OneLine extends StatelessWidget {
  const _OneLine(this.text, {required this.size, this.color});

  final String text;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(fontSize: size, color: color),
      ),
    ),
  );
}
