# Alerta Ya: cambios pedidos (para pasar a la app Flutter)

La app está en el repositorio `afelixc/APP-TE-RECORDARE` (rama `main` arma el APK).
`vista-previa.html` es la maqueta aprobada en la compu (artefacto https://claude.ai/artifact/2oSMvCH5t242ueCqT5kYzR).
Copiar su comportamiento en Flutter, respetando el estilo que ya tiene la app (barra azul ALERTA YA, micrófono naranja).

Ojo: las rondas 1 a 5 del rediseño minimalista (sesión anterior) nunca se subieron. Si no están en `main`,
rehacerlas también; la vista previa ya las incluye (Mensaje, Almanaque, Listado, Configuración, Ejemplos).

## Barra de abajo: 5 botones
Mensaje · Almanaque · Listado | Notas · Tareas
- Los tres primeros van juntos en azul. Una rayita los separa de Notas y Tareas.
- Notas (amarillo #d99a00 por defecto) y Tareas (verde #2e8b57) tienen su propio color, elegible en Configuración › Colores (con «Volver a los colores de siempre»).
- El botón activo queda marcado y se agranda un poco.
- Número rojo de Notas: cuántas carpetas o notas de afuera tienen algo sin tildar (no la cantidad de casillas).
- Número rojo de Tareas: tareas sin hacer.

## Notas (reemplaza a «Libreta»)
- Arriba: buscador, filtro (Todo / Solo carpetas / Solo notas) y botón + (Nueva carpeta / Nueva nota).
- Carpetas y notas mezcladas, ordenadas por fecha de creación: lo último arriba. Sin títulos «Carpetas»/«Notas».
- Notas sueltas o adentro de carpetas. Engranaje en cada recuadro: cambiar nombre y color, mover a otra carpeta, borrar.
- Recuadro de carpeta: nombre, borde y carpetita en verde; fondo blanco. Recuadro de nota: nombre, borde e ícono en amarillo; fondo blanco.
  Texto en negro; «N pendientes» en rojo sobre fondo rosa; «Todo hecho ✓» en verde; sin casillas dice «Nota».
- Color (nombre/borde/ícono) y fondo se eligen por separado.
- Nueva nota: abre el teclado en el título; Enter pasa al texto.
- Barra del editor: casilla para tildar, mayúsculas, subrayado, negrita, color de fondo, color de letra, tamaño (Chica, Normal, Mediana, Grande). Hoy se aplica al renglón entero.

## Tareas (botón aparte)
- Afuera solo carpetas (más nueva arriba). Sin subcarpetas ni tareas sueltas.
- Adentro de la carpeta: «PARA HACER» numerada, casilla, engranaje por tarea con: subir, bajar, editar, programar para que suene (día y hora; aparece en Almanaque y Listado), archivar, borrar.
- Archivar = completada: baja a «COMPLETADAS» (tachada), desde ahí se puede volver a Para hacer o borrar.
- Abajo: «Escribí o dictá tareas para hacer…», tilde verde y micrófono naranja; lo dictado se va agregando solo.
- Arriba en la carpeta: engranaje (nombre y color) y tacho para borrar la carpeta.
- Mismos colores que Notas (carpeta verde, fondo blanco, cambiables).
