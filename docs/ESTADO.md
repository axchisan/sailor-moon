# ESTADO DEL PROYECTO — empieza por aquí

> **Este es el documento de entrada.** Si eres un agente nuevo o el usuario
> retoma tras un tiempo, lee esto primero y luego el documento específico que
> necesites.
>
> **Última actualización:** 2026-08-11 · Fases E y F cerradas y C ter empezada.
> Antes: dos pasadas de rendimiento, el blockout dejando de verse y la tanda de
> arreglos de geometría

---

## 1. Qué es esto

Juego **Sailor Moon** en 3D para Android, regalo personal para la prima de 8 años
del usuario. **No comercial, no se publica en ninguna tienda.**

- **Género:** beat 'em up ligero en 3D con arenas de combate
- **Motor:** Godot 4.7.1, GDScript, renderizador **Mobile** (Vulkan/Metal)
- **Estética:** cel shading anime con MToon
- **Idioma:** todo en español, incluido el código y los comentarios

**Perfil del usuario:** desarrollador backend empresarial. Experiencia previa en
gamedev limitada y casi toda en 2D. Ninguna en 3D ni en arte. Explicar términos
de 3D la primera vez; usar analogías de backend (autoload ≈ singleton, Resource ≈
DTO, signals ≈ event bus).

---

## 2. En qué punto estamos

| Fase | Estado |
|---|---|
| **Fase 0 — Cimientos** | ✅ Cerrada. APK corriendo en el móvil real |
| **Fase 1 — Combate** | ✅ Cerrada. Peluchín, Cofrecito y Hadita terminados |
| **Fase 2 — Vertical slice (Nivel 1)** | 🟡 **En curso.** El escenario está terminado: construido, decorado, poblado y optimizado. Falta el movimiento nuevo, la conversación viva, el menú y la cinemática |
| Fases 3–5 | ⬜ Sin empezar |

El trabajo se organiza por el **plan maestro**
([`15-PLAN-MAESTRO.md`](15-PLAN-MAESTRO.md)), en fases A–H:

| Fase | Qué | Estado |
|---|---|---|
| **A** | Que el mundo sea sólido | ✅ |
| **B** | Texturas reciclables | ✅ |
| **C** | Mundo abierto, límites naturales | ✅ |
| **C bis** | Objetivos, portal y rincones | ✅ (falta el mapa de escenarios) |
| **C ter** | Que el nivel EXPLIQUE lo que pide | 🟡 Avisos ✅, cinemática ✅, jefe guardián ✅. Queda el panel de objetivos |
| **D** | Rendimiento | ✅ dos pasadas. 60 fps en el móvil |
| **E** | Movimiento y combate | ✅ **cerrada.** Salto en tres partes, doble salto, trepar cornisas y el Cofrecito rodeable |
| **F** | Conversación viva | ✅ **cerrada** salvo F5 (audio de Mercury, depende de ti) |
| **G** | Menú, guardado, vidas | ⬜ |
| **H** | Historia y cinemática | ⬜ guion escrito, sin montar |

### Lo que funciona hoy

**Combate** (prototipo en `scenes/prototypes/test_combat.tscn`):

- Movimiento 3D con cámara orbital, *coyote time* y *jump buffer*
- Combo de 3 golpes encadenable, auto-orientación al enemigo más cercano
- Especial con barra de carga, zoom, invulnerabilidad y área amplia
- `CombatFeel`: hit stop, screen shake, partículas, flash y SFX
- Tres enemigos con FSM propia; el Cofrecito con escudo frontal de 130°
- **Máximo 4 enemigos atacando a la vez** (fichas de `CombatDirector`)
- HUD por EventBus y controles táctiles

**Nivel 1 — el Parque de los Cerezos** (`scenes/levels/nivel_1_parque.tscn`,
detalle en [`18-ESTADO-NIVEL-1.md`](18-ESTADO-NIVEL-1.md)):

- Recorrido completo generado por código: placita de arranque → pasillo →
  arena → cruce de dos ramas → arena → cuesta → guardián → paseo de vuelta →
  claro del portal
- **Terreno por ruido** con llano, lomas y cordillera, y perspectiva aérea
- **Estanque con agua animada**, vaso cavado en el terreno y pasarela de 14 m
- **Nueve rincones compuestos**: kiosco de dulces, zona de juegos, plaza de la
  fuente, merendero, altar del gato, vivero y tres rincones de paso. Con suelo
  empedrado y senderos de losas que los unen al camino
- ~2.000 props en multimalla, con reparto de sitio: nada se planta encima de
  otra cosa ni dentro de un muro
- 6 objetivos que abren el portal, 7 Estrellas, 3 faroles, 4 rincones baliza
- Luna acompaña, con animación y cola por física. Mariposas y pajarillos
- Plano aéreo de apertura, saltable

### Lo siguiente, en orden

1. **C ter 4 — el jefe guardián del portal.** Con la lista completa el portal no
   se abre sin más: aparece un jefe y se abre al ganarle. Es lo más gordo que
   queda del nivel y lo que le da cierre
2. **Pulir el encuadre de la cinemática del portal** — funciona, pero el plano
   no siempre deja la ruina centrada (`_presentar()` en `portal_salida.gd`)
3. **Salientes para trepar** — la mecánica está, pero el parque tiene una sola
   plataforma y queda baja. Trepar abre el diseño de nivel solo si hay a dónde
   subir y algo arriba que lo merezca
4. **Fase G** — menú, guardado, corazones de vida escondidos
5. **Fase H** — cinemática de historieta y narrador
6. **Mapa de escenarios** — el portal ya se abre pero no lleva a ninguna parte

### Lo que se hizo en la sesión del 10-11 de agosto

**Rendimiento** — se descubrió que el cuello no era la geometría sino el coste
por píxel. El cielo hacía 32 `sin()` por píxel (la trampa 52 sin corregir ahí) y
el terreno 28 evaluaciones de ruido. Con eso arreglado, el móvil pasó de 25-41
fps a 60. Los recortes van **solo en Android** y limitan en vez de eliminar.

**Geometría** — el blockout dejó de dibujarse: el terreno sube hasta la cara de
arriba de las losas y el camino se pinta con una máscara. Después hubo una tanda
larga de arreglos de todo lo que se apoyaba en el blockout (muros flotando,
props en el aire, colisiones invisibles), con `tools/auditar_nivel.gd` como red.

**Fase E entera** — salto en tres partes con aterrizaje, doble salto, trepar
cornisas y el Cofrecito rodeable.

**Fase F casi entera** — retratos en vivo que siguen al que habla, bucle de
conversación por turnos, transiciones suaves y la transformación en tres tiempos.

**C ter empezada** — las puertas dicen qué falta y el portal se presenta.

### Pendientes concretos, por si se retoma en frío

| Qué | Dónde |
|---|---|
| Barra de vida del jefe | Va con el panel de objetivos, cuando haya interfaz |
| Ataque de área del jefe | La animación `golpe_suelo` está hecha y sin usar |
| **Panel de objetivos** | Esperando a que haya interfaz — decisión del usuario |
| Encuadre de la cinemática | `_presentar()` en `portal_salida.gd` |
| Sonido | Efectos y ambiente ✅. Falta la música. Ver [`22-ESTADO-AUDIO.md`](22-ESTADO-AUDIO.md) |
| Sonido propio de la transformación | `SFX_TRANSFORMACION` en `combat_feel.gd`. Va prestado del especial |
| Audio de Mercury (F5) | Depende del usuario: fish.audio, texto en `14-VOCES.md` |
| Zonas vacías y salientes para trepar | [`22-ESTADO-AUDIO.md`](22-ESTADO-AUDIO.md) | ⭐ Qué suena hoy, qué está a medias y qué falta |
| [`21-SONIDO-Y-MUSICA.md`](21-SONIDO-Y-MUSICA.md) | ⭐ El plan de sonido y música: de dónde sale, qué suena en cada momento y en qué orden |
| [`20-JEFE-GUARDIAN.md`](20-JEFE-GUARDIAN.md) | El jefe del Acto 1: concepto, prompt de imagen y qué hace falta |
| [`19-ERRORES-TERRENO.md`](19-ERRORES-TERRENO.md) |
| El APK pesa 132 MB | Subió al meter las animaciones. Sin diagnosticar |
| Dos rincones no caben | `AltarGato` y `Vivero`. Salen por consola en cada carga |

## 3. Índice de documentación

