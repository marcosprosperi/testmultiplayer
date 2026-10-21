# Herramientas de generación

Scripts de Python que generan contenido del juego. Godot no los procesa (`.gdignore`).

- `gen_levels.py` + `levelgen2.py`: generan `scenes/level_1.tscn` … `level_5.tscn` a partir de
  "secciones" (corridas, pozos, escaleras, trepadas, caídas, aplastadores, enemigos, globos…).
  Cada nivel es una función en `gen_levels.py`; cambiá la lista de secciones y regenerá:

      cd tools && python3 gen_levels.py ../scenes        # todos
      cd tools && python3 gen_levels.py ../scenes 2 4    # solo el 2 y el 4

  Ojo: regenerar pisa los cambios hechos a mano en esos niveles desde el editor.
- `gen_backgrounds.py`: genera las capas de fondo de `resources/backgrounds/`
  (`python3 gen_backgrounds.py ../resources/backgrounds ../resources/sky_.png`).
- `gen_sounds.py`: genera los efectos de sonido de `sounds/` (`python3 gen_sounds.py ../sounds`). Necesita numpy.
