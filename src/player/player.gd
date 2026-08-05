extends CharacterBody3D
class_name Player
## Controlador del jugador.
##
## El cuerpo NUNCA rota: rota solo el nodo `Model`. Así la cámara (hija) y la
## hitbox conservan un marco de referencia estable.
##
## El salto se parametriza en términos de diseño (altura y tiempos) en vez de
## gravedad y velocidad. Es mucho más fácil de ajustar: "quiero que salte 1,4 m
## y tarde 0,38 s en llegar arriba" en lugar de tocar números a ciegas.

@export_group("Movimiento")
@export var walk_speed: float = 2.6
@export var run_speed: float = 6.5
@export var acceleration: float = 22.0
@export var deceleration: float = 28.0
@export var air_control: float = 0.45
@export var rotation_speed: float = 14.0

@export_group("Salto")
@export var jump_height: float = 1.4
@export var jump_time_to_peak: float = 0.38
@export var jump_time_to_fall: float = 0.30
## Margen para saltar justo después de salirse de la plataforma.
@export var coyote_time: float = 0.12
## Margen para que el salto pulsado un poco antes de aterrizar cuente igual.
@export var jump_buffer_time: float = 0.15
@export var max_fall_speed: float = 20.0

@export_group("Combate")
@export var combo_attacks: Array[AttackData] = []
@export var special_attack: AttackData
## Ventana para encadenar el siguiente golpe. Deliberadamente enorme: a los
## 8 años el ritmo no es fiable y el combo debe salir SIEMPRE que se machaque.
@export var combo_window: float = 0.8
## Radio de búsqueda para la auto-orientación al atacar.
@export var target_range: float = 4.5
@export var invulnerability_time: float = 1.5
@export var knockback_friction: float = 9.0

@onready var model: Node3D = $Model
## Puede ser null: el prototipo de cápsula no tiene malla de personaje.
@onready var mesh: MeshInstance3D = get_node_or_null("Model/Body")
## Animador y pelo son opcionales para que la escena de cápsulas siga viva.
@onready var animator: CharacterAnimator = get_node_or_null("Model/Animador")
@onready var hair: HairPhysics = get_node_or_null("Model/Animador/Fisica")
@onready var camera_rig: CameraRig = $CameraRig
@onready var state_machine: StateMachine = $StateMachine
@onready var hitbox: Hitbox = $Model/Hitbox
@onready var special_hitbox: Hitbox = $SpecialHitbox
@onready var hurtbox: Hurtbox = $Hurtbox

var jump_velocity: float = 0.0
var jump_gravity: float = 0.0
var fall_gravity: float = 0.0

## Índice del último golpe conectado del combo (0 = sin combo activo).
var combo_index: int = 0
var combo_timer: float = 0.0
var invuln_timer: float = 0.0

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = true


## Ataques por defecto. Se cargan solo si no se han asignado en el inspector,
## así la escena no depende de referencias serializadas y sigue siendo
## editable desde el editor.
const DEFAULT_COMBO := [
	"res://assets/data/attacks/combo_1.tres",
	"res://assets/data/attacks/combo_2.tres",
	"res://assets/data/attacks/combo_3.tres",
]
const DEFAULT_SPECIAL := "res://assets/data/attacks/special.tres"


func _ready() -> void:
	add_to_group("player")
	_load_default_attacks()
	_recalculate_jump()

	hitbox.source = self
	special_hitbox.source = self
	# Solo el combo normal carga la barra. Si el especial se cargara a sí mismo,
	# en una oleada grande golpearía a 6 enemigos, recuperaría media barra y
	# sería encadenable casi sin límite. Siendo además invulnerable mientras
	# dura, eso convertiría el combate en pulsar un botón.
	hitbox.hit_landed.connect(_on_hit_landed)
	hurtbox.hit_taken.connect(_on_hurtbox_hit)

	# Material propio para poder parpadear sin afectar a otros nodos.
	if mesh != null:
		var material := mesh.get_active_material(0)
		if material != null:
			mesh.set_surface_override_material(0, material.duplicate())

	state_machine.setup(self)
	GameManager.reset_health()