| Documento | Contenido |
|---|---|
| [`00-GDD.md`](00-GDD.md) | Diseño: temática, guion por niveles, combate, accesibilidad |
| [`01-ARQUITECTURA.md`](01-ARQUITECTURA.md) | Estructura, autoloads, FSM, presupuestos de rendimiento |
| [`02-PIPELINE-ASSETS.md`](02-PIPELINE-ASSETS.md) | Herramientas (parcialmente obsoleto, ver 06) |
| [`03-ROADMAP.md`](03-ROADMAP.md) | Fases, checklists, riesgos, entorno de compilación Android |
| [`04-VALIDACION-VRM.md`](04-VALIDACION-VRM.md) | Validación del addon VRM y del shader MToon |
| [`05-COMBATE.md`](05-COMBATE.md) | **Guía de ajuste del combate.** "Quiero cambiar X → toca este archivo" |
| [`06-GUIA-ASSETS-3D.md`](06-GUIA-ASSETS-3D.md) | Pipeline 3D actual: hi3d.ai → Blender → Godot |
| [`07-ESCENARIOS.md`](07-ESCENARIOS.md) | Cómo se construyen los escenarios (3 capas) |
| [`08-ANIMACIONES-MIXAMO.md`](08-ANIMACIONES-MIXAMO.md) | Qué animaciones bajar y con qué ajustes |
| [`09-FISICA-PELO.md`](09-FISICA-PELO.md) | Coletas con inercia: cadenas de huesos + spring bones |
| [`10-ANIMATION-TREE.md`](10-ANIMATION-TREE.md) | AnimationTree montado, TimeScale y el lío de reposos de Mixamo |
| [`11-PLAN-ENEMIGOS.md`](11-PLAN-ENEMIGOS.md) | **Plan de enemigos:** plantilla, animación procedural y palancas de dificultad |
| [`12-REPARTO.md`](12-REPARTO.md) | **Reparto de personajes:** 11 procesados, qué falta por cada uno |
| [`13-NIVEL-1.md`](13-NIVEL-1.md) | Diseño original del Nivel 1 |
| [`14-VOCES.md`](14-VOCES.md) | Voces y audio |
| [`15-PLAN-MAESTRO.md`](15-PLAN-MAESTRO.md) | ⭐ **El plan.** Fases A–H, ordenadas por lo que desbloquea cada una |
| [`16-GUION.md`](16-GUION.md) | ⭐ **La historia completa**, escena por escena |
| [`17-ANIMACIONES.md`](17-ANIMACIONES.md) | ⭐ **Qué archivo subir a Mixamo** y con qué ajustes. Bloquea la Fase E |
| [`18-ESTADO-NIVEL-1.md`](18-ESTADO-NIVEL-1.md) | ⭐ **Estado del Nivel 1:** cómo se monta, qué hay, qué falta, rendimiento |
| [`22-ESTADO-AUDIO.md`](22-ESTADO-AUDIO.md) | ⭐ Qué suena hoy, qué está a medias y qué falta |
| [`21-SONIDO-Y-MUSICA.md`](21-SONIDO-Y-MUSICA.md) | ⭐ El plan de sonido y música: de dónde sale, qué suena en cada momento y en qué orden |
| [`20-JEFE-GUARDIAN.md`](20-JEFE-GUARDIAN.md) | El jefe del Acto 1: concepto, prompt de imagen y qué hace falta |
| [`19-ERRORES-TERRENO.md`](19-ERRORES-TERRENO.md) | ⭐ Fallos de montaje del escenario, cómo se arreglaron, y **las zonas vacías y los salientes que faltan** |
| [`CREDITOS.md`](CREDITOS.md) | Atribuciones de assets |

---

## 4. Mapa del código

65 scripts, 17 escenas. Lo que hay que conocer:

```
src/autoload/          Los "servicios". Orden en project.godot IMPORTA
  event_bus.gd           Solo señales. Todo se comunica por aquí
  game_manager.gd        Estado de partida: salud, especial, contadores
  save_manager.gd        JSON en user:// con save_version
  audio_manager.gd       Buses, música con crossfade, pool de 16 SFX
  scene_loader.gd        Carga asíncrona
  settings.gd            Volúmenes, idioma, assisted_mode
  combat_feel.gd         ⭐ TODO el jugo del combate en un solo sitio
  combat_director.gd     ⭐ Fichas de ataque (máx. 4 atacando)

src/core/
  state.gd, state_machine.gd   FSM genérica (jugador y enemigos)
  hitbox.gd, hurtbox.gd        Colisión de golpes por capas
  toon_material.gd             ⭐ Aplica MToon a cualquier malla PBR
  toon_root.gd                 Versión nodo del anterior
  impact_particles.gd

src/player/            player.gd + camera_rig.gd + states/ (8 estados)
src/enemies/           enemy.gd + blob_animator.gd + states/ (7 estados)
src/level/             ⭐ TODO el escenario se genera por código
  nivel.gd               Orquesta el montaje y coloca el terreno
  constructor_nivel.gd   El blockout: por dónde se juega. `RECORRIDO` manda
  decorador_nivel.gd     Qué se ve: props, rincones, senderos, estanque
  terreno_nivel.gd       Heightmap por ruido, zonas elevadas y hondonadas
  paleta_terreno.gd      Recetas de superficie (8 con un solo shader)
  terreno.gdshader       Triplanar + posterizado + perspectiva aérea
  agua.gdshader          Ondas, espuma de orilla y destellos
  camara_apertura.gd     El plano aéreo del arranque
  arena.gd               Oleadas y barrera mágica

src/gameplay/          Lo que se hace en el nivel
  objetivos_nivel.gd     Los 6 objetivos que abren el portal
  estrella_sueno.gd, farol.gd, rincon.gd, portal_salida.gd
  encuentro.gd           Personajes con los que se habla
  companero.gd           Luna, que sigue a Serena
  bichos.gd              Mariposas y pajarillos en multimalla

src/ui/                hud.gd, touch_controls.gd, debug_overlay.gd
src/core/modo_desarrollador.gd  ⭐ Panel de F1 con fps, draws y triángulos
src/data/attack_data.gd

tools/blender_preparar_modelo.py   Reduce modelos de IA a presupuesto
tools/blender_kit_parque.py        Kit 1: árboles, rocas, mobiliario
tools/blender_kit_expansion.py     Kit 2: portal, puente, detalle de suelo
tools/blender_kit_vida.py          Kit 3: puestos, materas, fuente, juegos
tools/validar_scripts.sh           ⭐ Compila todo. Usar SIEMPRE antes de probar
tools/auditar_nivel.gd             ⭐ Recorre el mapa buscando fallos de montaje,
                                     con coordenadas. Pasarla al tocar el
                                     recorrido o el terreno
tools/generar_textura_ruido.gd     Hornea el patrón de las superficies
```

### Cómo se monta un nivel

El orden importa y está en `nivel.gd`:

1. **Constructor** — levanta el blockout desde `RECORRIDO` y decide por dónde
   se juega. Se puede jugar en gris, sin nada más
2. **Terreno** — se centra en el parque, se apoya en las zonas elevadas que le
   dice el constructor y cava las hondonadas del estanque
3. **Decorador** — posa los props con rayos sobre el suelo, así que el suelo
   tiene que existir ya. Reparte el sitio: estanque → rincones → senderos →
   camino → arenas → campo → detalle → linde

**Ninguno conoce al siguiente.** Se puede borrar el decorador entero y el nivel
se sigue jugando igual.

### Capas de colisión 3D

| # | Nombre | Valor |
|---|---|---|
| 1 | world | 1 |
| 2 | player | 2 |
| 3 | enemy | 4 |
| 4 | player_hitbox | 8 |
| 5 | enemy_hitbox | 16 |
| 6 | player_hurtbox | 32 |
| 7 | enemy_hurtbox | 64 |
| 8 | interactable | 128 |

---

## 5. Entorno (rutas reales, verificadas)

| Cosa | Ruta / valor |
|---|---|
| Proyecto | `/Users/mac/Documents/Dev/Games/sailor-moon` |
| Godot | `/Applications/Godot.app/Contents/MacOS/Godot` (4.7.1) |
| JDK | `/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home` |
| Android SDK | `/opt/homebrew/share/android-commandlinetools` |
| Build-Tools | 35.0.0 · Platform 35 · Platform-Tools 37 |
| Keystore debug | `~/.android/debug.keystore` (alias `androiddebugkey`, pass `android`) |
| git-lfs | `/opt/homebrew/bin/git-lfs` |
| APK | `export/sailor_moon.apk` — `com.familia.sailormoon`, minSdk 24, arm64-v8a |

### Comandos

