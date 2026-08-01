# Pipeline de assets — herramientas gratuitas, con IA donde compensa

> Premisa: no eres artista. El objetivo es que ningún asset requiera dibujar o modelar desde cero.
> Todo en este documento es gratis o tiene un plan gratuito utilizable, y funciona en macOS.

## Resumen ejecutivo

| Necesidad | Herramienta principal | Alternativa |
|---|---|---|
| Personajes anime 3D | **VRoid Studio** (gratis, nativo Mac) | 3D AI Studio, Meshy |
| Props y objetos | **Meshy AI** o **Tripo AI** (texto/imagen → 3D) | Quaternius, Kenney (CC0) |
| Escenarios | Kits modulares CC0 + Godot CSG | Meshy para piezas sueltas |
| Rigging | VRoid ya viene rigueado; **Mixamo** para el resto | AccuRIG, auto-rig de Tripo/Meshy |
| Animaciones | **Mixamo** (gratis, enorme) | Quaternius CC0, Cinevva |
| Limpieza / retopo / export | **Blender** (obligatorio en el flujo) | — |
| Texturas y UI 2D | **Krita** o **Photopea** | GIMP |
| Música | Suno / Udio (plan gratis) | Incompetech, Pixabay Music |
| SFX | **Freesound.org**, Pixabay | jsfxr para efectos retro |
| Voces | ElevenLabs (plan gratis) o grabarlas con tu prima | — |

---

## 1. Personajes: VRoid Studio es la respuesta correcta

Esta es la decisión más importante del pipeline gráfico. Para **personajes 3D estilo anime**, VRoid Studio le gana a cualquier generador de IA genérico, y por bastante:

