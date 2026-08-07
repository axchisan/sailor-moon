# Reparto de personajes

> **2026-08-07.** Once personajes procesados y verificados. Serena es la única
> rigueada; el resto está listo para subir a Mixamo.

## 1. Estado del reparto

| Personaje | Altura | Triángulos | Modelo | Rig | En juego |
|---|---|---|---|---|---|
| **Chibi Moon** | 1,10 m | 25.000 | ✅ | ⬜ | ⬜ |
| **Sailor Saturno** | 1,35 m | 25.000 | ✅ | ⬜ | ⬜ |
| **Serena** (Sailor Moon) | 1,55 m | 25.000 | ✅ | ✅ Mixamo + pelo | ✅ **Jugable** |
| **Sailor Mercury** | 1,58 m | 25.000 | ✅ | ⬜ | ⬜ |
| **Sailor Mars** | 1,60 m | 25.000 | ✅ | ⬜ | ⬜ |
| **Sailor Venus** | 1,62 m | 25.000 | ✅ ⚠️ | ⬜ | ⬜ |
| **Sailor Neptuno** | 1,62 m | 25.000 | ✅ | ⬜ | ⬜ |
| **Sailor Jupiter** | 1,68 m | 25.000 | ✅ ⚠️ | ⬜ | ⬜ |
| **Sailor Uranus** | 1,70 m | 25.000 | ✅ | ⬜ | ⬜ |
| **Sailor Pluto** | 1,75 m | 25.000 | ✅ | ⬜ | ⬜ |
| **Tuxedo Mask** | 1,80 m | 25.000 | ✅ | ⬜ | ⬜ |

⚠️ = llevaban geometría de más pegada, ya separada (§2).

Las alturas están puestas a escala real y ordenadas a propósito: de 1,10 m
(Chibi Moon, una niña) a 1,80 m (Tuxedo Mask). Puestos en fila se lee como un
reparto de verdad, y en combate la diferencia de tamaño da información al
instante sobre a quién tienes delante.

Procesados de **~2.000.000 de triángulos y texturas 4K** a 25.000 y 2048, con
`tools/blender_preparar_modelo.py`.

## 2. Objetos que venían pegados al personaje

El generador 3D añadió decorado que no se pidió y lo dejó **soldado a la misma
malla** del personaje. No se ve como un objeto aparte: es la misma malla.

| Personaje | Qué traía | Coste |
|---|---|---|
| **Sailor Venus** | Un coral marino a sus pies | 4.702 tris (≈19 % de su presupuesto) |
| **Sailor Jupiter** | Un arbusto tipo bonsái a sus pies | 9.752 tris (≈39 % de su presupuesto) |

**No se borraron: se separaron**, y viven en `assets/models/props/` como
`coral_marino.glb` y `arbusto_bonsai.glb`. Sirven de decorado para los
escenarios ([`07-ESCENARIOS.md`](07-ESCENARIOS.md)) — el bonsái encaja en un
jardín y el coral en un nivel marino.

Al quitárselos, Venus y Jupiter **recuperaron su presupuesto entero**: los
25.000 triángulos son ahora todos personaje. Antes, 4 de cada 10 triángulos de
Jupiter eran un arbusto.

### Cómo se hizo (por si aparece otro)

1. Se agrupan las islas de malla del **GLB ya procesado** con union-find sobre
   sus cajas de contorno. Aparecen los grupos separados del cuerpo.
2. Se exporta cada grupo suelto como prop y **se anota su caja en metros**.
3. Se **reprocesa el personaje desde el original**, borrando los vértices dentro
   de esa caja *antes* de decimar. Así la decimación reparte los 25.000
   triángulos solo entre el personaje.

> **Trampa:** el agrupado hay que hacerlo sobre el **GLB procesado**, no sobre
> el original. Exportar a glTF duplica vértices en las costuras de UV, lo que
> parte la malla en islas separables (199 en el procesado). El original está
> genuinamente más conectado: solo da 5 islas, y el coral toca la mano de Venus
> a 5 cm, así que a cualquier umbral se fusiona con ella.

## 3. Buena noticia: vienen en T-pose