```bash
# git-lfs NO está en el PATH de shells no interactivas
export PATH="/opt/homebrew/bin:$PATH"

# Importar recursos / refrescar la caché de clases globales
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import

# Reaplicar las rutas de Android (el editor las borra al cerrarse)
./tools/configurar_android.sh

# Exportar APK
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --export-debug "Android" export/sailor_moon.apk

# Instalar en el móvil (depuración USB activada)
/opt/homebrew/share/android-commandlinetools/platform-tools/adb install -r export/sailor_moon.apk
```

### MCP disponibles

- **Godot** (`mcp__godot__*`) — editar el proyecto y **controlar el juego en
  ejecución** (`game_eval`, `game_screenshot`). Es lo que permite verificar de
  verdad en vez de suponer.
- **Blender** (`mcp__blender__*`) — Blender 5.2 LTS. **Blender debe estar
  abierto.**

---

## 5 bis. Dónde mirar el estado del Nivel 1

[`18-ESTADO-NIVEL-1.md`](18-ESTADO-NIVEL-1.md) tiene la foto al día: cómo se
monta un nivel y en qué orden, el recorrido paso a paso, qué props existen, qué
está hecho y qué falta. Es el documento que se actualiza al cerrar cada bloque.

---

## 6. ⚠️ Trampas ya pisadas — no volver a caer

Esta sección vale más que ninguna otra. Todo esto costó tiempo de depurar.

### Godot

1. **`SpringArm3D` coloca a sus hijos escribiéndoles la `position`.** Nunca
   escribas `position` en un hijo suyo. La sacudida de cámara usa
   `h_offset`/`v_offset`. *(La cámara en 3ª persona estuvo rota toda la Fase 0
   por esto, y al consultar `camera.position` desde fuera daba el valor correcto:
   solo fallaba lo renderizado.)*
2. **`monitoring` / `monitorable` dentro de una señal de física** → error
   `Function blocked during in/out signal`. Usa `set_deferred`.
3. **El timer del hit stop necesita `ignore_time_scale = true`** (4º parámetro de
   `create_timer`) o se congela él mismo y el juego no recupera la velocidad.
4. **Una clase nueva con `class_name` no existe hasta ejecutar `--import`.** Si
   no, `game_eval` cae al depurador y bloquea el MCP.
5. **El MCP inserta los autoloads en orden inverso.** Hay que reordenarlos a mano
   en `project.godot`: `Settings` necesita que `AudioManager` ya exista.
6. **El MCP activa plugins como `vrm/enabled=true`, formato que Godot 4 ignora en
   silencio.** El correcto es
   `enabled=PackedStringArray("res://addons/.../plugin.cfg")`.
7. **`Models/` necesita un archivo `.gdignore`.** Sin él Godot importa los
   originales de 80 MB y la caché pasa de 18 MB a 273 MB.
8. **El preset de exportación del MCP sale sin la sección `[preset.0.options]`** y
   la exportación falla. Hay que escribirlo a mano.
9. **Un `SkeletonModifier3D` escribe en un búfer temporal, no en la pose
   permanente.** Leer `get_bone_pose_rotation()` desde fuera devuelve la pose
   ANTERIOR al modificador. Parece que la física no hace nada cuando sí funciona.
10. **`bound_box` de un objeto con Armature está cacheado y puede mentir.** Para
   medir de verdad hay que recorrer los vértices.
11. **El AABB de una malla con esqueleto se calcula sobre la POSE DE REPOSO.**
   Si la animación saca la geometría de esa caja, Godot la descarta por frustum
   culling y el personaje DESAPARECE según el ángulo de cámara, aunque esté
   delante. Se arregla con `MeshInstance3D.custom_aabb` (lo hace
   `CharacterAnimator._ampliar_aabb()`).
12. **Los modelos de Mixamo miran hacia +Z**, y Godot usa −Z como frente. Hay
   que girar el nodo visual 180° en Y.
13. **Un nodo hijo no puede conectarse a un `@onready` de su padre en `_ready()`.**
   Los hijos se inicializan primero, así que la propiedad todavía es `null` y la
   conexión se pierde EN SILENCIO. Hay que engancharse en el primer `_process`
   (lo hace `BlobAnimator`).
14. **Los modelos de hi3d.ai miran a +Z, igual que los de Mixamo.** Todo modelo
   importado necesita 180° en Y, personajes y enemigos por igual.
15. **GDScript no es Python:** no hay listas por comprensión y `round()` solo
   acepta un argumento (para decimales, `snappedf(x, 0.1)`). Un error de sintaxis
   dentro de `game_eval` deja el juego atrapado en el depurador y bloquea el MCP.
16. **Godot renombra los huesos de Mixamo: `mixamorig:Hips` → `mixamorig_Hips`.**
   Los dos puntos pasan a guion bajo al importar. Buscar por el nombre original
   devuelve −1 y parece que el modelo no está rigueado cuando sí lo está.
   *(Lo comprueba `tools/validar_rigueados.gd`.)*

### Blender (MCP)

12. **`bpy.ops.wm.read_homefile()` invalida el contexto** para los operadores
   posteriores del *mismo* script. Divide en dos llamadas MCP: una importa, otra
   procesa.
13. **`read_factory_settings` está bloqueado** por el sandbox del MCP. Usa
    `read_homefile(use_empty=True)`.
14. **Blender 5.2:** el motor es `BLENDER_EEVEE` (no `BLENDER_EEVEE_NEXT`), y los
    nodos hay que buscarlos **por tipo** (`n.type == 'BSDF_PRINCIPLED'`), no por
    nombre: los nombres están traducidos al idioma del usuario.
15. **Al desemparentar con `CLEAR_KEEP_TRANSFORM`, el objeto absorbe la escala del
    padre.** Si luego asignas `scale = factor` la sobrescribes y el tamaño sale
    mal. Aplica transformaciones primero.
16. **Quitar los Empty limpia la selección** y el siguiente operador falla con
    "Falta objeto activo". Reafirma selección y objeto activo.
17. **Para deformar una malla, NO selecciones por islas.** Usa pesos continuos por
    posición. *(Rotar los brazos por islas rasgó los codos: el brazo atraviesa
    varias islas y la frontera es justo por donde se abre el corte.)*
18. **El importador de glTF deja `rotation_mode = 'QUATERNION'`.** Asignar
    `ob.rotation_euler` no hace absolutamente nada y `transform_apply` aplica una
    rotación de cero **sin avisar**. Para girar geometría de forma fiable:
    `ob.data.transform(Matrix.Rotation(ang, 4, 'Z'))`. *(Costó tres intentos
    creer que la rotación no se aplicaba: `dimensions` salía idéntico porque
    además está cacheado — hay que medir sobre los vértices.)*
19. **Para SEPARAR objetos pegados, agrupa islas sobre el GLB ya procesado, no
    sobre el original.** Exportar a glTF duplica vértices en las costuras de UV y
    eso parte la malla en islas separables (199 en el procesado frente a 5 en el
    original). Luego se anota la caja del añadido en metros y **se reprocesa el
    personaje desde el original borrando esa caja antes de decimar**, para que los
    25.000 triángulos se repartan solo entre el personaje. *(Ver
    [`12-REPARTO.md`](12-REPARTO.md) §2: el arbusto de Jupiter se llevaba el 39 %
    de su presupuesto.)*

### Entorno

18. **Godot fuera de `/Applications` sufre App Translocation:** macOS le da una
    ruta temporal distinta en cada arranque. **Ya resuelto**, está en
    `/Applications`.
19. **`git-lfs` no está en el PATH de shells no interactivas.** `export
    PATH="/opt/homebrew/bin:$PATH"` antes de cualquier `git add`.
20. **Al cerrar el editor de Godot puede sobrescribir `editor_settings-4.7.tres`**
    con las rutas viejas de Android y romper la exportación. Hay copia en
    `editor_settings-4.7.tres.bak-preandroid`.

### Herramientas de IA para 3D

21. **Tripo y Meshy cobran por EXPORTAR, no por generar.** Al evaluar una
    herramienta nueva, lo primero que hay que probar es **descargar un archivo**.
22. **hi3d.ai no deja configurar polígonos ni texturas.** Todo llega a ~2.000.000
    de triángulos con texturas 4K, así que el paso por Blender es obligatorio.
23. **Antes de perseguir un defecto en un modelo rigueado, mira si ya estaba en
    el `.glb` sin riguear.** Las botas de Uranus traen picos y muescas de
    fábrica; intentar limarlos solo erosiona el borde. Media hora perdida por no
    hacer la comprobación de un minuto.
24. **Los modelos traen un canal alpha que no usan, y Godot les activa
    `transparency = 2` (alpha scissor).** Recorta píxeles del pelo y abre
    agujeros. Blender no lo enseña porque su material va en modo opaco. Lo
    corrige `tools/importar_personaje.gd`, enganchado con `import_script/path`
    en el `.import` de cada FBX.
