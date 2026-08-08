# Escenarios — cómo se construyen de verdad

## La respuesta corta, para que no pierdas tiempo buscando

**No existe una herramienta que te genere un nivel 3D jugable a partir de un
prompt.** Ni gratuita ni de pago. Las que lo prometen devuelven una masa de
geometría sin colisiones, sin escala, sin materiales separados y sin posibilidad
de moverte por ella.

Nadie construye escenarios así. Un escenario de videojuego se hace con **tres
capas** y las tres se montan en el motor:

| Capa | Qué es | De dónde sale |
|---|---|---|
| **1. Fondo** | Cielo, horizonte, edificios lejanos. Nunca lo pisas | Skybox / HDRI panorámico |
| **2. Suelo y volúmenes** | Por donde caminas y chocas | Se hace en Godot con CSG |
| **3. Props** | Farolas, bancos, árboles, vallas | Piezas sueltas, generadas o CC0 |

La IA sirve muy bien para la capa 1 y la capa 3. La capa 2 se hace a mano en
Godot, y es más rápido de lo que parece.

---

## Capa 1 — El fondo (skybox / HDRI)

Es el truco que hace que un escenario pequeño parezca un mundo. Una imagen
panorámica de 360° envuelve la escena; el jugador nunca llega hasta ella.

### Opciones gratuitas

