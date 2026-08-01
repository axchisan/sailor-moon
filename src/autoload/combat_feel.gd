extends Node
## Todo el "jugo" del combate centralizado en un único servicio.
##
## Cuando el combate se sienta flojo, este es el ÚNICO archivo que hay que tocar.
## En un beat 'em up, esto importa más que cualquier sistema: un golpe con hit
## stop, sacudida y partículas se siente diez veces mejor que uno sin ellos,
## aunque el daño sea idéntico.

signal shake_requested(strength: float, duration: float)

## Presets de impacto por tipo de golpe.
const IMPACT_LIGHT := {"stop": 0.04, "shake": 0.15, "shake_time": 0.12}
const IMPACT_MEDIUM := {"stop": 0.06, "shake": 0.25, "shake_time": 0.18}
const IMPACT_HEAVY := {"stop": 0.10, "shake": 0.50, "shake_time": 0.30}
const IMPACT_SPECIAL := {"stop": 0.18, "shake": 0.80, "shake_time": 0.50}

var _hit_stop_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Punto de entrada único: un impacto completo.
func impact(world_position: Vector3, preset: Dictionary = IMPACT_MEDIUM) -> void:
	hit_stop(preset.get("stop", 0.06))
	shake(preset.get("shake", 0.25), preset.get("shake_time", 0.18))
	spawn_impact_particles(world_position)


## Congela el juego un instante al conectar el golpe.
## Es el truco de game feel más potente que existe y el más barato.
func hit_stop(duration: float) -> void:
	if duration <= 0.0 or _hit_stop_active:
		return
	_hit_stop_active = true
	Engine.time_scale = 0.05
	# ¡OJO! El cuarto parámetro (ignore_time_scale) DEBE ser true.
	# Si no, el timer se congela con el juego y nunca vuelve la velocidad normal.
	# Es el error clásico al implementar hit stop.
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stop_active = false


## La cámara escucha esta señal. CombatFeel no conoce a la cámara.
func shake(strength: float, duration: float) -> void:
	if strength <= 0.0:
		return
	shake_requested.emit(strength, duration)


## TODO (Fase 1): instanciar la escena de partículas de estrellas y corazones.
func spawn_impact_particles(_world_position: Vector3) -> void:
	pass


## TODO (Fase 1): parpadeo blanco sobre el material del enemigo golpeado.
func flash(target: Node3D, duration: float = 0.08) -> void:
	if target == null:
		return
	await get_tree().create_timer(duration, true, false, true).timeout


## Utilidad para pruebas: desactiva todo el jugo y compara.
## Sirve para comprobar cuánto está aportando realmente cada efecto.
func set_juice_enabled(enabled: bool) -> void:
	set_process(enabled)
	if not enabled:
		Engine.time_scale = 1.0
