# Plan maestro — de prototipo a juego

> El Nivel 1 se recorre entero y tiene lore, coleccionables y conversación. Lo
> que falta ya no es «más nivel»: es que el mundo **se comporte como un mundo**
> y que el juego **empiece contando algo**. Este documento ordena todo lo que
> queda para no ir dando bandazos.
>
> Estado y trampas técnicas: [`ESTADO.md`](ESTADO.md).
> Historia y personajes: [`16-GUION.md`](16-GUION.md).
> Animaciones que hay que bajar: [`17-ANIMACIONES.md`](17-ANIMACIONES.md).

## Cómo está ordenado

Ocho fases. El orden **no** es por dificultad ni por lo vistoso que quede: es
por lo que desbloquea a lo demás.

| Fase | Qué | Estado | Por qué va aquí |
|---|---|---|---|
| **A** | Que el mundo sea sólido | ✅ | Atravesar a Mercury o caerse por un agujero rompe la ilusión más que cualquier textura fea |
| **B** | Texturas reciclables | ✅ | Todo lo que se construya después las usará. Hacerlo tarde obliga a repintar |
| **C** | Mundo abierto, límites naturales | ✅ | Necesita las texturas de B para que los taludes y las rocas se lean |
| **C bis** | Objetivos, portal y rincones | ✅ | El nivel necesitaba un cierre y sitios a los que ir |
| **C ter** | Que el nivel EXPLIQUE lo que pide | ⬜ | El nivel tiene objetivos pero no los dice en ninguna parte |
| **D** | Rendimiento | ✅ dos pasadas | Se mide cuando el escenario ya tiene su carga real, no antes |
| **E** | Movimiento y combate | ✅ | Salto, doble salto, trepar cornisas y el Cofrecito rodeable |
| **F** | Conversación viva | ⬜ | Depende de E (librería de animaciones montada) |
| **G** | Marco: menú, guardado, vidas | ⬜ | Necesita que el juego ya sea agradable de jugar |
| **H** | Historia y cinemática | ⬜ | Lo último que se monta, lo primero que se ve |

> **Dónde estamos:** el escenario y el movimiento están hechos. Lo siguiente es
> la **Fase F** —que la conversación deje de ser texto y gestos sueltos— y la
> **C ter**, que el nivel explique lo que pide.
>
> Nada bloquea: las 25 animaciones están en la librería compartida.

**Lo que puede ir en paralelo, y depende de ti:** el arte de la cinemática (H).
No me bloquea a mí y te bloquea a ti si se deja para el final.

---

## Fase A — Que el mundo sea sólido

Todo esto son cosas que, jugando, dicen «esto es un prototipo».

### A1. Colisión de los props

Ahora mismo **nada** de la decoración tiene cuerpo. Se decidió así al montarla
(los muros ya definían lo caminable) y para lo que había era correcto, pero se
atraviesa el tronco de un cerezo y eso no se sostiene.

La regla no es «todo sólido»: es **sólido lo que en la vida real pararía a una
niña de ocho años**.

| Pieza | Colisión | Forma |
|---|---|---|
| Tronco de cerezo | Sí | Cilindro de 0,3 m, solo el tronco |
| Copa del cerezo | **No** | Son flores. Se atraviesan y está bien |
| Roca | Sí | Esfera achatada |
| Banco | Sí | Caja |
| Farol de piedra, papelera | Sí | Cilindro |
| Valla | Sí | Caja fina, alineada |
| Arbusto | **No** | Se pisa y se pasa. Frenarse con un seto es lo que más molesta |
| Fondo lejano | **No** | Está a 60-200 m |

Como los props van en `MultiMesh`, la colisión no puede salir de la malla: se
añade una forma primitiva por instancia en un solo `StaticBody3D` por tipo.
Barato y suficiente.

### A2. Cuerpo sólido para personajes y enemigos

- **`Encuentro`** es un `Area3D` pelado: Mercury no tiene cuerpo y se atraviesa.
  Necesita un `StaticBody3D` con cápsula, separado del área que dispara la
  conversación.
- **Enemigos**: revisar las capas. Deben empujarse con la jugadora sin poder
  atravesarla, y dejar de colisionar solo al morir.

### A3. Agujeros en el suelo

Hay sitios por donde se cae del mundo. Hay que **buscarlos de forma sistemática**,
no a ojo: barrido de rayos hacia abajo por toda la superficie jugable, y lista
de coordenadas sin suelo. Sospechosos principales: las juntas entre tramos, el
encuentro de los pasillos con las arenas y las bocas del cruce.

