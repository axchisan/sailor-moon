extends Node
class_name StateMachine
## Máquina de estados genérica. La usan tanto el jugador como los enemigos.
##
## Uso: colgar nodos State como hijos, llamar a `setup(actor)` desde el _ready
## del actor, y delegar `_physics_process` aquí.

signal state_changed(from_state: String, to_state: String)

@export var initial_state: NodePath
@export var debug_log: bool = false

var actor: Node = null
var current: State = null


func setup(p_actor: Node) -> void:
	actor = p_actor

	for child in get_children():
		if child is State:
			child.actor = actor
			child.state_machine = self

	var start: State = null
	if not initial_state.is_empty():
		start = get_node_or_null(initial_state) as State
	if start == null:
		for child in get_children():
			if child is State:
				start = child
				break

	if start == null:
		push_error("StateMachine sin estados válidos: %s" % get_path())
		return

	current = start
	current.enter()


func update(delta: float) -> void:
	if current == null:
		return
	var next := current.update(delta)
	if next != "":
		transition_to(next)


func physics_update(delta: float) -> void:
	if current == null:
		return
	var next := current.physics_update(delta)
	if next != "":
		transition_to(next)


func handle_input(event: InputEvent) -> void:
	if current == null:
		return
	var next := current.handle_input(event)
	if next != "":
		transition_to(next)


## Cuántos cambios de estado se permiten en un mismo fotograma antes de dar por
## hecho que algo se ha enredado.
##
## UN BUCLE DE ESTADOS CUELGA EL JUEGO ENTERO, sin error y sin pantalla: se queda
## congelado y hay que matar el proceso. Pasó con el guardián — un estado devolvía
## su propio nombre cuando no encajaba ningún ataque, así que entraba, preguntaba,
## no encajaba nada y volvía a entrar, todo dentro del mismo fotograma.
##
## Ocho es más de lo que ninguna transición legítima necesita encadenar, y a
## cambio el peor caso pasa de «se cuelga» a «un aviso por consola y sigue
## jugándose». En un juego que va a estar en manos de una niña de ocho años, esa
## diferencia no es un detalle.
const CAMBIOS_POR_FOTOGRAMA := 8

var _cambios: int = 0
var _fotograma: int = -1


func transition_to(state_name: String, msg: Dictionary = {}) -> void:
	var ahora := Engine.get_process_frames()
	if ahora != _fotograma:
		_fotograma = ahora
		_cambios = 0
	_cambios += 1
	if _cambios > CAMBIOS_POR_FOTOGRAMA:
		push_error("[FSM %s] bucle de estados cortado en '%s' (%d cambios en un fotograma)"
			% [get_path(), state_name, _cambios])
		return

	var next := get_node_or_null(NodePath(state_name)) as State
	if next == null:
		push_error("Estado inexistente: '%s' en %s" % [state_name, get_path()])
		return

	var from: String = String(current.name) if current != null else ""
	if current != null:
		current.exit()
	current = next
	current.enter(msg)

	if debug_log:
		var actor_name: String = String(actor.name) if actor != null else "?"
		print("[FSM %s] %s -> %s" % [actor_name, from, state_name])
	state_changed.emit(from, state_name)


func get_state_name() -> String:
	if current == null:
		return ""
	return String(current.name)
