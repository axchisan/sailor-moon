# Estado del audio

Qué suena hoy, qué está a medias y qué falta. Se actualiza al tocar sonido.

## ✅ Implementado y funcionando

### Jugadora
| Qué | Tomas |
|---|---|
| Pasos andando | 4 |
| Pasos corriendo | 3 (tomas propias, no las de andar aceleradas) |
| Salto | 3 |
| Aterrizaje | 2 |
| Daño recibido | 1 |
| Golpe, golpe fuerte, especial | 1 c/u |
| Golpe **al aire** (cuando falla) | 3 |

### Enemigos
| Qué | Tomas |
|---|---|
| Voz al aparecer y al caer | 3 |
| Aviso justo antes de atacar | 2 |
| Bloqueo (Cofrecito) | 1 |

El aviso es el que más trabaja: llega **sin mirar**, y en una arena con cuatro
enemigos alrededor no se puede estar pendiente de todos a la vez.

### El guardián
Pasos (3), puño (3), golpe al suelo (3), encaje (2), despertar, carga, rugido y
derrumbe. No usa la voz de los enemigos —`tiene_voz = false`—: el chillido de
un bicho pequeño no le pega nada a dos metros y medio de piedra.

### El mundo
Farol, Estrella, puerta mágica. Ambiente de parque en bucle, más agua y fuego
con posición en el mundo.

## ✅ El ambiente, funcionando

Fondo de parque en bucle, más agua y fuego con posición en el mundo — suben al
acercarse y bajan al alejarse solos, sin una línea que lo gestione.

**Un solo reproductor de fuego** que se mueve al farol más cercano, en vez de
uno por farol: suena exactamente igual y cuesta la sexta parte.

## ⬜ Falta

- **Toda la música.** No hay ni una pieza. Es lo siguiente, después de los menús.
- Portal al abrirse (`portal_abre.wav` está cortado, sin enchufar).
- Pasos de tierra (cortados, sin usar: hace falta detectar la superficie).
- Agarrarse a una cornisa.
- Rincones, objetivo cumplido, acto terminado.
- Interfaz entera.
- Sonido propio de la transformación (va prestado del especial).

## Los volúmenes, y por qué importan ahora

Todo pasa por los buses `Music`, `SFX` y `Voice`, que ya tienen volumen
ajustable — la interfaz de configuración solo tendrá que mover esos tres.

Pero **el volumen de cada sonido dentro del bus es cosa aparte**, y ese hay que
dejarlo bien antes: si los pasos están diez decibelios por encima de los golpes,
bajar el bus entero baja los dos y el desequilibrio sigue ahí. Los `-19 dB` de
los pasos o los `-20 dB` del golpe al aire son eso: la mezcla entre ellos, no el
volumen general.

Referencia actual (más negativo = más bajo):

| | dB |
|---|---|
| Golpe al suelo del guardián | −2 |
| Golpes de combate | −2 a −4 |
| Daño, bloqueo | −1 a −3 |
| Salto, aterrizaje | −13 a −15 |
| Aviso de enemigo | −17 |
| **Pasos** | **−19** (andando), **−18** (corriendo) |
| Golpe al aire | −20 |
| Voz de enemigo al aparecer | −24 |
| Ambiente de fondo | −26 |

## De dónde sale

- **Efectos**: los descarga el usuario de [Freesound](https://freesound.org)
  con el filtro en **CC0**. Se procesan con `ffmpeg` — recorte por detección de
  silencios, `loudnorm` a volumen común, mono 44,1 kHz, `.wav`.
- **Originales usados** en `~/Documents/audios usados/`.
- **Kenney** (CC0) en `audio_fuentes/`: sirve para menús, no para el mundo — es
  sonido de juego retro.

El plan completo está en [`21-SONIDO-Y-MUSICA.md`](21-SONIDO-Y-MUSICA.md).
