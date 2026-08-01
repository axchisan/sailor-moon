extends Area3D
class_name Hurtbox
## Zona que RECIBE daño. No decide nada: avisa a su actor y este resuelve.
##
## Mantener la decisión fuera de la hurtbox permite que el jugador y los
## enemigos reaccionen distinto al mismo golpe sin duplicar código de colisión.

signal hit_taken(hitbox: Hitbox)

## Nodo dueño de esta hurtbox (el CharacterBody3D). Si se deja vacío, usa `owner`.
@export var actor_path: NodePath

var _actor: Node3D = null


func _ready() -> void:
	# Diferido por el mismo motivo que en Hitbox: los enemigos se instancian
	# dentro de señales de física y la asignación directa está bloqueada ahí.
	set_deferred("monitoring", false)
	set_deferred("monitorable", true)
	if not actor_path.is_empty():
		_actor = get_node_or_null(actor_path) as Node3D
	if _actor == null:
		_actor = owner as Node3D


func get_actor() -> Node3D:
	return _actor


func take_hit(hitbox: Hitbox) -> void:
	hit_taken.emit(hitbox)
