# Resumen de sesión
_Última actualización: 2026-11-25_

## Objetivo
App Android (Flutter) **Alerta Ya** (antes Te Recordaré / Recordame). Esta sesión: pulir Notas y Tareas
(casillas, ordenar, pantalla prendida, borrar con cuidado y Deshacer). Última versión publicada: **4.0** (ejecución 95).

## Contexto clave
- Repo `afelixc/APP-TE-RECORDARE`; rama de trabajo `claude/gifted-dijkstra-mgq7ob`. El usuario autoriza pasar a `main`
  cuando lo pide ("subila"). Cada push a `main` arma el APK (versión = (N − 55) / 10). Reglas completas en `CLAUDE.md`.
- Antes de subir: `flutter analyze` y `flutter test` (hoy 136 pruebas pasan).
- Flutter no viene en el contenedor: bajar la 3.47.9 a `~/flutter` (tar de storage.googleapis.com) y
  `git config --global --add safe.directory /root/flutter`.
- Si el armado en GitHub falla con "Could not resolve" de Maven: es pasajero, relanzar con
  `gh api -X POST repos/afelixc/APP-TE-RECORDARE/actions/runs/<id>/rerun-failed-jobs` (pasó en la 94).
- App para tocar en el navegador (datos de ejemplo en `main.dart`, carpeta «Alejandro»):
  `flutter build web --no-tree-shake-icons --no-web-resources-cdn --pwa-strategy=none`; publicar con una página
  propia (`app.html` que carga `flutter_bootstrap.js`), sin `AssetManifest.bin`, `*.symbols`, skwasm, wimp, webparagraph.
  Artefacto: https://claude.ai/artifact/9EbqUx4UHwwMAo98dLFJUN (quedó sin los últimos cambios del tacho y botones).
- Maqueta "Borrar y deshacer": `docs/maqueta-borrar-notas.html`, https://claude.ai/artifact/3gQ5okzRYRRpu8JytzSZpz
- Archivos tocados: `lib/features/notes/note_editor.dart`, `notes_screen.dart`, `tasks_screen.dart`,
  `box_widgets.dart` (`undoToast`/`undoToastOn`, `KeepAwakeButton`, `confirmDelete`, `confirmFolderDelete`),
  `MainActivity.kt` (canal `recordame/pantalla`), `lib/main.dart` (ejemplos), `test/notebook_test.dart`.
- Usuario: no programador, rioplatense, usa **letra grande** en el teléfono; manda fotos; quiere probar antes.

## Decisiones tomadas
- Tildar manda el renglón al final de su bloque de casillas; botón A-Z ordena faltan y tildadas por separado.
- Lamparita (pantalla prendida) en cada nota y en cada carpeta de Tareas, con cartel "💡 Pantalla prendida…".
- Adentro de una carpeta de Notas solo se crean notas (sin subcarpetas ni filtro).
- Borrar: carpetas (Notas y Tareas, aun vacías) y notas → dos toques + cartel en el medio + Deshacer 5 s;
  tareas y "borrar solo las tildadas" → dos toques + Deshacer.
- Botones del cartel: mismo tamaño, una palabra por renglón nunca partida, centrados (`sameFontSize`).
- Deshacer va centrado debajo del texto del cartelito.

## Hecho
- Versiones en `main`: 3.8 (tildadas abajo, A-Z, lamparita), 3.9 (solo notas en carpetas, Deshacer,
  tercera confirmación, tacho con dos opciones), 4.0 (botones sin partir con letra grande, cartel siempre).
- `CLAUDE.md` actualizado con todo lo anterior.

## En curso / Problemas abiertos
- Falta que el usuario pruebe la 4.0 en el teléfono (sobre todo el cartel con letra grande).
- El artefacto web interactivo no tiene los cambios de la 3.9/4.0 (rearmarlo si quiere verlo ahí).

## Próximos pasos
1. Preguntar cómo quedó la 4.0 y corregir lo que pida (con fotos).
2. Para cambios visuales: rearmar la versión web y publicarla en el mismo artefacto antes de subir a `main`.
3. Correr `flutter analyze` y `flutter test`, pasar a `main` y vigilar el armado en GitHub.
