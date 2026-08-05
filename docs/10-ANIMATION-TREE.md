# AnimationTree — montado y verificado

> **2026-08-04.** Las 15 animaciones de Mixamo funcionan sobre Serena, con
> física de pelo y cel shading simultáneos, a 60 fps.
> Escena de prueba: `scenes/prototypes/test_animaciones.tscn`

## 1. Qué se montó

```
BlendTree
 ├── maquina  (StateMachine)
 │    ├── locomocion  ← BlendSpace1D: idle ↔ walk ↔ run
 │    ├── jump · fall · land
 │    ├── attack_1 · attack_2 · attack_3 · special
 │    └── hurt · dizzy · victory · transform
 └── escala   (TimeScale)
```

- **`locomocion` es una mezcla continua**, no tres estados sueltos: al acelerar
  no hay salto entre andar y correr.
- **Transiciones de todos con todos** (132 en total, generadas en bucle), así
  `travel()` siempre llega en un paso desde cualquier estado.
- **Fundido de 0,12 s**, salvo al entrar a un golpe, que baja a **0,04 s**: un
  fundido largo se come el impacto.
- **`TimeScale`** encaja la animación en la duración que dicta el combate.

## 2. Por qué existe el TimeScale

Las animaciones de Mixamo duran 1–2 s; nuestros golpes duran 0,29 s. El combate
**ya está ajustado y se siente bien**, así que manda el código y la animación se
adapta.

| Animación | Dura | Objetivo | Escala aplicada |
|---|---|---|---|
| `attack_1` | 1,00 s | 0,29 s | 3,45× |
| `attack_2` | 2,17 s | 0,29 s | **5,00×** (tope) |
| `attack_3` | 2,13 s | 0,53 s | 4,03× |
| `special` | 2,70 s | 1,30 s | 2,08× |
| `hurt` | 1,20 s | 0,35 s | 3,43× |
| `dizzy` | 2,13 s | 1,60 s | 1,33× |

Hay un **tope de 5×** (`escala_maxima`): por encima la animación se ve como un
borrón. `attack_2` lo alcanza, así que se queda a medias y la corta el siguiente
golpe — que es exactamente lo que pasa en cualquier beat 'em up al encadenar.

Si `attack_2` acaba viéndose truncada, hay una alternativa ya descargada:
`attack_1_alt.fbx` (Cross Punch), más corta.

## 3. API

```gdscript
# Cambiar de estado, encajando la animación en la duración del combate
animador.travel("attack_1", 0.29)

# Estado sin ajuste de tiempo (velocidad natural)
animador.travel("victory")

# Mezcla parado ↔ andar ↔ correr según la velocidad real
animador.set_locomotion_speed(player.get_horizontal_speed())
```

## 4. ⚠️ El problema gordo: Mixamo exporta reposos distintos

Al principio el personaje salía **tumbado**. La causa tardó en encontrarse:

**Mixamo exporta poses de reposo diferentes según descargues *With Skin* o
*Without Skin*.** Comparando `idle.fbx` (With Skin) con `walk.fbx` (Without
Skin), ambos recién bajados:

| Hueso | Diferencia |
|---|---|
| `mixamorig_Hips` | 0,081 de posición |
| `mixamorig_LeftArm` | **53,3°** |
| `mixamorig_LeftUpLeg` | 5,5° |

Eso **no es culpa del paso por Blender** — se verificó comparando dos descargas
directas de Mixamo entre sí.

### Por qué al final no importa

Las pistas de Mixamo fijan la pose de los huesos de forma **absoluta**, no
relativa al reposo. Y el deformado de la malla usa las *bind poses* guardadas en
el `Skin`, no el reposo del esqueleto. Así que basta con que la **orientación
base** coincida.

### Lo que sí había que arreglar

El modelo se exportaba desde Blender en **glTF**, y eso dejaba una rotación de
90° en el hueso `Hips` y otra en el nodo `Armature`. Al aplicarle encima la pose
absoluta de la animación, el personaje se tumbaba.

**Solución: exportar el modelo en FBX**, el mismo formato e importador que las
animaciones. Con `add_leaf_bones=False` y `primary_bone_axis='Y'` (la convención
de Mixamo). Eso deja la rotación del `Hips` a 0° y el personaje se pone de pie.

> **El modelo bueno es `assets/models/characters/serena_rigged.fbx`.**
> El `.glb` se eliminó para que nadie lo use por error.

## 5. Cómo se reconstruye todo

```bash
# 1. Consolidar los FBX de Mixamo en una AnimationLibrary
godot --headless --path . --script tools/construir_libreria_animaciones.gd

# 2. Comprobar que el reposo del modelo es compatible
godot --headless --path . --script tools/comparar_esqueletos.gd
```

Para añadir una animación nueva: se deja el FBX en
`assets/animations/serena/` con el nombre canónico, se añade a la constante
`ANIMACIONES` del script (indicando si es bucle) y se vuelve a ejecutar.

## 6. Lo que falta: sustituir la cápsula por Serena

El `AnimationTree` está montado y verificado, pero **el jugador del prototipo de
combate sigue siendo una cápsula**. Para el cambio hay que:

1. En `scenes/prototypes/player.tscn`, bajo `Model`, montar la jerarquía
   `CharacterAnimator → HairPhysics → ToonRoot → serena_rigged.fbx`
   y quitar `Body` y `Nose`
2. Comprobar hacia dónde mira el modelo: `face_direction()` en `player.gd`
   asume que mira a **−Z**. Si mira al revés, rotarlo 180° en Y
3. En cada estado de `src/player/states/`, llamar a `travel()` en su `enter()`:

| Estado | Llamada |
|---|---|
| `Idle` / `Move` | `travel("locomocion")` + `set_locomotion_speed()` cada frame |
| `Jump` | `travel("jump")` |
| `Fall` | `travel("fall")` |
| `Attack` | `travel("attack_%d" % indice, attack.total_time())` |
| `Special` | `travel("special", attack.total_time())` |
| `Hurt` | `travel("hurt", STUN_TIME)` |
| `Dizzy` | `travel("dizzy", DIZZY_TIME)` |

4. Llamar a `HairPhysics.reset()` dentro de `Player.respawn()`
5. Y el paso que quedó pendiente de la Fase 1: mover el encendido de la hitbox a
   *call method tracks* de la animación, para que el golpe conecte en el frame
   exacto del impacto
