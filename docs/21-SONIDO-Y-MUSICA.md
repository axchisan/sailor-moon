# Sonido y música

El juego lleva desde el principio **mudo salvo seis golpes**. Y el sonido no es
la capa de barniz que se pone al final: es la mitad de que pegar se sienta bien,
la mitad de que un sitio parezca un sitio, y lo único que puede decir «esto que
acabas de hacer estuvo bien» sin escribirlo en pantalla.

Este documento es el plan entero: de dónde sale cada cosa, qué suena en cada
momento y en qué orden hacerlo.

---

## 1. De dónde sacamos el material

Lo primero fue probar qué se puede descargar de verdad, porque media internet de
«recursos gratis para juegos» son páginas muertas o que piden cuenta. Lo de
abajo está **comprobado descargando**, no leído en una lista.

### Efectos: Kenney — lo primero que hay que mirar siempre

**[kenney.nl/assets/category:Audio](https://kenney.nl/assets/category:Audio)** ·
Licencia **CC0** (dominio público: sin atribución, sin condiciones, sin letra
pequeña) · Descarga directa por HTTP, sin cuenta.

Ya están descargados en `audio_fuentes/kenney/`, **368 sonidos en `.ogg`** —que
es el formato nativo de Godot, sin conversiones— y cinco megas en total:

| Pack | Cuántos | Para qué |
|---|---|---|
| `impact-sounds` | 130 | Golpes, pasos sobre distintos suelos, impactos |
| `rpg-audio` | 50 | Pasos, tela, metal, madera, cofres |
| `interface-sounds` | 100 | Menús, confirmaciones, avisos |
| `music-jingles` | 85 | Fanfarrias cortas de logro y de derrota |

La carpeta lleva un `.gdignore` a propósito: **son la despensa, no el
inventario**. Godot no los importa, no pesan en el APK y no ensucian el buscador
de recursos. Lo que se usa se copia a `assets/audio/` con un nombre que diga qué
es —`guardian_paso.ogg`, no `footstep07.ogg`—, y así el proyecto solo carga con
lo que de verdad suena.

### Música: Incompetech (Kevin MacLeod)

**[incompetech.com](https://incompetech.com/music/royalty-free/music.html)** ·
Licencia **CC-BY** (gratis, incluso comercial, **a cambio de citar al autor**) ·
Descarga directa de `.mp3`, sin cuenta.

Patrón de descarga, comprobado:

```
https://incompetech.com/music/royalty-free/mp3-royaltyfree/<Titulo>.mp3
```

La atribución es obligatoria y va en [`CREDITOS.md`](CREDITOS.md). No es un
trámite: es la condición con la que nos dejan usarla.

> **FreePD.com cerró en 2025** tras diecisiete años. Sale en todas las listas de
> «música libre» que hay por ahí y ya no existe; si aparece en algún tutorial,
> saltárselo.

### Si hace falta algo que no esté

En este orden:

1. **[OpenGameArt.org](https://opengameart.org)** — descarga directa. Ojo: cada
   pieza tiene su licencia (CC0, CC-BY, GPL…), hay que mirarla una por una.
2. **[Pixabay](https://pixabay.com/sound-effects/)** — mucho y bueno, pero la
   descarga automática pide clave de API. Sirve para buscar tú a mano.
3. **[Musopen](https://musopen.org)** — clásica de dominio público. Para si algún
   día hace falta algo orquestal.
4. **[itch.io con filtro CC0](https://itch.io/game-assets/free/tag-sound-effects)**
   — packs de gente que hace juegos; calidad muy irregular.

**Lo que no vamos a usar:** nada de bibliotecas que pidan licencia por proyecto,
ni sonidos sacados del anime original. Esto es un regalo que no se publica, pero
meter material con dueño dentro del repositorio es empezar a acumular deuda que
un día hay que pagar.

---

## 2. Cómo está montado ahora

Ya existe [`AudioManager`](../src/autoload/audio_manager.gd) y no hay que
rehacerlo. Tiene:

- **Tres buses**: `Music`, `SFX`, `Voice`, cada uno con su volumen en ajustes.
- **Fundido cruzado** entre canciones (`play_music`), con dos reproductores que
  se turnan.
- **Un grupo de 16 reproductores** para efectos, que se van reciclando: así diez
  golpes seguidos no crean diez nodos ni se cortan entre ellos.
- **Variación de tono** automática en cada efecto (±10%). Es lo que evita el
  efecto ametralladora — el mismo sonido repetido idéntico veinte veces seguidas
  se vuelve insoportable, y con un poco de tono aleatorio deja de notarse.

Lo que hay grabado hoy: seis efectos de combate y las voces de Mercury. **Cero
música y cero ambiente.**

### Dónde va cada cosa

```
assets/audio/
  musica/      una carpeta por escena     ← vacío
  ambiente/    bucles largos de fondo     ← vacío
  sfx/
    combate/   golpes, daño, derrota
    mundo/     faroles, estrellas, portal, puertas
    jefe/      el guardián
    ui/        menús, avisos, objetivos
  voces/       ya está, por personaje
```

---

## 3. La música, escena por escena

La regla de fondo: **el parque es un sitio agradable donde a veces pasan cosas**,
no un juego de acción con ratos tranquilos. La música por defecto es la del
parque, y todo lo demás son excepciones que vuelven a ella.

| Momento | Cómo tiene que sonar | Cuánto dura |
|---|---|---|
| **Menú / título** | La melodía del juego, tranquila, reconocible. Es lo que suena mientras se decide jugar | bucle 1-2 min |
| **El parque** | Ligera, curiosa, sin prisa. Tiene que aguantar veinte minutos sin cansar: por eso poca percusión y nada de melodía pegadiza | bucle 2-3 min |
| **Combate en arena** | Entra al cerrarse la barrera y se va al abrirse. Más ritmo, misma paleta — que se note que es el mismo juego | bucle 1-2 min |
| **El claro del portal** | Más quieta y más abierta. Aquí no se pelea, se llega | bucle 1-2 min |
| **El guardián** | Lo único solemne del acto. Percusión pesada y lenta, como él | bucle 2 min |
| **Encuentro con Amy** | Se baja la del parque y entra algo cálido y corto, solo mientras se habla | 30-60 s |
| **Transformación** | No es música de fondo: es un momento. Sube, brilla y termina | 6-8 s |

### Las tres reglas de la mezcla

1. **Al hablar, la música baja, no se corta.** Cortarla deja un silencio que
   suena a error; bajarla a un tercio deja oír la voz sin que se note el cambio.
2. **Una canción por sitio, y se queda.** Cambiar de tema cada dos minutos marea.
   El fundido cruzado de un segundo que ya tiene el `AudioManager` es
   suficiente para que ningún cambio se note brusco.
3. **El silencio también se usa.** Antes de que el guardián despierte no debería
   sonar nada — dos segundos de nada hacen más por ese momento que cualquier
   redoble.

---

## 4. Los efectos, acción por acción

Marcados con ✅ los que ya suenan.

### Combate

| Qué | Cuándo | Dónde buscarlo |
|---|---|---|
| ✅ Golpe normal | Cada impacto | ya está |
| ✅ Golpe fuerte | Tercer golpe del combo | ya está |
| ✅ Daño recibido | Serena recibe | ya está |
| ✅ Bloqueo | El Cofrecito para un golpe | ya está |
| ✅ Especial | El ataque cargado | ya está |
| ✅ Derrota de enemigo | Un enemigo cae | ya está |
| Golpe al aire | Se ataca sin dar a nada | `impact-sounds`, los suaves |
| Salto | Al despegar | `rpg-audio/cloth*` |
| Aterrizaje | Al tocar suelo | `impact-sounds/footstep_*` |
| Pasos de Serena | Andando y corriendo | `impact-sounds/footstep_grass_*` |
| Agarrarse a una cornisa | Al engancharse | `rpg-audio/cloth*` |

Los pasos son los que más se notan aunque nadie los oiga conscientemente: sin
ellos, andar por el parque es flotar. Van con variación de tono y **cuatro
muestras alternándose**, o se convierten en un tictac.

### El guardián

| Qué | Cuándo |
|---|---|
| Piedra que se despierta | Los cinco segundos de `despertar` — roce grave, largo |
| Pasos | Cada pisada. Graves y con temblor; es lo que le da el peso |
| Puño | El golpe normal, al impactar |
| Puños contra el suelo | El ataque de área. Lo más gordo que suena en todo el acto |
| Aviso del área | Mientras el círculo crece — un zumbido que sube |
| Le entra un golpe | Piedra contra piedra, seco |
| Rugido de fase | Al cambiar de fase |
| Se derrumba | Al caer: piedra asentándose, y luego silencio |

### El mundo

| Qué | Cuándo |
|---|---|
| Farol encendido | Chispa y un tono que sube |
| Estrella recogida | Campanilla. Es el sonido que más veces se oye: tiene que gustar a la séptima vez |
| Rincón encontrado | Un acorde corto de logro |
| Puerta mágica que se abre | El paso que se libera |
| Portal despierto | Grave que crece, con brillo |
| Portal usado | El cambio de escenario |
| Objetivo cumplido | Jingle corto — `music-jingles` |
| Acto terminado | Fanfarria de verdad |

### Interfaz

Botón, confirmar, cancelar, abrir el panel de objetivos, pausa. Todo de
`interface-sounds`, y todo **corto**: un sonido de menú que dura más de un tercio
de segundo estorba.

### Ambiente

Va aparte de la música, en bucle y bajo. Es lo que hace que el parque no sea un
decorado:

- **Fondo de parque**: pájaros lejanos y aire entre las hojas.
- **Agua**: cerca del estanque, más alto cuanto más cerca. Con `AudioStreamPlayer3D`
  se resuelve solo.
- **Fuego de farol**: crepitar bajito al lado de cada farol encendido — así se
  oye cuál está encendido antes de verlo.

---

## 5. En qué orden hacerlo

Por cuánto cambian el juego, no por cuánto cuestan:

1. **Pasos y aterrizaje.** Es lo que más se nota y lo que ya está descargado.
   Andar sin sonido es lo que hace que un juego parezca una maqueta.
2. **Música del parque.** Veinte minutos de silencio de fondo es lo primero que
   se siente raro al jugar.
3. **Los del guardián.** Es el momento más importante del acto y va mudo.
4. **Los del mundo** — faroles, estrellas, rincones. Cada uno confirma que algo
   ha pasado, y ahora eso solo lo dice un cartel.
5. **Música de combate y de jefe.**
6. **Ambiente.**
7. **Interfaz.** Va la última porque es la que menos se echa de menos.

---

## 6. Lo que hay que cuidar

- **En el móvil, con el altavoz del teléfono.** Lo que en cascos es un grave
  precioso, ahí no existe. Todo tiene que funcionar en un altavoz malo y
  pequeño: eso significa nada de sonidos que vivan solo en los graves.
- **El volumen se mezcla al final, no al principio.** Cada efecto suelto suena
  bien; el problema aparece cuando suenan siete a la vez.
- **Ocho años.** Nada estridente, nada que asuste de golpe. El guardián impone
  por lo grave y lo lento, no por dar un susto.
- **Un sonido por acción, y siempre el mismo.** Si recoger una Estrella suena
  distinto cada vez, deja de significar «has recogido una Estrella».