Además, **red de seguridad**: un suelo invisible muy abajo que devuelve al
último punto firme. Existe el rescate por altura, pero conviene que no dependa
de un único número.

### A4. Los gatos

1. **La cara está desfasada.** La proyección plana que pinta ojos y boca se
   ancla a la caja envolvente de la cabeza, y los huecos reales de la malla
   están más abajo. Hay que anclarla **a los huecos**, no a la caja.
2. **Sin colisión.** Luna debe empujar y ser empujada, no atravesarse.
3. **Se hunde en las cuestas.** Sigue a la jugadora en el plano y no consulta el
   suelo: en el pasillo empinado se mete dentro. Necesita un rayo hacia abajo
   para pegarse al terreno.

### A5. Farol flotante

Uno de los tres del objetivo está en el aire. Es el que lleva peana; hay que
comprobar que la peana se coloca donde toca en un tramo con pendiente.

### A6. Diálogo: avanzar y cerrar

El `Panel` se traga el clic antes de que llegue a `_unhandled_input`, así que
solo avanza tocando **fuera** del cuadro, que es justo donde nadie toca. Y no
hay forma de cerrar una conversación.

### A7. Modo desarrollador

Antes de tocar el sistema de daño hace falta poder probar sin morirse.

- Invulnerable, con interruptor
- Saltar a cualquier tramo del recorrido
- Contador de FPS y draw calls en pantalla
- Ver los límites de colisión

---

## Fase B — Texturas que se puedan reciclar ✅ hecha

> [`terreno.gdshader`](../src/level/terreno.gdshader) y
> [`paleta_terreno.gd`](../src/level/paleta_terreno.gd). Ocho superficies, un
> solo shader, cero archivos de textura.
>
> La proyección sale de la **posición en el mundo**, no de las UV: el blockout
> son cajas escaladas y multimallas sin desplegar, y así un metro de hierba mide
> igual en todas las piezas por distinto que sea su tamaño. Se elige el eje
> dominante de la normal en vez de mezclar tres muestras — cuesta un tercio y en
> geometría de cajas no se nota.
>
> Para una superficie nueva se añade una receta con dos colores y tres números.
> Para la plaza de piedra de una ciudad, `PaletaTerreno.tenida("piedra", …)` y
> ya está.

El problema no es que falten texturas: es que **hacer una por objeto no
escala**. Van a venir plazas de piedra, interiores, un templo, y no puede haber
un `.png` por cada superficie.

### El sistema

Una **biblioteca de materiales procedurales**, cada uno con:

- Un patrón generado por código (hierba, tierra pisada, losa, madera, muro)
- **Color por parámetro**: el mismo material de losa sirve para gris de ciudad,
  arena de templo o mármol, cambiando dos colores
- Tamaño de repetición en metros, para que la escala sea la misma en todos los
  escenarios
- Trazo de contorno donde toque, que es lo que da el aire dibujado

Con eso, un escenario nuevo no pide texturas nuevas: pide **otra combinación**
de las que hay.

### El estilo

Lo que hace que algo se lea como anime no es el detalle, es:

- **Pocos tonos por superficie**, con saltos claros entre ellos, no degradados
- **Manchas grandes** y bordes marcados
- Contraste entre la zona pisable y el resto

### Piezas de la primera tanda

`hierba`, `hierba_seca`, `tierra_camino`, `losa_piedra`, `muro_roca`,
`madera`, `agua`. Con esas siete y el tintado por parámetro se cubre el parque
entero y buena parte de lo que venga.

---

## Fase C — Que parezca un mundo, no un pasillo ✅ hecha

> **Los setos del parque no se tocaron.** Un seto de jardín es la linde de un
> parque, no el final del mundo, y está bien que se lea así. Lo que faltaba era
> que *hubiera mundo más allá del seto*.
>
> Ahora hay 34 m de campo abierto alrededor de todo lo construido y, al fondo,
> una ladera al 60° que no se sube — la jugadora trepa hasta 45°, así que el
> número no es estético. Se construye en tramos tangentes, como el anillo de las
> arenas, para que la colisión sea exacta.
>
> Un círculo perfecto se leería como el borde de un cráter, así que el contorno
> lleva dos ondas de distinta frecuencia, y al pie van tres filas de arboleda —
> una de ellas trepando por la cuesta — más un pedregal que rompe la línea donde
> el llano se junta con la ladera. La ladera se dejó en 5,5 m: a 9 superaba a los
> árboles que la tapan y volvía a parecer un muro inclinado.

