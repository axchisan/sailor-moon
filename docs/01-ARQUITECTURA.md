# Arquitectura técnica

> Escrito con analogías de backend, que es tu terreno. Godot se parece más a lo que ya conoces de lo que parece.

## 1. Traducción de conceptos

| En backend empresarial | En Godot |
|---|---|
| Singleton / servicio inyectado | **Autoload** (nodo global accesible desde cualquier script) |
| DTO / entidad de datos | **Resource** (`.tres`), serializable, tipado, editable en el inspector |
| Event bus / pub-sub (Kafka, RabbitMQ) | **Signals** + un autoload `EventBus` |
| Módulo / componente reutilizable | **Escena** (`.tscn`) instanciable |
| Interfaz / contrato | Clase base + `class_name`, o duck typing con `has_method()` |
| DI container | Autoloads + `@export` para inyectar dependencias desde el editor |
| Migraciones de BD | Versionado del archivo de guardado (`save_version` en el JSON) |
| Test de integración | Escena de prueba aislada que se ejecuta con F6 |

La diferencia mental grande: en backend el ciclo es *request → response*. En un juego es un bucle a 60 fps donde `_process(delta)` se ejecuta 60 veces por segundo. Todo lo caro (buscar nodos, instanciar, cargar) se hace **fuera** de ese bucle.

## 2. Estructura de carpetas

```
res://
├── addons/                  # plugins (VRM importer, etc.)
├── assets/
│   ├── models/              # .glb importados de Meshy/VRoid/Blender
│   │   ├── characters/
│   │   ├── props/
│   │   └── environment/
│   ├── animations/          # .glb solo con animación (retargeting)
│   ├── textures/
│   ├── materials/           # .tres compartidos (toon base, etc.)
│   ├── audio/
│   │   ├── music/
│   │   ├── sfx/
│   │   └── voice/
│   ├── fonts/
│   └── ui/                  # sprites 2D de HUD y menús
├── src/
│   ├── autoload/            # GameManager, EventBus, SaveManager, AudioManager, SceneLoader
│   ├── core/                # clases base: Actor, Interactable, Collectible, StateMachine
│   ├── player/              # controlador, cámara, estados, transformación
│   ├── enemies/
│   ├── level/               # checkpoints, triggers, puertas, plataformas
│   ├── ui/                  # HUD, menús, controles táctiles
│   └── data/                # Resources: LevelData, SailorData, OutfitData
├── scenes/
│   ├── levels/              # 01_parque.tscn ... 06_torre.tscn
│   ├── ui/
│   └── prototypes/          # greybox y escenas de test
├── shaders/                 # toon.gdshader, outline.gdshader, water, etc.
├── docs/                    # este directorio
└── export/                  # builds generados (en .gitignore)
```

Regla: `assets/` es lo que se importa desde fuera, `src/` es lo que escribes tú, `scenes/` es lo que se ensambla. Nunca mezclar.

## 3. Autoloads (los "servicios")

| Autoload | Responsabilidad | Analogía |
|---|---|---|
| `EventBus` | Solo declara signals. No tiene lógica. Todos publican y se suscriben aquí. | Broker de mensajes |
| `GameManager` | Estado de la partida en memoria: sailor activa, estrellas, chispas, nivel actual | Sesión / contexto de aplicación |
| `SaveManager` | Serializa `GameManager` a JSON en `user://`, con `save_version` para migrar | Repositorio + migraciones |
| `AudioManager` | Buses, música con crossfade, pool de reproductores de SFX | Servicio de infraestructura |
| `SceneLoader` | Cambio de escena asíncrono con pantalla de carga | Router |
| `Settings` | Volumen, idioma, calidad gráfica; persistido aparte | Config |

**Regla de oro:** los sistemas se comunican por `EventBus`, no llamándose directamente. El HUD no conoce al jugador; escucha `EventBus.health_changed`. Esto evita el acoplamiento que en un juego se vuelve inmanejable en dos semanas.