25. **Para marcar geometría y comprobarla en un render, usa VERDE, no rojo.**
    Media Sailor va de rojo: con marca roja es imposible saber qué está marcado
    y qué era así de fábrica. Una hora perdida creyendo que la falda de Mars
    estaba mal seleccionada cuando solo era su color.
26. **Un panel colocado en el ángulo θ de un círculo se rota `90° − θ`, no `−θ`.**
    Con `−θ` los paneles quedan de canto y el anillo se ve como los radios de
    una rueda. Estaba mal en la barrera de `arena.gd` desde la Fase 1.
27. **Para mover al jugador desde el MCP hay que enviar la ACCIÓN
    (`move_forward`), no la tecla (`W`).** El jugador lee
    `Input.get_vector("move_left", …)`; las pulsaciones de tecla sueltas no
    llegan y el personaje se queda quieto sin dar ningún error.
28. **Comparar contra el original, no contra el recuerdo.** Hay copia de los FBX
    tal como bajaron de Mixamo en `Models/rigged_originales/` (fuera de git).
    Antes de tocar uno, se restaura desde ahí. *(El FBX original de Uranus se
    perdió por no tener esto todavía.)*
29. **Los tramos del recorrido se registran por su EJE, no por su superficie.**
    `tramos[i]["origen"]` cae a media losa de profundidad (`grosor_suelo / 2`).
    Sembrando props ahí directamente, todo el parque aparece medio metro
    enterrado: los árboles se quedan detrás de los muros y las vallas parecen
    estacas cortadas. `punto_en_tramo()` ya suma ese medio metro; cualquier otro
    código que coloque cosas sobre un tramo tiene que sumarlo también.
30. **Un `hundir`/desvío en fracción del semiancho no vale entre tramos de
    distinto ancho.** Un árbol a 1,5 semianchos cae a 5,25 m en el cruce (ancho
    7) y a 6,75 m en un pasillo (ancho 9): en uno invade el camino y en el otro
    se esconde tras el muro. Lo que va **fuera** del muro se mide en metros
    desde el eje del muro (`fuera`), no en fracción.
31. **Dos superficies casi coplanares a 2 cm no bastan.** El disco de hierba
    puesto 0,02 m por debajo de las losas rayaba el suelo a diez metros: el
    z-buffer no distingue las dos a esa distancia. Con 0,28 m desaparece. El
    mismo síntoma con bandas —pero en las sombras— es *shadow acne*, y se cura
    con `shadow_normal_bias` y bajando `directional_shadow_max_distance`.
32. **La pieza dice en qué eje está modelada; el rumbo del camino no.** La
    cortina de `puerta_magica.gd` y la valla del kit se construyen a lo largo de
    su **X local**, y `atan2(−d.x, −d.z)` orienta el −Z. Para la puerta eso ya
    la deja atravesada (sin sumar 90°) y para la valla hay que sumarlos. Sumar
    o no sumar «los 90° de siempre» sin mirar la pieza da una barrera pegada al
    muro que no corta nada, o una fila de vallas cruzadas como aspas.
33. **El pintado automático de pesos falla EN SILENCIO y el `.glb` sale sin
    skin.** `bpy.ops.object.parent_set(type='ARMATURE_AUTO')` con la malla de
    Luna avisó «Falla al buscar solución para uno o más huesos», dejó los 3135
    vértices sin grupo y el exportador sacó un modelo que se ve perfecto, no da
    ningún error y no se mueve. En `blender_riguear_gatos.py` los pesos se
    reparten **por distancia al segmento del hueso**: menos fino, pero
    determinista y sin depender de que la malla esté sana. Y siempre se cuenta
    cuántos vértices quedaron sueltos antes de exportar.
34. **Un `Control` se come el toque antes de `_unhandled_input`.** El cuadro de
    diálogo ocupa media pantalla y venía con el filtro por defecto (`STOP`), así
    que tocarlo no hacía nada: solo avanzaba tocando FUERA, que es justo donde
    nadie toca. Se arregla poniendo `MOUSE_FILTER_IGNORE` en **todo el árbol**
    del cuadro — basta que un hijo lo pare para que el agujero siga ahí.
35. **Dos superficies tangentes no cierran.** Un pasillo que acaba exactamente
    donde empieza el disco de la arena deja rendijas por las que se cae del
    mundo: en el Nivel 1 eran 67. Las losas se solapan medio metro, los discos
    de arena sobresalen para cubrir las esquinas contra el borde curvo, y el
    disco de hierba lleva colisión como red de seguridad. Para comprobarlo,
    barrido de rayos en rejilla de 50 cm, **excluyendo los cuerpos de los
    props**: si no, un tronco tapa el rayo y falsea el resultado.
36. **La altura de un tramo solo vale ENCIMA del tramo.** En el pasillo que sube
    al guardián, todo lo sembrado fuera del muro se calculaba a la altura del
    camino —hasta 2,5 m— mientras el terreno de al lado es la hierba, plana:
    árboles, rocas y un farol flotando. Cualquier cosa que se coloque sobre el
    escenario se posa con un rayo, no con una cuenta.
37. **Las capas de colisión hay que mirarlas las dos.** La jugadora tenía
    `collision_mask = 1` (solo `world`), así que atravesaba a los enemigos por
    mucho cuerpo que estos tuvieran. Un `Area3D` como el de `Encuentro` no da
    bulto ninguno: para que no se atraviese a un personaje hace falta un
    `StaticBody3D` aparte del área que escucha.
38. **En `fragment()` todo viene en espacio de VISTA, y no existe
    `NORMAL_WORLD`.** Hay que pasar `VERTEX` y `NORMAL` por `INV_VIEW_MATRIX`
    —la posición con `w = 1`, la normal con `w = 0`—. Inventarse un
    `NORMAL_WORLD` deja el material en **blanco liso** sin más pista que una
    línea de `SHADER ERROR` perdida entre los avisos del arranque: el shader no
    compila y Godot cae al material por defecto, que parece un problema de
    iluminación y no de código.
39. **Cuidado con las variables de bucle que se llaman como una propiedad.** Al
    pasar los colores del blockout a nombres de superficie, la propiedad `borde`
    quedó ensombrecida por un `for borde: float in [-1.0, 1.0]`, y se colaba un
    número donde iba el nombre del material. GDScript sí lo detecta, pero el
    mensaje habla del argumento de `_losa()` y no de la variable culpable.
40. **El blockout también cuenta para el presupuesto de draw calls.** 84 cajas
    como `MeshInstance3D` sueltos son 84 draw calls, más de la mitad de los 150
    del §8. Agrupadas en un `MultiMeshInstance3D` por color son 4, y los
    `StaticBody3D` se quedan solo con la colisión, que no cuesta dibujado. El
    Nivel 1 pasó de 163 a 57.
41. **Godot NO reimporta un `.glb` regenerado si el editor no está abierto.** Se
    reescribió el puente en Blender, se exportó bien (14 m en vez de 3), y el
    juego seguía poniendo el viejo — sin ningún error. La caché de importación
    manda mientras el `.md5` coincida. Para forzarla:
    ```bash
    rm -f .godot/imported/<pieza>.glb-*.md5 .godot/imported/<pieza>.glb-*.scn
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
    ```
    Vale para cualquier asset regenerado desde `tools/`, no solo modelos.
42. **El agua tiene que morir DENTRO de la ladera del vaso, no antes.** La
    lámina se hizo del radio nominal y el vaso a 1,18 de ese radio, así que
    quedaba un anillo de hoyo seco alrededor del charco: se leía como una mancha
    azul flotando en un cráter y la espuma de orilla —que se calcula por
    profundidad— solo salía por el lado donde el terreno subía antes. La lámina
    va al 1,14 (`BORDE_AGUA` en `decorador_nivel.gd`): el terreno la recorta
    cerca del borde y la línea de costa la dibuja el propio relieve. Pasarse del
    1,18 es peor todavía — el agua asomaría por encima de la hierba.
43. **`_posar()` no vale para nada que vaya sobre el estanque.** Lanza un rayo
    hacia abajo, y dentro del vaso el rayo encuentra el fondo cavado: la lámina
    de agua acabó 1,85 m bajo tierra (invisible, sin ningún error) y el puente
    hundido. El nivel del agua se mide promediando cuatro puntos de la ORILLA, y
    el puente lleva `"posar": false` en su receta.
