# Resumen de sesión
_Última actualización: 2026-11-18_

## Objetivo
App Te Recordaré (Flutter, Android): pasar la Libreta de botón flotante a una solapa de la barra de abajo
y que la solapa elegida se agrande y se destaque.

## Contexto clave
- Repo `afelixc/APP-TE-RECORDARE`; rama de trabajo `claude/great-bell-yyvhpg`. Cada push a `main` arma el APK
  y la app ofrece "Actualizar" (versión que ve el usuario = (N − 55) / 10; la ejecución 84 es la 2.9).
- Reglas completas en `CLAUDE.md` (antes de subir: `flutter analyze` y `flutter test` sin errores).
- Archivos tocados: `lib/features/home/home_shell.dart` (solapas, `_NotebookTabIcon`, tema de la barra),
  `lib/features/notebook/quick_note.dart` (antes `notebook_fab.dart`: `QuickNoteBar`, hoja "¿En qué carpeta anoto?"),
  `lib/features/notebook/notebook_page.dart` (`NotebookPage(inTab:)`, `openNotebook` va a la solapa), `test/widget_test.dart`.
- Maquetas: "Libreta flotante y notas" (grilla, `docs/maqueta-libreta-flotante.html`)
  https://claude.ai/artifact/41FxEDkRfuGMm2EpP8zMg5 y maqueta para tocar (`docs/maqueta-interactiva.html`)
  https://claude.ai/artifact/VQgdWGTe8F77zY9jwM6SRG
- Flutter no viene instalado en el contenedor: se bajó la 3.47.9 (la del workflow) a la carpeta temporal.
- El usuario no es programador; habla rioplatense. Quiere ver y tocar los cambios antes de instalar.

## Decisiones tomadas
- Barra: Chat · Almanaque · Listado · Libreta · Configuración — pedido del usuario.
- Libreta en recuadro amarillo con botoncito rojo de pendientes — pedido del usuario.
- Sin botón flotante ni hoja Cancelar / Abrir libreta; se anota abajo de la Libreta ("Anotar en", Tarea/Nota, campo).
- Al cambiar de solapa la Libreta vuelve a su inicio (`HomeShell._visit`) — pedido del usuario.
- El botón "Libreta" del Chat queda y lleva a la solapa.
- Solapas más grandes (alto 88, íconos 26 / elegida 33, letra 12,5 / elegida 14 en negrita y color) — pedido del usuario.
- Las maquetas para mostrar tienen que ser interactivas (tocar, entrar, salir), no imágenes — el usuario lo pidió.

## Hecho
- Todo lo anterior en código, con pruebas pasando (135) y `flutter analyze` limpio.
- Subido a `main` (commit 7b5fa54): se armó la ejecución 84 = versión 2.9.
- Maquetas actualizadas y publicadas (links arriba).
- Se publicó una prueba de la app web ("Prueba Te Recordaré", https://claude.ai/artifact/JzH8jc1BcXjE8WeGbZ16Tf)
  que al usuario no le sirvió; se ofreció borrarla, sin respuesta.

## En curso / Problemas abiertos
- Falta confirmar que la versión 2.9 se armó bien y que el usuario la instaló y probó.
- Deslizar el dedo justo sobre el buscador de la Libreta no cambia de solapa (más abajo sí).
- En la maqueta para tocar, las pantallas de Configuración no están armadas (solo el menú).

## Próximos pasos
1. Preguntar cómo quedó la 2.9 en el celular y corregir lo que pida.
2. Mostrar cada cambio nuevo primero en la maqueta para tocar y recién después pasarlo a `main`.
