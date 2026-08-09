# ESTADO DEL PROYECTO — empieza por aquí

> **Este es el documento de entrada.** Si eres un agente nuevo o el usuario
> retoma tras un tiempo, lee esto primero y luego el documento específico que
> necesites.
>
> **Última actualización:** 2026-08-09 · Nivel 1 decorado, poblado y
> optimizado. Fases A-D del plan maestro cerradas

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
| **D** | Rendimiento | ✅ primera pasada, medida en el móvil |
| **E** | Movimiento y combate | ⬜ **bloqueada:** faltan animaciones de Mixamo |
| **F** | Conversación viva | ⬜ |
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

1. **Bajar las animaciones de Mixamo** — es lo único que bloquea la Fase E, y
   depende del usuario. Ver [`17-ANIMACIONES.md`](17-ANIMACIONES.md): se sube
   **`Models/rigged_originales/serena_rigged.fbx`** y **no se le hace rig**
2. **Fase E** — salto nuevo, doble salto, trepar cornisas, y que al Cofrecito
   se le pueda pegar por el costado
3. **Fase F** — retratos en el diálogo, animación de hablar, audio de Mercury
4. **Fase G** — menú, guardado, corazones de vida escondidos
5. **Fase H** — cinemática de historieta y narrador
6. **Mapa de escenarios** — el portal ya se abre pero no lleva a ninguna parte

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

---

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
izquierda** en el móvil. Muestra fps, draw calls y triángulos, y **separa
pantalla de sombra** — que es la cifra que importa: el pase de sombra llegó a
costar el triple que la imagen y sumados no se veía (trampa 50).

Medir SIEMPRE en el móvil. En el Mac todo va a 60 fps y el problema no aparece,
y además la pantalla del teléfono es mucho más ancha que un 16:9: ve bastante
más mundo de golpe y sube los draw calls.

### Estado del Nivel 1, medido

| | Antes de optimizar | Ahora |
|---|---|---|
| Triángulos de pantalla | 97.500 | ~82.000 |
| Triángulos de sombra | 260.700 | ~62.000 |
| **Total por fotograma** | **358.200** | **~144.000** |
| Draw calls (móvil) | 156 | ~83 |
| fps en el móvil | 28–35 | por medir |

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
