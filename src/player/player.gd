extends CharacterBody3D
class_name Player
## Controlador del jugador.
##
## El cuerpo NUNCA rota: rota solo el nodo `Model`. Así la cámara (hija) y las
## futuras hitbox conservan un marco de referencia estable.
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

@onready var model: Node3D = $Model
@onready var camera_rig: CameraRig = $CameraRig
@onready var state_machine: StateMachine = $StateMachine

var jump_velocity: float = 0.0
var jump_gravity: float = 0.0
var fall_gravity: float = 0.0

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = true


func _ready() -> void:
	add_to_group("player")
	_recalculate_jump()
	state_machine.setup(self)


func _recalculate_jump() -> void:
	jump_velocity = (2.0 * jump_height) / jump_time_to_peak
	jump_gravity = (-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)
	fall_gravity = (-2.0 * jump_height) / (jump_time_to_fall * jump_time_to_fall)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	state_machine.physics_update(delta)
	move_and_slide()
	_was_on_floor = is_on_floor()


func _tick_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)


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


func just_landed() -> bool:
	return is_on_floor() and not _was_on_floor


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


## Gira el modelo hacia la dirección de avance. El modelo mira hacia -Z.
func face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, rotation_speed * delta)


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()
