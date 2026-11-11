# Herramientas de generación

Scripts de Python que generan contenido del juego. Godot no los procesa (`.gdignore`).

- `gen_levels.py` + `levelgen2.py`: generan todos los niveles (`scenes/level_1.tscn`, `level_2.tscn`…)
  a partir de "secciones" (corridas, pozos, escaleras, trepadas, caídas, aplastadores, enemigos, globos…).
  Cada nivel es una función en `gen_levels.py`; cambiá la lista de secciones y regenerá:

      cd tools && python3 gen_levels.py ../scenes        # todos
      cd tools && python3 gen_levels.py ../scenes 2 4    # solo el 2 y el 4

  Ojo: regenerar pisa los cambios hechos a mano en esos niveles desde el editor.
  Un nivel nuevo también hay que sumarlo a la lista `levels` de `scenes/main.tscn` (nombre y dificultad).
  Al generar se actualiza `race/levels_version.gd`, la "huella" de los niveles: es parte de la versión
  del juego, y dos versiones con niveles distintos no se dejan jugar juntas.
- `gen_tilesets.py`: recolorea el tileset de naturaleza en versión nieve y volcán
  (`resources/nature_snow.png`, `nature_volcano.png`; `python3 gen_tilesets.py ../resources`).
- `gen_backgrounds.py`: genera las capas de fondo de `resources/backgrounds/`
  (`python3 gen_backgrounds.py ../resources/backgrounds ../resources/sky_.png`).
- `gen_sounds.py`: genera los efectos de sonido de `sounds/` (`python3 gen_sounds.py ../sounds`). Necesita numpy.
- `gen_music.py`: genera la música en loop de `sounds/` (`music_menu`, `music_race` y `music_dark`
  para la cueva y la noche) con melodías escritas como notas (`python3 gen_music.py ../sounds`).
  Necesita numpy.

## Pruebas

En `tests/` hay guiones que juegan solos, sin ventana. Sirven para ver que un cambio no rompió nada
(`godot` es el ejecutable de Godot 4):

- **Carreras de bots en todos los niveles** (unos 4 minutos): ¿llegan todos a la meta?, ¿cuánto tardan?,
  ¿dónde pierden? Un nivel donde los bots dejan de llegar suele tener un salto imposible o una trampa injusta.

      tools/tests/run_bots.sh godot          # todos los niveles a la vez
      tools/tests/run_bots.sh godot 3 10     # solo el 3 y el 10

  Imprime una línea `RESULT` por nivel; el detalle de cada carrera queda en `/tmp/bots_race/`.
  Lo normal: 7/7 en todos, con pocas caídas, salvo en los niveles "¡Extremo!" (muchas caídas, y puede que no lleguen todos).

- **Dos jugadores en red** (host e invitado en la misma PC): unirse, cómo se ve el otro, perder y volver,
  el límite de tiempo, la carrera siguiente, volver a la sala y correr otra vez. Cada uno imprime lo que ve
  y lo que debería ver ("expect…").

      godot --headless --path . -s tools/tests/two_players.gd -- host &
      godot --headless --path . -s tools/tests/two_players.gd -- client

El juego acepta `-- --port=N` para usar otro puerto (así corren varias partidas a la vez en la misma PC).
