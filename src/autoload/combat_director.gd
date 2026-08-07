extends Node
## Reparte "fichas de ataque" entre los enemigos.
##
## Es el sistema que garantiza el pilar de diseño más importante del combate:
## NUNCA más de 3 enemigos atacando a la vez. Los demás rodean al jugador
## esperando turno. Es el patrón clásico del género y es lo que evita que una
## niña de 8 años se vea rodeada y machacada sin poder reaccionar.
##
## Sin esto, ocho enemigos que se acercan a la vez atacan a la vez, y el juego
## pasa de divertido a injusto en un segundo.

signal token_granted(enemy: Node)
signal token_released(enemy: Node)

## Enemigos que pueden atacar simultáneamente. Subir esto es la palanca más
## directa para que el combate se sienta más agobiante.
@export var max_attackers: int = 4

var _holders: Array[int] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Intenta reservar el turno de ataque. Devuelve false si no hay hueco.
func request_token(enemy: Node) -> bool:
	if enemy == null:
		return false
	_purge_invalid()

	var id := enemy.get_instance_id()
	if id in _holders:
		return true
	if _holders.size() >= max_attackers:
		return false

	_holders.append(id)
	token_granted.emit(enemy)
	return true


func release_token(enemy: Node) -> void:
	if enemy == null:
		return
	var id := enemy.get_instance_id()
	if _holders.has(id):
		_holders.erase(id)
		token_released.emit(enemy)


func has_token(enemy: Node) -> bool:
	return enemy != null and enemy.get_instance_id() in _holders


func active_attackers() -> int:
	_purge_invalid()
	return _holders.size()


## Al cambiar de arena o de escena hay que soltar todo.
func reset() -> void:
	_holders.clear()


## Un enemigo purificado o liberado a mitad de ataque dejaría su ficha
## bloqueada para siempre. Esto la recupera.
func _purge_invalid() -> void:
	var alive: Array[int] = []
	for id in _holders:
		var node := instance_from_id(id)
		if node != null and is_instance_valid(node) and node.is_inside_tree():
			alive.append(id)
	_holders = alive