func _load_default_attacks() -> void:
	if combo_attacks.is_empty():
		for path in DEFAULT_COMBO:
			var data := load(path) as AttackData
			if data != null:
				combo_attacks.append(data)
	if special_attack == null:
		special_attack = load(DEFAULT_SPECIAL) as AttackData


func _recalculate_jump() -> void:
	jump_velocity = (2.0 * jump_height) / jump_time_to_peak
	jump_gravity = (-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)
	fall_gravity = (-2.0 * jump_height) / (jump_time_to_fall * jump_time_to_fall)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	state_machine.physics_update(delta)
	move_and_slide()
	_was_on_floor = is_on_floor()

	if animator != null:
		animator.set_locomotion_speed(get_horizontal_speed())


## Pide una animación. `duracion` la encaja en el tiempo que dicta el combate;
## 0 la deja a velocidad natural. Segura si no hay animador (prototipo gris).
func play(estado: String, duracion: float = 0.0) -> void:
	if animator != null:
		animator.travel(estado, duracion)


func _tick_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)

	if combo_timer > 0.0:
		combo_timer = maxf(0.0, combo_timer - delta)
		if combo_timer == 0.0:
			combo_index = 0

	if invuln_timer > 0.0:
		invuln_timer = maxf(0.0, invuln_timer - delta)
		_update_blink()


# --- Entrada ------------------------------------------------------------------

## Dirección de movimiento en espacio de mundo, relativa a la cámara. Normalizada.
func get_move_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.length_squared() < 0.0001:
		return Vector3.ZERO

	var cam_basis := camera_rig.get_camera_basis()
	var direction := cam_basis.z * input.y + cam_basis.x * input.x
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return Vector3.ZERO
	return direction.normalized()


## Intensidad del joystick, 0.0 - 1.0. Con teclado siempre es 1.0.
func get_move_strength() -> float:
	return minf(Input.get_vector("move_left", "move_right", "move_forward", "move_back").length(), 1.0)


func wants_jump() -> bool:
	return _jump_buffer_timer > 0.0 and _coyote_timer > 0.0


func consume_jump() -> void:
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0


func wants_attack() -> bool:
	return Input.is_action_just_pressed("attack")


func wants_special() -> bool:
	return Input.is_action_just_pressed("special") and GameManager.is_special_ready()


func just_landed() -> bool:
	return is_on_floor() and not _was_on_floor


# --- Combo -------------------------------------------------------------------

## Devuelve el índice del siguiente golpe (1..N) y reinicia la ventana.
func advance_combo() -> int:
	combo_index = combo_index + 1
	if combo_index > combo_attacks.size():
		combo_index = 1
	combo_timer = combo_window
	return combo_index


func get_attack(index: int) -> AttackData:
	if combo_attacks.is_empty():
		return null
	return combo_attacks[clampi(index - 1, 0, combo_attacks.size() - 1)]


func is_last_combo_hit(index: int) -> bool:
	return index >= combo_attacks.size()


func reset_combo() -> void:
	combo_index = 0
	combo_timer = 0.0


# --- Puntería asistida -------------------------------------------------------

## Busca el mejor objetivo cercano. NO usa un cono estricto: puntúa por
## distancia y ángulo, de modo que siempre prefiere lo que tienes delante pero
## nunca te deja golpear al aire por estar 5 grados desviada.
##
## Sin esto un beat 'em up en 3D es injugable con joystick virtual. Es la
## barrera número uno para una niña de 8 años.
func get_attack_target() -> Node3D:
	var facing := -model.global_transform.basis.z
	var input_dir := get_move_direction()
	var aim := input_dir if input_dir.length_squared() > 0.01 else facing

	var best: Node3D = null
	var best_score := INF

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue

		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0.0
		var distance := to_enemy.length()
		if distance > target_range:
			continue

		var angle := 0.0
		if distance > 0.05:
			angle = aim.angle_to(to_enemy / distance)
		# El ángulo penaliza, pero no descarta: mejor pegarle a algo que fallar.
		var score := distance + angle * 1.6
		if score < best_score:
			best_score = score
			best = enemy

	return best


