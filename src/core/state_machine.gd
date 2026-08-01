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


func transition_to(state_name: String, msg: Dictionary = {}) -> void:
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
