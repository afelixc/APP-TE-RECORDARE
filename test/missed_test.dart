import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:recordame/app.dart';
import 'package:recordame/core/settings.dart';
import 'package:recordame/data/memory_reminder_repository.dart';
import 'package:recordame/data/reminder.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_AR'));

  testWidgets('los vencidos sin responder salen en un cartelito rojo y se '
      'responden con Hecho / 1 hora / Mañana', (tester) async {
    final now = DateTime.now();
    final repo = MemoryReminderRepository([
      Reminder(
        title: 'Llamar a Juan',
        dueAt: now.subtract(const Duration(hours: 2)),
      ),
      Reminder(
        title: 'Pagar la luz',
        dueAt: now.subtract(const Duration(days: 1)),
      ),
      Reminder(title: 'Lavar el auto', dueAt: now.add(const Duration(days: 2))),
    ]);
    final settings = AppSettings(MemorySettingsStore(), MemoryKeyStore());
    await tester.pumpWidget(RecordameApp(reminders: repo, settings: settings));
    await tester.pumpAndSettle();

    expect(find.text('Te quedaron 2 sin responder'), findsOneWidget);
    await tester.tap(find.byKey(const Key('missed-banner')));
    await tester.pumpAndSettle();
    expect(find.text('Pagar la luz'), findsOneWidget);
    expect(find.text('Lavar el auto'), findsNothing);

    final all = await repo.watchAll().first;
    final luz = all.firstWhere((r) => r.title == 'Pagar la luz').id;
    final juan = all.firstWhere((r) => r.title == 'Llamar a Juan').id;
    await tester.tap(find.byKey(Key('missed-done-$luz')));
    await tester.pumpAndSettle();
    expect((await repo.getById(luz!))!.done, isTrue);
    expect(find.text('Te quedó 1 sin responder'), findsWidgets);

    await tester.tap(find.byKey(Key('missed-snooze_1h-$juan')));
    await tester.pumpAndSettle();
    expect((await repo.getById(juan!))!.dueAt.isAfter(now), isTrue);
    // Con el último respondido la hoja se cierra y el cartelito se va.
    expect(find.byKey(const Key('missed-banner')), findsNothing);
    expect(find.byKey(Key('missed-done-$juan')), findsNothing);
  });

  testWidgets('salir de la app y volver arranca en Mensaje, salvo en '
      'Configuración', (tester) async {
    final settings = AppSettings(MemorySettingsStore(), MemoryKeyStore());
    await tester.pumpWidget(
      RecordameApp(reminders: MemoryReminderRepository(), settings: settings),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manual-entry')), findsNothing);

    await tester.tap(find.byKey(const Key('tab-Listado')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pick-many')), findsOneWidget);
    _leaveAndCome(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pick-many')), findsNothing);

    // En Configuración se queda donde estaba.
    await tester.tap(find.byKey(const Key('top-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configuración').last);
    await tester.pumpAndSettle();
    expect(find.text('Modo de uso'), findsWidgets);
    _leaveAndCome(tester);
    await tester.pumpAndSettle();
    expect(find.text('Modo de uso'), findsWidgets);
  });
}

void _leaveAndCome(WidgetTester tester) {
  for (final st in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(st);
  }
}
