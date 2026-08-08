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

| Fase | Qué | Por qué va aquí |
|---|---|---|
| **A** | Que el mundo sea sólido | Atravesar a Mercury o caerse por un agujero rompe la ilusión más que cualquier textura fea |
| **B** | Texturas reciclables | Todo lo que se construya después las usará. Hacerlo tarde obliga a repintar |
| **C** | Mundo abierto, límites naturales | Necesita las texturas de B para que los taludes y las rocas se lean |
| **D** | Rendimiento | Se mide cuando el escenario ya tiene su carga real, no antes |
| **E** | Movimiento y combate | Depende de las animaciones de Mixamo, que se bajan en paralelo |
| **F** | Conversación viva | Depende de E (librería de animaciones montada) |
| **G** | Marco: menú, guardado, vidas | Necesita que el juego ya sea agradable de jugar |
| **H** | Historia y cinemática | Lo último que se monta, lo primero que se ve |

**Lo que se puede hacer en paralelo:** bajar animaciones de Mixamo (A→E) y
generar el arte de la cinemática (H). Ninguna de las dos me bloquea a mí, y las
dos te bloquean a ti si se dejan para el final.

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

## Fase B — Texturas que se puedan reciclar

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

## Fase C — Que parezca un mundo, no un pasillo

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

## Fase D — Rendimiento

Hay tirones en zonas concretas. Antes de optimizar a ciegas, **medir**:

1. Recorrido automático por todo el nivel, midiendo por tramo
2. Tabla de FPS, draw calls y triángulos por zona
3. Atacar solo lo que aparezca

Sospechosos, por probabilidad:

- **Sombras**: el mapa direccional cubre mucho y cada cerezo proyecta
- **El contorno del cel shading**: duplica geometría de cada personaje
- **Física del pelo**: cinco personajes con varias cadenas
- **Enemigos**: instanciar en mitad de la pelea provoca el tirón justo al empezar

Herramientas: LOD por distancia, apagar sombras lejanas, agrupar enemigos en
una reserva creada al cargar en vez de en mitad del combate.

---

## Fase E — Movimiento y combate

### E1. Salto

El actual es raro. Se sustituye la animación y se separan las tres partes:
impulso, caída y aterrizaje, con transiciones cortas.

### E2. Doble salto

Segundo impulso en el aire, con giro. Además de que se siente bien, **abre el
diseño de nivel**: se pueden poner sitios altos con recompensa.

### E3. Trepar cornisas

Detección de borde delante y a la altura del pecho → se agarra → sube. Cambia
cómo se lee el mundo: un saliente deja de ser un muro y pasa a ser un camino.

### E4. Cofrecito

Tiene un escudo frontal de **130°** y gira a **2,2 rad/s**: te encara antes de
que llegues al costado, y por eso solo cae con el especial.

- Estrechar el escudo a ~80°
- Bajar el giro a ~1,1 rad/s
- **Aturdimiento tras bloquear**: si para un golpe, se queda quieto un momento
  con el escudo bajado. Así el bloqueo enseña a rodear en vez de castigar

---

## Fase F — Conversación viva

### F1. Retratos

Cara del personaje en el panel. Se pueden sacar **del propio modelo 3D**: se
renderiza en Blender un primer plano con fondo transparente. Sale gratis, sale
idéntico al personaje del juego y no hay que buscar imágenes por ahí.

Tres gestos por personaje: normal, contenta, preocupada.

### F2. Animación de hablar

Ahora una línea dispara un gesto seco. Debe entrar un **bucle de hablar**
mientras dura la frase, y los gestos puntuales mezclarse encima.

### F3. Transiciones

Lo de Mercury («¿hay alguien ahí?» y salta la de alerta de golpe) es que se
viaja al estado sin fundido. Todas las transiciones de conversación con mezcla
de 0,25-0,35 s.

### F4. Transformación

La animación actual no da la sensación. Hace falta una de verdad, con su pose
final, más efecto de partículas, destello y un buen golpe de sonido.

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