### El problema del arranque

Empiezas y ves un muro. Lo primero que hace cualquiera es saltar hacia él para
ver qué hay detrás — y lo que hay es el final del mundo.

### Cómo se cierra un mundo sin que se note

Por orden de credibilidad:

1. **Desnivel**: el terreno sube y no se puede escalar. El más limpio
2. **Cúmulo de rocas**: montón de piedras grandes, natural en un parque
3. **Arboleda densa**: troncos juntos, se ve a través pero no se pasa
4. **Agua**: estanque o río. Además queda bonito
5. **Valla con seto detrás**: para el borde de un parque urbano es realista
6. **Muro liso**: lo que hay ahora. El último recurso

La zona de arranque pasa a ser **abierta**: una explanada con el camino saliendo
de ella, cerrada por una arboleda con desnivel. Que se pueda dar la vuelta y
correr un poco sin toparse con nada.

### Ensanchar

Los pasillos de 9 m son un tubo. Con las colisiones puestas se pueden hacer
mucho más anchos, porque ya no hace falta que el muro dirija: dirigen el camino
pintado y los props.

---

## Fase C bis — Objetivos, mapa y desbloqueo de escenarios

> Pendiente de implementar. El diseño queda aquí para no improvisarlo.

### El problema

El Nivel 1 se acaba matando lo que hay y hablando con Mercury. Eso no da para
un acto: hace falta que el parque **pida ser recorrido**, y que pasar al
siguiente escenario sea algo que se gana, no algo que pasa.

### El Acto 1 se cierra con una lista, no con un jefe

El teleport al Nivel 2 aparece cuando están hechas **todas** estas cosas:

| Objetivo | Por qué está |
|---|---|
| Las 3 arenas limpias | Es el hilo principal |
| Los 3 faroles encendidos | Obliga a mirar arriba y a los lados |
| Hablar con Mercury | Es la historia |
| **7 Estrellas de Sueño** | Obliga a salir del camino |
| **Los 4 rincones del parque** | Obliga a recorrer el campo abierto |
| El guardián derrotado | El cierre |

Las dos en negrita son las nuevas, y las que hacen que el espacio del parque
sirva de algo. Sin ellas, el campo abierto es decorado.

**Regla:** ningún objetivo puede fallarse para siempre. Todo se puede volver a
intentar, y lo recogido no se pierde al morir.

### El teleport

Un círculo de luz en el torii de la entrada — el sitio por el que se entró al
parque, que es el sitio por el que se sale. Apagado hasta que la lista está
completa; entonces se enciende y Luna lo dice en voz alta.

### El mapa

Pantalla aparte, con los escenarios como puntos sobre una ilustración de Tokio:

- **Completado** — a todo color, se puede volver
- **Abierto** — brillando, es a donde toca ir
- **Cerrado** — silueta gris, sin nombre

Que los cerrados **se vean** es lo que hace que el mapa funcione: enseña cuánto
queda por delante. Y volver a un nivel ya hecho tiene que servir para algo —
las Estrellas que falten siguen ahí.

### Qué hace falta del terreno

Para que ese mapa se lea como un sitio y no como una lista de burbujas, cada
escenario tiene que tener **forma propia**: el parque es un valle, el templo
está en un cerro, el puerto es una costa. El terreno ya lo permite — la
deformación del contorno se controla con dos números — pero hay que decidir la
silueta de cada nivel al construirlo, no después.

---

## Fase C ter — Que el nivel EXPLIQUE lo que pide

> Pedido el 2026-08-10, después de recorrer el parque entero. Sin empezar.

El nivel ya tiene objetivos, pero no los dice en ninguna parte: se llega a la
puerta del guardián y no se abre, y no hay forma de saber por qué. Una niña de
ocho años ahí se queda dando vueltas.

### C ter 1. Avisos en las puertas ✅ hecho

- **Puerta del guardián**: al acercarse dice «Faltan 2 faroles por encender».
  La cuenta la mantiene `nivel.gd` con cada farol que se enciende; la puerta
  solo enseña la frase, porque no tiene por qué saber de qué va el objetivo
