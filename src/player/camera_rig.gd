extends Node3D
class_name CameraRig
## Cámara orbital en tercera persona.
##
## SpringArm3D empuja la cámara hacia atrás y la acerca automáticamente cuando
## hay una pared en medio; sin él, la cámara atraviesa la geometría.
##
## En táctil solo rota si el dedo empieza en la MITAD DERECHA de la pantalla:
## la izquierda queda reservada para el joystick virtual (Fase 1).

@export_group("Sensibilidad")
@export var mouse_sensitivity: float = 0.0025
@export var stick_sensitivity: float = 2.8
@export var touch_sensitivity: float = 0.004

@export_group("Límites")
@export var min_pitch: float = -55.0
@export var max_pitch: float = 25.0

@export_group("Encuadre")
@export var distance: float = 5.0
@export var fov: float = 70.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var _yaw: float = 0.0
var _pitch: float = -15.0
var _looking_with_mouse: bool = false

# Sacudida de cámara, alimentada por CombatFeel
var _shake_strength: float = 0.0
var _shake_duration: float = 0.0
var _shake_elapsed: float = 0.0


func _ready() -> void:
	spring_arm.spring_length = distance
	camera.fov = fov
	_pitch = rad_to_deg(spring_arm.rotation.x)
	_yaw = rotation.y
	CombatFeel.shake_requested.connect(_on_shake_requested)


func _unhandled_input(event: InputEvent) -> void:
	# Ratón: se mira manteniendo el botón derecho. Así el izquierdo queda libre.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_looking_with_mouse = event.pressed

	elif event is InputEventMouseMotion and _looking_with_mouse:
		_add_look(-event.relative.x * mouse_sensitivity, -event.relative.y * mouse_sensitivity)

	elif event is InputEventScreenDrag:
		if event.position.x > get_viewport().get_visible_rect().size.x * 0.5:
			_add_look(-event.relative.x * touch_sensitivity, -event.relative.y * touch_sensitivity)


func _process(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length_squared() > 0.0001:
		var sens := stick_sensitivity * Settings.camera_sensitivity * delta
		_add_look(-look.x * sens, -look.y * sens)

	_update_shake(delta)


func _add_look(delta_yaw: float, delta_pitch: float) -> void:
	_yaw += delta_yaw
	_pitch = clampf(_pitch + rad_to_deg(delta_pitch), min_pitch, max_pitch)
	rotation.y = _yaw
	spring_arm.rotation.x = deg_to_rad(_pitch)


# --- Sacudida ----------------------------------------------------------------

func _on_shake_requested(strength: float, duration: float) -> void:
	# Una sacudida nueva no interrumpe a otra más fuerte todavía en curso.
	if strength < _shake_strength and _shake_elapsed < _shake_duration:
		return
	_shake_strength = strength
	_shake_duration = duration
	_shake_elapsed = 0.0


## La sacudida se aplica con `h_offset` / `v_offset`, NUNCA con `position`.
##
## SpringArm3D coloca a sus hijos moviéndoles la `position` en cada frame de
## física. Si aquí se tocara `position`, este `_process` la pisaría y la cámara
## se quedaría clavada en el origen del brazo, es decir, dentro del personaje.
## Los offsets desplazan la vista sin tocar la transformación del nodo.
func _update_shake(delta: float) -> void:
	if _shake_elapsed >= _shake_duration:
		if not is_zero_approx(camera.h_offset) or not is_zero_approx(camera.v_offset):
			camera.h_offset = 0.0
			camera.v_offset = 0.0
		return

	_shake_elapsed += delta
	var falloff := 1.0 - (_shake_elapsed / _shake_duration)
	var amount := _shake_strength * falloff * falloff
	camera.h_offset = randf_range(-amount, amount)
	camera.v_offset = randf_range(-amount, amount)


# --- API ---------------------------------------------------------------------

## Base de la cámara en espacio de mundo. El jugador la usa para moverse
## en relación a lo que ve, que es lo que espera cualquier jugador.
func get_camera_basis() -> Basis:
	return camera.global_transform.basis


## Acercón rápido de cámara. Se usa en el ataque especial: acercarse y volver
## convierte un ataque normal en un momento.
func zoom_punch(amount: float = 1.8, duration: float = 0.18) -> void:
	var tween := create_tween()
	tween.tween_property(spring_arm, "spring_length", maxf(1.5, distance - amount), duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.5)
	tween.tween_property(spring_arm, "spring_length", distance, 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
