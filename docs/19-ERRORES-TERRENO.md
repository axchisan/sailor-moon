# Errores de terreno tras la reforma — corregidos

> Encontrados probando el Nivel 1 el 2026-08-10, después de que el terreno
> absorbiera el camino. **Todos corregidos y verificados** — la auditoría
> (`tools/auditar_nivel.gd`) sale limpia y el estanque y el pasillo se han
> mirado en marcha.
>
> Contexto de la reforma: [`ESTADO.md`](ESTADO.md) §6, trampas 69 a 72.

## Cómo quedó cada uno

| # | Qué era | Cómo se arregló |
|---|---|---|
| 1 | El parque sobre el estanque, puente colapsado, cerezo atravesándolo | El estanque **busca sitio** en vez de colgarse de un punto que se mueve, y el puente **reserva su paso** |
| 2 | Muro saltable en la arena | La colisión del muro sube 4 m más que su malla: el límite se respeta sin que el parque parezca amurallado |
| 3 y 4 | Muros de pasillo flotando | Se les entierra el pie 2 m |
| 5 | Un muro cruzando el pasillo | En los giros, el muro del tramo nuevo se retira de la esquina |
| 6 | Props en el aire | El rayo que los posa **aparta el blockout** y solo puede encontrar el terreno |
| 7 | Pasillos que no cierran contra las arenas | Contra una arena el muro se **alarga** hasta solaparse |

## Segunda tanda (2026-08-10, tarde)

| Qué era | Cómo se arregló |
|---|---|
| **Colisiones invisibles que paraban a la jugadora** y obligaban a saltar para entrar en la arena del portal | El suelo del blockout **ya no colisiona**. El terreno sube hasta su cara de arriba, pero con vértices cada 3,2 m se queda corto en el BORDE, y ahí la losa asomaba como un escalón invisible: medidos **48 cm** en la entrada de la arena del portal y **1,14 m** en el pasillo. No se arregla afinando el aplanado —una rejilla de tres metros no puede reproducir el canto de una losa—: manda una sola superficie, y es la que se ve |
| La barrera **rosada** de las arenas se saltaba | Su caja de choque sube 4,5 m más que el panel (`barrier_extra_collision` en `arena.gd`). Era esto lo que se había pedido; por error se le había hecho a los muros verdes del blockout — que se quedan así porque también hacía falta |

**Cómo se encontró:** barriendo una línea con rayos y buscando saltos bruscos de
altura, comparando el terreno solo contra el terreno más el blockout. Los
escalones invisibles no se ven, pero un rayo sí los mide.

## Lo que queda pendiente

- **Los cantos de los setos.** Siguen siendo cajas: se les ve la cara de arriba
  y las esquinas, y eso es lo que aún hace que se lean como bloques. No es un
  fallo de montaje, es que a la pieza le falta remate.
- **Dos rincones no encuentran sitio** (`AltarGato` y `Vivero`). Salen por
  consola en cada carga. De nueve rincones se colocan siete.
- **Props encima de Sailor Mercury**: un arbusto y alguna cosa más le caen
  dentro. El `Encuentro` no reserva su hueco, igual que le pasaba al puente.
- **El farol de al lado de Mercury flota.** Es el tercero del objetivo, el que
  va alto a propósito (`FAROLES` en `constructor_nivel.gd` lo pone a 1,6 m),
  pero se posa como si estuviera al ras.
- **Un muro de pasillo que no conecta con el anillo de la arena** (foto 4, cerca
  de `(45.6, 0.6, -60.9)`), por los dos lados. El alargue contra arenas se hace
  cuando el paso vecino ES una arena; ahí debe de haber un giro de por medio y
  no se aplica.
- **`ClaroPortal` tiene 3 bocas** en la auditoría. No es nuevo: el cilindro del
  suelo tapaba los rayos y lo ocultaba. Ahora que el suelo no colisiona, se ve
  que su anillo tiene más aberturas de las previstas.

## La herramienta

`tools/auditar_nivel.gd` recorre el mapa y comprueba cinco cosas, cada aviso con
su coordenada. **Hay que pasarla después de tocar el recorrido o el terreno**:

```bash
godot --headless --path . --script tools/auditar_nivel.gd
```

Dibuja además un plano del nivel en planta (`plano_nivel.png`), que es lo que
enseña de un vistazo si algo se ha ido a montar encima de otra cosa. Los avisos
de texto dicen qué pieza pisa a cuál; el plano da la vista de conjunto, que es
justo lo que faltaba para ver que el estanque se había metido bajo el parque.

---

## El análisis original

## La causa común: el blockout se enterró y nadie avisó a lo que se apoyaba en él

No son seis fallos distintos, son casi todos el mismo.

Antes, el suelo del blockout **se dibujaba**, y los muros, vallas y props se
colocaban sobre él: la losa era a la vez lo que se veía y la referencia de
altura, así que cuadraban por construcción.