- **Portal dormido**: recita **lo que falta**, no la lista entera con lo hecho
  tachado. La lista completa se lee como deberes; lo que queda por hacer se lee
  como un plan. Y con las cuentas donde las hay: «Estrellas de Sueño (3 de 7)»

Los dos llevan enfriamiento: entrar y salir del área tres veces no suelta el
mismo cartel tres veces.

> **Lo importante es cómo está escrito.** «Faltan 2 faroles» manda a jugar; «no
> puedes pasar» manda a irse. A los ocho años esa diferencia es toda la
> diferencia.

### C ter 2. La cinemática del portal ✅ primera versión

La primera vez que se entra en el claro —y solo la primera— la cámara sube a
mirar el portal en contrapicado, se para un momento sobre él, y entonces sí se
recita lo que falta. Ese par de segundos son lo que convierte la ruina en un
objetivo: hasta que no se mira, es piedra decorativa.

Se quita el control mientras dura: si se puede andar, se anda, y la escena se la
pierde justo quien más falta le hace verla.

> **Falta pulir el encuadre.** Funciona y se ejecuta, pero el plano no siempre
> deja el portal centrado. Los números están en `_presentar()`: el punto de
> cámara (`cerca`), a dónde mira (`mirar`) y los tiempos del recorrido.

### C ter 3. Un panel de objetivos que se pueda consultar

Lo que hay que hacer, siempre a mano: estrellas, faroles, rincones, arenas,
Mercury. Con lo conseguido marcado. No hace falta que sea un menú — puede ser
Luna, que para eso acompaña.

### C ter 4. El guardián del portal

Cuando la lista está completa y se vuelve al portal, **no se abre sin más**:
aparece el guardián del portal, un jefe de verdad, y el portal se abre al
ganarle. Es el cierre del acto: la recompensa de haberlo recorrido todo no es
una puerta que se abre, es la pelea que se ha ganado el derecho a tener.

Va después de la Fase E (hace falta que el combate esté a punto) y encaja con
la Fase H, que es cuando se monta lo narrativo.

---

## Fase D — Rendimiento ✅ primera pasada

**Medido en el móvil, no supuesto.** El punto de partida eran 28-35 fps con 156
draw calls y 168.000 triángulos.

Lo primero fue **separar pantalla de sombra** en el contador: sumados no decían
nada, y separados salió que el pase de sombra costaba casi el triple que la
imagen. Ese fue el hallazgo que ordenó todo lo demás.

Seis técnicas, de más a menos impacto:

1. **Sombras** — de cuatro cascadas a una, alcance de 55 a 24 m, y sin sombra
   en el detalle menudo. Quitó 230.000 triángulos
2. **Descarte por frustum** — las multimallas se trocean en parcelas de 70 m.
   Antes cada una tenía una caja envolvente que cubría el mapa entero y **no se
   descartaba nunca**: las 460 matas de hierba se dibujaban mirases a donde
   mirases
3. **Descarte por oclusión** — cada muro del blockout lleva su
   `OccluderInstance3D`. Mirando al seto: 32 draw calls; al camino: 105
4. **LOD por distancia** — `ALCANCE` apaga cada pieza cuando deja de aportar
   (una piedrecita a 36 m, una brizna a 44), con desvanecido
5. **LOD de malla** — el cerezo tiene dos versiones: 596 triángulos de cerca y
   236 a partir de 44 m
6. **Menos polígonos en origen** — `divisiones` en `_esfera()`. El decorado bajó
   de 489.000 triángulos a 277.000

Y en los shaders: el hash de ruido ya no usa `sin()` —eran más de treinta senos
por píxel en una superficie que ocupa la pantalla entera, y era el tirón
constante—, MSAA cambiado por FXAA, mapa de sombras a 2048 con filtro duro, y
distancia de renderizado de 155 m con la niebla cerrando entre 78 y 148.

**Resultado: de 358.200 triángulos por fotograma a ~144.000, y de 156 draw
calls a ~83.**

### Lo que NO se puede usar

**Bajar la resolución de render** (`scaling_3d/scale`). Es la palanca más fuerte
que hay en un móvil, pero con cel shading emborrona los contornos duros —que son
justo lo que define el estilo— y se ve peor que en un juego fotográfico. Probado
y descartado (trampa 63).

### Si hace falta una segunda pasada

Por orden de lo que queda por apretar:

- Alcance de sombra de 24 a 18 m
- Quitar la sombra a los cerezos (se pierde bastante, es el último recurso)
- Menos props: `copias` en `CAMPO` y `LIMITE` de `decorador_nivel.gd`
- Bajar el detalle menudo, que son ~1.100 de los 2.000 props

