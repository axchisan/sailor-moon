extends Label
## Overlay de depuración para la escena de pruebas.
##
## Sirve para verificar de un vistazo que la máquina de estados transiciona
## bien y que los FPS aguantan en el móvil. Se quita en las builds finales.

@export var target_path: NodePath

var _player: Player = null


func _ready() -> void:
	if not target_path.is_empty():
		_player = get_node_or_null(target_path) as Player
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player


func _process(_delta: float) -> void:
	if _player == null:
		text = "Sin jugador en la escena"
		return

	var fsm := _player.state_machine
	text = "FPS: %d\nEstado: %s\nVel H: %.2f m/s\nVel Y: %.2f\nEn suelo: %s\nRenderizador: %s" % [
		Engine.get_frames_per_second(),
		fsm.get_state_name(),
		_player.get_horizontal_speed(),
		_player.velocity.y,
		"si" if _player.is_on_floor() else "no",
		RenderingServer.get_current_rendering_method(),
	]