| Herramienta | Qué da | Notas |
|---|---|---|
| **[Poly Haven](https://polyhaven.com/hdris)** | HDRIs reales, **CC0** | Sin IA, sin registro, sin límite. **Empieza por aquí** |
| **[3DTexel](https://3dtexel.com/hdri-generator/)** | HDRI por prompt, gratis | Exporta PNG equirectangular y HDR |
| **[KenerateAI](https://kenerateai.com/ai-3d-environment-generator)** | Skybox 360° + EXR + malla GLB | Sin marca de agua |
| **[Panorama Generator](https://panoramagenerator.com/skybox-generator)** | Panorámica equirectangular `.hdr` | Listo para Blender/Unity/UE |

### Prompts para nuestros niveles

```
anime style japanese park at golden hour, cherry blossom trees in the distance,
soft pastel sky, fluffy clouds, dreamy magical atmosphere, 360 panorama

anime style japanese shrine grounds at sunset, red torii gates far away,
autumn maple trees, warm orange sky, 360 panorama

anime style tokyo shopping street at dusk, neon signs in the distance,
purple and pink sky, 90s anime background art, 360 panorama

anime style theater interior, red velvet curtains, warm stage lights,
magical sparkles in the air, 360 panorama
```

### Cómo se pone en Godot

En el `WorldEnvironment` que ya tenemos: `Environment > Background > Mode: Sky`,
y en `Sky` cambias `ProceduralSkyMaterial` por un **`PanoramaSkyMaterial`** con
tu imagen. Un solo cambio y el nivel cambia de personalidad entera.

---

## Capa 2 — Suelo y volúmenes, en Godot

Aquí no hace falta ninguna herramienta externa. Godot trae **CSG** (geometría
constructiva): cubos, cilindros y esferas que se suman y restan. Es exactamente
para lo que se diseñó — bloquear un nivel rápido.

Para nuestras arenas hace falta muy poco:

- `CSGBox3D` para el suelo y las plataformas
- `CSGCylinder3D` para el borde circular de la arena
- Materiales planos de color, que el cel shading hace el resto

**Regla de oro:** monta el nivel **gris y jugable primero**, y decóralo después.
Es la misma regla que seguimos en la Fase 1 con las cápsulas, y funcionó.

Cuando el nivel esté validado, las piezas CSG se pueden sustituir por props
reales, o dejarlas si ya se ven bien con el toon shader.

---

## Capa 3 — Props

Aquí sí volvemos a las herramientas de IA, **una pieza por generación**.

> **Nunca pidas la escena entera.** "Parque japonés completo" da una masa
> inservible. Diez piezas sueltas te dan un kit que reutilizas en todos los
> niveles.

### Fuentes, por orden de conveniencia

**1. Bibliotecas CC0 — mira aquí ANTES de generar**

Suelen tener mejor topología que cualquier IA, pesan poquísimo y son gratis sin
límite ni atribución:

- **[Kenney](https://kenney.nl/assets)** — kits modulares coherentes, poly counts
  sensatos, atlas de texturas compartidos. El estándar de oro para prototipar
- **[Quaternius](https://quaternius.com/)** — packs temáticos de bajo poligonaje,
  estilo simpático que encaja con el nuestro
- **[Poly Haven](https://polyhaven.com/models)** — modelos y texturas CC0

Buscar 10 minutos aquí ahorra horas de limpieza en Blender.

**2. hi3d.ai** — para lo que no encuentres. Recuerda que es solo imagen → 3D,
así que necesitarás una imagen del objeto (búscala o genérala).

### Props del Nivel 1 (Parque Juuban)

| Prop | Polígonos | Prioridad |
|---|---|---|
| Banco de parque | 3.000 | alta |
| Farol de piedra (*tōrō*) | 3.000 | alta |
| Árbol de cerezo | 3.000 | alta |
| Arbusto redondo | 1.500 | alta |
| Papelera | 1.000 | media |
| Fuente de piedra | 3.000 | media |
| Valla baja de madera | 1.500 | media |

Todos pasan por `tools/blender_preparar_modelo.py` igual que los personajes.

---

## Receta completa para el Nivel 1

1. **Skybox:** genera o descarga una panorámica de parque japonés al atardecer
2. **Blockout:** en Godot, `CSGBox3D` para el suelo + las tres arenas y los
   tramos que las unen. **Juega el nivel así, en gris.**
3. **Props:** consigue el kit de 7 piezas (CC0 primero, hi3d.ai lo que falte)
4. **Colocación:** duplica y reparte props por el nivel. Un `MultiMeshInstance3D`
   si acabas poniendo docenas de arbustos iguales
5. **Cel shading:** cuelga todo de un nodo `ToonRoot` y queda unificado
6. **Presupuesto:** vigila que el total no pase de 150 draw calls (ver
   [`01-ARQUITECTURA.md`](01-ARQUITECTURA.md) §8)

---

## Especificación del Nivel 1 — Parque Juuban

Concretando la receta para el primer nivel real. La arena de pruebas actual mide
11 m de radio y ha demostrado funcionar con 8 enemigos, así que es la unidad.

### Recorrido

```
   INICIO ──tramo A── [ARENA 1] ──tramo B── [ARENA 2] ──tramo C── [GUARDIÁN]
   (Luna te                2 oleadas          3 oleadas            jefe suave
    guía)                  2 y 3 enemigos     3, 4 y 4
```

| Zona | Largo | Qué pasa |
|---|---|---|
| Tramo A | ~20 m | Se aprende a mover y saltar. Chispas por el camino guían |
| Arena 1 | Ø 22 m | Primer combate. Solo Peluchines |
| Tramo B | ~25 m | Plataformas bajas para saltar. Primera Estrella de Sueño escondida |
| Arena 2 | Ø 22 m | Aparece el Cofrecito: enseña que hay que rodear |
| Tramo C | ~15 m | Subida hacia el guardián, sin enemigos: tensión |
| Guardián | Ø 26 m | Jefe con más vida y tres oleadas de apoyo |

**Duración objetivo:** 8–10 minutos. Es un tutorial, no una maratón.

### Presupuesto de props

Con 7 piezas distintas se decora el nivel entero, repitiéndolas y rotándolas:

| Pieza | Cantidad | Polígonos c/u |
|---|---|---|
| Árbol de cerezo | ~14 | 3.000 |
| Arbusto redondo | ~25 | 1.500 |
| Farol de piedra | ~10 | 3.000 |
| Banco | ~6 | 3.000 |
| Valla baja | ~20 | 1.500 |
| Papelera | ~4 | 1.000 |
| Fuente | 1 | 3.000 |

Los arbustos y las vallas, al repetirse tanto, van con
`MultiMeshInstance3D`: 25 arbustos pasan de 25 draw calls a **1**.

### Estado: blockout hecho y jugado ✅

`scenes/levels/nivel_1_parque.tscn`. Se recorrió de principio a fin y se llegó
a `[Nivel] nivel_1 completado`.

Lo levanta **`src/level/constructor_nivel.gd`** a partir de una lista de tramos:

```gdscript
{"tipo": "pasillo", "largo": 20.0, "ancho": 9.0},
{"tipo": "arena",   "radio": 11.0, "nodo": "Arena1"},
{"tipo": "giro",    "grados": -90.0},
...
```

Cambiar el largo de un tramo recoloca **todo lo que va detrás**, arenas
incluidas. Es lo que hace usable un blockout: se toca veinte veces, y a mano
cada retoque obliga a recolocar cada pieza posterior.

> **Se generó con `MeshInstance3D` + `StaticBody3D`, no con CSG.** CSG es cómodo
> cuando montas a mano en el editor; generando por código no aporta nada, es más
> caro en móvil y Godot lo recompila en cada arranque.

Oleadas del nivel: 2+3 en la Arena 1 (solo Peluchines, se aprende a pegar),
3+4+4 en la Arena 2 (entra el Cofrecito: hay que rodear), 3+4+5 en el Guardián
(con Cofrecito y Hadita). **28 enemigos en total.**

Con la tecla **P** se ve la planta desde arriba. Un blockout se juzga mirando el
plano: si desde ahí no se entiende por dónde se va, jugándolo tampoco.

#### Dos fallos que costaron encontrar

**Los paneles curvos salían radiales, como los radios de una rueda.** Al colocar
un segmento en el ángulo θ de un círculo hay que rotarlo **φ = 90° − θ**, no
`−θ`: rotando `Y` un ángulo φ el eje Z local va a `(sin φ, 0, cos φ)`, y para
que mire al centro hay que igualarlo a la normal `(cos θ, 0, sin θ)`. El mismo
error estaba en la barrera mágica de `arena.gd` desde la Fase 1.

**Los huecos de entrada y salida de las arenas caían en el lado equivocado.** Si
detrás de una arena viene un giro, la salida va en la dirección **ya girada**;
usando la de entrada, el pasillo siguiente arranca de un punto del borde que
está tapado y la arena se convierte en una trampa sin salida.

### Orden de montaje

1. **Blockout** y jugarlo en gris de principio a fin. Si el recorrido no
   se entiende sin decoración, tampoco se entenderá con ella
2. **Skybox** de parque japonés al atardecer
3. **Props** por bloques: primero árboles y arbustos (definen el espacio),
   después el mobiliario
4. **Colisión:** los props decorativos NO llevan colisión. Solo el suelo, las
   paredes invisibles del recorrido y las plataformas. Menos física y menos
   sitios donde atascarse
5. **Medir** draw calls y triángulos contra el presupuesto de
   [`01-ARQUITECTURA.md`](01-ARQUITECTURA.md) §8

### Lo que define el nivel más que los props

- **El suelo debe leerse.** Un camino de color distinto marcando por dónde ir
  vale más que veinte árboles
- **Las arenas se ven de lejos.** Un círculo en el suelo o un cambio de textura
  avisa de que ahí va a pasar algo
- **Nada de callejones sin salida.** A los 8 años, perderse no es un reto, es un
  abandono

## Lo que NO conviene hacer

- ❌ Buscar la herramienta mágica que genere el nivel entero. No existe
- ❌ Generar props a 2 millones de triángulos y meterlos sin pasar por Blender
- ❌ Decorar antes de que el nivel sea jugable en gris
- ❌ Modelos distintos para cada arbusto: uno solo, repetido y rotado