44. **Cada siembra iba a ciegas y ninguna sabía de las demás.** Los carriles, el
    campo, las coronas de arena y la linde repartían dos mil props sobre el
    mismo terreno sin llevar ninguna cuenta: bancos dentro de peñascos, faroles
    clavados en un tronco, matorrales saliendo de un banco. Al montar el
    registro de ocupación salieron **334 props montados unos sobre otros y 219
    metidos dentro de un muro** — no era un fallo de ninguna siembra, es que
    faltaba quien repartiera el sitio. Ahora cada copia reserva un círculo
    (`HUECO` + rejilla `_huecos`) y la siguiente que caiga encima se descarta.
45. **Contra un muro se mide el PIE de la pieza, no su copa.** El primer intento
    usaba el hueco entero, y descartó **70 de 70 vallas**: van pegadas al seto
    justamente a propósito. Un cerezo con el tronco a medio metro del muro está
    bien plantado aunque las flores pasen por encima. Las recetas declaran
    `pie`, y solo para eso.
46. **El rayo de `_posar()` iba de +4 a −8 metros.** En las faldas de las
    colinas el terreno ya estaba por encima del punto de salida, el rayo no
    encontraba nada y el prop se plantaba a la altura cero del centro del nivel
    — o sea, enterrado varios metros. De ahí salía la hierba asomando por dentro
    del suelo. Ahora va de +90 a −60 y, si no toca nada, **se descarta la copia**
    en vez de dejarla flotando.
47. **El orden de siembra decide quién se queda el sitio.** Los rincones
    compuestos se colocaban al final, y los cerezos de la segunda fila del
    camino —que van a siete metros del muro— caían dentro de la plaza de la
    fuente y la llenaban de troncos. Van los PRIMEROS de todo, después del
    estanque: lo más importante reserva antes.
48. **Un sendero recto entre dos puntos cruza los muros que haya en medio.** El
    andén de la plaza de la fuente salía del camino, atravesaba el seto y
    reaparecía al otro lado. `_punto_del_recorrido_mas_cercano()` ya no coge el
    punto más cercano a secas: prueba puntos de todo el recorrido y se queda con
    el más cercano **desde el que se llega sin cruzar nada** (`_hay_paso()`).
49. **Un radio mayor que la celda de la rejilla no se ve desde lejos.** La
    rejilla de ocupación mira las nueve celdas vecinas, así que un círculo de
    once metros registrado en una celda de seis solo lo ven los props que caigan
    muy cerca. Por eso los rincones NO usan la rejilla: van en su propia lista
    (`_sitios_rincon` + `_en_un_rincon()`).
50. **El pase de sombra puede costar MÁS que la pantalla, y no se ve en el
    total.** El contador de Godot suma los dos; mirándolo así, 358.000
    triángulos no decían nada. Separados eran **97.000 de pantalla y 260.000 de
    sombra**: cada objeto que proyecta sombra se dibuja otra vez por cada
    cascada, y había cuatro. Una sola cascada, 30 m de alcance y quitarle la
    sombra al detalle menudo lo dejó en 31.000. Mide siempre
    `VIEWPORT_RENDER_INFO_TYPE_VISIBLE` y `_TYPE_SHADOW` por separado — el panel
    de F1 ya los muestra.
51. **Una multimalla es UN objeto para el motor, con UNA caja envolvente.** Las
    460 matas de hierba iban todas en la misma, así que su caja cubría el mapa
    entero y **nunca salía del campo de visión**: se dibujaban las 460 mirases a
    donde mirases. Igual los 238 cerezos. Hay que **trocear por parcelas**
    (`LADO_PARCELA` en `decorador_nivel.gd`) para que el descarte por frustum y
    por distancia sirvan de algo. Cuesta más nodos; un nodo descartado no cuesta
    nada y un triángulo dibujado sí.
52. **`sin()` en un shader que cubre la pantalla es carísimo en un móvil.** El
    hash de ruido del terreno era el clásico `fract(sin(dot(p,k))*43758.5)`, y
    entre la proyección triplanar y el grano salían **más de treinta senos por
    píxel**. En una GPU de móvil el seno es una operación transcendental, a una
    fracción del ritmo de una multiplicación: era el tirón constante, el que se
    notaba «en todo el mapa» y no en una zona. Sustituido por un hash de
    multiplicaciones y `fract`.
53. **`hundir` positivo dejó las losas del empedrado EXACTAMENTE al ras.** El
    modelo va de −0,05 a +0,05, así que hundirlo 5 cm ponía su cara de arriba a
    la altura justa del terreno: coplanar, y parpadeando en cuanto giraba la
    cámara. El valor tiene que ser negativo (levantar).
54. **Dos superficies del blockout a la misma altura se pelean, y el solape
    existe a propósito.** El disco de la arena y la losa del pasillo se montan
    uno sobre otro para que no queden agujeros en la junta (trampa 3), pero se
    construían a la misma cota: dos caras coplanares justo en la zona de solape.
    Ahora hay un `desnivel` de 10 cm — se sube andando sin enterarse y se lee
    como un cambio de pavimento.
55. **`cortes` era un parámetro muerto en `_esfera()`.** Muchas piezas lo
    pasaban (`cortes=4`, `cortes=5`) creyendo que bajaban la resolución, y la
    función lo ignoraba: **todas las esferas del proyecto salían a 320 caras**.
    Una piedrecita de siete centímetros costaba lo mismo que la copa de un
    árbol. El parámetro de verdad es `divisiones` (0 → 20 caras, 1 → 80, 2 →
    320); el decorado pasó de 489.000 triángulos a 277.000 solo con ponerlo bien
    donde no se nota.
56. **Un `match` sin el caso que toca se lo traga sin decir nada.** El paso
    `{"tipo": "pradera"}` llevaba desde que se escribió sin construirse porque
    `construir()` no tenía esa rama: el nivel entero salía cincuenta metros más
    corto, se aparecía pegada al canto del primer pasillo, y la corona de la
    primera arena caía sobre el camino de salida —de ahí el árbol en mitad del
    sendero—. **Todo `match` sobre datos lleva un `_:` que avise.**
57. **…y ese comodín va EL ÚLTIMO.** Puesto en medio se traga los casos que
    vienen detrás. Colocándolo tras `"cruce"` desaparecieron `"giro"` y
    `"arena"`: el nivel se quedó en un pasillo suelto con una sola arena.
    GDScript lo avisa con «Unreachable pattern», que es fácil de pasar por alto
    entre otros avisos.
58. **Algo elevado sin colisión es algo por dentro de lo que se camina.** Al
    subir la franja de camino diez centímetros para quitarle el z-fighting se
    convirtió en un escalón: el personaje seguía pisando el suelo de debajo y la
    franja le tapaba las botas. Si una superficie sobresale, hay que poder
    subirse encima.
59. **Un rincón compuesto necesita terreno LLANO, y hay que comprobarlo.** La
    plaza de la fuente cayó en una ladera y quedó con los bancos desperdigados
    cuesta abajo y el empedrado colgando como escamas. `_es_llano()` mira nueve
    puntos —el centro y ocho alrededor— porque el centro puede estar horizontal
    justo en el borde de una cuesta.
60. **El terreno se centraba donde lo dejó el editor, no en el parque.** Su zona
    llana y sus colinas se miden desde su propio origen; al alargar el recorrido
    el parque se desplazó treinta metros, se salió del llano y media mitad acabó
    metida en las faldas de las montañas. Lo coloca `nivel.gd` desde
    `extension()`, así que el llano sigue al parque pase lo que pase.
61. **Lo que va tumbado tiene que tumbarse CON el suelo.** Las losas del
    empedrado se plantaban siempre horizontales y en una cuesta sobresalían de
    canto. `_apoyo()` devuelve también la normal, y las recetas con
    `seguir_suelo` alinean su «arriba» a ella.
62. **Los giros escritos a mano salen mal, y salen mal TODOS a la vez.** Los
    cuatro bancos de la plaza llevaban 0, 90, 180 y 270 puestos a ojo, y los
    cuatro acabaron de espaldas al agua: las piezas del kit miran a su −Z, que
    no es lo que uno supone al escribir el número. Con `mirar: "centro"` el giro
    se calcula (`atan2(en.x, en.y)`) y además sigue valiendo si se mueve la
    pieza.
63. **Bajar la resolución de render se nota MÁS en cel shading, no menos.** Se
    probó `scaling_3d/scale = 0.8` —la palanca de rendimiento más fuerte que hay
    en un móvil— y la imagen queda emborronada: el filtro que estira el
    resultado deja los contornos duros, que son justo lo que define el estilo,
    con un halo blando que canta muchísimo. **En este proyecto el rendimiento se
    saca de dibujar menos mundo, no de dibujarlo peor.**
