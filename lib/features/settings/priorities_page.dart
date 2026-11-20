import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../data/reminder.dart';
import '../../data/scheduling_reminder_repository.dart';
import '../notifications/notification_service.dart';
import '../notifications/notification_sound.dart';
import '../notifications/priority_config.dart';
import '../notifications/priority_sounds.dart';
import 'notifications_section.dart';

/// Color de cada prioridad (las ventanitas y los botones del Chat).
Color priorityColor(ReminderPriority p) => switch (p) {
  ReminderPriority.normal => const Color(0xFF2E8B57),
  ReminderPriority.media => const Color(0xFFC27A00),
  ReminderPriority.alta => const Color(0xFFC43C3C),
};

String _raw(String id) => 'android.resource://com.afelixc.recordame/raw/$id';

/// Resumen chico de lo que hace cada prioridad ("1 vez, no repite").
String prioritySummary(ReminderPriority p, PriorityConfig c) =>
    c.summary(p.index);

/// Consejo de cómo conviene usar cada prioridad.
String priorityTip(ReminderPriority p) => switch (p) {
  ReminderPriority.normal =>
    'Para la normal se aconseja que suene 1 o 2 veces y que no repita, o que '
        'repita poco.',
  ReminderPriority.media =>
    'Para la media se aconseja que repita con más frecuencia (cada 5 o 10 '
        'minutos) hasta que lo atiendas.',
  ReminderPriority.alta =>
    'Para la alta se aconseja que suene más veces seguidas (3 o más), que '
        'repita seguido y en pantalla completa, como una alarma.',
};

IconData _priorityIcon(ReminderPriority p) => switch (p) {
  ReminderPriority.normal => Icons.notifications_none,
  ReminderPriority.media => Icons.notifications_active_outlined,
  ReminderPriority.alta => Icons.alarm,
};

/// Notificaciones: "Tocá una prioridad para elegir cómo suena", con Normal,
/// Media, Alta (cada una abre sus opciones) y el Ejemplo.
class PrioritiesSection extends StatefulWidget {
  const PrioritiesSection({super.key, required this.service});

  final NotificationService service;

  @override
  State<PrioritiesSection> createState() => _PrioritiesSectionState();
}

class _PrioritiesSectionState extends State<PrioritiesSection> {
  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.service.priorities;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tocá una prioridad para elegir cómo suena',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        for (final p in ReminderPriority.values) ...[
          _PrioRow(
            key: Key('prio-${p.name}'),
            color: priorityColor(p),
            icon: _priorityIcon(p),
            title: p.label,
            subtitle: prioritySummary(p, c),
            onTap: () =>
                _open(PriorityPage(service: widget.service, priority: p)),
          ),
          const SizedBox(height: 10),
        ],
        _PrioRow(
          key: const Key('prio-ejemplo'),
          color: theme.brightness == Brightness.dark
              ? theme.colorScheme.primary
              : const Color(0xFF2C3A66),
          icon: Icons.phone_android,
          title: 'Ejemplo',
          subtitle: 'Cómo te llega un aviso',
          onTap: () => _open(const _ExamplePage()),
        ),
      ],
    );
  }
}

