# Reparto de personajes

> **2026-08-07.** Siete personajes procesados y verificados en Godot.

## 1. Estado del reparto

| Personaje | Altura | Triángulos | Modelo | Rig | En juego |
|---|---|---|---|---|---|
| **Serena** (Sailor Moon) | 1,55 m | 25.000 | ✅ | ✅ Mixamo + pelo | ✅ **Jugable** |
| **Chibi Moon** | 1,10 m | 25.000 | ✅ | ⬜ | ⬜ |
| **Sailor Saturno** | 1,35 m | 25.000 | ✅ | ⬜ | ⬜ |
| **Sailor Mars** | 1,60 m | 25.000 | ✅ | ⬜ | ⬜ |
| **Sailor Neptuno** | 1,62 m | 25.000 | ✅ | ⬜ | ⬜ |
| **Sailor Uranus** | 1,70 m | 25.000 | ✅ | ⬜ | ⬜ |
| **Tuxedo Mask** | 1,80 m | 25.000 | ✅ | ⬜ | ⬜ |

Las alturas están puestas a escala real y ordenadas a propósito: de 1,10 m
(Chibi Moon, una niña) a 1,80 m (Tuxedo Mask). Puestos en fila se lee como un
reparto de verdad, y en combate la diferencia de tamaño da información al
instante sobre a quién tienes delante.

Procesados de **~2.000.000 de triángulos y texturas 4K** a 25.000 y 2048, con
`tools/blender_preparar_modelo.py`.

## 2. Buena noticia: vienen en T-pose

A diferencia de Serena —que llegó con los brazos casi pegados y hubo que
abrírselos a mano en Blender— **estos seis vienen ya en T-pose**, que es
exactamente lo que quiere el auto-rigger de Mixamo. No hay que tocarles la pose.

## 3. Lo que hay que hacer con cada uno

### Paso 1 — Riguear en Mixamo

Los FBX ya están listos en `Models/mixamo/`:

```
chibi_moon_para_mixamo.fbx      sailor_neptuno_para_mixamo.fbx
sailor_mars_para_mixamo.fbx     sailor_saturno_para_mixamo.fbx
sailor_uranus_para_mixamo.fbx   tuxedo_mask_para_mixamo.fbx
```

Se sube cada uno, se marcan barbilla, muñecas, codos, rodillas e ingle, y se
descarga **con skin**. Nada más: **no hace falta bajar ni una animación**.

### Paso 2 — Reutilizar las animaciones que ya existen

Aquí está el pago de una decisión que se tomó al principio del proyecto:

> *"Todas comparten el mismo esqueleto humanoide y las mismas animaciones. Se
> diferencian por VFX, proyectiles, alcance y ritmo — no por animación nueva."*

Mixamo genera **el mismo esqueleto `mixamorig:*` para todos**. La
`AnimationLibrary` que ya está montada (`serena_animaciones.res`, 15
animaciones) **funciona tal cual sobre cualquiera de ellos**. Cero descargas
nuevas, cero trabajo de animación.

Un personaje nuevo se monta con la misma jerarquía de `player.tscn`:
`CharacterAnimator → HairPhysics → ToonRoot → modelo.fbx`.

### Paso 3 — Física de pelo y capa

Como con Serena, Mixamo no riguea nada que no sea el esqueleto humanoide. Lo que
cuelga se queda rígido y se ve mal:

| Personaje | Qué necesita cadenas de spring bones |
|---|---|
| **Tuxedo Mask** | **La capa.** Es lo más visible del personaje y rígida cantaría muchísimo |
| **Sailor Mars** | Melena larga hasta la cintura |
| **Chibi Moon** | Las dos coletas |
| **Sailor Neptuno** | Melena media (opcional) |
| Saturno, Uranus | Pelo corto: no hace falta |

El procedimiento está resuelto y documentado en
[`09-FISICA-PELO.md`](09-FISICA-PELO.md): se trazan las mechas, se les crea una
cadena de huesos colgando de `Head`, se repintan los pesos con transición suave
y `SpringBoneChain` las mueve en Godot.

**La capa de Tuxedo Mask es un caso nuevo:** cuelga de la espalda (`Spine2`), no
de la cabeza, y es una superficie ancha en vez de una mecha. Necesita **3–4
cadenas en paralelo** en lugar de una, y `max_angle` bajo para que no se levante
como un ala.

### Paso 4 — Objetos en la mano

- **Sailor Uranus** lleva una espada y **Tuxedo Mask** un bastón y una rosa.
  Al estar pegados a la malla, siguen a la mano sin trabajo extra. No hay que
  hacer nada.

## 4. Presupuesto: cuidado con cuántos hay a la vez

Cada personaje son **25.000 triángulos, y el contorno del cel shading los
duplica a 50.000** de coste de dibujado. El presupuesto del proyecto es de
150.000 triángulos en pantalla ([`01-ARQUITECTURA.md`](01-ARQUITECTURA.md) §8).

| Escena | Triángulos aprox. |
|---|---|
| 1 jugadora + 8 enemigos | 50.000 + 80.000 = **130.000** ✅ |
| 2 personajes jugables + 6 enemigos | 100.000 + 60.000 = **160.000** ⚠️ |
| Las 6 del reparto a la vez | **300.000** ❌ |

**Conclusión:** en combate hay **una sola** jugable en pantalla. Para escenas de
grupo (el final del juego, un menú de selección), o se bajan a 10.000 tris con
una segunda pasada de decimación, o se les quita el contorno.

## 5. Cómo se ordenan en la historia

El GDD contempla cinco Sailors jugables (Moon, Mars, Mercury, Jupiter, Venus).
Los modelos que hay ahora **no son ese conjunto**: llegaron Uranus, Neptuno,
Saturno, Chibi Moon y Tuxedo Mask.

Dos caminos, y conviene decidirlo antes de riguear:

1. **Cambiar el reparto del guion** a las que hay. Neptuno y Uranus son un dúo
   con personalidad muy marcada y funcionan igual de bien como desbloqueables.
   Chibi Moon encaja perfecta como el personaje sorpresa post-créditos que ya
   estaba planeado.
2. **Generar Mercury, Jupiter y Venus** para completar el guion original, y
   dejar estas como extras.

La opción 1 no cuesta nada y ya está pagada. La 2 son tres modelos más.
