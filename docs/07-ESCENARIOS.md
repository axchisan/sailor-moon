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

## Lo que NO conviene hacer

- ❌ Buscar la herramienta mágica que genere el nivel entero. No existe
- ❌ Generar props a 2 millones de triángulos y meterlos sin pasar por Blender
- ❌ Decorar antes de que el nivel sea jugable en gris
- ❌ Modelos distintos para cada arbusto: uno solo, repetido y rotado