64. **Una losa grande del blockout borra el relieve que tenga debajo.** La
    pradera de arranque se probó a 52×54 y a 34×46, y las dos veces se leyó como
    un bloque cuadrado puesto encima del mapa. Además desplaza el parque entero,
    y con él todo lo que se coloca por rumbo y distancia desde su centro: el
    estanque y su puente acabaron tapados. Las losas de suelo, pequeñas.
65. **En el `SpringArm3D` del jugador, el pitch NEGATIVO sube la cámara.** Es al
    revés de lo que parece al leer el número, y comprobarlo con una captura
    puede engañar: si el personaje está cayendo cuando se mide, la cámara está
    en transición y sale al revés. Medir `cam.global_position.y` contra
    `jugador.global_position.y` tras dejar asentar la física: −32° pone la
    cámara 3,3 m por encima, +32° la pone por debajo.
66. **Se optimizó la geometría cuando lo caro era pintar píxeles.** Toda la Fase
    D atacó triángulos y draw calls: de 358.000 a 144.000 y de 156 a 83. Los fps
    en el móvil casi no se movieron —seguía entre 25 y 41— porque el cuello no
    estaba ahí. La pista estaba en los propios números: **74.600 triángulos y
    106 draw calls dando 35 fps** es absurdo, un móvil de 2019 mueve eso de
    sobra. Y no había correlación entre draw calls y fps, pero sí entre fps y
    **cuánta pantalla ocupaban el terreno y el cielo**. Antes de optimizar hay
    que saber si el cuello es geometría (triángulos, llamadas), píxeles
    (shaders, transparencias) o CPU — son tres problemas distintos y las
    soluciones de uno no hacen nada por los otros. La prueba que lo decide es
    **bajar la resolución de render**: si los fps se disparan, es de píxeles.
67. **La trampa 52 se corrigió en el terreno y se quedó sin corregir en el
    cielo.** `cielo_anime.gdshader` seguía con `fract(sin(dot(p,k))*43758.5)`,
    y entre las 4 octavas del `fbm()` y las DOS pasadas (nube y sombra de nube)
    salían **32 senos por píxel de cielo**. Y el cielo no es un detalle del
    fondo: se pinta en todos los píxeles que no tape nada, que en un parque con
    el horizonte despejado es un tercio de la pantalla. Su comentario decía que
    «se calcula una vez y se guarda en la radiancia» — eso vale para la LUZ que
    el cielo aporta, no para el fondo, que se dibuja siempre. **Cuando se
    arregle algo así, hay que buscar el mismo patrón en el resto del proyecto.**
68. **Un patrón procedural que no cambia nunca no tiene por qué calcularse en
    cada píxel.** El terreno hacía 2 octavas × 3 planos de proyección triplanar
    + grano = **28 evaluaciones de hash por píxel**, unas trescientas
    operaciones, en la superficie que ocupa media pantalla. Y el patrón es
    siempre el mismo: entre la hierba y la madera cambian los colores y la
    escala, no el ruido. Horneado a una textura de tres canales
    (`tools/generar_textura_ruido.gd`) son tres lecturas, que es para lo que una
    GPU tiene unidades dedicadas. De paso los mapas MIP quitan el hormigueo que
    el ruido procedural hacía en la distancia: **se ve mejor, no peor**.
    *(Ojo con el `.import`: los PNG entran con `mipmaps/generate=false` y hay
    que activarlo a mano, o no hay mips y además se lee más caro.)*
69. **El blockout no tenía por qué verse.** El suelo era una caja de un metro de
    grosor apoyada sobre el terreno, y el camino OTRA caja de 16 cm encima. De
    ahí salían a la vez el canto vertical —la «plataforma cuadrada» que se veía
    por todo el parque—, un escalón por el que se tropezaba y el z-fighting de
    las juntas. Ahora las losas siguen existiendo como CUERPO —dan una
    superficie plana exacta, que una rejilla de tres metros no puede garantizar—
    pero no se dibujan: el terreno sube hasta su cara de arriba y las tapa, y el
    camino se pinta con una máscara. Un cuerpo sin malla no cuesta ni un
    triángulo ni una llamada de dibujado: el nivel pasó de 114 piezas en 4 lotes
    a 96 en 2, y de ~106-156 draw calls a **74**.
70. **La resolución de la máscara no depende de la de la malla.** Es lo que hace
    viable pintar el camino: la rejilla del terreno tiene celdas de más de tres
    metros y subirla sería multiplicar los triángulos, pero el borde del sendero
    lo dibuja una textura de 1024 px (25 cm por texel). Detalle fino sobre
    geometría gruesa.
71. **Aproximar un rectángulo con círculos deja las esquinas fuera.** Las zonas
    que levantan el terreno bajo el escenario eran círculos, y un pasillo es un
    rectángulo: el terreno subía en festón y por las esquinas asomaba el canto
    de la losa. Ahora son rectángulos orientados, con la misma convención de
    giro que los `estorbos` del decorador (`hacia.rotated(giro)`) — **conviene
    que solo haya una convención en todo el proyecto**.
72. **Una transición más corta que una celda sale en diente de sierra.** Una
    falda de medio metro al 20 % mide metro y medio y la celda del terreno mide
    3,2: la cuesta entera cabía dentro de una celda y en vez de un talud salía
    un borde aserrado siguiendo la rejilla. Dos soluciones, y la barata es la
    buena: **promediar la altura con la de los vecinos** (`_suavizar_faldas()`)
    en vez de subir la resolución de toda la malla. Y mejor todavía: poner el
    llano del terreno **directamente a la altura del suelo pisable**, y así en
    la parte llana —que es casi todo— no hay nada que levantar ni que dentar.
73. **Un borde de sombra en zigzag no es «borde duro de cel shading», es
    aliasing.** `soft_shadow_filter_quality = 0` dejaba las sombras grandes
    recortadas en sierra sobre el terreno, y se confundía fácilmente con un
    defecto del relieve — hicieron falta dos intentos de suavizar el terreno
    para caer en que la culpa era de la luz. Se identificó apagando las sombras
    con el banco de pruebas (F8): el zigzag desapareció entero. Con el filtro a
    2 se quita y **no cuesta un solo triángulo más**, solo unas muestras de
    textura.
74. **El banco de pruebas paga su coste el primer día.** `F8` —o un toque en la
    esquina superior derecha en el móvil— va apagando una cosa cada vez (cielo,
    shader de terreno, sombras, niebla, decorado, post, media resolución) desde
    el juego completo. Sirve para medir en el móvil con UN APK en vez de
    exportar uno por corazonada, y para atribuir cada fps a algo concreto. Va en
    la esquina DERECHA porque el joystick flotante se queda con todo lo que se
    toque en la mitad izquierda.

75. **Al dejar de dibujarse algo, todo lo que se apoyaba en ello se queda
    huérfano.** El suelo del blockout pasó a ser invisible y lo que se ve es el
    terreno — pero los muros y los props siguieron colocándose respecto al
    blockout, que es un número exacto, mientras que el terreno tiene ruido y
    faldas suavizadas. Según de qué lado cayeran los dos dedos de diferencia, el
    muro flotaba o se hundía y se volvía saltable. **Cuando algo deja de ser la
    referencia visual, hay que repasar quién se estaba midiendo contra ello.**
76. **Enterrar es más barato que nivelar.** Se puede perseguir que el terreno
    quede perfectamente plano bajo cada muro —contra el ruido, contra el
    suavizado, contra la rejilla— o se le pueden dar dos metros de pie
    enterrado y olvidarse. Lo que sobra no se ve porque queda dentro del
    terreno. `muro_pie` en `constructor_nivel.gd`.
77. **Lo que se ve y lo que choca no tienen por qué medir lo mismo.** El seto
    quedaba bajo donde el terreno de al lado subía, y se saltaba. Subirlo de
    verdad lo habría convertido en un paredón, que es justo lo contrario de lo
    que se busca. La colisión sube cuatro metros más que la malla (`muro_tope`):
    el límite se respeta y el parque sigue pareciendo un parque.
78. **Un tramo no es una línea, tiene ancho — y en un giro ese ancho invade
    hacia atrás.** El tramo nuevo arranca donde acabó el anterior, así que se
    mete media anchura sobre él y sus muros aparecen cruzando el pasillo de
    antes. Se veía como un muro puesto al azar en mitad del camino, con su fila
    de vallas. Los muros se retiran en las esquinas
    (`_recorte_de_esquina()`), y contra una arena hacen lo contrario y se
    alargan — que es la trampa 35 otra vez, pero en los muros: recto contra
    curvo deja una cuña por la que se cuela la jugadora.
