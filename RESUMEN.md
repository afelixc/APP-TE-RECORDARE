# Resumen de sesión
_Última actualización: 2026-11-27_

## Objetivo
App Android (Flutter) **Alerta Ya** (antes Te Recordaré / Recordame). Esta sesión: achicar los recuadros
de Notas/Tareas, emparejar la barra de abajo y poner "Sonar en silencio" en un renglón.
Última versión publicada: **4.4** (ejecución 99, release v1.0.99, armado OK).

## Contexto clave
- Repo `afelixc/APP-TE-RECORDARE`; rama de trabajo `claude/loving-sagan-f1bbz4`. El usuario autoriza pasar a `main`
  cuando lo pide ("subila"). Cada push a `main` arma el APK (versión = (N − 55) / 10). Reglas completas en `CLAUDE.md`.
- Antes de subir: `flutter analyze` y `flutter test` (hoy 138 pruebas pasan).
- Flutter no viene en el contenedor: bajar la 3.47.9 (tar de storage.googleapis.com) a `/opt/flutter` y
  `git config --global --add safe.directory /opt/flutter`.
- Si el armado en GitHub falla con "Could not resolve" de Maven: es pasajero, relanzar con
  `gh api -X POST repos/afelixc/APP-TE-RECORDARE/actions/runs/<id>/rerun-failed-jobs`.
- App para tocar en el navegador (datos de ejemplo en `main.dart`):
  `flutter build web --no-tree-shake-icons --no-web-resources-cdn --pwa-strategy=none`; publicar con una página
  propia (`build/web/pagina.html` que carga `flutter_bootstrap.js`), sin `AssetManifest.bin`, `*.symbols`, skwasm,
  wimp, webparagraph; `assets/NOTICES` y `*.frag` con contentType `text/plain`.
  Artefacto (al día con la 4.4): https://claude.ai/artifact/9EbqUx4UHwwMAo98dLFJUN
- Archivos tocados: `lib/features/notes/box_widgets.dart` (`BoxCard`, `boxNameSize`, `_cardHeight`, `BoxGrid`),
  `notes_screen.dart`, `tasks_screen.dart`, `boxes.dart` (`firstLine`, `boxTitle`),
  `lib/features/home/home_shell.dart` (`AppTab.short`/`shown`, `_BottomBar`),
  `lib/features/reminders/priority_chooser.dart`, `test/notebook_test.dart`, `test/widget_test.dart`.
- Usuario: no programador, rioplatense, usa **letra grande** en el teléfono; manda fotos; quiere ver antes en la compu.

## Decisiones tomadas
- Recuadros de Notas/Tareas: un renglón de nombre ("…" si no entra, letra 16 a 13 igual en todos) + engranaje;
  abajo "N pendientes" / "Nota" / "Vacía". Nota sin título muestra su primer renglón.
- Diferenciar: carpetas con pestañita arriba, negrita y fondo teñido; notas con franja gruesa a la izquierda.
- Barra de abajo: "Almanaque" se lee "Calend." (la key sigue `tab-Almanaque`); todos los nombres con la misma
  letra y altura; el elegido agranda solo el dibujo.
- "Sonar aunque esté en silencio" en un renglón (se achica si no entra).

## Hecho
- Versión 4.4 en `main` y en la rama; `CLAUDE.md` actualizado; artefacto web publicado con estos cambios.

## En curso / Problemas abiertos
- Falta que el usuario pruebe la 4.4 en el teléfono (con letra grande).

## Próximos pasos
1. Preguntar cómo quedó la 4.4 y corregir lo que pida (con fotos).
2. Para cambios visuales: rearmar la versión web y publicarla en el mismo artefacto antes de subir a `main`.
3. Correr `flutter analyze` y `flutter test`, pasar a `main` y vigilar el armado en GitHub.
