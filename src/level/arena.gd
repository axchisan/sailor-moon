extends Area3D
class_name Arena
## Arena de combate: se cierra con una barrera mágica, lanza oleadas y se abre
## al limpiarlas.
##
## Es la unidad de contenido del juego. Un nivel es:
##   tramo → arena → tramo → arena → tramo → guardián
##
## Además de ser el formato del género, abarata la producción: las arenas son
## pequeñas y contenidas, no mundos abiertos.

@export var arena_id: String = "arena_1"
## Enemigos por oleada. [2, 3, 4] = tres oleadas de dificultad creciente.
@export var waves: Array[int] = [2, 3, 4]
## Enemigo básico: es el que rellena las oleadas.
@export var enemy_scene: PackedScene
## Enemigos que se mezclan con el básico (Cofrecito, Globito…).
@export var enemy_scenes_extra: Array[PackedScene] = []
## Proporción de enemigos extra dentro de una oleada.
@export_range(0.0, 1.0) var extra_ratio: float = 0.34
## Oleada a partir de la cual aparecen los extra. Con 1, la primera oleada es
## solo del enemigo básico: se aprende a pegar antes de aprender a rodear.
@export var extra_from_wave: int = 1
@export var spawn_radius: float = 7.5
## Pausa entre oleadas para que respire.
@export var wave_delay: float = 1.2

@export_group("Barrera mágica")
@export var barrier_radius: float = 11.0
@export var barrier_height: float = 3.5
## Más segmentos = círculo más redondo y más draw calls. 16 es buen equilibrio.
@export var barrier_segments: int = 16
@export var barrier_color: Color = Color(1.0, 0.55, 0.85, 0.28)

var started: bool = false
var cleared: bool = false

var _wave_index: int = -1
var _spawned: Array[Node] = []
var _delay_timer: float = 0.0
var _waiting: bool = false
var _barrier: Node3D = null


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_barrier()
	_set_barrier(false)
	set_physics_process(false)


## Construye la barrera como un anillo de paneles. Se genera por código porque
## a mano en el .tscn serían 16 nodos duplicados imposibles de reajustar.
func _build_barrier() -> void:
	_barrier = Node3D.new()
	_barrier.name = "Barrier"
	add_child(_barrier)

	var material := StandardMaterial3D.new()
	material.albedo_color = barrier_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = barrier_color
	material.emission_energy_multiplier = 0.6

	var segment_width := TAU * barrier_radius / float(barrier_segments) * 1.08
	var size := Vector3(segment_width, barrier_height, 0.25)

	var mesh := BoxMesh.new()
	mesh.size = size
	var shape := BoxShape3D.new()
	shape.size = size

	for i in barrier_segments:
		var angle := TAU * float(i) / float(barrier_segments)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector3(cos(angle), barrier_height * 0.5, sin(angle)) * \
			Vector3(barrier_radius, 1.0, barrier_radius)
		# Tangente al círculo, no radial: rotando `Y` un ángulo φ el eje Z local
		# va a (sin φ, 0, cos φ), y para que mire al centro hay que igualarlo a
		# la normal (cos θ, 0, sin θ) → φ = 90° − θ. Con `−θ` los paneles
		# quedaban de canto y la barrera se veía como los radios de una rueda.
		body.rotation.y = PI * 0.5 - angle

		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.material_override = material
		body.add_child(visual)

		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)

		_barrier.add_child(body)


func _on_body_entered(body: Node3D) -> void:
	if started or cleared:
		return
	if not body.is_in_group("player"):
		return
	start()


func start() -> void:
	if started:
		return
	started = true
	set_physics_process(true)
	_set_barrier(true)

	GameManager.set_checkpoint(global_position)
	EventBus.arena_started.emit(arena_id, waves.size())
	_next_wave()


func _physics_process(delta: float) -> void:
	if cleared:
		return

	if _waiting:
		_delay_timer -= delta
		if _delay_timer <= 0.0:
			_waiting = false
			_next_wave()
		return

	if _alive_count() > 0:
		return

	EventBus.wave_cleared.emit(_wave_index)

	if _wave_index + 1 >= waves.size():
		_finish()
	else:
		_waiting = true
		_delay_timer = wave_delay


func _next_wave() -> void:
	_wave_index += 1
	if _wave_index >= waves.size():
		_finish()
		return

	var count: int = waves[_wave_index]
	for i in count:
		_spawn_enemy(i, count)


func _spawn_enemy(index: int, total: int) -> void:
	var escena := _elegir_enemigo()
	if escena == null:
		push_error("Arena '%s' sin enemy_scene asignada." % arena_id)
		return

	var enemy := escena.instantiate() as Node3D
	if enemy == null:
		return

	# Repartidos en círculo para que no aparezcan todos amontonados encima
	# del jugador. Aparecer pegado a la cara es lo más injusto que hay.
	var angle := TAU * (float(index) / maxf(1.0, float(total))) + randf() * 0.4
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * spawn_radius
	get_parent().add_child(enemy)
	enemy.global_position = global_position + offset + Vector3.UP * 0.5

	_spawned.append(enemy)


## Mezcla la oleada. Los enemigos extra solo entran a partir de
## `extra_from_wave`, para que cada mecánica nueva llegue de una en una.
func _elegir_enemigo() -> PackedScene:
	if not enemy_scenes_extra.is_empty() and _wave_index >= extra_from_wave:
		if randf() < extra_ratio:
			return enemy_scenes_extra[randi() % enemy_scenes_extra.size()]
	return enemy_scene


func _alive_count() -> int:
	var alive := 0
	var still_valid: Array[Node] = []
	for node in _spawned:
		if node == null or not is_instance_valid(node):
			continue
		still_valid.append(node)
		var enemy := node as Enemy
		if enemy != null and not enemy.defeated:
			alive += 1
	_spawned = still_valid
	return alive


func _finish() -> void:
	cleared = true
	set_physics_process(false)
	_set_barrier(false)
	CombatDirector.reset()
	EventBus.arena_cleared.emit(arena_id)


func _set_barrier(active: bool) -> void:
	if _barrier == null:
		return
	_barrier.visible = active
	for body in _barrier.get_children():
		for child in body.get_children():
			if child is CollisionShape3D:
				child.set_deferred("disabled", not active)