---

## Fase E — Movimiento y combate

> **Las animaciones ya están dentro** (2026-08-10): 25 en la librería
> compartida. Ver [`17-ANIMACIONES.md`](17-ANIMACIONES.md).

### E1. Salto ✅ hecho

Las tres partes separadas: impulso (`jump_start`), caída (`jump_loop`) y
**aterrizaje**, que era el que faltaba. La animación de aterrizaje llevaba
tiempo en la librería y en la máquina de animación, pero no la pedía nadie: al
tocar suelo se pasaba directo a `Idle`.

Ahora hay un estado `Land` propio, porque reproducirla sin él no funciona — el
`enter()` del estado siguiente pide `locomocion` en el mismo fotograma y se la
come. Dura 0,22 s (la de Mixamo dura más de un segundo, y un segundo sin
control después de cada salto es una eternidad), se puede cancelar moviéndose,
saltando o pegando, y **solo sale si se venía cayendo de verdad**: con cada
bordillo de diez centímetros disparándola, el personaje iba dando respingos.

### E2. Doble salto ✅ hecho

Segundo impulso en el aire, con voltereta. Al 85 % del primero —si fuera igual
o mayor, el primero sobra— y **anulando la velocidad vertical antes**, así que
sube lo mismo tanto si se pide arriba del todo como cayendo a plomo. Sin eso,
encadenarlo tarde no levantaba del suelo y parecía que el botón no respondía.

Se repone al tocar suelo, y durante la voltereta se sigue teniendo control.

### E3. Trepar cornisas ✅ hecho

Detección con dos rayos: uno horizontal a la altura del pecho para ver si hay
pared, y otro vertical desde arriba para encontrar el canto. Se comprueba que el
canto esté a una altura agarrable (1,0–2,3 m) y que sea una superficie por la
que se pueda andar — un tejado inclinado no es una cornisa, se agarraría para
acabar resbalando.

Solo se busca **cayendo**, no subiendo: mirándola también en la subida, se
engancharía en el borde nada más despegar de un saliente bajo y agarrarse
pasaría de ser una ayuda a ser un estorbo.

Colgada se está sin prisa —no hay temporizador, no se cae sola— y hay dos
salidas: `jump` sube, y tirar del joystick hacia el lado contrario suelta. Se
suelta así porque **no hay más botones**: en el móvil están joystick, salto y
golpe, y no cabe uno de «soltar».

Al subir, la posición se interpola a mano y con la vertical por delante de la
horizontal: en línea recta el personaje entra en diagonal atravesando la
esquina del muro.

> **Lo que falta ahora es NIVEL, no mecánica.** El parque tiene una sola
> plataforma trepable y queda baja. Trepar «abre el diseño de nivel» solo si hay
> salientes a los que subir y algo arriba que merezca la pena — eso toca al
> repasar el escenario.

### E4. Cofrecito ✅ hecho

Tenía un escudo frontal de **130°** y giraba a **2,2 rad/s**: te encaraba antes
de que llegaras al costado, así que solo caía con el especial. Un enemigo con
una sola respuesta no enseña nada — enseña a esperar a que se cargue la barra.

- Escudo de 130° a **80°**
- Giro de 2,2 a **1,1 rad/s**
- **Aturdimiento tras bloquear**: cada vez que para un golpe se queda 0,65 s
  quieto y con el escudo abajo, y durante ese hueco se le entra por donde sea

Lo tercero es lo que lo cambia todo, porque convierte el bloqueo en una
INVITACIÓN: pegas de frente, ves que rebota, y en ese hueco te da tiempo a
rodearlo. La lección se aprende sola, sin un cartel que la explique.

Se reutiliza el estado `Stagger`, que ya hacía exactamente eso —frenar, guardar
la hitbox y no contraatacar— solo que durando menos.

---

## Fase F — Conversación viva

### F1. Retratos

Cara del personaje en el panel. Se pueden sacar **del propio modelo 3D**: se
renderiza en Blender un primer plano con fondo transparente. Sale gratis, sale
idéntico al personaje del juego y no hay que buscar imágenes por ahí.

Tres gestos por personaje: normal, contenta, preocupada.

### F2. Animación de hablar ✅ hecho