## Gira el modelo de golpe hacia un punto. Instantáneo a propósito: al atacar,
## la respuesta inmediata se siente mucho mejor que una interpolación.
func snap_face_to(target_position: Vector3) -> void:
	var direction := target_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	model.rotation.y = atan2(-direction.x, -direction.z)


# --- Física -------------------------------------------------------------------

func apply_gravity(delta: float) -> void:
	var g := jump_gravity if velocity.y > 0.0 else fall_gravity
	velocity.y = maxf(velocity.y + g * delta, -max_fall_speed)


func do_jump() -> void:
	velocity.y = jump_velocity
	consume_jump()


## Acelera hacia la dirección pedida. `control` reduce la maniobrabilidad en el aire.
func apply_horizontal_movement(direction: Vector3, strength: float, delta: float, control: float = 1.0) -> void:
	var target := Vector3.ZERO
	var rate := deceleration

	if direction.length_squared() > 0.0001:
		var speed := lerpf(walk_speed, run_speed, strength)
		target = direction * speed
		rate = acceleration

	rate *= control
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)


## Frenado libre, para estados que no aceptan entrada (ataque, daño).
func apply_friction(delta: float, rate: float = -1.0) -> void:
	var f := knockback_friction if rate < 0.0 else rate
	velocity.x = move_toward(velocity.x, 0.0, f * delta)
	velocity.z = move_toward(velocity.z, 0.0, f * delta)


## Gira el modelo hacia la dirección de avance. El modelo mira hacia -Z.
func face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, rotation_speed * delta)


func get_forward() -> Vector3:
	return -model.global_transform.basis.z


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


# --- Daño --------------------------------------------------------------------

func is_invulnerable() -> bool:
	return invuln_timer > 0.0


func _on_hurtbox_hit(enemy_hitbox: Hitbox) -> void:
	if is_invulnerable() or GameManager.health <= 0:
		return

	var attack := enemy_hitbox.attack
	var damage := attack.damage if attack != null else 1
	var knockback := attack.knockback if attack != null else 5.0
	var knockback_up := attack.knockback_up if attack != null else 1.0

	GameManager.take_damage(damage)
	CombatFeel.player_hurt(global_position + Vector3.UP)

	var direction := enemy_hitbox.get_knockback_direction(global_position)
	invuln_timer = invulnerability_time
	reset_combo()

	if GameManager.health <= 0:
		state_machine.transition_to("Dizzy", {"knockback": direction * knockback, "up": knockback_up})
	else:
		state_machine.transition_to("Hurt", {"knockback": direction * knockback, "up": knockback_up})


## Cada golpe conectado carga la barra del especial.
func _on_hit_landed(_hurtbox: Hurtbox) -> void:
	GameManager.add_special_charge(1)


## Reaparición sin castigo: misma arena, salud llena. Nunca se pierde progreso.
func respawn() -> void:
	var point := GameManager.last_checkpoint
	if point != Vector3.ZERO:
		global_position = point
	velocity = Vector3.ZERO
	invuln_timer = invulnerability_time
	GameManager.reset_health()
	# Sin esto el pelo sale disparado por la inercia acumulada antes del salto.
	if hair != null:
		hair.reset()
	EventBus.player_respawned.emit(global_position)


## Parpadeo de invulnerabilidad. Con el modelo real no hay una sola malla que
## esconder, así que se parpadea el nodo entero.
func _update_blink() -> void:
	var objetivo: Node3D = mesh if mesh != null else model
	if objetivo == null:
		return
	if invuln_timer <= 0.0:
		objetivo.visible = true
		return
	# Parpadeo a ~12 Hz mientras dura la invulnerabilidad.
	objetivo.visible = fmod(invuln_timer, 0.16) > 0.08