Ahora la losa sigue existiendo como cuerpo pero **no se dibuja**; lo que se ve es
el terreno, que sube hasta su cara de arriba. Y el terreno **no es plano**: tiene
el ruido del relieve y, sobre todo, el suavizado de faldas (`_suavizar_faldas()`)
que promedia alturas cerca de los bordes. Los muros, en cambio, se siguen
colocando a la altura del TRAMO, que es un número exacto.

Resultado, según de qué lado caiga la diferencia:

- El terreno queda **por debajo** → el muro flota, y con él lo que se apoyó cerca
- El terreno queda **por encima** → el muro se hunde y **se puede saltar**

Todo lo demás de la lista sale de ahí, menos el estanque y las juntas de las
arenas, que son de antes.

## Los fallos, uno por uno

### 1. El parque montado sobre el estanque · `(4.3, 2.7, -61.3)`

El puente casi colapsa con la orilla y hay un cerezo atravesándolo. **No es de la
reforma**: es la trampa 64 repitiéndose. El estanque se sitúa por rumbo y
distancia desde el centro del parque, y ese centro se movió al agrandar la
pradera de arranque.

Además, el cerezo dentro del puente dice que **el puente no reserva su sitio** en
el registro de ocupación (`HUECO`), o que se siembra después que los cerezos.

Arreglo: que el estanque deje de depender de un punto que se mueve, y que el
puente reserve su hueco antes de que se siembre el arbolado.

### 2. Muro saltable en la arena · `(87.1, 5.5, -92.0)`

El terreno elevado junto al muro deja el borde a una altura desde la que se salta
por encima.

**Lo que pidió el usuario, literal:** mantener la altura visual de ese límite,
pero que no se pueda pasar por encima. O sea, la solución NO es subir el muro —
se vería un paredón— sino **separar lo que se ve de lo que se choca**: dejar la
malla como está y darle al cuerpo una caja más alta (invisible), que llegue por
encima de cualquier salto.

Conviene hacerlo en `_losa()` para los `Borde`, no caso por caso.

### 3 y 4. Muro de pasillo flotando · `(65.2, 4.6, -81.7)` y `(67.5, 4.6, -97.9)`

Los dos lados del mismo pasillo. El terreno es «un poquito irregular» y el muro
se coloca a altura fija.

Arreglo: **bajar la base de los muros** bastante por debajo del suelo (un metro o
dos). Un muro con el pie enterrado nunca flota, y lo que sobra no se ve porque
queda dentro del terreno. Es más barato y más robusto que intentar que el terreno
quede perfectamente plano.

### 5. Un muro atravesando otro pasillo · `(80.9, 7.7, -84.4)`

Un muro cruza el pasillo y tapa media anchura; una valla hace lo mismo. Este
**no es de altura, es de planta**: hay geometría del blockout metida donde no
toca. Sospechoso: el tramo con `subida` y los muros del tramo vecino, o un
`giro` que deja los bordes de dos tramos cruzados.

Hay que mirar `_pasillo()` y el encadenado de tramos en `construir()`.

### 6. Props flotando y cerezo dentro del muro · `(44.5, 0.6, -61.0)`

Pared, tronco y farol flotando, y un cerezo atravesando el muro del pasillo.

Lo de los props es la misma causa de fondo, pero por otra vía: `_posar()` lanza un
rayo hacia abajo y **la capa 1 incluye las losas invisibles del blockout**. Donde
la losa está por encima del terreno, el prop se posa sobre la losa —que no se
ve— y parece que flota. Hay que decidir sobre qué se posa: si sobre el terreno
siempre, o excluir del rayo los cuerpos del blockout.

El cerezo dentro del muro es la trampa 45: se mide el pie contra el muro, y un
tronco a medio metro se da por bueno. Aquí no lo es.

### 7. Los pasillos no cierran contra las arenas

Las paredes rectas de los pasillos no encajan con el anillo curvo de las arenas y
quedan huecos por los que se puede colar la colisión. Es de antes de la reforma y
es hermano de la trampa 35 (dos superficies tangentes no cierran), pero aplicado
a los MUROS en vez de al suelo.

## Cómo se comprueba cada arreglo

`F5` salta de tramo en tramo, y `F6` enseña las formas de colisión — que es lo
que hace falta para el nº 2 y el nº 7, porque el problema está en el cuerpo y no
en lo que se ve. El panel de `F1` da la posición para cotejarla con las de arriba.

**Ninguno de estos se da por bueno sin verlo en marcha.** Varios de ellos se
«arreglan» en el papel y siguen igual en el juego, que es justo cómo se llegó
hasta aquí.

## Orden sugerido

1. **Bajar el pie de los muros** — arregla el 3, el 4 y parte del 6 de una vez,
   y es el cambio más pequeño
2. **Decidir sobre qué se posan los props** — el resto del 6
3. **Cuerpo más alto que la malla en los bordes** — el 2
4. **El muro cruzado** — el 5, que hay que investigar aparte
5. **El estanque y el puente** — el 1
6. **Las juntas de muro contra arena** — el 7
7. **Barrido sistemático** buscando más casos de lo mismo por todo el nivel
