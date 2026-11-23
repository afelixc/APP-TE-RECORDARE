# Resumen de sesión
_Última actualización: 2026-11-23_

## Objetivo
App Android (Flutter) **Alerta Ya** (antes Te Recordaré / Recordame): pasar a la app la maqueta "Alerta Ya"
(Mensaje, Notas, Tareas, barra de 5 botones) y lo que se había hecho en la "versión minimalista" del chat anterior.

## Contexto clave
- Repo `afelixc/APP-TE-RECORDARE`; rama de trabajo `claude/gifted-dijkstra-mgq7ob` (el usuario autorizó pasar a `main` cada cambio). Cada push a `main` arma el APK
  (versión que ve el usuario = (N − 55) / 10; ejecución 93 = versión 3.8). Reglas completas en `CLAUDE.md`.
- Antes de subir: `flutter analyze` y `flutter test` sin errores (131 pruebas; en esta sesión no había Flutter y una prueba vieja rompió la compilación 92: correr las pruebas o mirar el resultado en Actions antes de dar por publicado).
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
- Notas con casillas: al tildar, el renglón baja al final de su bloque de casillas (queda arriba de las tildadas); al destildar sube — pedido del usuario.
- Nombre "Alerta Ya" en todos los textos y `android:label` — lo eligió el usuario. Se mantienen `Recordame.apk`,
  `applicationId`, paquete `recordame`.
- La Libreta se pasa sola a Notas y Tareas (`migrateNotebook`) — eligió el usuario "pasarlo solo".
- Configuración y Ejemplos van en el menú ⋮; el chat completo en Configuración → "Chat completo".
- Recuadros de Notas/Tareas: mismo alto (`boxCardHeight`, 176) y "pendientes" abajo alineado — pedido del usuario.
- Prioridad con 3 puntitos (elegido más grande con anillo negro) — como en la versión minimalista.
- Notificaciones como la minimalista: Normal/Media/Alta/Ejemplo; la normal también tiene veces/repetir/durante/vibrar;
  "No repetir" en todas; "Aviso en 10 segundos".
- Editor de notas sin botón de mayúsculas — pedido del usuario.
- Tareas adentro de una carpeta: todas del mismo alto (2 renglones con "…"); tocarlas abre `TaskPage` con el texto
  entero — pedido del usuario.
- Nombre de los recuadros: entero en hasta 3 renglones, sin partir palabras, misma letra en todos (20 a 12) — pedido.
- Almanaque: mes en un renglón y letras de los días pegadas al mes — pedido del usuario.

## Hecho
- Sesión 2026-11-23 (versión 3.8, ejecución 93, en `main`): en `note_editor.dart` tildadas abajo (`_toggleCheck`), botón A-Z `note-sort` (`_sortAlpha`), botón lamparita `note-awake` (pantalla prendida; canal `recordame/pantalla` en `MainActivity.kt`, se suelta al salir). Ajustada la prueba en `test/notebook_test.dart`. Falta sumar esto a `CLAUDE.md`.
- Versiones subidas a `main` con APK armado: 3.2 (Alerta Ya, Mensaje, Notas, Tareas, migración, v1.0.87),
  3.3 (puntitos, notificaciones minimalistas, recuadros iguales, v1.0.88), 3.4 (tareas mismo alto + `TaskPage`,
  almanaque compacto, v1.0.89), 3.5 (nombres de carpeta en hasta 3 renglones, número rojo más adentro, v1.0.90).
  `CLAUDE.md` actualizado con cada una.
- Si el armado falla con 429 / "Could not resolve" de Maven: es pasajero; se relanza con
  `gh api -X POST repos/afelixc/APP-TE-RECORDARE/actions/runs/<id>/rerun-failed-jobs` (pasó en la 3.4 y la 3.5).

## En curso / Problemas abiertos
- Falta que el usuario pruebe la 3.8 (tildadas abajo, A-Z, lamparita; la ejecución 92 falló y la 93 salió bien) y la 3.5 en el teléfono, y Notificaciones / prioridad Normal repitiendo
  ("Aviso en 10 segundos"), que no se pueden ver en la compu.
- De la minimalista pueden faltar detalles chicos no verificados (textos como "Plan gratis · tocá para usar la IA",
  registro de acciones "Hecho ✓: … (desde la notificación)" en el chat completo).
- Listado quedó como estaba (no se comparó a fondo con la minimalista).

## Próximos pasos
0. Anotar la versión 3.8 en `CLAUDE.md`.
1. Preguntar cómo quedó la 3.8 y la 3.5 en el teléfono y corregir lo que pida.
2. Si hace falta, comparar Almanaque, Listado y Chat completo con la versión minimalista (artefacto P6bQ…).
3. Mostrar cada cambio primero (maqueta o fotos) y recién después subir a `main`.
