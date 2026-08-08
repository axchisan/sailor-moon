# ESTADO DEL PROYECTO — empieza por aquí

> **Este es el documento de entrada.** Si eres un agente nuevo o el usuario
> retoma tras un tiempo, lee esto primero y luego el documento específico que
> necesites.
>
> **Última actualización:** 2026-08-07 · Reparto de 11 personajes procesado y
> limpio de objetos añadidos

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
| **Fase 0 — Cimientos** | ✅ **Cerrada.** APK corriendo en el móvil real |
| **Fase 1 — Combate** | ✅ **Cerrada.** Los tres enemigos terminados: Peluchín, Cofrecito y Hadita |
| **Fase 2 — Vertical slice (Nivel 1)** | 🟡 **En curso.** Serena jugable. Reparto de 11 personajes procesado, rigueado y montado con física de pelo. **Falta el escenario del Nivel 1** |
| Fases 3–5 | ⬜ Sin empezar |

### Lo que funciona hoy

Prototipo jugable en `scenes/prototypes/test_combat.tscn` (es la escena
principal del proyecto):

- Movimiento 3D con cámara orbital, *coyote time* y *jump buffer*
- Combo de 3 golpes (daño 1/1/2) con ventana de 0,8 s, encadenable machacando
- Auto-orientación al enemigo más cercano
- Ataque especial con barra de carga, zoom, invulnerabilidad y área amplia
- `CombatFeel`: hit stop, screen shake, partículas, flash y SFX
- Enemigo Peluchín con FSM de 7 estados
- **Sistema de fichas: nunca más de 4 enemigos atacando a la vez** (verificado)
- Enemigos con modelo real, animación procedural y eliminación al derrotarlos
- **Cofrecito con escudo frontal**: hay que rodearlo o romperle la guardia con
  el especial. Oleadas mixtas de los dos arquetipos
- Arena con barrera mágica y oleadas configurables
- HUD por EventBus y controles táctiles (joystick flotante + botones)
- 60 fps con 9 enemigos y partículas
- **Serena como personaje jugable**, con las 15 animaciones de Mixamo, coletas
  con física de inercia y cel shading MToon

### Lo siguiente, en orden

1. ~~Descargar las animaciones~~ ✅ Las 15 descargadas y consolidadas
2. ~~Montar el `AnimationTree`~~ ✅ Verificado a 60 fps con pelo y cel shading
3. ~~Sustituir la cápsula por Serena~~ ✅ **Serena ya es el jugador.**
   Combo verificado con sus animaciones, física de pelo y cel shading, 60 fps
4. ~~Cofrecito~~ ✅ **Terminado.** Escudo frontal de 130°, se rodea o se le
   revienta la guardia con el especial
5. **Mover la activación de la hitbox a *call method tracks* de la animación.**
   Hoy la enciende un temporizador del estado; con la animación real conectaría
   en el frame exacto del impacto
6. **Riguear el reparto en Mixamo.** 6 personajes listos en `Models/mixamo/`.
   Reutilizan la misma AnimationLibrary sin descargar nada
   — ver [`12-REPARTO.md`](12-REPARTO.md)
7. Escenario del Nivel 1 — especificación en [`07-ESCENARIOS.md`](07-ESCENARIOS.md)

---

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
| [`12-REPARTO.md`](12-REPARTO.md) | **Reparto de personajes:** 7 procesados, qué falta por cada uno |
| [`CREDITOS.md`](CREDITOS.md) | Atribuciones de assets |

---

## 4. Mapa del código

38 scripts, 8 escenas. Lo que hay que conocer:

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
src/level/arena.gd     Oleadas y barrera mágica
src/ui/                hud.gd, touch_controls.gd, debug_overlay.gd
src/data/attack_data.gd

tools/blender_preparar_modelo.py   ⭐ Reduce modelos de IA a presupuesto
```

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
26. **Comparar contra el original, no contra el recuerdo.** Hay copia de los FBX
    tal como bajaron de Mixamo en `Models/rigged_originales/` (fuera de git).
    Antes de tocar uno, se restaura desde ahí. *(El FBX original de Uranus se
    perdió por no tener esto todavía.)*

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
| Triángulos en pantalla | < 150.000 |
| Personaje principal | 15–25k tris · textura 2048 |
| Enemigo | 3–5k tris · textura 1024 |
| Enemigos simultáneos | 8 activos |
| Draw calls | < 150 |
| Luces dinámicas | 1 direccional + 2–3 puntuales |

Modelos actuales: los 11 personajes a 25.000 tris · Peluchín, Cofrecito y Hadita
a 5.000 · props de escenario (coral 4.700, bonsái 9.750). ✅

---

## 9. Nota legal

Sailor Moon es propiedad de Naoko Takeuchi / Kodansha / Toei Animation. Regalo
personal, no distribuido ni monetizado. **No publicar en Google Play, itch.io ni
ninguna tienda.** Instalación por sideload en el dispositivo de la prima.