/// Un renglón de color: dibujo, nombre, resumen y la flechita.
class _PrioRow extends StatelessWidget {
  const _PrioRow({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Ejemplo": así te llega un aviso.
class _ExamplePage extends StatelessWidget {
  const _ExamplePage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ejemplo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Así te llega un aviso', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          const NotificationExample(),
          const SizedBox(height: 10),
          Text(
            'Tocá HECHO cuando lo hiciste; 1 HORA o MAÑANA lo posponen. '
            'Tocando el aviso también podés posponerlo 15 minutos.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Dibujo de cómo se ve un aviso, con sus botones.
class NotificationExample extends StatelessWidget {
  const NotificationExample({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Tres casilleros separados, del mismo ancho, con el texto centrado y en
    // un renglón (si no entra, la letra se achica). Así 1 HORA queda justo
    // en el medio entre HECHO y MAÑANA.
    Widget button(String t) => Expanded(
      child: Container(
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.primary.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            t,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Llamar al contador por los papeles del auto',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Text('Recordatorio · 10:00 h', style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            spacing: 8,
            children: [button('HECHO'), button('1 HORA'), button('MAÑANA')],
          ),
        ],
      ),
    );
  }
}

/// Opciones de una prioridad, en grande.
class PriorityPage extends StatefulWidget {
  const PriorityPage({
    super.key,
    required this.service,
    required this.priority,
  });

  final NotificationService service;
  final ReminderPriority priority;

  @override
  State<PriorityPage> createState() => _PriorityPageState();
}

class _PriorityPageState extends State<PriorityPage> {
  late PriorityConfig _c = widget.service.priorities;

  Future<void> _set(PriorityConfig c) async {
    setState(() => _c = c);
    final scope = AppScope.of(context);
    await widget.service.setPriorities(c);
    scope.settings.prioritiesRaw = c.encode();
    // Los avisos ya programados pasan a la configuración nueva.
    final repo = scope.reminders;
    if (repo is SchedulingReminderRepository) await repo.resync();
  }

  Future<void> _test() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final warning = await widget.service.showPriorityTest(widget.priority);
      if (warning != null && mounted) {
        showSoundWarning(
          context,
          warning,
          () => widget.service.showPriorityTest(widget.priority),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo: $e')));
    }
  }

  /// Elige un sonido del teléfono para la media o la alta.
  Future<void> _pickFromPhone({required bool alta}) async {
    final messenger = ScaffoldMessenger.of(context);
    final current = alta ? _c.altaPhoneUri : _c.mediaPhoneUri;
    try {
      final picked = await SoundPicker.pickFromPhone(current);
      if (picked == null || picked.uri == null) return;
      final uri = picked.uri!;
      if (alta) {
        final ms = await SoundPicker.duration(uri);
        await _set(
          _c.copyWith(
            altaSound: PriorityConfig.phoneSound,
            altaPhoneUri: uri,
            altaPhoneName: picked.name,
            altaPhoneMillis: ms ?? 3000,
          ),
        );
      } else {
        final ms = await SoundPicker.duration(uri);
        await _set(
          _c.copyWith(
            mediaSound: PriorityConfig.phoneSound,
            mediaPhoneUri: uri,
            mediaPhoneName: picked.name,
            mediaPhoneMillis: ms ?? 3000,
          ),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Este teléfono no deja elegir sonidos desde otra app.'),
        ),
      );
    }
  }

  /// "Elegir otro sonido del teléfono…", debajo de la lista de sonidos.
  Widget _phoneButton({required bool alta}) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(top: 4),
    shape: RoundedRectangleBorder(
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(10),
    ),
    child: ListTile(
      key: Key(alta ? 'alta-phone' : 'media-phone'),
      dense: true,
      leading: const Icon(Icons.library_music_outlined),
      title: const Text('Elegir un sonido del teléfono…'),
      subtitle: const Text('Tonos, alarmas y notificaciones'),
      onTap: () => _pickFromPhone(alta: alta),
    ),
  );

  @override
  void dispose() {
    SoundPicker.stop();
    super.dispose();
  }

  Widget _box(List<Widget> children) {
    final color = priorityColor(widget.priority);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _choice<T>(
    String label,
    T value,
    List<T> options,
    String Function(T) text,
    ValueChanged<T> onChanged, {
    Key? key,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(label, maxLines: 1),
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<T>(
          key: key,
          value: options.contains(value) ? value : options.first,
          items: [
            for (final o in options)
              DropdownMenuItem(value: o, child: Text(text(o))),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    ),
  );

  /// "Cuántas veces suena seguido": 1, 3, 5, hasta "Hecho" u otro número
  /// (de 1 a [PriorityConfig.maxTimes]).
  Widget _timesChoice(int value, ValueChanged<int> onChanged, {Key? key}) {
    const other = -1;
    final preset = PriorityConfig.timesOptions;
    final custom = value != 0 && !preset.contains(value);
    final options = [...preset, if (custom) value, 0, other];
    String text(int v) => v == 0
        ? 'Hasta Hecho'
        : v == other
        ? 'Otro…'
        : v == 1
        ? '1 vez'
        : '$v veces';
    return _choice<int>('Cuántas veces suena', value, options, text, (v) async {
      if (v != other) return onChanged(v);
      final picked = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text('¿Cuántas veces (1 a ${PriorityConfig.maxTimes})?'),
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var n = 1; n <= PriorityConfig.maxTimes; n++)
                  OutlinedButton(
                    key: Key('times-$n'),
                    onPressed: () => Navigator.of(ctx).pop(n),
                    child: Text('$n'),
                  ),
              ],
            ),
          ],
        ),
      );
      if (picked != null) onChanged(picked);
    }, key: key);
  }

