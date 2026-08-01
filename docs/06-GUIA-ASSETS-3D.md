# Guía de generación de recursos 3D con Tripo AI

> Sustituye a VRoid Studio como pipeline de personajes.
> Complementa a [`02-PIPELINE-ASSETS.md`](02-PIPELINE-ASSETS.md).

## 0. El dato que cambia todo

**El modo texto-a-3D de Tripo genera internamente una imagen y luego la convierte
a 3D.** No son dos tuberías distintas: es la misma, y en modo imagen tú controlas
el paso intermedio en vez de dejárselo a la IA.

Consecuencia práctica:

| Tipo de asset | Modo | Por qué |
|---|---|---|
| **Personajes reconocibles** (Serena, Rei, Luna…) | **Imagen → 3D** | El texto nunca va a clavar un diseño concreto. Con imagen decides tú |
| **Enemigos y props inventados** (Peluchín, farol, banco) | **Texto → 3D** | No hay un diseño que respetar; ahorras el paso de buscar imagen |

---

## 1. Ajustes exactos de generación

Panel **Geometría y textura**, antes de pulsar *Generar modelo*:

| Ajuste | Valor | Motivo |
|---|---|---|
| Modelo IA | **v3.1 – Máx. calidad** | Ya lo tienes puesto |
| Modelo HD / Malla Smart | **Modelo HD** para personajes | Malla Smart para props simples |
| Calidad de malla Ultra | **OFF** | Genera detalle que vamos a tirar igualmente |
| Completar con IA y mejora 3D | **OFF** | Actívalo solo si la espalda sale mal |
| Textura | **ON** | |
| Texture Quality | **2K** | 4K y 8K son de pago y en móvil no aportan |
| PBR | **ON** | Da un albedo limpio, separado de la iluminación. Es justo lo que el cel shading necesita |
| Topología | **Triángulo** | glTF y Godot trabajan en triángulos. *Cuadrilátero* solo sirve si vas a editar en Blender |
| **Conteo de Polígonos** | **⚠️ EL CRÍTICO** | Ver tabla abajo |

### ⚠️ El conteo de polígonos es el ajuste que más importa

Tu Serena salió con **593.292 caras**. Nuestro presupuesto para el personaje
principal es de **15.000–25.000 triángulos**. Está **24 veces por encima**.

En un móvil, con ese modelo más 8 enemigos en pantalla, el juego no llega a 30 fps.

| Asset | Conteo de polígonos |
|---|---|
| Serena / cualquier Sailor | **25.000** |
| Luna (gato) | **6.000** |
| Enemigos (Peluchín, Globito, Cofrecito) | **5.000** |
| Props grandes (farol, banco, árbol) | **3.000** |
| Props pequeños (chispa, estrella, broche) | **1.000** |

> **Ponlo ANTES de generar.** Regenerar cuesta otros 30 créditos. Si el modelo ya
> está hecho, usa **Remesh** (barra lateral izquierda) para bajarlo sin regenerar
> — comprueba primero cuántos créditos cuesta.

### Tus créditos

115 créditos ≈ **3 generaciones más** a 30 c/u. Prioriza en este orden:

1. **Serena en traje de Sailor** ← ya la tienes ✅
2. **Serena de civil** (uniforme escolar) — necesaria para la transformación
3. **Peluchín** (enemigo básico) — es el único enemigo que el código usa hoy

