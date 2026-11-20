# Resumen de sesión
_Última actualización: 2026-11-20_

## Objetivo
App Android (Flutter) **Alerta Ya** (antes Te Recordaré / Recordame): pasar a la app la maqueta "Alerta Ya"
(Mensaje, Notas, Tareas, barra de 5 botones) y lo que se había hecho en la "versión minimalista" del chat anterior.

## Contexto clave
- Repo `afelixc/APP-TE-RECORDARE`; rama de trabajo `claude/relaxed-mayer-wla80d`. Cada push a `main` arma el APK
  (versión que ve el usuario = (N − 55) / 10; ejecución 88 = versión 3.3). Reglas completas en `CLAUDE.md`.
- Antes de subir: `flutter analyze` y `flutter test` sin errores (hoy 129 pruebas pasan).
- Flutter no viene en el contenedor: se bajó la 3.47.9 (la del workflow) a `~/flutter`
  (hizo falta `git config --global --add safe.directory /root/flutter`).
- Vista web para fotos: `flutter build web --no-tree-shake-icons --no-web-resources-cdn` + servidor local + Playwright.
  En la web Notificaciones no se abre (sin servicio) y el Mensaje con IA no se ve (sin clave).
- Maquetas/artefactos: "Alerta Ya" (HTML) https://claude.ai/artifact/2oSMvCH5t242ueCqT5kYzR (copia en
  `docs/maqueta-alerta-ya.html`, pedido en `docs/pedido-alerta-ya.md`); "versión minimalista" (app compilada, sin código)
  https://claude.ai/artifact/P6bQTpX1cHU27ytukgGKUC; "Alerta Ya · Notas" https://claude.ai/artifact/5XyzEDbDgtVG1ufEQQ6KFR.
- Archivos nuevos: `lib/features/notes/` (`boxes.dart` modelos + migración, `box_widgets.dart` recuadros,
  `notes_screen.dart`, `note_editor.dart`, `tasks_screen.dart`), `lib/features/home/top_bar.dart`.
- Tocados: `home_shell.dart` (`_BottomBar`), `chat/ai_chat.dart` y `chat_screen.dart` (Mensaje),
  `reminders/priority_chooser.dart` (puntitos), `settings/priorities_page.dart`, `notifications_section.dart`,
  `notifications/priority_config.dart` y `notification_service.dart` (normal repite), `core/settings.dart`.
- Usuario: no programador, habla rioplatense; quiere ver los cambios antes y cuidado con detalles visuales.

## Decisiones tomadas
- Nombre "Alerta Ya" en todos los textos y `android:label` — lo eligió el usuario. Se mantienen `Recordame.apk`,
  `applicationId`, paquete `recordame`.
- La Libreta se pasa sola a Notas y Tareas (`migrateNotebook`) — eligió el usuario "pasarlo solo".
- Configuración y Ejemplos van en el menú ⋮; el chat completo en Configuración → "Chat completo".
- Recuadros de Notas/Tareas: mismo alto, nombre en 1 renglón con la misma letra (hasta 20; los que necesitarían
  < 15 se cortan con "…"), "pendientes" abajo alineado — pedido del usuario.
- Prioridad con 3 puntitos (elegido más grande con anillo negro) — como en la versión minimalista.
- Notificaciones como la minimalista: Normal/Media/Alta/Ejemplo; la normal también tiene veces/repetir/durante/vibrar;
  "No repetir" en todas; "Aviso en 10 segundos".
- Editor de notas sin botón de mayúsculas — pedido del usuario.

## Hecho
- Versión 3.2 (Alerta Ya, Mensaje, Notas, Tareas, migración) y 3.3 (ajustes de arriba) subidas a `main`;
  ambos APK se armaron bien (releases v1.0.87 y v1.0.88). `CLAUDE.md` actualizado.

## En curso / Problemas abiertos
- Falta que el usuario pruebe la 3.3 en el teléfono, sobre todo Notificaciones y la prioridad Normal repitiendo
  ("Aviso en 10 segundos").
- De la minimalista pueden faltar detalles chicos no verificados (textos como "Plan gratis · tocá para usar la IA",
  registro de acciones "Hecho ✓: … (desde la notificación)" en el chat completo).
- Almanaque y Listado quedaron como estaban (no se comparó a fondo con la minimalista).

## Próximos pasos
1. Preguntar cómo quedó la 3.3 en el teléfono y corregir lo que pida.
2. Si hace falta, comparar Almanaque, Listado y Chat completo con la versión minimalista (artefacto P6bQ…).
3. Mostrar cada cambio primero (maqueta o fotos) y recién después subir a `main`.