79. **Colocar por rumbo y distancia desde un punto que se mueve falla siempre,
    tarde o temprano.** Es la trampa 64 por segunda vez: el estanque colgaba del
    centro del parque, el centro se desplazó al agrandar la pradera, y el
    estanque acabó debajo del parque con el puente colapsado. Ahora el rumbo es
    una PREFERENCIA: se prueba, y si ahí no cabe se abre en abanico hasta
    encontrar sitio libre (`sitio_del_estanque()`). Si cambia el recorrido, se
    aparta solo.
80. **Lo que no reserva su sitio, lo pierde.** El puente iba con
    `reserva: false` y el arbolado se sembraba después: cerezo en mitad de la
    pasarela. Reserva en varios círculos pequeños a lo largo del eje, no en uno
    grande — un círculo más ancho que la celda de la rejilla no lo ve nadie
    desde lejos (trampa 49).
81. **`MultiMesh.get_instance_transform()` miente en `--headless`.** Pregunta al
    servidor de render, y el driver de mentira devuelve la identidad para todas
    las instancias. Se estuvo un rato creyendo que todos los muros del parque
    medían un metro y estaban en el origen. Para auditar sin render hay que leer
    los `StaticBody3D` y sus formas, que son nodos de verdad.
82. **Un plano en planta encuentra lo que ninguna lista de avisos encuentra.**
    Los textos dicen si una pieza pisa a otra; para ver que el estanque se ha
    ido a parar debajo del parque hace falta MIRAR el mapa. Y desde dentro del
    juego no se ve el nivel entero. Lo dibuja `tools/auditar_nivel.gd`.
83. **Un arco que cruza el 0° sale partido en dos.** La entrada de la Arena 1
    aparecía como «339°→360°» y «0°→22°», o sea dos agujeros donde solo había
    una boca perfectamente normal. Cualquier medida angular alrededor de un
    círculo tiene que volver a juntar los extremos antes de contar.
84. **Mixamo no exporta siempre con la misma jerarquía, y eso deja al personaje
    en POSE T.** Las animaciones viejas traían sus pistas como
    `Skeleton3D:mixamorig_Hips`; las bajadas meses después vienen con un nodo de
    más: `Armature/Skeleton3D:mixamorig_Hips`. El `AnimationPlayer` cuelga del
    padre del esqueleto y busca `Skeleton3D` justo debajo, así que con el
    `Armature/` delante no encuentra nada — y **una pista que no encuentra su
    hueso no se queja**: simplemente no mueve nada. Las 56 fallaban a la vez y
    el personaje se quedaba en la pose de reposo del modelo, que en un rigueado
    de Mixamo es la T. Es de la familia de la trampa 16: el hueso está, el
    esqueleto está, y lo que no cuadra es cómo se le llama desde la pista.
    `construir_libreria_animaciones.gd` recorta ahora todo lo que haya antes de
    `Skeleton3D:`, así que da igual cómo venga el FBX.
85. **«In Place» de Mixamo quita el avance horizontal, NO el vertical.** Y la
    altura ya la lleva la física, así que las dos cosas se suman: midiendo la
    pista de posición de la cadera, `double_jump` subía el modelo hasta 2,15 m
    (de pie está a 0,91) y `land` lo bajaba a 0,57. En el salto subía de más y
    al aterrizar **atravesaba el suelo**. La cadera se ancla a su altura de pie
    (`_anclar_la_cadera()`), dejándole bajar 30 cm para que el amortiguado del
    aterrizaje no se pierda, pero sin dejarle subir: de subir se encarga
    `velocity.y`.
86. **Un `pkill -f "Godot.*sailor-moon"` no mata el juego si se lanzó con
    `--path .`** — en la línea de órdenes no aparece el nombre del proyecto por
    ningún lado. Se estuvo midiendo contra una instancia vieja y las
    propiedades nuevas salían `null`, que parecía un fallo del código. Para
    matarlo de verdad: `kill -9 $(lsof -nP -iTCP:9090 -sTCP:LISTEN -t)`.
87. **Un personaje se posa ENCIMA DE SÍ MISMO si no se aparta del rayo.** Un
    `Encuentro` lleva un `StaticBody3D` con cápsula para que no se le atraviese
    (trampa 37), y el rayo que lo posa sale de muy arriba y baja en vertical: lo
    primero que encuentra es su propio cuerpo. Mercury quedaba metro y cuarto en
    el aire, y cada vez que se volviera a posar subiría otro tanto — llamándolo
    dos veces a mano, subía a 4,45. Todo lo que se posa con un rayo y tenga
    cuerpo propio tiene que excluirse a sí mismo.
88. **Para pegar un personaje a una pared, lo que manda no es el esqueleto sino
    la carne.** Colgada de una cornisa, el HUESO de la espina a tres centímetros
    del muro parece perfecto y la cara ya está dentro de la piedra: el pecho y
    la cabeza sobresalen bastante por delante del hueso. Se arrima el modelo
    (`ACERCAR_MODELO`) solo hasta donde la carne aguanta, y lo que falta para
    que las manos alcancen el canto se saca **doblando los brazos**, no
    acercando más el cuerpo.
89. **Un `SkeletonModifier3D` es la única forma de retocar una pose animada.**
    Escribir la rotación desde un `_process` la pisa el `AnimationTree` al
    fotograma siguiente, y desactivar el árbol para escribir devuelve el
    esqueleto a la pose de reposo — que en un rigueado de Mixamo es la T, así
    que en vez de brazos doblados sale una T con las manos donde no van. Y ojo
    al calibrar: por la trampa 9, `get_bone_global_pose()` devuelve la pose
    ANTERIOR al modificador, así que los números dicen que no hace nada aunque
    en pantalla se vea perfectamente. Ahí hay que mirar, no medir.
---

90. **Una señal que nadie escucha no da ningún error.** `EventBus.show_message`
   la emitían veintiún sitios —el portal, las puertas, los faroles, los
   objetivos— y el HUD nunca se conectó a ella. Todos esos avisos llevaban desde
   siempre gritando al vacío. No se ve leyendo el código que emite, porque ese
   código está bien; solo se ve probando el mensaje en pantalla. Si un aviso
   «no sale», comprobar primero que alguien lo escucha:
   `EventBus.show_message.get_connections().size()`.
91. **Dos números que tienen que ir juntos acaban separándose.** El disparador de
   las arenas medía 6 m en el `.tscn` y la barrera 11 en el script: entre uno y
   otra quedaba un anillo de cinco metros por el que se cruzaba la arena entera
   sin que arrancara la pelea. Ahora el disparador se calcula del radio de la
   barrera. Cuando dos medidas describen la misma cosa, que solo se escriba una.
92. **Un `SubResource` del `.tscn` lo comparten todos los nodos que lo usan.** Las
   cuatro arenas apuntaban al mismo `CylinderShape3D`; cambiarle el radio a una
   se lo cambiaba a las cuatro y ganaba la última en inicializarse. `duplicate()`
   antes de tocar nada que venga de la escena.
93. **`look_at` es un error, no un aviso, si se mira a donde ya se está.** Y el
   error corta la ejecución de la función a la mitad, así que lo que viniera
   después —devolver el control, abrir un panel— no llega a pasar. En una
   cinemática cuya cámara depende de por dónde llegue la jugadora, eso falla a
   veces sí y a veces no. Comprobar la distancia antes de llamarlo.

94. **La `global_position` de una arena no es su suelo.** El nodo `Guardian` está
   a y=2,5 y el suelo por el que se anda a y=3,6: los enemigos aparecían medio
   metro bajo tierra, salían despedidos a cualquier parte y la oleada se quedaba
   esperando a uno que ya no se podía matar. Los sitios de aparición se sacan
   ahora con un rayo al suelo real, igual que los faroles y los props (trampa 37
   otra vez, en otro sitio). Si algo se coloca «a la altura de la arena», está
   mal colocado.
95. **Un enemigo perdido cuelga el nivel para siempre.** La oleada solo avanza
   cuando no queda nadie vivo, así que uno inalcanzable —volando fuera, caído,
   atascado— deja el juego muerto sin decir nada. Hay vigilancia en
   `_vigilar_perdidos()`, pero la regla general es: **cualquier condición de
   avance que dependa de que un enemigo muera necesita una salida**.
96. **Dos números con el mismo «de 6» en el mismo renglón se confunden siempre.**
   «✓ Enciende los seis faroles  (2 de 6)» — el segundo par son objetivos del
   parque, no faroles, y no hay forma de leerlo bien. El conteo estaba perfecto;
   lo que estaba mal era la frase. Antes de buscar un bug en un contador, leer en
   voz alta lo que sale por pantalla.