  Widget _sounds(
    List<(String, String, String?)> sounds,
    String current,
    ValueChanged<String> onPick,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final (id, name, uri) in sounds)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 4),
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: id == current ? scheme.primary : scheme.outlineVariant,
                width: id == current ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(
                id == current
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: id == current ? scheme.primary : null,
              ),
              title: Text(name),
              trailing: IconButton(
                tooltip: 'Escuchar $name',
                icon: const Icon(Icons.play_circle_outline),
                onPressed: () => SoundPicker.play(uri),
              ),
              onTap: () {
                SoundPicker.play(uri);
                onPick(id);
              },
            ),
          ),
      ],
    );
  }

  static const _stops =
      'Se corta cuando tocás "Hecho". Si tocás "1 hora" o "Mañana", se calla '
      'y a esa hora vuelve a empezar a repetir.';

  String _hour(int h) => '${h.toString().padLeft(2, '0')}:00';

  Future<void> _testLater() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.scheduleTest(
        const Duration(seconds: 10),
        priority: widget.priority,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Te llega un aviso en 10 segundos. Podés cerrar la app.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.priority;
    final color = priorityColor(p);
    final c = _c;
    final example = DateTime(2026, 1, 1, 10);
    String times(List<DateTime> l) => l.isEmpty
        ? 'suena a esa hora y no repite'
        : 'repite a las ${l.take(5).map((t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}').join(' · ')}'
              '${l.length > 5 ? ' … (${l.length} veces)' : ''}';

    final (timesValue, every) = c.of(p.index);
    final repeats = switch (p) {
      ReminderPriority.normal => c.normalRepeats(example),
      ReminderPriority.media => c.mediaRepeats(example),
      ReminderPriority.alta => c.altaRepeats(example),
    };
    final name = p.name;
    final box = _box([
      _timesChoice(
        timesValue,
        (v) => _set(switch (p) {
          ReminderPriority.normal => c.copyWith(normalTimes: v),
          ReminderPriority.media => c.copyWith(mediaTimes: v),
          ReminderPriority.alta => c.copyWith(altaTimes: v),
        }),
        key: Key('$name-times'),
      ),
      _choice(
        'Repetir cada',
        every,
        p == ReminderPriority.alta
            ? PriorityConfig.altaEveryOptions
            : PriorityConfig.everyOptions,
        PriorityConfig.everyLabel,
        (v) => _set(switch (p) {
          ReminderPriority.normal => c.copyWith(normalEvery: v),
          ReminderPriority.media => c.copyWith(mediaEvery: v),
          ReminderPriority.alta => c.copyWith(altaEvery: v),
        }),
        key: Key('$name-every'),
      ),
      if (every != 0)
        switch (p) {
          ReminderPriority.normal => _choice(
            'Durante',
            c.normalFor,
            PriorityConfig.normalForOptions,
            PriorityConfig.forLabel,
            (v) => _set(c.copyWith(normalFor: v)),
            key: const Key('normal-for'),
          ),
          ReminderPriority.media => _choice<int>(
            'Durante',
            c.mediaInHours ? -1 : c.mediaFor,
            [...PriorityConfig.mediaForOptions, -1],
            (v) => v == -1 ? 'En un horario' : PriorityConfig.forLabel(v),
            (v) => _set(
              v == -1
                  ? c.copyWith(mediaInHours: true)
                  : c.copyWith(mediaInHours: false, mediaFor: v),
            ),
            key: const Key('media-for'),
          ),
          ReminderPriority.alta => _choice(
            'Durante',
            c.altaFor,
            PriorityConfig.altaForOptions,
            (v) => PriorityConfig.forLabel(v, alta: true),
            (v) => _set(c.copyWith(altaFor: v)),
            key: const Key('alta-for'),
          ),
        },
      if (p == ReminderPriority.media && every != 0 && c.mediaInHours) ...[
        _choice(
          'Desde',
          c.mediaFrom,
          [for (var h = 0; h < 24; h++) h],
          _hour,
          (v) => _set(c.copyWith(mediaFrom: v)),
        ),
        _choice(
          'Hasta',
          c.mediaTo,
          [for (var h = 1; h <= 24; h++) h],
          _hour,
          (v) => _set(c.copyWith(mediaTo: v)),
        ),
      ],
      if (p == ReminderPriority.alta) ...[
        SwitchListTile(
          key: const Key('alta-vibrate'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Vibrar fuerte'),
          value: c.altaVibrate,
          onChanged: (v) => _set(c.copyWith(altaVibrate: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pantalla completa, como alarma'),
          value: c.altaFullScreen,
          onChanged: (v) async {
            if (v) await widget.service.requestFullScreen();
            await _set(c.copyWith(altaFullScreen: v));
          },
        ),
      ] else
        SwitchListTile(
          key: Key('$name-vibrate'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Vibrar'),
          value: p == ReminderPriority.normal
              ? c.normalVibrate
              : c.mediaVibrate,
          onChanged: (v) => _set(
            p == ReminderPriority.normal
                ? c.copyWith(normalVibrate: v)
                : c.copyWith(mediaVibrate: v),
          ),
        ),
      Text(
        'Si es a las 10:00: ${times(repeats)}.'
        '${repeats.isEmpty ? '' : '\n$_stops'}',
        style: theme.textTheme.bodySmall,
      ),
    ]);

    final tip = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates_outlined, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(priorityTip(p), style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );

    final List<Widget> sound = switch (p) {
      ReminderPriority.normal => [
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            key: const Key('normal-sound'),
            leading: const Icon(Icons.music_note),
            title: Text(widget.service.soundName),
            subtitle: const Text('Tocá para cambiarlo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await showSoundPicker(context, widget.service);
              if (mounted) setState(() {});
            },
          ),
        ),
      ],
      ReminderPriority.media => [
        _sounds(
          [
            (
              PriorityConfig.appSound,
              'El de la app (${widget.service.soundName})',
              widget.service.soundUri,
            ),
            for (final s in mediaSounds) (s.id, s.name, _raw(s.id)),
            if (c.mediaPhoneUri != null)
              (
                PriorityConfig.phoneSound,
                'Del teléfono: ${c.mediaPhoneName ?? 'sonido elegido'}',
                c.mediaPhoneUri,
              ),
          ],
          c.mediaSound,
          (id) => _set(c.copyWith(mediaSound: id)),
        ),
        _phoneButton(alta: false),
      ],
      ReminderPriority.alta => [
        _sounds(
          [
            for (final s in altaSounds) (s.id, s.name, _raw(s.id)),
            if (c.altaPhoneUri != null)
              (
                PriorityConfig.phoneSound,
                'Del teléfono: ${c.altaPhoneName ?? 'sonido elegido'}',
                c.altaPhoneUri,
              ),
          ],
          c.altaSound,
          (id) => _set(c.copyWith(altaSound: id)),
        ),
        _phoneButton(alta: true),
      ],
    };

    final testStyle = FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    );
    final children = <Widget>[
      box,
      const SizedBox(height: 10),
      tip,
      const SizedBox(height: 14),
      Text(
        p == ReminderPriority.alta ? 'Musiquita' : 'Sonido',
        style: theme.textTheme.titleSmall,
      ),
      const SizedBox(height: 6),
      ...sound,
      const SizedBox(height: 14),
      Text('Probar', style: theme.textTheme.titleSmall),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: FilledButton(
              key: const Key('priority-test'),
              style: testStyle,
              onPressed: _test,
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Aviso ahora', maxLines: 1),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              key: const Key('priority-test-later'),
              style: testStyle,
              onPressed: _testLater,
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Aviso en 10 segundos', maxLines: 1),
              ),
            ),
          ),
        ],
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text('Prioridad ${p.label.toLowerCase()}')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: children),
      ),
    );
  }
}