```gdscript
# src/autoload/event_bus.gd
extends Node

signal star_collected(total: int)
signal sparkle_collected(total: int)
signal health_changed(current: int, max: int)
signal special_charge_changed(ratio: float)   # 0.0-1.0, para la barra del HUD
signal special_ready()                        # el botón brilla y suena
signal special_used(sailor_id: String, attack_name: String)
signal combo_hit(index: int)                  # 1, 2 o 3
signal transformation_started(sailor_id: String)
signal transformation_finished(sailor_id: String)
signal enemy_purified(enemy_name: String, total_friends: int)
signal arena_started(arena_id: String, wave_count: int)
signal wave_cleared(wave_index: int)
signal arena_cleared(arena_id: String)
signal checkpoint_reached(position: Vector3)
signal level_completed(level_id: String)
signal request_scene_change(scene_path: String)
```

## 4. Jugador: máquina de estados

El controlador del personaje es lo primero que se descontrola si se escribe como un `if/elif` gigante. Se usa una máquina de estados con un nodo por estado:

```
Player (CharacterBody3D)
├── Model (Node3D)              # malla instanciada; intercambiable civil/sailor
│   └── AnimationTree           # StateMachine de animación + blending
├── CollisionShape3D
├── Hurtbox (Area3D)            # dónde ME pueden golpear
├── Hitbox (Area3D, disabled)   # dónde YO golpeo; lo activa la animación
├── TargetDetector (Area3D)     # cono frontal para la auto-orientación
├── CameraRig (Node3D)
│   └── SpringArm3D → Camera3D
└── StateMachine (Node)
    ├── Idle · Walk · Run
    ├── Jump · Fall · Land
    ├── Attack1 · Attack2 · Attack3   # el combo de 3
    ├── Special
    ├── Hurt · Dizzy
    └── Transform
```

Cada estado es un script con `enter()`, `exit()`, `update(delta)`, `physics_update(delta)` y devuelve el nombre del siguiente estado o `""`. Es el patrón State de toda la vida.

## 5. Arquitectura de combate

El sistema nervioso del juego. Cuatro piezas, deliberadamente pequeñas:

### 5.1 Hitbox / Hurtbox

Dos `Area3D` en capas de colisión distintas. La **hitbox** del jugador está desactivada por defecto y **la activa la propia animación** mediante *call method tracks* del `AnimationPlayer`: en el frame exacto del golpe se llama `enable_hitbox()`, y unos frames después `disable_hitbox()`. Esto es lo que hace que el golpe se sienta sincronizado con lo que se ve, y evita escribir *timers* a mano.

```gdscript
# src/core/hitbox.gd
extends Area3D
class_name Hitbox

@export var damage: int = 1
@export var knockback: float = 4.0
@export var hit_stop: float = 0.06

func _on_area_entered(hurtbox: Area3D) -> void:
    if hurtbox is Hurtbox and hurtbox.owner != owner:
        hurtbox.take_hit(self)
        CombatFeel.impact(global_position, hit_stop)
```

### 5.2 `CombatFeel` (autoload)

Todo el "jugo" centralizado en un único servicio. Un solo sitio que tocar cuando el combate se sienta flojo:

```gdscript
# src/autoload/combat_feel.gd
extends Node

func impact(pos: Vector3, stop: float = 0.06, shake: float = 0.3) -> void:
    hit_stop(stop)
    shake_camera(shake)
    spawn_particles(pos)
    play_hit_sound()

func hit_stop(duration: float) -> void:
    Engine.time_scale = 0.05
    await get_tree().create_timer(duration, true, false, true).timeout
    Engine.time_scale = 1.0
```

> Ojo con el `hit_stop`: el timer debe crearse con `ignore_time_scale = true` (el cuarto parámetro), o se congelará él también y el juego no volverá a la velocidad normal. Es el error clásico.

### 5.3 Sistema de fichas de ataque (*attack tokens*)

Garantiza el pilar de "nunca más de 3 atacando a la vez". El gestor de la arena reparte un número fijo de fichas; un enemigo solo puede entrar a atacar si consigue una y la devuelve al terminar. Los demás orbitan al jugador esperando. Es el patrón estándar del género y es lo que evita que la niña se vea rodeada y machacada.

### 5.4 IA de enemigo

Máquina de estados minúscula: `Idle → Approach → Wait (sin ficha) → Telegraph → Attack → Recover → Stagger → Purified`. Nada de *behavior trees*, nada de navmesh complejo — las arenas son planas y pequeñas, basta con `move_toward` y evitación simple entre enemigos.

## 6. Renderizado — decidido: Mobile

