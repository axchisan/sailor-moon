# Estado del audio

Qué suena hoy, qué está a medias y qué falta. Se actualiza al tocar sonido.

## ✅ Implementado y funcionando

| Qué | Tomas | Notas |
|---|---|---|
| Golpe, golpe fuerte, especial | 1 c/u | Grabación real; sustituyeron a los sintéticos |
| Daño recibido, bloqueo, purificar | 1 c/u | De antes |
| **Guardián** — pasos | 3 | Se sortean |
| **Guardián** — puño | 3 | |
| **Guardián** — golpe al suelo | 3 | |
| **Guardián** — encaje (le entra un golpe) | 2 | |
| **Guardián** — despertar, carga, rugido, derrumbe | 1 c/u | La carga suena al empezar cada ataque: es el aviso que llega sin mirar |
| **Pasos de Serena** — andar | 4 | Por distancia recorrida, no por tiempo |
| **Pasos de Serena** — correr | 3 | Tomas distintas, no las de andar aceleradas |
| **Salto** | 3 | |
| **Farol** al encenderse | 1 | |
| **Estrella** al recogerla | 1 | |
| Voces de Mercury | varias | Pendiente regenerarlas (F5) |

## 🟡 A medias

**El ambiente.** Los `.mp3` están recortados en `assets/audio/ambiente/`
—bosque, agua, fuego, portal— y `AmbienteNivel` está escrito con sonido
posicional 3D. Pero **el nodo no llega a crearse**: el código está en
`nivel._ready()`, compila, y en ejecución no aparece en la escena.

Ya se descartó:

- Reconectar `finished` a `play()` (un sonido que no carga se llama a sí mismo
  sin parar) — quitado, no era.
- Decodificar siete mp3 dentro de `_ready()` — ahora arranca diferido y se usa
  **un solo reproductor de fuego** que se mueve al farol más cercano, en vez de
  seis. Sigue sin aparecer.

Lo siguiente que hay que mirar: si `_ready()` del nivel llega hasta esa línea
(un `print` justo antes lo dice en un minuto), y si `AmbienteNivel.new()` está
fallando en silencio por el `class_name`.

## ⬜ Falta

- **Toda la música.** No hay ni una pieza.
- Portal al abrirse (`portal_abre.wav` está cortado, sin enchufar).
- Pasos de tierra (cortados, sin usar: hace falta detectar la superficie).
- Aterrizaje, golpe al aire, agarrarse a una cornisa.
- Puerta mágica, rincones, objetivo cumplido, acto terminado.
- Interfaz entera.

## De dónde sale

- **Efectos**: los descarga el usuario de [Freesound](https://freesound.org)
  con el filtro en **CC0**. Se procesan con `ffmpeg` — recorte por detección de
  silencios, `loudnorm` a volumen común, mono 44,1 kHz, `.wav`.
- **Originales usados** en `~/Documents/audios usados/`.
- **Kenney** (CC0) en `audio_fuentes/`: sirve para menús, no para el mundo — es
  sonido de juego retro.

El plan completo está en [`21-SONIDO-Y-MUSICA.md`](21-SONIDO-Y-MUSICA.md).
