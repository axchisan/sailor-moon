extends Node
class_name State
## Estado base. Es el patrón State de siempre: cada estado es un nodo hijo de
## un StateMachine y devuelve el nombre del siguiente estado, o "" para seguir.
##
## NOTA: se usa `actor` y no `owner` porque `owner` ya existe en Node (apunta al
## nodo raíz de la escena) y sobreescribirlo rompe cosas de forma sutil.

var actor: Node = null
var state_machine: StateMachine = null


func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> String:
	return ""


func physics_update(_delta: float) -> String:
	return ""


func handle_input(_event: InputEvent) -> String:
	return ""