El resto (props, coleccionables, otras Sailors) puede esperar o salir de
bibliotecas CC0 como [Kenney](https://kenney.nl/assets) y
[Quaternius](https://quaternius.com/), que son gratis e ilimitadas.

---

## 2. Ajustes de exportación

| Ajuste | Valor |
|---|---|
| Formato | **GLB** ✅ (ya lo tienes bien) |
| Resolución de textura | **2k** para Serena y las Sailors · **1k** para enemigos · **512** para props pequeños |

**Por qué GLB:** es glTF 2.0 binario, el formato que mejor soporta Godot, y mete
malla + esqueleto + texturas en un solo archivo. FBX solo hace falta si vas a
pasar por Mixamo (ver §5).

Deja los `.glb` en:

```
assets/models/characters/     ← Serena, Sailors, Luna
assets/models/props/          ← farol, banco, coleccionables
assets/models/environment/    ← piezas grandes de escenario
```

---

## 3. Imágenes de referencia: cómo conseguir las ideales

La IA lee la imagen **al detalle**, así que la calidad de la referencia decide la
calidad del modelo. Requisitos, por orden de importancia:

| Requisito | Detalle |
|---|---|
| **Pose** | T-pose o A-pose. Nada de poses de acción: los brazos cruzados o las piernas ocultas confunden a la IA |
| **Cuerpo completo** | Sin recortes. Que se vean los pies |
| **Fondo** | Blanco liso o transparente (PNG) |
| **Iluminación** | Uniforme y clara. Las sombras marcadas la IA las interpreta como geometría |
| **Resolución** | Mínimo 1040×1040. Cuanto más nítida, menos "blandurria" sale la malla |
| **Silueta legible** | Que el pelo, la falda y los accesorios se distingan del fondo |

### Las tres mejores fuentes, en orden

**1. Fotos de figuras coleccionables** ← *la mejor con diferencia*

Busca `S.H.Figuarts Sailor Moon`, `Figuarts Sailor Mars official photo`,
`Bandai Sailor Moon figure product photo`. Las fotos de producto de Bandai son
exactamente lo que la IA quiere: **cuerpo entero, fondo blanco, luz de estudio
uniforme, alta resolución y pose neutra**. Es difícil encontrar mejor input.

**2. Hojas de modelo de animación (*settei*)**

Busca `Sailor Moon settei`, `Sailor Moon 設定資料`, `Sailor Moon model sheet`.
Son las hojas que usaban los animadores: frente, perfil y espalda del mismo
personaje, con proporciones consistentes. Perfectas de referencia, aunque al ser
line art plano dan menos volumen que una figura.

**3. Generar la imagen con IA**

Si no encuentras la vista que necesitas, genera un *character sheet*:
[3D AI Studio](https://www.3daistudio.com/Tools/CharacterSheetGenerator),
[Anifusion](https://anifusion.ai/dashboard/character-sheets/) o
[Pixa](https://www.pixa.com/create/character-turnaround-sheet).
Subes una imagen del personaje y te devuelve vistas consistentes.

> **Ojo con la multivista de Tripo:** el botón *Generar multivistas* es de pago en
> tu plan. Trabajaremos con **una sola vista frontal**, así que la espalda del
> modelo se la inventa la IA. Para nuestro juego, donde la cámara va detrás del
> personaje… conviene revisar que la espalda no salga rara. Si sale mal, ahí sí
> activa *Completar con IA y mejora 3D*.

Nota: usamos arte oficial solo como referencia para un regalo privado que no se
publica ni se monetiza, en línea con lo acordado en el GDD.

---

## 4. Prompts listos para usar

### 4.1 Enemigos (texto → 3D)

Son diseños nuestros, así que el texto funciona perfecto.

**Peluchín** (el básico, ya implementado en el código):
```
cute chibi plush monster creature, round body, big innocent eyes,
small stubby arms, soft purple and lavender fur, tiny horn,
friendly not scary, magical girl anime villain minion,
cel shaded flat colors, low poly game asset, clean topology,
T-pose, white background, no baked shadows
```

**Globito** (enemigo a distancia):
```
cute floating balloon monster, translucent light blue body,
small wings, big round eyes, tiny arms, soap bubble texture,
magical girl anime style, harmless and funny,
cel shaded flat colors, low poly game asset, white background
```

**Cofrecito** (enemigo con escudo):
```
cute treasure chest monster with small legs, wooden body with
golden trim, holding a round shield, sleepy eyes, anime chibi style,
magical girl game enemy, cel shaded flat colors, low poly game asset,
white background
```

### 4.2 Props del Parque Juuban (texto → 3D)

Uno por prompt. **Nunca pidas la escena entera:** "parque japonés completo" da
una masa de geometría inservible; diez piezas sueltas te dan un kit reutilizable.

```
japanese park wooden bench, simple shape, cel shaded flat colors, low poly game asset, white background
japanese stone lantern toro, weathered grey stone, cel shaded flat colors, low poly game asset, white background
cherry blossom tree sakura, pink flowers, stylized round canopy, cel shaded flat colors, low poly game asset, white background
japanese park trash bin, green metal, cel shaded flat colors, low poly game asset, white background
round trimmed bush, bright green, cel shaded flat colors, low poly game asset, white background
small stone water fountain, japanese park style, cel shaded flat colors, low poly game asset, white background
```

### 4.3 Coleccionables y objetos mágicos (texto → 3D)

```
magical glowing star crystal collectible, pink and gold, faceted,
cute anime game pickup item, cel shaded flat colors, low poly, white background

small sparkle gem pickup, pale pink crystal shard, glowing,
cute anime game item, cel shaded flat colors, low poly, white background

magical girl transformation brooch, round golden locket with pink gem
and wings, ornate but simple shapes, anime prop,
cel shaded flat colors, low poly, white background

golden tiara with red gem in the center, thin elegant circlet,
magical girl anime accessory, cel shaded flat colors, low poly, white background
```

### 4.4 Vocabulario que funciona

**Incluye siempre:** `cel shaded`, `flat colors`, `low poly`, `game asset`,
`clean topology`, `white background`, `T-pose` (personajes), `no baked shadows`.

**Evita siempre:** `realistic`, `photorealistic`, `4k`, `highly detailed`,
`ultra detailed`, `cinematic lighting`. Generan mallas pesadas y con luz
horneada en la textura, que es veneno para el cel shading.

---

## 5. Rigging y animación

### El camino recomendado: Tripo → Mixamo → Godot

Aunque Tripo tiene auto-rig y animación propios, pasar por Mixamo nos conviene
porque **ya validamos que Godot retargetea desde nomenclatura humanoide estándar**
(ver [`04-VALIDACION-VRM.md`](04-VALIDACION-VRM.md)).

1. En Tripo, exporta el modelo en **T-pose** como **FBX**.
2. Súbelo a [Mixamo](https://www.mixamo.com/) (gratis con cuenta Adobe).
   Te lo riguea solo: marcas barbilla, muñecas, codos, rodillas e ingle.
3. Descarga las animaciones:
   - La **primera** con *With Skin* (trae la malla).
   - Las **demás** con *Without Skin* (solo esqueleto, mucho más ligeras).
4. En Godot, el retargeting por mapeo de huesos las aplica sobre el mismo modelo.

**Las 15 animaciones que necesitamos** (se preparan UNA vez y sirven para las
cinco Sailors, porque comparten esqueleto):

| Categoría | Animaciones | Dónde buscarlas en Mixamo |
|---|---|---|
| Locomoción | `idle`, `walk`, `run` | *Idle*, *Walking*, *Running* |
| Aire | `jump_start`, `jump_loop`, `land` | *Jump* |
| Combate | `attack_1`, `attack_2`, `attack_3`, `special` | *Martial Arts*, *Fighting*, *Magic* |
| Reacción | `hurt`, `dizzy`, `victory` | *Hit Reaction*, *Dizzy*, *Victory* |
| Narrativa | `transform_pose`, `talk_idle` | *Praying*, *Talking* |

Para `attack_3` va bien cualquier *spinning kick*; para `special`, cualquier
*casting* o *power up*.

### Alternativa: el auto-rig de Tripo

Más rápido (botón *Animar* en la barra lateral) pero con menos animaciones
disponibles. Sirve para prototipar; para las 15 finales, Mixamo gana.

---

## 6. Meter el modelo en Godot

### 6.1 Escala y origen

Tripo exporta a escala arbitraria. En Godot, **1 unidad = 1 metro**, y Serena
debería medir **~1,55 m**.

Ajuste rápido, sin Blender: seleccionas el nodo del modelo y le pones `scale`
hasta que su altura cuadre con la cápsula de 1,6 m que ya tenemos.

Ajuste correcto, en Blender: escalas, aplicas transformaciones (`Ctrl+A`), pones
el origen entre los pies y reexportas GLB.

### 6.2 Cel shading — el paso que sustituye a MToon de VRoid

Los modelos de Tripo llegan con `StandardMaterial3D` PBR, que se ve **realista,
no anime**. Perdíamos el cel shading que VRoid daba gratis.

Ya está resuelto: `src/core/toon_material.gd` reaprovecha el shader MToon que
trajo el addon VRM y lo aplica a **cualquier** malla.

```gdscript
# En el _ready del personaje, tras instanciar el modelo
ToonMaterial.apply($Model)
```

Convierte cada superficie a MToon conservando la textura, y añade el contorno
negro con un `next_pass` en `cull_front` (la técnica de *inverted hull*).

**Verificado** sobre las cápsulas del prototipo: 10 superficies convertidas,
contorno activo, **60 fps**. Los parámetros de la llamada (`shade_color`,
`toony`, `outline_width`, `rim_color`) se ajustan cuando estén los modelos
reales — con las cápsulas sin textura el rim light se ve exagerado.

### 6.3 Sustituir la cápsula por Serena

En `scenes/prototypes/player.tscn`, bajo el nodo `Model`:

1. Instancia el `.glb` de Serena como hijo de `Model`.
2. Borra (o esconde) `Body` y `Nose`.
3. Comprueba que **mira hacia −Z**: es la convención que usa `face_direction()`
   en `player.gd`. Si mira al revés, rota el modelo 180° en Y.
4. Ajusta la altura para que los pies queden en y = 0.
5. La `CollisionShape3D`, la `Hitbox` y la `Hurtbox` **no se tocan**: son
   independientes del aspecto, que es justo para lo que se diseñaron así.

---

## 7. Resumen: qué generar y en qué orden

| # | Asset | Modo | Polígonos | Textura | Estado |
|---|---|---|---|---|---|
| 1 | Serena – Sailor Moon | Imagen | 25.000 | 2k | ✅ hecho (falta bajar polígonos) |
| 2 | Serena – civil | Imagen | 25.000 | 2k | pendiente |
| 3 | Peluchín | Texto | 5.000 | 1k | pendiente |
| 4 | Estrella de Sueño | Texto | 1.000 | 512 | pendiente |
| 5 | Chispa | Texto | 800 | 512 | pendiente |
| 6 | Broche de transformación | Texto | 1.000 | 512 | pendiente |
| 7 | Luna (gato) | Imagen | 6.000 | 1k | pendiente |
| 8 | Props del parque (×6) | Texto | 3.000 | 512 | CC0 mejor |
| 9 | Globito y Cofrecito | Texto | 5.000 | 1k | tras la Fase 1 |

**Lo siguiente que deberías hacer:** pasar la Serena que ya tienes por **Remesh**
a 25.000 polígonos y exportarla en **GLB a 2k**. Con eso puedo sustituir la
cápsula y ver cómo queda el cel shading sobre un modelo de verdad.
