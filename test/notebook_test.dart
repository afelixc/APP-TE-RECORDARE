import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:recordame/core/settings.dart';
import 'package:recordame/data/memory_reminder_repository.dart';
import 'package:recordame/features/notebook/notes.dart';
import 'package:recordame/features/notes/boxes.dart';
import 'package:recordame/features/notes/note_editor.dart';
import 'package:recordame/features/notes/notes_screen.dart';
import 'package:recordame/features/notes/tasks_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_AR'));
  test('cuenta lo que falta hacer, con los ítems de adentro', () {
    final at = DateTime(2026);
    final f = NoteFolder(
      'Casa',
      items: [
        NoteItem(
          'Compras',
          at: at,
          sub: const [
            SubItem('pan', done: true),
            SubItem('leche'),
            SubItem('vino'),
          ],
        ),
        NoteItem('Llamar al plomero', at: at),
        NoteItem('Ya está', at: at, done: true),
        NoteItem(
          'Lista tildada',
          at: at,
          sub: const [SubItem('a', done: true)],
        ),
      ],
    );
    expect(f.toDo, 4);
    expect(notebookToDo([f, NoteFolder('Vacía')]), 4);
    expect(toDoLabel(0), 'Todo hecho ✓');
    expect(toDoLabel(4), '4 pendientes');
    expect(toDoLabel(1), '1 pendiente');
  });

  test('separa lo dictado en renglones', () {
    expect(
      splitNotes(
        'cargame estos ítems uno llamar al contador dos comprar tornillos '
        'tres pagar la luz',
      ),
      ['Llamar al contador', 'Comprar tornillos', 'Pagar la luz'],
    );
    expect(
      splitNotes(
        'me faltó llevar el auto al taller y también pedir presupuesto de chapa',
      ),
      ['Llevar el auto al taller', 'Pedir presupuesto de chapa'],
    );
    expect(splitNotes('1. pan\n2. leche'), ['Pan', 'Leche']);
    expect(splitNotes('Pasar por lo de Juan'), ['Pasar por lo de Juan']);
    // "una" dentro de la frase no corta: solo al principio de un ítem.
    expect(splitNotes('comprar una lámpara'), ['Comprar una lámpara']);
    // Contar en orden: "dos kilos" no corta.
    expect(splitNotes('comprar dos kilos de pan'), [
      'Comprar dos kilos de pan',
    ]);
    expect(splitNotes('primero ir al banco segundo comprar dos sillas'), [
      'Ir al banco',
      'Comprar dos sillas',
    ]);
  });

  test('la libreta de antes pasa a la carpeta General', () async {
    final store = MemorySettingsStore();
    await store.write(
      'libreta',
      '[{"t":"Pan","d":true,"at":"2026-11-01T10:00:00"},'
          '{"t":"Leche","at":"2026-11-01T10:00:00"}]',
    );
    final s = AppSettings(store, MemoryKeyStore());
    await s.load(const ['claude']);
    expect(s.folders.single.name, 'General');
    expect(s.folders.single.items.map((n) => n.text), ['Leche', 'Pan']);
  });

  test('cuenta hasta 10 cosas dictadas', () {
    expect(
      splitNotes(
        'uno pan dos leche tres huevos cuatro yerba cinco azúcar seis fideos '
        'siete arroz ocho aceite nueve sal diez café',
      ),
      [
        'Pan',
        'Leche',
        'Huevos',
        'Yerba',
        'Azúcar',
        'Fideos',
        'Arroz',
        'Aceite',
        'Sal',
        'Café',
      ],
    );
  });

  test(
    'la Libreta vieja pasa sola a Notas y Tareas, sin perder nada',
    () async {
      final store = MemorySettingsStore();
      final at = DateTime(2026, 1, 2);
      await store.write(
        'libreta',
        NoteFolder.encodeAll([
          NoteFolder(
            'Casa',
            color: 0xFF2F6FB3,
            items: [
              NoteItem('Pintar la reja', at: at),
              NoteItem('Sacar la basura', at: at, done: true),
              NoteItem(
                'Compras',
                at: at,
                sub: const [SubItem('pan', done: true), SubItem('leche')],
              ),
            ],
            memos: [
              Memo(title: 'Wi-Fi', text: 'Red: Casa\nClave abajo', at: at),
            ],
          ),
          NoteFolder('Vacía'),
        ]),
      );
      final s = AppSettings(store, MemoryKeyStore());
      await s.load(const []);
      expect(s.taskFolders.map((f) => f.name), ['Casa', 'Vacía']);
      expect(s.taskFolders.first.color, 'azul');
      expect(s.tasks.map((t) => (t.name, t.done)), [
        ('Pintar la reja', false),
        ('Sacar la basura', true),
      ]);
      final folder = s.notes.firstWhere((n) => n.folder);
      expect(folder.name, 'Casa');
      final compras = s.notes.firstWhere((n) => n.name == 'Compras');
      expect(compras.parent, folder.id);
      expect(compras.pendingChecks, 1);
      final wifi = s.notes.firstWhere((n) => n.name == 'Wi-Fi');
      expect(wifi.lines.map((l) => l.text), ['Red: Casa', 'Clave abajo']);
      expect(notesBadge(s.notes), 1);
      expect(s.tasksToDo, 1);
      // Se guarda: al volver a abrir no se repite.
      final again = AppSettings(store, MemoryKeyStore());
      await again.load(const []);
      expect(again.tasks.length, 2);
      expect(again.notes.length, s.notes.length);
      // Y va en la copia.
      expect(s.exportPrefs(const []).keys, containsAll(['notas', 'tareas']));
    },
  );

  test('número rojo de Notas: las de afuera con algo sin tildar', () {
    final f = NoteBox(folder: true, name: 'Casa');
    final all = [
      f,
      NoteBox(
        folder: false,
        name: 'a',
        parent: f.id,
        lines: const [NoteLine('x', check: false), NoteLine('y', check: false)],
      ),
      NoteBox(
        folder: false,
        name: 'b',
        lines: const [NoteLine('z', check: true)],
      ),
      NoteBox(
        folder: false,
        name: 'c',
        lines: const [NoteLine('w', check: false)],
      ),
    ];
    // Casa (2 casillas) y "c": 2, no la cantidad de casillas.
    expect(notesBadge(all), 2);
    final back = NoteBox.decodeAll(NoteBox.encodeAll(all));
    expect(back[1].lines.first.check, false);
    expect(back[1].parent, f.id);
  });

  testWidgets('Notas: crear carpeta y nota adentro; lo último arriba', (
    tester,
  ) async {
    final s = AppSettings(MemorySettingsStore(), MemoryKeyStore());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NotesScreen(settings: s)),
      ),
    );
    expect(find.textContaining('Acá no hay nada todavía'), findsOneWidget);
    await tester.tap(find.byKey(const Key('notes-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva carpeta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('box-name')), 'Casa');
    await tester.tap(find.byKey(const Key('box-save')));
    await tester.pumpAndSettle();
    expect(s.notes.single.folder, true);
    expect(s.notes.single.color, 'verde');
    await tester.tap(find.text('Casa'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('folder-back')), findsOneWidget);
    // Adentro de una carpeta solo se crean notas: sin filtro ni menú.
    expect(
      find.text('Todavía no hay notas acá.\nTocá + para crear una nota.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('notes-filter')), findsNothing);
    await tester.tap(find.byKey(const Key('notes-add')));
    await tester.pumpAndSettle();
    expect(find.text('Nueva carpeta'), findsNothing);
    expect(find.byKey(const Key('note-title-field')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('note-title-field')), 'Pan');
    await tester.tap(find.byKey(const Key('note-back')));
    await tester.pumpAndSettle();
    expect(s.notes.where((n) => !n.folder).single.parent, s.notes.first.id);
    s.notes.removeWhere((n) => !n.folder);
    await s.saveNoteBoxes();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('folder-back')));
    await tester.pumpAndSettle();
    expect(find.text('Casa'), findsOneWidget);
    // Una nota suelta, más nueva: va arriba.
    s.notes.add(NoteBox(folder: false, name: 'Ideas'));
    await s.saveNoteBoxes();
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Ideas')).dx,
      lessThan(tester.getTopLeft(find.text('Casa')).dx),
    );
    expect(find.text('Nota'), findsOneWidget);
    // Filtro: solo carpetas.
    await tester.tap(find.byKey(const Key('notes-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Solo carpetas'));
    await tester.pumpAndSettle();
    expect(find.text('Ideas'), findsNothing);
    expect(find.text('Casa'), findsOneWidget);
  });

  testWidgets('editor: casilla, Enter sigue con casilla, negrita y tamaño', (
    tester,
  ) async {
    final s = AppSettings(MemorySettingsStore(), MemoryKeyStore());
    final n = NoteBox(folder: false);
    s.notes.add(n);
    await tester.pumpWidget(
      MaterialApp(
        home: NoteEditor(settings: s, note: n, isNew: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('note-title-field')), 'Súper');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tool-cb')));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byKey(const Key('note-body')),
      matching: find.byType(TextField),
    );
    await tester.enterText(field.first, '​Pan\nLeche');
    await tester.pumpAndSettle();
    expect(n.name, 'Súper');
    expect(n.lines.map((l) => (l.text, l.check)), [
      ('Pan', false),
      ('Leche', false),
    ]);
    await tester.tap(find.byKey(const Key('note-check-0')));
    await tester.pumpAndSettle();
    // La tildada baja al final, abajo de las que faltan.
    expect(n.lines.map((l) => (l.text, l.check)), [
      ('Leche', false),
      ('Pan', true),
    ]);
    expect(n.pendingChecks, 1);
    await tester.tap(find.byKey(const Key('tool-neg')));
    await tester.pumpAndSettle();
    expect(n.lines.first.bold, true);
    await tester.tap(find.byKey(const Key('tool-tam')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('size-grande')));
    await tester.pumpAndSettle();
    expect(n.lines.first.size, LineSize.grande);
    // Borrar la marca del principio junta el renglón con el de arriba.
    await tester.enterText(field.last, 'Pan');
    await tester.pumpAndSettle();
    expect(n.lines.map((l) => l.text), ['LechePan']);
  });

  testWidgets('Notas: borrar carpeta con notas pide 3 pasos y se deshace', (
    tester,
  ) async {
    final s = AppSettings(MemorySettingsStore(), MemoryKeyStore());
    final f = NoteBox(folder: true, name: 'Alejandro');
    s.notes
      ..add(f)
      ..add(NoteBox(folder: false, name: 'Uno', parent: f.id))
      ..add(NoteBox(folder: false, name: 'Dos', parent: f.id));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NotesScreen(settings: s)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('note-folder-Alejandro')),
        matching: find.byIcon(Icons.settings),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gear-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gear-delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('adentro tenés 2 notas'), findsOneWidget);
    await tester.tap(find.byKey(const Key('folder-delete-ok')));
    await tester.pumpAndSettle();
    expect(s.notes, isEmpty);
    expect(find.text('Deshacer'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(s.notes.length, 3);
    expect(find.text('Alejandro'), findsOneWidget);
  });

  testWidgets('editor: borrar solo las tildadas y deshacer', (tester) async {
    final s = AppSettings(MemorySettingsStore(), MemoryKeyStore());
    final n = NoteBox(
      folder: false,
      name: 'Súper',
      lines: [
        const NoteLine('Pan', check: false),
        const NoteLine('Leche', check: true),
        const NoteLine('Queso', check: true),
      ],
    );
    s.notes.add(n);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditor(settings: s, note: n),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('note-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Borrar solo las tildadas (2)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('note-delete-checked')));
    await tester.pumpAndSettle();
    expect(n.lines.map((l) => l.text), ['Pan']);
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(n.lines.map((l) => l.text), ['Pan', 'Leche', 'Queso']);
    // Ordenar de la A a la Z: las que faltan arriba, las tildadas abajo.
    await tester.tap(find.byKey(const Key('note-sort')));
    await tester.pumpAndSettle();
    expect(n.lines.map((l) => l.text), ['Pan', 'Leche', 'Queso']);
  });

  testWidgets('Tareas: borrar carpeta con tareas pide 3 pasos y se deshace', (
    tester,
  ) async {
    final s = AppSettings(MemorySettingsStore(), MemoryKeyStore());
    final f = TaskFolder(name: 'Casa');
    s.taskFolders.add(f);
    await s.addTasks(f, ['Pintar', 'Barrer']);
    final repo = MemoryReminderRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TasksScreen(settings: s, reminders: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Casa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-folder-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-folder-delete')));
    await tester.pumpAndSettle();
    expect(find.textContaining('adentro tenés 2 tareas'), findsOneWidget);
    await tester.tap(find.byKey(const Key('folder-delete-cancel')));
    await tester.pumpAndSettle();
    expect(s.taskFolders.length, 1);
    await tester.tap(find.byKey(const Key('task-folder-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-folder-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('folder-delete-ok')));
    await tester.pumpAndSettle();
    expect(s.taskFolders, isEmpty);
    expect(s.tasks, isEmpty);
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(s.taskFolders.single.name, 'Casa');
    expect(s.tasks.map((t) => t.name), ['Pintar', 'Barrer']);
  });

  testWidgets('Tareas: carpeta, agregar, archivar, volver y borrar', (
    tester,
  ) async {
    final s = AppSettings(MemorySettingsStore(), MemoryKeyStore());
    final repo = MemoryReminderRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TasksScreen(settings: s, reminders: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Todavía no hay carpetas'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tasks-new-folder')));
    await tester.pumpAndSettle();
    // La muestra cambia en vivo con el nombre.
    expect(
      find.descendant(
        of: find.byKey(const Key('box-sample')),
        matching: find.text('Carpeta nueva'),
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const Key('box-name')), 'Casa');
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('box-sample')),
        matching: find.text('Casa'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('box-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Casa'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('notebook-input')),
      'uno pintar la reja dos sacar la basura',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('notebook-send')));
    await tester.pumpAndSettle();
    expect(s.tasks.map((t) => t.name), ['Pintar la reja', 'Sacar la basura']);
    expect(find.text('PARA HACER (2)'), findsOneWidget);
    expect(s.tasksToDo, 2);
    // Bajar la primera.
    await tester.tap(find.byKey(const Key('task-gear-Pintar la reja')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-down')));
    await tester.pumpAndSettle();
    expect(s.tasks.first.name, 'Sacar la basura');
    // Archivar: baja a Completadas.
    await tester.tap(find.byKey(const Key('task-archive')));
    await tester.pumpAndSettle();
    expect(s.tasks.firstWhere((t) => t.name == 'Pintar la reja').done, true);
    expect(find.text('COMPLETADAS (1)'), findsOneWidget);
    // Desde ahí vuelve a Para hacer.
    await tester.tap(find.byKey(const Key('task-gear-Pintar la reja')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-unarchive')));
    await tester.pumpAndSettle();
    expect(s.tasksToDo, 2);
    // Borrar: hay que tocar dos veces.
    await tester.tap(find.byKey(const Key('task-gear-Sacar la basura')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-delete')));
    await tester.pumpAndSettle();
    expect(s.tasks.length, 2);
    await tester.tap(find.byKey(const Key('task-delete')));
    await tester.pumpAndSettle();
    expect(s.tasks.map((t) => t.name), ['Pintar la reja']);
    // Tildar la casilla también la completa.
    await tester.tap(find.byKey(const Key('task-check-Pintar la reja')));
    await tester.pumpAndSettle();
    expect(s.tasksToDo, 0);
  });

  testWidgets('Tareas: programar para que suene crea el recordatorio', (
    tester,
  ) async {
    final s = AppSettings(MemorySettingsStore(), MemoryKeyStore());
    final f = TaskFolder(name: 'General');
    s.taskFolders.add(f);
    await s.addTasks(f, ['Pagar el gas']);
    final repo = MemoryReminderRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TasksScreen(settings: s, reminders: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('General'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-gear-Pagar el gas')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-ring')));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué día y hora te aviso?'), findsOneWidget);
    await tester.tap(find.text('Mañana 9:00'));
    await tester.tap(find.byKey(const Key('ring-save')));
    await tester.pumpAndSettle();
    final r = (await repo.watchAll().first).single;
    expect(r.title, 'Pagar el gas');
    expect(r.dueAt.hour, 9);
    expect(s.tasks.single.reminderId, r.id);
    // Archivarla da por hecho el recordatorio.
    await tester.tap(find.byKey(const Key('task-gear-Pagar el gas')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-archive')));
    await tester.pumpAndSettle();
    expect((await repo.getById(r.id!))!.done, true);
  });

  testWidgets(
    'Tareas: recuadros iguales, nombre entero y pendientes alineados',
    (tester) async {
      tester.view.physicalSize = const Size(780, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final s = AppSettings(MemorySettingsStore(), MemoryKeyStore());
      final now = DateTime.now();
      final general = TaskFolder(name: 'General', created: now);
      final impresiones = TaskFolder(
        name: 'Impresiones',
        created: now.subtract(const Duration(minutes: 1)),
      );
      s.taskFolders.addAll([general, impresiones]);
      await s.addTasks(general, [for (var i = 0; i < 7; i++) 'Tarea $i']);
      await s.addTasks(impresiones, ['Una']);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TasksScreen(
              settings: s,
              reminders: MemoryReminderRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final a = tester.getRect(find.byKey(const Key('task-folder-General')));
      final b = tester.getRect(
        find.byKey(const Key('task-folder-Impresiones')),
      );
      expect(a.height, b.height);
      // "Impresiones" en un renglón: mismo alto que "General".
      final t1 = tester.getRect(find.text('General'));
      final t2 = tester.getRect(find.text('Impresiones'));
      expect(t2.height, closeTo(t1.height, 0.5));
      final p7 = tester.getRect(find.text('7 pendientes'));
      final p1 = tester.getRect(find.text('1 pendiente'));
      expect(p7.center.dy, closeTo(p1.center.dy, 0.5));
      expect(a.bottom - p7.bottom, lessThan(20));
    },
  );

  testWidgets('Tareas: todas del mismo alto; la larga se abre entera', (
    tester,
  ) async {
    final s = AppSettings(MemorySettingsStore(), MemoryKeyStore());
    final f = TaskFolder(name: 'Claude');
    s.taskFolders.add(f);
    const long =
        'Agente para que estén monitoreando todas las conversaciones y vaya '
        'dejando un historial limpito que lo vaya guardando';
    await s.addTasks(f, [long, 'Corta']);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TasksScreen(settings: s, reminders: MemoryReminderRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claude'));
    await tester.pumpAndSettle();
    final a = tester.getSize(find.byKey(const Key('task-$long')));
    final b = tester.getSize(find.byKey(const Key('task-Corta')));
    expect(a.height, b.height);
    await tester.tap(find.byKey(const Key('task-open-$long')));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byKey(const Key('task-full')));
    expect(field.controller!.text, long);
    await tester.enterText(find.byKey(const Key('task-full')), 'Agente nuevo');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(s.tasks.first.name, 'Agente nuevo');
  });

  testWidgets('Tareas: el nombre largo de la carpeta se ve entero', (
    tester,
  ) async {
    final s = AppSettings(MemorySettingsStore(), MemoryKeyStore());
    const long = 'Claude y cosas para revisar de la compu';
    s.taskFolders.addAll([TaskFolder(name: long), TaskFolder(name: 'General')]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TasksScreen(settings: s, reminders: MemoryReminderRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final p = tester.renderObject<RenderParagraph>(find.text(long));
    expect(p.didExceedMaxLines, isFalse);
    final a = tester.getSize(find.byKey(const Key('task-folder-$long')));
    final b = tester.getSize(find.byKey(const Key('task-folder-General')));
    expect(a.height, b.height);
  });
}