Ahora hay un **bucle de hablar** (`talk_idle`) por debajo de toda la
conversación, y los gestos se mezclan encima como acentos. Antes cada línea
disparaba un gesto suelto y, entre gesto y gesto, los dos personajes volvían a
la pose de estar de pie: dos estatuas turnándose para soltar un manotazo.

Tras cada gesto se vuelve al bucle. No hay señal fiable de «este gesto terminó»
—el `AnimationTree` mezcla y no avisa por estado— así que se le pregunta a la
librería cuánto dura y se espera eso, igual que hace el combate para encajar los
golpes.

Y los gestos del diálogo de Mercury dejan de ser prestados del combate: `hurt`
pasa a `surprised` y `victory` a `nod`, que es lo que dicen las frases.

### F3. Transiciones

Lo de Mercury («¿hay alguien ahí?» y salta la de alerta de golpe) es que se
viaja al estado sin fundido. Todas las transiciones de conversación con mezcla
de 0,25-0,35 s.

### F4. Transformación ✅ hecha (falta su sonido)

Era una sola pose: se saltaba a `transform_pose` y ahí se quedaba, sin efecto
ninguno. Se leía como «ha cambiado de postura», no como que acaba de convertirse
en Sailor Mercury.

Ahora son tres tiempos, con los tiempos medidos de las propias animaciones —si
un día se cambia `transform_start` por otra más larga, esto sigue cuadrando:

1. **Alza el broche** (`transform_start`) y sube un remolino de chispas doradas
2. **El destello**, justo en el corte entre una animación y otra: estallido
   blanco, el tiempo se para 0,16 s y la cámara se sacude. Aquí es donde pasa
3. **La pose**, sostenida mientras cae la purpurina

El hit stop va DESPUÉS del destello y no antes: parar el tiempo justo cuando la
luz llena la pantalla es lo que hace que el momento se sienta importante.

> **Le falta su sonido.** Ahora mismo va prestado del ataque especial, y no es lo
> mismo: el especial es un golpe y esto es una aparición. Hace falta uno propio
> —campanillas subiendo, un golpe de arpa, algo con brillo— y se cambian dos
> líneas en `combat_feel.gd` (`SFX_TRANSFORMACION` y `SFX_TRANSFORMACION_INICIO`).

### F5. Audio de Mercury

«Por el poder estelar del planeta Mercurio» va lento y sin emoción. Se
regenera en fish.audio con otra etiqueta y más ritmo. El texto y las etiquetas,
en [`14-VOCES.md`](14-VOCES.md).

---

## Fase G — El marco del juego

### G1. Menú principal

Continuar · Partida nueva · Ajustes · Salir. Fondo con el parque de verdad
detrás, no una pantalla plana.

### G2. Guardado

Tres ranuras. Se guarda: nivel, checkpoint, estrellas, corazones, personajes
desbloqueados y tiempo jugado. Autoguardado al pasar cada checkpoint.

### G3. Muerte y checkpoints

- Corazones que se pierden al recibir daño
- Al quedarse sin ninguno, se vuelve al último checkpoint
- **Nunca se pierde el progreso de coleccionables**: lo recogido, recogido está
- Checkpoints visibles y generosos

### G4. Corazones escondidos

Suben el máximo de vida. Escondidos de verdad, y **permanentes**: una vez
encontrado, ya no se pierde.

### G5. Modo desarrollador

El de la Fase A, con más cosas según hagan falta.

---

## Fase H — Historia

Todo el detalle en [`16-GUION.md`](16-GUION.md). El montaje:

1. **Cinemática de apertura en viñetas.** Ilustraciones fijas con movimiento de
   cámara, voz de narrador y música. Cuatro o cinco viñetas, minuto y medio
2. **Escenas entre niveles**, más cortas
3. **Final**

El arte se genera aparte. Lo que hace falta de mí es el guion, el montaje y
que suene.

---

## Qué hago primero

**Fase A entera**, en este orden:

1. Colisiones de props (lo que más se nota)
2. Cuerpo sólido de Mercury y enemigos
3. Barrido de agujeros del suelo
4. Los gatos: cara, colisión y pegarse al terreno
5. Farol flotante
6. Diálogo: avanzar y cerrar
7. Modo desarrollador

Y en paralelo, para ti: [`17-ANIMACIONES.md`](17-ANIMACIONES.md) tiene la lista
de qué subir a Mixamo y con qué nombre guardarlo. Cuanto antes empieces, antes
se puede hacer la Fase E.
