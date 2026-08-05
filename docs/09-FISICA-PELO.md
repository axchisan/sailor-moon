# Física de pelo — coletas con inercia

> **Resuelto y verificado el 2026-08-04.**
> Respuesta corta a la pregunta que lo originó: **NO hay que volver a descargar
> ninguna animación de Mixamo.**

## 1. El problema

Mixamo riguea **solo el esqueleto humanoide**: 65 huesos `mixamorig:*` (caderas,
columna, cuello, cabeza, brazos, dedos, piernas). Ni uno para el pelo.

Resultado: las coletas de Serena quedaron pesadas al hueso `Head` y se movían
como un bloque rígido. Con unas coletas de **95 cm que llegan a las rodillas**,
eso se ve fatal en cuanto el personaje se mueve.

Medido sobre el modelo rigueado: **1.867 vértices** pegados a `Head` que están
más de 15 cm por debajo de la cabeza.

## 2. Por qué no hay que rehacer las animaciones

Las animaciones de Mixamo **solo contienen curvas para huesos `mixamorig:*`**.
Los huesos de pelo que añadimos no existen para ellas, así que sencillamente no
los tocan. La animación mueve el cuerpo, y la física mueve el pelo encima.

Las 6 animaciones ya descargadas (`Idle`, `Walking`, `Running`, `Jumping Up`,
`Jumping Down`, `Falling Idle`) **siguen siendo válidas**, y las que falten
también. Se descargan igual que dice [`08-ANIMACIONES-MIXAMO.md`](08-ANIMACIONES-MIXAMO.md).

## 3. Lo que se hizo en Blender

### 3.1 Trazar las coletas

Se aisló la geometría del pelo (vértices dominados por `Head` y laterales) y se
calculó su centroide en franjas de altura, obteniendo el recorrido real de cada
coleta: sale del odango en `z = 0,64` y cae hacia atrás y afuera hasta
`z = −0,27`. Perfectamente simétricas.

### 3.2 Crear las cadenas de huesos

**10 huesos nuevos**, 5 por coleta, siguiendo ese recorrido:

```
mixamorig:Head
├── Hair_L_1 → Hair_L_2 → Hair_L_3 → Hair_L_4 → Hair_L_5
└── Hair_R_1 → Hair_R_2 → Hair_R_3 → Hair_R_4 → Hair_R_5
```

Longitudes: 12, 23, 22, 23 y 20 cm. El primero cuelga de `Head` **sin conectar**
(para no arrastrar la cabeza); los demás encadenados, así al girar uno arrastra
a los siguientes.

El esqueleto pasa de 65 a **75 huesos**.

### 3.3 Repintar los pesos

Para cada vértice de pelo se calcula su posición `u` a lo largo de la cadena y
se reparte el peso entre los dos huesos más cercanos:

| Zona | Peso |
|---|---|
| `u < 0,12` | 100% `Head` — es cuero cabelludo, no debe moverse |
| `0,12 < u < 0,30` | Transición suave `Head` → cadena |
| `u > 0,30` | 100% cadena |

**2.423 vértices repintados**, ninguno se quedó sin peso.

Todo el proceso está guardado en `Models/serena_rigged_pelo.blend`.

## 4. Lo que se hizo en Godot

### `src/core/spring_bone_chain.gd`

Un `SkeletonModifier3D` con el algoritmo clásico de **VRM SpringBone**. Por cada
hueso y cada frame:

```
inercia  = (punta_actual − punta_anterior) × (1 − drag)
elástico = dirección_de_reposo × stiffness × delta
peso     = gravedad × gravity_power × delta
punta_nueva = punta_actual + inercia + elástico + peso
→ se recorta a la longitud del hueso (no se estira)
→ se limita el ángulo (no se dobla del revés)
→ se convierte en rotación local del hueso
```

Coste: 10 huesos con aritmética vectorial simple. Despreciable en móvil.

### `src/core/hair_physics.gd`

Nodo que monta las cadenas en tiempo de ejecución. Se pone como **padre** del
modelo importado; busca el `Skeleton3D` y le cuelga una `SpringBoneChain` por
coleta.

Se hace por código y no en el `.tscn` porque las escenas instanciadas de un
`.glb` no admiten hijos nuevos sin marcarlas como editables, y eso se rompe cada
vez que se reimporta el modelo.

## 5. Parámetros y cómo ajustarlos

Todos en el inspector del nodo `HairPhysics`:

| Parámetro | Defecto | Qué hace |
|---|---|---|
| `stiffness` | 1.4 | Fuerza con la que vuelve al reposo. Más alto = más rígido |
| `drag` | 0.45 | Rozamiento. Alto = se para antes. Bajo = se columpia mucho |
| `gravity_power` | 0.9 | Cuánto pesa. 0 = flota |
| `gravity_dir` | abajo | Apuntarlo de lado simula viento constante |
| `max_angle` | 75° | Tope de separación. Evita que se doble del revés |

**Recetas:**

- *Pelo más vivo y juguetón:* `drag 0.30`, `stiffness 1.0`
- *Pelo más pesado y serio:* `drag 0.65`, `gravity_power 1.6`
- *Ráfaga de viento (transformación, especial):* animar `gravity_dir` y
  `gravity_power` con un `Tween`

**Importante:** llamar a `HairPhysics.reset()` al teletransportar o reaparecer al
personaje. Si no, el pelo sale disparado por la inercia acumulada del salto.

## 6. Verificación

| Prueba | Resultado |
|---|---|
| Cadenas montadas sobre el esqueleto | ✅ `Spring_Hair_L_1`, `Spring_Hair_R_1` |
| Huesos del esqueleto | 75 (65 Mixamo + 10 pelo) |
| Desviación máxima sacudiendo al personaje | **53,3°** |
| Reposo tras frenar | 4,5° (caída natural por gravedad) |
| Viento lateral constante | Coletas horizontales, deformación suave ✅ |
| Rendimiento | 60 fps |

## 7. ⚠️ Trampa que costó tiempo

**Un `SkeletonModifier3D` escribe en un búfer temporal, no en la pose
permanente.** Leer `skeleton.get_bone_pose_rotation()` desde fuera del
modificador devuelve la pose **anterior** al modificador (la de la animación),
no el resultado.

Durante la depuración eso parecía indicar que la física no hacía nada, cuando en
realidad sí funcionaba. Para verificar hay que mirar la malla renderizada o
instrumentar dentro del propio modificador (por eso existe `debug_angles`).

**El otro fallo:** el `swing` calculado está en el espacio del **padre**, así que
se aplica como `swing * rest`, no `rest * swing`. Con el orden invertido el giro
se interpreta en el espacio del propio hueso y el resultado sale casi constante.

## 8. Reutilizar esto en otros personajes

El sistema es genérico: sirve para cualquier cadena de huesos.

- **Faldas** — 3–4 cadenas alrededor de la cintura, `stiffness` alto y
  `max_angle` bajo (30°) para que no se levante demasiado
- **Lazos y cintas** — cadenas cortas de 2–3 huesos, `drag` bajo
- **Las demás Sailors** — el mismo procedimiento; el script de Blender que traza
  y pinta está documentado aquí y en `Models/serena_rigged_pelo.blend`

Para el Peluchín y el Cofrecito no hace falta: son bolas y cofres, y se animan
procedimentalmente (ver [`06-GUIA-ASSETS-3D.md`](06-GUIA-ASSETS-3D.md) §4.2).
