extends Control
class_name TouchControls
## Joystick virtual + botones grandes.
##
## Traduce el táctil a las MISMAS acciones del InputMap que usa el teclado
## (`move_*`, `attack`, `jump`, `special`). Así todo el código de juego funciona
## igual en móvil y en escritorio sin una sola condición `if es_movil`.
##
## El joystick es "flotante": aparece donde pongas el dedo en la mitad
## izquierda, no en una posición fija. Para una niña de 8 años esto es mucho
## mejor: no tiene que buscar el joystick, el joystick va a ella.

@export var joystick_radius: float = 120.0
@export var deadzone: float = 0.18
## Fracción de pantalla reservada al joystick. El resto es para la cámara.
@export var left_zone_ratio: float = 0.5

@onready var joy_base: Control = %JoyBase
@onready var joy_knob: Control = %JoyKnob
@onready var special_button: Button = %SpecialButton

var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _pressed_actions: Array[String] = []


func _ready() -> void:
	joy_base.visible = false
	_connect_button(%AttackButton, "attack")
	_connect_button(%JumpButton, "jump")
	_connect_button(%SpecialButton, "special")
	EventBus.special_ready.connect(_on_special_ready)
	EventBus.special_used.connect(_on_special_used)
	special_button.modulate = Color(1, 1, 1, 0.45)


func _connect_button(button: Button, action: String) -> void:
	button.button_down.connect(func(): Input.action_press(action))
	button.button_up.connect(func(): Input.action_release(action))


func _exit_tree() -> void:
	_release_all()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and event.position.x <= _left_limit():
				_touch_index = event.index
				_origin = event.position
				_show_joystick(event.position)
				get_viewport().set_input_as_handled()
		elif event.index == _touch_index:
			_release_joystick()
			get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_joystick(event.position)
		get_viewport().set_input_as_handled()


func _left_limit() -> float:
	return get_viewport_rect().size.x * left_zone_ratio


func _show_joystick(position_px: Vector2) -> void:
	joy_base.visible = true
	joy_base.global_position = position_px - joy_base.size * 0.5
	joy_knob.position = (joy_base.size - joy_knob.size) * 0.5


func _update_joystick(position_px: Vector2) -> void:
	var offset := position_px - _origin
	if offset.length() > joystick_radius:
		offset = offset.normalized() * joystick_radius

	joy_knob.position = (joy_base.size - joy_knob.size) * 0.5 + offset

	var value := offset / joystick_radius
	_apply_direction(value)


func _release_joystick() -> void:
	_touch_index = -1
	joy_base.visible = false
	_release_all()


## Reparte el vector del joystick entre las cuatro acciones direccionales,
## conservando la intensidad analógica (caminar despacio o correr).
func _apply_direction(value: Vector2) -> void:
	_press("move_left", maxf(0.0, -value.x))
	_press("move_right", maxf(0.0, value.x))
	_press("move_forward", maxf(0.0, -value.y))
	_press("move_back", maxf(0.0, value.y))


func _press(action: String, strength: float) -> void:
	if strength > deadzone:
		Input.action_press(action, strength)
		if action not in _pressed_actions:
			_pressed_actions.append(action)
	else:
		Input.action_release(action)
		_pressed_actions.erase(action)


func _release_all() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(action)
	_pressed_actions.clear()


func _on_special_ready() -> void:
	special_button.modulate = Color(1, 1, 1, 1)
	var tween := create_tween().set_loops(6)
	tween.tween_property(special_button, "scale", Vector2(1.15, 1.15), 0.25)
	tween.tween_property(special_button, "scale", Vector2.ONE, 0.25)


func _on_special_used(_sailor_id: String, _attack_name: String) -> void:
	special_button.modulate = Color(1, 1, 1, 0.45)
	special_button.scale = Vector2.ONE