Dispositivo objetivo confirmado: Android moderno (2019+), con Vulkan. Se usa el renderizador **Mobile**, que es [lo recomendado para 3D en Android](https://developer.android.com/games/engines/godot/godot-renderers): forward clustered afinado para GPUs de mosaico (Adreno, Mali, Apple). `Forward+` queda descartado para móvil por diseño.

```ini
[rendering]
renderer/rendering_method="mobile"
renderer/rendering_method.mobile="mobile"
rendering_device/driver.windows="d3d12"
```

Esto nos habilita: iluminación decente, bloom para el brillo mágico, GPUParticles3D para los impactos y la purificación, y toon shading de calidad. Todo lo que el combate necesita para sentirse bien.

Si en el perfilado sobre el dispositivo real el rendimiento no llega, el orden de recorte es: bloom → sombras dinámicas → conteo de partículas → resolución de render (`viewport/scaling_3d_scale` a 0.8).

## 7. Estilo anime: cómo se consigue

No basta con importar un modelo bonito; el look anime viene del shader:

1. **Toon shading:** iluminación en escalones (2–3 bandas) en vez de degradado. Shader propio en `shaders/toon.gdshader` usando `light()` en Godot 4.
2. **Outline:** contorno negro. La técnica barata y compatible con móvil es el *inverted hull*: una segunda malla escalada hacia fuera con las normales invertidas y `cull_front`. Cuesta un draw call extra por personaje, aceptable con 5–8 personajes en pantalla.
3. **Rim light:** brillo suave en los bordes, muy característico del anime.
4. **Sombra propia** (la del rostro) pintada en la textura, no calculada.
5. **Post-proceso:** bloom suave para el brillo mágico. En móvil hay que medirlo, es lo primero que se cae si baja el rendimiento.

Si usamos VRoid Studio para los personajes, el addon **VRM de Godot incluye el shader MToon**, que ya es un toon shader de calidad de producción. Eso nos ahorra escribir el punto 1 y 2 para personajes; el shader propio quedaría para el escenario.

## 8. Presupuesto de rendimiento en Android (objetivo: 60 fps, aceptable 30)

Ajustado al beat 'em up: hasta 8 enemigos simultáneos en arena, más partículas de impacto.

| Recurso | Presupuesto |
|---|---|
| Triángulos en pantalla | < 150.000 |
| Personaje principal | 15–25k tris |
| Enemigo | **3–5k tris** (son muchos a la vez; aquí hay que ser estrictos) |
| Enemigos simultáneos | 8 activos + los purificados como decoración (malla simplificada) |
| Draw calls | < 150 |
| Texturas | 1024² para personajes, 512² para props, comprimidas (ETC2/ASTC) |
| Luces dinámicas | 1 direccional + 2–3 puntuales máximo por escena |
| Sombras | Solo la direccional, resolución baja |
| Materiales únicos | Reutilizar al máximo; atlas para props del escenario |

Las mallas de IA vienen con topología sucia y demasiados triángulos. **Siempre pasan por decimación en Blender antes de entrar al proyecto** — esto está detallado en `02-PIPELINE-ASSETS.md`.

> **Enemigos purificados:** al acumularse decenas por nivel, se sustituyen por una versión de malla reducida sin física ni IA, con animación en bucle. Si aun así pesa, se usa `MultiMeshInstance3D`.

## 9. Guardado

JSON plano en `user://save.json` (en Android va a la carpeta privada de la app). Estructura versionada:

```json
{
  "save_version": 1,
  "level_progress": { "01_parque": { "stars": 3, "sparkles": 47, "friends": 12 } },
  "unlocked_sailors": ["moon", "mars"],
  "unlocked_outfits": ["default", "lazo_rosa"],
  "equipped_outfit": "lazo_rosa",
  "settings": { "music": 0.8, "sfx": 1.0 }
}
```

Guardado automático en checkpoints y al completar nivel. Sin menú de ranuras.

## 10. Control de versiones

El directorio **no es un repositorio git todavía**. Conviene inicializarlo ya: los assets 3D binarios son pesados y sin git no hay forma de volver atrás cuando algo se rompa. Recomendación: `git init` + Git LFS para `*.glb`, `*.png`, `*.ogg`, `*.wav`. El `.gitignore` actual ya excluye `.godot/` y `/android/`, que es lo correcto.
