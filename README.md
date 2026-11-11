# Carreras Locas

Juego de carreras de plataformas para hasta 8 jugadores en red, hecho con Godot 4.
Cada carrera es un nivel con trampas, enemigos, monedas y poderes; al final del
campeonato gana quien juntó más puntos. Los lugares libres se pueden completar con bots.

## Cómo se juega

| Acción | Teclado | Gamepad |
|---|---|---|
| Moverse | A / D o flechas | Cruceta o stick izquierdo |
| Saltar (un toque: salto corto; mantener: salto largo) | Espacio o flecha arriba | Botón de abajo (A / ✕) |
| Usar el poder | E | Botón de la izquierda (X / ☐) |
| Pausa | Esc | Start |
| Ver el campeonato | Tab (mantener) | |
| Pantalla completa | F11 | |

Las teclas se pueden cambiar en **Opciones → Controles**.

- **Monedas:** cada una suma 1 punto al final de la carrera, pero te hace un poco más lento.
- **Poderes:** se consiguen en las cajas "?". Cuanto más atrás vas, mejores salen.
- **Banderas:** si perdés, volvés a la última bandera que tocaste.
- **Límite de tiempo:** cuando llega la primera persona, el resto tiene 2 minutos
  para terminar. Quien no llega queda atrás, ordenado por cuánto avanzó.

## Jugar con otros

Quien arma la partida toca **Crear partida** y elige las reglas y los niveles en la sala.

- **En la misma red (misma casa):** los demás tocan **Unirse a una partida** y la partida aparece sola en la lista.
- **Por internet:** los demás escriben la IP del host en "O escribí la IP del host". Dos formas de que esa IP funcione:
  - *Red privada virtual (lo más simple):* todos instalan [Tailscale](https://tailscale.com) (o ZeroTier / Radmin VPN),
    entran a la misma red y usan la IP que muestra el programa (en Tailscale empieza con `100.`).
  - *Abrir el puerto:* el host toca **Abrir a internet** en la sala: el juego le pide al router que abra el
    puerto (UPnP) y muestra la IP pública para pasarles. Se cierra al salir de la partida. Si el router no lo
    permite, se puede redirigir a mano el puerto **8080 UDP** a la PC del host.
    No funciona si el proveedor de internet comparte la IP entre clientes (CGNAT): el juego avisa.

Todos tienen que tener **la misma versión** del juego (se ve arriba a la derecha en el menú,
por ejemplo `v3.2f79362e`). Si no coincide, el juego avisa y no deja entrar.

## Exportar para Windows

1. En Godot: **Proyecto → Exportar → Manage Export Templates → Download and Install** (una sola vez).
2. Elegir "Windows Desktop" → **Export Project...**, destildar "Export With Debug" → **Save**.
3. Queda `build/CarrerasLocas.exe` (un solo archivo). Esa carpeta no se sube al repo.

## Cómo está armado

| Carpeta | Qué hay |
|---|---|
| `autoload/` | Lo que vive toda la partida: red (`NetworkManager`), jugadores y reglas (`PlayersManager`), la carrera (`RaceManager`), opciones, sonido, música |
| `scenes/` | Menú, escena principal, jugador y los niveles (`level_1.tscn` … generados, ver abajo) |
| `race/` | Lo que hay en un nivel: enemigos, trampas, poderes, fondos, banderas, meta, y el cerebro de los bots |
| `lobby/`, `hud/`, `ui/` | Sala de espera, lo que se ve durante la carrera, menús y tema visual |
| `tools/` | Generadores de niveles, fondos, sonidos y música (Python), y las pruebas. Ver [tools/README.md](tools/README.md) |

Los enemigos y las trampas se mueven con el reloj de la carrera, así están en el mismo
lugar en todas las pantallas sin mandar nada por la red. Cada jugador mueve a su propio
personaje y decide cuándo pierde; el host decide lo que es de todos (monedas, poderes, llegadas).

Si cambiás algo que haga que dos versiones no puedan jugar juntas (reglas, poderes, mensajes de red),
subí `GAME_VERSION` en `autoload/NetworkManager.gd`. Los cambios en los niveles se detectan solos.