A diferencia de Serena —que llegó con los brazos casi pegados y hubo que
abrírselos a mano en Blender— **el resto viene ya en T-pose**, que es
exactamente lo que quiere el auto-rigger de Mixamo. No hay que tocarles la pose.

## 4. Lo que hay que hacer con cada uno

### Paso 1 — Riguear en Mixamo

Los FBX ya están listos en `Models/mixamo/`:

```
chibi_moon_para_mixamo.fbx       sailor_neptuno_para_mixamo.fbx
sailor_jupiter_para_mixamo.fbx   sailor_pluto_para_mixamo.fbx
sailor_mars_para_mixamo.fbx      sailor_saturno_para_mixamo.fbx
sailor_mercury_para_mixamo.fbx   sailor_uranus_para_mixamo.fbx
sailor_venus_para_mixamo.fbx     tuxedo_mask_para_mixamo.fbx
```

Se sube cada uno, se marcan barbilla, muñecas, codos, rodillas e ingle, y se
descarga **con skin**. Nada más: **no hace falta bajar ni una animación**.

El archivo descargado se guarda como
`assets/models/characters/<nombre>_rigged.fbx`, igual que Serena.

> **Trampa ya pisada:** Mixamo ofrece exportar en glTF. **No.** El glTF sale con
> 90° de más en `Hips` y el personaje aparece tumbado en Godot. Siempre **FBX**.

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
| **Sailor Venus** | Melena larguísima, hasta las rodillas: es la que más lo nota |
| **Sailor Mars** | Melena larga hasta la cintura |
| **Sailor Pluto** | Melena larga |
| **Chibi Moon** | Las dos coletas |
| **Sailor Jupiter** | La coleta alta |
| **Sailor Neptuno** | Melena media (opcional) |
| Saturno, Uranus, Mercury | Pelo corto: no hace falta |

El procedimiento está resuelto y documentado en
[`09-FISICA-PELO.md`](09-FISICA-PELO.md): se trazan las mechas, se les crea una
cadena de huesos colgando de `Head`, se repintan los pesos con transición suave
y `SpringBoneChain` las mueve en Godot.

**La capa de Tuxedo Mask es un caso nuevo:** cuelga de la espalda (`Spine2`), no
de la cabeza, y es una superficie ancha en vez de una mecha. Necesita **3–4
cadenas en paralelo** en lugar de una, y `max_angle` bajo para que no se levante
como un ala.

### Paso 4 — Objetos en la mano

- **Sailor Uranus** lleva una espada, **Sailor Pluto** su báculo y **Tuxedo
  Mask** un bastón y una rosa. Al estar pegados a la malla, siguen a la mano sin
  trabajo extra. No hay que hacer nada.

## 5. Presupuesto: cuidado con cuántos hay a la vez

Cada personaje son **25.000 triángulos, y el contorno del cel shading los
duplica a 50.000** de coste de dibujado. El presupuesto del proyecto es de
150.000 triángulos en pantalla ([`01-ARQUITECTURA.md`](01-ARQUITECTURA.md) §8).

| Escena | Triángulos aprox. |
|---|---|
| 1 jugadora + 8 enemigos | 50.000 + 80.000 = **130.000** ✅ |
| 2 personajes jugables + 6 enemigos | 100.000 + 60.000 = **160.000** ⚠️ |
| Las 11 del reparto a la vez | **550.000** ❌ |

**Conclusión:** en combate hay **una sola** jugable en pantalla. Para escenas de
grupo (el final del juego, un menú de selección), o se bajan a 10.000 tris con
una segunda pasada de decimación, o se les quita el contorno.

## 6. Cómo se ordenan en la historia

Ya está el reparto completo del guion original (Moon, Mercury, Mars, Jupiter,
Venus) **más** el sistema solar exterior (Uranus, Neptuno, Pluto, Saturno),
Chibi Moon y Tuxedo Mask.

La decisión tomada es **no meterlos todos de golpe**: cada escenario presenta a
uno o dos, con su momento de encuentro y su motivo para unirse. Se van
encontrando y desbloqueando conforme avanza la historia.

El reparto por nivel se define en [`07-ESCENARIOS.md`](07-ESCENARIOS.md) y el
guion en [`00-GDD.md`](00-GDD.md). Chibi Moon sigue reservada como el personaje
sorpresa del final.