97. **Un objetivo con la meta escrita a mano se queda viejo y bloquea el nivel.**
   «Despeja los tres caminos» pedía tres y solo podía recibir dos, porque la
   arena del guardián contaba en otro objetivo distinto: imposible de terminar,
   y con él el nivel entero, porque la puerta espera a que estén los seis.
   Jugando no hay forma de notarlo salvo dando vueltas buscando algo que no
   existe. Ahora las metas las fija quien coloca las cosas (`fijar_meta`), no
   una constante. Regla: **si algo se genera, su cuenta se genera con ello**.
98. **Para probar el final hay que poder saltar al final.** El jefe estaba
   detrás de tres arenas, seis faroles, siete Estrellas y cuatro rincones —
   veinte minutos por cada cosa que se quiera mirar. Lo que cuesta veinte
   minutos probar se prueba poco y tarde, que es como se quedan los fallos
   dentro. `F10` (o abajo a la derecha en el móvil, con el panel abierto).

## 7. Decisiones tomadas y por qué

| Decisión | Motivo |
|---|---|
| Beat 'em up en vez de aventura | Elección del usuario. Se mitigó el coste compartiendo esqueleto y animaciones entre las 5 Sailors |
| Renderizador Mobile | Dispositivo objetivo Android 2019+. `Forward+` está descartado en móvil |
| Fichas de ataque (máx. 3) | Sin esto, 8 enemigos atacan a la vez y el juego se vuelve injusto |
| Auto-orientación por puntuación, no por cono | Apuntar en 3D con joystick virtual es la barrera nº 1 para una niña de 8 años |
| Ventana de combo de 0,8 s | Deliberadamente enorme: machacar debe funcionar SIEMPRE |
| El especial no se recarga a sí mismo | Devolvía el 41% por uso y era encadenable siendo invulnerable |
| ~~Purificar en vez de matar~~ → **eliminación real** | Lo pidió la jugadora al probarlo. El aviso rojo antes de cada golpe se mantiene |
| Joystick flotante | Aparece donde pone el dedo; a los 8 años es mejor que uno fijo |
| Enemigos con animación procedural | Son bolas y cofres: Mixamo no puede riguearlos y no hace falta |
| `Models/` fuera de git | 231 MB de originales regenerables desde hi3d.ai |

---

## 8. Presupuestos de rendimiento

Objetivo 60 fps, aceptable 30.

| Recurso | Presupuesto |
|---|---|
| Triángulos por fotograma | < 150.000 **contando pantalla Y sombra** |
| Personaje principal | 15–25k tris · textura 2048 |
| Enemigo | 3–5k tris · textura 1024 |
| Enemigos simultáneos | 8 activos |
| Draw calls | < 150 |
| Luces dinámicas | 1 direccional + 2–3 puntuales |

Modelos actuales: los 11 personajes a 25.000 tris · Peluchín, Cofrecito y Hadita
a 5.000 · props de escenario (coral 4.700, bonsái 9.750). ✅

### Cómo se mide

**Panel del modo desarrollador: F1**, o **tres toques en la esquina superior
izquierda** en el móvil. **Tocando el panel se copian todos sus datos al
portapapeles** (o `F9`): el informe completo más la posición exacta como
`Vector3(…)`, hacia dónde mira y qué pisa. Va también por consola, para
pescarlo con `adb logcat` cuando el portapapeles del móvil no ayuda. Muestra fps, draw calls y triángulos, y **separa
pantalla de sombra** — que es la cifra que importa: el pase de sombra llegó a
costar el triple que la imagen y sumados no se veía (trampa 50).

Medir SIEMPRE en el móvil. En el Mac todo va a 60 fps y el problema no aparece,
y además la pantalla del teléfono es mucho más ancha que un 16:9: ve bastante
más mundo de golpe y sube los draw calls.

### Estado del Nivel 1, medido

| | 1ª pasada (geometría) | 2ª pasada (píxeles) |
|---|---|---|
| Triángulos de pantalla | ~82.000 | ~75.000 |
| Triángulos de sombra | ~62.000 | ~63.000 |
| **Total por fotograma** | **~144.000** | **~139.000** |
| Draw calls | ~106–156 | **74** |
| fps en el móvil | 25–41 | **por medir** |

La segunda pasada apenas toca las cifras de geometría **y ese es justamente el
resultado**: la primera pasada ya había dejado los triángulos en su sitio y los
fps seguían en 25–41, porque el cuello no estaba ahí (trampa 66). Lo que se
atacó esta vez es el **coste por píxel**:

1. **El cielo hacía 32 `sin()` por píxel** — la trampa 52 sin corregir en
   `cielo_anime.gdshader`. Es el shader que más pantalla pinta del juego
2. **El terreno hacía 28 evaluaciones de ruido por píxel** — ahora el patrón va
   horneado en una textura y son tres lecturas
3. **74 draw calls en vez de 106–156** — el suelo del blockout dejó de dibujarse
4. **Sombras sin el zigzag** — filtro suave en vez de duro, y sin coste de
   geometría

Las cifras de arriba son del Mac (que va a 60 siempre). **La medición que vale
es la del móvil, con F8**, y está sin hacer.

Las seis técnicas que lo bajaron están en
[`18-ESTADO-NIVEL-1.md`](18-ESTADO-NIVEL-1.md) §Rendimiento.

**Lo que NO se puede usar:** bajar la resolución de render
(`scaling_3d/scale`). Es la palanca más fuerte que hay en móvil, pero con cel
shading emborrona los contornos duros y se ve peor que en un juego fotográfico
— ver trampa 63.

---

## 9. Nota legal

Sailor Moon es propiedad de Naoko Takeuchi / Kodansha / Toei Animation. Regalo
personal, no distribuido ni monetizado. **No publicar en Google Play, itch.io ni
ninguna tienda.** Instalación por sideload en el dispositivo de la prima.


99. **Un estado que devuelve su propio nombre cuelga el juego entero.** Sin
   error, sin pantalla: se congela y hay que matar el proceso. El guardián lo
   hizo — cuando a cierta distancia no le encajaba ningún ataque devolvía
   «Approach», y como es `EApproach` quien pregunta, entraba, preguntaba, no
   encajaba nada y volvía a entrar, todo en el mismo fotograma. Ahora
   `StateMachine` corta a los ocho cambios por fotograma y lo deja en un aviso
   por consola. **Nunca devolver el nombre del estado que pregunta**: para «sigue
   como estás» está la cadena vacía.


100. **Una excepción en `_ready()` mata todo lo que venga detrás, en silencio.**
   Una llamada con `call()` y un argumento de menos —`sitio_del_estanque()` pide
   el constructor— tiraba el resto del `_ready()` del nivel entero. El síntoma no
   se parecía en nada a la causa: «el nodo de ambiente no se crea», y el nodo se
   creaba tres líneas más abajo de donde reventaba. Se persiguió como si fuera un
   problema de audio.
   **`call("nombre")` no comprueba la firma al compilar**: usar la llamada
   directa (`decorador.sitio_del_estanque(x)`) lo habría cantado al validar.

---

## Orden de las próximas sesiones

Una cosa por sesión, cerrada y probada antes de pasar a la siguiente. El motivo
de escribirlo es que cada tema de abajo depende del anterior, y hacerlos a la
vez obliga a rehacer trabajo.

### 1. El sistema de menús
Título, pausa, ajustes y el panel de objetivos —que lleva esperando desde que se
decidió que iría «cuando haya interfaz»—. **Va antes que la música a propósito**:
la música de menú no se puede colocar ni probar sin menú, y la estructura de
pistas depende de cuántas pantallas haya y de cómo se pase de una a otra.

### 2. La banda sonora
Solo cuando 1 esté hecho. Mezcla de piezas libres y generadas con IA, con:

- El esquema de qué suena en cada pantalla y en cada momento del nivel — la
  primera versión está en [`21-SONIDO-Y-MUSICA.md`](21-SONIDO-Y-MUSICA.md) §3.
- Una **serie de prompts** para las generadas, uno por pieza, con el
  instrumento, el ritmo, la duración y el punto de bucle. Igual que se hizo con
  el prompt del guardián: la mitad del prompt son requisitos técnicos, no gustos.
- Qué se busca en bancos libres y qué se genera.

### 3. Rematar el sonido que falta
La lista de ⬜ en [`22-ESTADO-AUDIO.md`](22-ESTADO-AUDIO.md).

### 4. Dar vida al parque
Las zonas vacías y los salientes para trepar de
[`19-ERRORES-TERRENO.md`](19-ERRORES-TERRENO.md).
