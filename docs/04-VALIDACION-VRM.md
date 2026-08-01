# Validación del pipeline VRM — RESULTADO: ✅ APROBADO

**Fecha:** 2026-08-01 · **Godot:** 4.7.1.stable · **Renderizador:** Mobile (Metal/Vulkan)

El plan A (VRoid Studio → VRM → Godot con MToon) **funciona**. No hace falta el plan B
(GLB + toon shader propio). Esta es la decisión más importante del pipeline gráfico
y queda cerrada.

## Qué se instaló

| Addon | Versión | Ruta |
|---|---|---|
| VRM Importer | 2.0.1 | `addons/vrm/` |
| MToon Shader | 3.4.0 | `addons/Godot-MToon-Shader/` |

Origen: [V-Sekai/godot-vrm](https://github.com/V-Sekai/godot-vrm), rama `master`
(último push 2026-07-08, soporta Godot 4.1+).

Activados en `project.godot`:
```ini
[editor_plugins]
enabled=PackedStringArray("res://addons/Godot-MToon-Shader/plugin.cfg", "res://addons/vrm/plugin.cfg")
```

> ⚠️ El MCP los activó con el formato `vrm/enabled=true`, que Godot 4 **ignora
> silenciosamente**. Los plugins parecían activos y no lo estaban. Si algún día
> el importador deja de funcionar, revisar primero que esta sección use
> `enabled=PackedStringArray(...)`.

## Modelo de prueba

**AliciaSolid** (VRM 0.51), el modelo de test estándar de UniVRM. 7,5 MB.
Ubicado en `assets/models/characters/_vrm_test/`, **excluido del repositorio**
por `.gitignore`: es propiedad de Dwango y solo se usó para validar.

Escena de prueba: `scenes/prototypes/test_vrm.tscn`. Para volver a usarla con un
modelo propio, basta con dejar el `.vrm` en esa carpeta con el mismo nombre.

## Resultados medidos

| Métrica | Valor | Veredicto |
|---|---|---|
| **Esqueleto** | `GeneralSkeleton`, 129 huesos | ✅ Nombre estándar de `SkeletonProfileHumanoid` |
| **Nomenclatura de huesos** | `Hips`, `LeftUpperLeg`, `LeftLowerLeg`, `LeftFoot`... | ✅ Humanoide estándar |
| **Materiales** | 20, **todos** `ShaderMaterial` con `mtoon.gdshader` / `mtoon_trans_zwrite.gdshader` | ✅ Cel shading de fábrica |
| **Blend shapes faciales** | 60 en total (49 en `face`: `mouth_a`, `mouth_i`, `mouth_u`...) | ✅ Sirven para lipsync y expresiones |
| **Spring bones** | Nodo `secondary` presente | ✅ Pelo y falda con física automática |
| **FPS** | 60 estables, un personaje en pantalla | ✅ |
| **Triángulos** | 31.798 | ⚠️ Por encima del presupuesto |
| **Superficies (draw calls)** | 20 por personaje | ⚠️ Demasiadas para móvil |

## Las dos consecuencias que sí importan

### 1. `GeneralSkeleton` = retargeting de Mixamo garantizado

Que el esqueleto se llame `GeneralSkeleton` y use nomenclatura humanoide estándar
significa que las animaciones de Mixamo se pueden aplicar directamente con el
sistema de mapeo de huesos de Godot 4. **Esto es lo que hace viable el beat 'em up:**
las 15 animaciones se preparan una vez y sirven para las cinco Sailors.

### 2. Hay que optimizar antes de meter modelos al juego

Los números de AliciaSolid son de un modelo de VTubing, no de un juego móvil:

- **31.798 triángulos** frente al presupuesto de 15–25k → decimación en Blender.
- **20 superficies = ~20 draw calls por personaje.** Con 8 enemigos en pantalla
  serían 160 draw calls solo en personajes, y el presupuesto total es 150.

**Acción para los modelos propios:** usar la **reducción de materiales y huesos del
propio exportador de VRoid Studio** (está en el diálogo de exportación). Reduce las
superficies agrupando materiales, que es exactamente el cuello de botella. Objetivo:
bajar de 20 superficies a 4–6 por personaje, y de 32k a ~15k triángulos.

Para los enemigos, con presupuesto de 3–5k triángulos, VRoid no es la herramienta:
mejor generadores de IA o assets CC0, que salen mucho más ligeros.

## Lo que queda por tu parte

1. Instalar **VRoid Studio** (gratis, nativo Mac): https://vroid.com/en/studio
2. Modelar a Serena y exportar dos VRM: traje civil y traje de Sailor.
3. En el diálogo de exportación, **activar la reducción de materiales y huesos**.
4. Dejar los `.vrm` en `assets/models/characters/` y avisarme.

Detalle del flujo completo en [`02-PIPELINE-ASSETS.md`](02-PIPELINE-ASSETS.md).