- Es gratuito y corre nativo en macOS.
- Está hecho exclusivamente para el estilo anime: ojos, pelo, uniformes escolares. Es exactamente la estética de Sailor Moon.
- Sale **ya rigueado** con esqueleto humanoide estándar y con *blendshapes* faciales. Sin rigging manual.
- La topología es limpia (no como la de un generador de IA), así que la malla se anima bien.
- Exporta **VRM** y **GLB**, y Godot tiene un [importador VRM oficial con shader MToon](https://godotengine.org/asset-library/asset/2031) para 4.1+.
- El pelo se hace con "guías" que se pintan, no modelando. Perfecto para alguien que no modela.

**Flujo para las 5 Sailors:**
1. Crear el modelo base de Serena en VRoid (cuerpo, cara, ojos, pelo con las dos coletas y odangos).
2. Duplicar el proyecto y variar cara/pelo/color para Rei, Amy, Lita y Mina. Cada variación son ~30 min, no un modelo nuevo.
3. Cada personaje necesita **dos trajes**: civil (uniforme escolar) y Sailor. En VRoid se crean como dos exports del mismo modelo → en Godot se intercambia la malla en la transformación.
4. Exportar a VRM. Reducir polígonos en el propio exportador de VRoid (tiene opciones de reducción de materiales y huesos, úsalas: bajan mucho los draw calls).
5. Importar en Godot con el addon VRM.

> **A verificar en la Fase 0:** el addon VRM es oficialmente compatible con Godot 4.1+; hay que confirmar que funciona sin fricción en 4.7.1 antes de comprometer el pipeline entero. Si diera problemas, el plan B es exportar GLB desde VRoid y escribir nosotros el toon shader.

## 2. Props, enemigos y objetos: generadores de IA

Aquí sí compensa la IA, porque son objetos sueltos sin animación compleja.

| Herramienta | Plan gratis | Rigging | Licencia de salida gratuita |
|---|---|---|---|
| [**Meshy AI**](https://www.meshy.ai/features/text-to-3d) | Sí, créditos mensuales | Auto-rig incluido | CC BY 4.0 (requiere atribución si se publica) |
| [**Tripo AI**](https://www.tripo3d.ai/) | Generoso | Auto-rig incluido | CC BY 4.0 |
| [**3D AI Studio**](https://www.3daistudio.com/TextTo3D) | 100 créditos/mes | Rig + animación | Revisar términos |
| Luma Genie | Sí | No | Solo uso no comercial |

Como el juego se queda privado, la atribución CC BY no es un obstáculo real, pero conviene ir anotando en `docs/CREDITOS.md` de dónde salió cada cosa desde el día uno. Recuperarlo después es un infierno.

**Cómo escribir prompts que sirvan** (esto marca la diferencia):

```
✅ "chibi anime style crystal star collectible, pink and gold,
    smooth low poly, flat cel shaded colors, clean topology,
    game asset, white background, T-pose, no shadows baked"

❌ "una estrella de Sailor Moon"
```

Palabras que conviene incluir siempre: `low poly`, `game asset`, `cel shaded`, `flat colors`, `clean topology`, `white background`. Palabras a evitar: `realistic`, `detailed`, `4k`, `photorealistic` — generan mallas pesadas e inservibles para móvil.

**Nunca pidas escenas completas.** Pide piezas sueltas y las ensamblas tú en Godot. Un prompt de "parque japonés completo" da una masa de geometría inutilizable; diez prompts de "banco", "farol", "árbol de cerezo", "papelera" te dan un kit.

## 3. Bibliotecas gratuitas — mira aquí antes de generar

Muchas veces lo que necesitas ya existe, con mejor topología que cualquier IA y licencia CC0 (sin atribución, sin restricciones):

- **[Quaternius](https://quaternius.com/)** — CC0. Personajes, props, naturaleza, y **animaciones**. Excelente calidad y bajo poligonaje.
- **[Kenney](https://kenney.nl/assets)** — CC0. Kits modulares, UI, SFX. El estándar de oro para prototipar.
- **[Poly Haven](https://polyhaven.com/)** — CC0. HDRIs y texturas.
- **[Sketchfab](https://sketchfab.com/)** — filtrar por licencia CC0 / CC BY.
- **[Godot Asset Library](https://godotengine.org/asset-library/)** — addons y algunos assets.
- **[itch.io](https://itch.io/game-assets/free)** — mucho asset gratuito 3D y de UI.

Regla práctica: **buscar 10 minutos antes de generar.** Ahorra horas de limpieza.

## 4. Animaciones: Mixamo sigue siendo el rey gratuito

- [Mixamo](https://www.mixamo.com/) (Adobe, gratis con cuenta): subes un `.fbx`, te auto-riguea, y tienes acceso a cientos de animaciones (idle, walk, run, jump, hurt, victory, dance...). Descargas en FBX.
- Godot 4 tiene **retargeting de animaciones con mapeo de huesos incorporado**, así que se pueden aplicar animaciones de Mixamo a un modelo de VRoid aunque los esqueletos no coincidan exactamente.
- Alternativas si Mixamo se queda corto: **Quaternius** (animaciones CC0 listas), **AccuRIG** (gratis, de Reallusion), **Cinevva** (exporta GLB directo, pensado para Godot), **Sorceress 3D Studio** (auto-rig en navegador).

### Lista de animaciones necesarias (beat 'em up)

**Las cinco Sailors comparten esqueleto humanoide de VRoid, así que estas animaciones se preparan UNA vez y sirven para las cinco.** Esta es la decisión que hace viable el género con presupuesto cero: las Sailors se diferencian por VFX y proyectiles, no por animación propia.

| Categoría | Animaciones |
|---|---|
| Locomoción | `idle`, `walk`, `run` |
| Aire | `jump_start`, `jump_loop`, `land` |
| **Combate** | `attack_1`, `attack_2`, `attack_3` (patada giratoria), `special` |
| Reacción | `hurt`, `dizzy`, `victory` |
| Narrativa | `transform_pose`, `talk_idle` |

Quince en total. Todas existen en Mixamo gratis; buscar en las categorías *Fighting*, *Martial Arts* y *Magic*. Para `attack_3` funciona bien cualquier *spinning kick*; para `special`, cualquier animación de *casting* o *power up*.

**Enemigos:** `idle`, `walk`, `telegraph` (preparar golpe), `attack`, `stagger`, `purified`. Seis, compartidas por los tres arquetipos.

Nota sobre Mixamo: al descargar, marcar **"Without Skin"** para las animaciones adicionales (solo el esqueleto, mucho más ligero) y "With Skin" solo para la primera. En Godot se combinan con el retargeting por mapeo de huesos.

La secuencia de transformación **no** se anima como animación de personaje: es cámara + partículas + cambio de malla + un giro simple. Mucho más barato y queda mejor.

## 5. Limpieza obligatoria en Blender

Ningún asset de IA entra directo al proyecto. El paso por [Blender](https://www.blender.org/) (gratis, nativo Mac, incluido Apple Silicon) es innegociable:

1. Importar el `.glb`/`.fbx`.
2. **Decimate** hasta el presupuesto de triángulos (ver `01-ARQUITECTURA.md` §7).
3. Verificar escala (1 unidad Godot = 1 metro) y que el origen esté en los pies del personaje / base del objeto.
4. Rotación aplicada, transformaciones limpias (`Ctrl+A`).
5. Eliminar materiales duplicados y cámaras/luces basura que traen los exports.
6. Exportar **glTF 2.0 (.glb)** — es el formato que mejor soporta Godot.

Con eso ya tienes el 90% de Blender que vas a necesitar. No hace falta aprender a modelar.

## 6. Texturas, UI y 2D en Mac

| Herramienta | Para qué | Notas |
|---|---|---|
| **[Krita](https://krita.org/)** | Retoque de texturas, iconos, HUD | Gratis, open source, nativo Mac. La mejor opción de pintura |
| **[Photopea](https://www.photopea.com/)** | Ediciones rápidas en el navegador | Gratis, clon de Photoshop, cero instalación |
| **[GIMP](https://www.gimp.org/)** | Edición raster general | Gratis |
| **[LibreSprite](https://libresprite.github.io/)** | Pixel art (si hiciera falta algún icono) | Fork libre de Aseprite |
| **Quixel Mixer** | Mezcla de materiales PBR | Gratis, Mac |
| **[Lospec Palette List](https://lospec.com/palette-list)** | Paletas de color coherentes | Ayuda mucho si el color no es lo tuyo |

Para la UI (botones, marcos, iconos de corazón y estrella): generarlos con una IA de imagen en PNG con fondo transparente y recortarlos en Krita/Photopea es más rápido que dibujarlos. Godot usa `NinePatchRect` para que los marcos escalen bien en cualquier resolución de pantalla.

## 7. Audio

- **Música:** Suno o Udio en plan gratuito, con prompts tipo *"upbeat magical girl anime theme, orchestral, cheerful, 90s anime opening style, instrumental, loopable"*. Alternativas CC: Incompetech, Pixabay Music, FreePD.
- **SFX:** [Freesound.org](https://freesound.org/) (filtrar por licencia CC0), Kenney Audio (CC0), Pixabay.
- **Voces:** dos caminos. ElevenLabs en plan gratis para las voces del juego, o —muchísimo mejor idea— **grabar a tu prima poniendo la voz de algún personaje**. Convierte el regalo en otra cosa.
- Formato: `.ogg` para música (comprimido), `.wav` para SFX cortos.

## 8. Orden de trabajo recomendado para los assets

No generes assets bonitos hasta tener el juego funcionando en gris. El orden que evita tirar trabajo a la basura:

1. **Greybox:** cápsulas y cubos de Godot (CSG). Se juega el nivel completo así.
2. **Placeholder:** modelos CC0 de Quaternius/Kenney que ya funcionan y pesan poco.
3. **Final:** VRoid + IA + limpieza, sustituyendo pieza a pieza.

Si la escena está bien organizada, sustituir un placeholder por el modelo final es cambiar la referencia de una escena. Ese es el motivo de la estructura de carpetas de `01-ARQUITECTURA.md`.

---

## Fuentes consultadas

- [Best AI Tools for 3D Game Assets (2026) — Meshy](https://www.meshy.ai/blog/best-ai-tools-for-3d-game-assets)
- [Best AI 3D Character and Avatar Generators in 2026 — 3DAI Studio](https://www.3daistudio.com/blog/best-ai-3d-character-and-avatar-generators-2026)
- [The Best Auto Rig Mixamo Alternative Tools — Tripo3D](https://www.tripo3d.ai/content/en/guide/the-best-auto-rig-mixamo-alternative-tools)
- [Free Character Animations and Auto-Rigging: Mixamo and Its Alternatives (2026) — Cinevva](https://app.cinevva.com/guides/free-character-animations-rigging)
- [VRM Importer for 3D Avatars and MToon Shader — Godot Asset Library](https://godotengine.org/asset-library/asset/2031)
- [Easy Anime Character Creation with VRoid Studio and Blender — GameFromScratch](https://gamefromscratch.com/easy-anime-character-creation-with-vroid-studio-and-blender/)
- [Godot renderer options — Android Developers](https://developer.android.com/games/engines/godot/godot-renderers)
- [Optimizing 3D scenes in Godot on Arm GPUs — Arm Community](https://developer.arm.com/community/arm-community-blogs/b/mobile-graphics-and-gaming-blog/posts/optimizing-3d-scenes-in-godot-on-arm-gpus)
- [Optimizing Godot for Mobile — A Field Guide](https://slicker.me/godot/mobile-optimization.html)
- [40 Best pixel art / sprite editors as of 2026 — Slant](https://www.slant.co/topics/1547/~best-pixel-art-sprite-editors)
