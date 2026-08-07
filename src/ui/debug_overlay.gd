extends Label
## Overlay de depuración para las escenas de prueba.
##
## En la Fase 1 lo importante que muestra es `Atacando`: si alguna vez pasa de
## 3, el sistema de fichas está roto y el combate se vuelve injusto.

@export var target_path: NodePath

var _player: Player = null


func _ready() -> void:
	if not target_path.is_empty():
		_player = get_node_or_null(target_path) as Player
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			text = "Sin jugador en la escena"
			return

	var enemies := get_tree().get_nodes_in_group("enemies").size()

	text = "FPS: %d   (%s)\nEstado: %s\nVel H: %.1f m/s\nCombo: %d (%.2fs)\nEspecial: %d%%\nEnemigos: %d\nAtacando: %d / %d" % [
		Engine.get_frames_per_second(),
		RenderingServer.get_current_rendering_method(),
		_player.state_machine.get_state_name(),
		_player.get_horizontal_speed(),
		_player.combo_index,
		_player.combo_timer,
		int(GameManager.get_special_ratio() * 100.0),
		enemies,
		CombatDirector.active_attackers(),
		CombatDirector.max_attackers,
	]
