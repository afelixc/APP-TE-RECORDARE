import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';

import '../calendar_sync/device_calendar.dart';
import 'settings_screen.dart';

/// Abre el ajuste de Android para que no frene a Alerta Ya en segundo plano.
Future<void> openBatterySettings() async {
  try {
    await const AndroidIntent(
      action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
      data: 'package:com.afelixc.recordame',
    ).launch();
  } catch (_) {
    await const AndroidIntent(
      action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
    ).launch();
  }
}

Future<void> showBatteryHelp(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const BatteryHelpPage()));

/// "Evitar que el teléfono cierre la app": para qué sirve y cómo hacerlo.
class BatteryHelpPage extends StatefulWidget {
  const BatteryHelpPage({
    super.key,
    this.check = AndroidDeviceCalendar.batteryFree,
  });

  /// Si Android ya deja a Alerta Ya sin restricciones.
  final Future<bool> Function() check;

  @override
  State<BatteryHelpPage> createState() => _BatteryHelpPageState();
}

class _BatteryHelpPageState extends State<BatteryHelpPage>
    with WidgetsBindingObserver {
  bool? _free;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Al volver del ajuste de Android, ver si quedó bien.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final free = await widget.check();
    if (mounted) setState(() => _free = free);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final free = _free;
    final (color, bg, icon, title, detail) = switch (free) {
      true => (
        Colors.green.shade800,
        Colors.green.shade50,
        Icons.battery_full,
        'Listo ✓ Sin restricciones',
        'Android deja a Alerta Ya trabajar con la app cerrada.',
      ),
      false => (
        const Color(0xFF6B5418),
        const Color(0xFFFFF4D6),
        Icons.battery_alert,
        'Android puede frenar a Alerta Ya',
        'Para que no lo haga, tocá el botón de abajo.',
      ),
      null => (
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
        Icons.hourglass_top,
        'Revisando…',
        '',
      ),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Que no se cierre la app')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: color, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (detail.isNotEmpty)
                        Text(detail, style: TextStyle(color: color)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SettingsCard(
            title: '¿Para qué sirve?',
            children: [
              Text(
                'Para ahorrar batería, muchos teléfonos "duermen" a las apps '
                'que no estás usando. Si duermen a Alerta Ya:',
              ),
              _Bullet('Los avisos pueden llegar tarde o no llegar.'),
              _Bullet(
                'No se sincroniza con Google Calendar con la app cerrada: lo '
                'que anotes desde la compu no te avisa hasta que abras '
                'Alerta Ya.',
              ),
              Text(
                'Dejándolo "sin restricciones", Alerta Ya se despierta solo un '
                'momento cuando hace falta (un aviso o un cambio en el '
                'calendario). Casi no gasta batería.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('battery-open'),
            icon: const Icon(Icons.battery_saver_outlined),
            label: const Text('Abrir el ajuste de batería'),
            onPressed: openBatterySettings,
          ),
          const SizedBox(height: 6),
          Text(
            'Si aparece un cartel, tocá "Permitir". Si se abre una lista, '
            'buscá Alerta Ya y elegí "Sin restricciones" o "No optimizar".',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text('Según tu teléfono', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Algunas marcas tienen un ajuste más, aparte del de arriba:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          for (final (brand, steps) in _brands)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(brand),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final s in steps) _Bullet(s)],
            ),
        ],
      ),
    );
  }
}

const _brands = [
  (
    'Samsung',
    [
      'Ajustes → Aplicaciones → Alerta Ya → Batería → "Sin restricciones".',
      'Ajustes → Batería → Límites de uso en segundo plano: fijate que '
          'Alerta Ya NO esté en "Aplicaciones en suspensión".',
    ],
  ),
  (
    'Xiaomi, Redmi o POCO',
    [
      'Ajustes → Aplicaciones → Administrar aplicaciones → Alerta Ya → '
          'Ahorro de batería → "Sin restricciones".',
      'En la misma pantalla, prendé "Inicio automático".',
    ],
  ),
  (
    'Motorola',
    [
      'Ajustes → Aplicaciones → Alerta Ya → Batería → "Sin restricciones" '
          '(o "Uso de batería en segundo plano": permitir).',
    ],
  ),
  (
    'Huawei u Honor',
    [
      'Ajustes → Batería → Inicio de aplicaciones → Alerta Ya: apagá '
          '"Administrar automáticamente" y dejá prendidas las tres opciones.',
    ],
  ),
  (
    'Otra marca',
    [
      'Ajustes → Aplicaciones → Alerta Ya → Batería: elegí "Sin '
          'restricciones", "No optimizar" o parecido.',
    ],
  ),
];

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  '),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
