extends Node3D
class_name Projectile
## Proyectil enemigo: la esquirla de espejo que lanza la Hadita.
##
## DISEÑO: es LENTO a propósito. Un proyectil rápido en un juego para una niña
## de 8 años es imposible de esquivar y se percibe como injusto. Este viaja a
## 5 m/s, se ve venir de lejos y se esquiva andando de lado — que es justo la
## lección que enseña este enemigo.
##
## No usa física: se mueve a mano y comprueba el suelo con un rayo. Un
## RigidBody3D para esto sería pagar por nada.

@export var velocidad: float = 5.0
@export var vida: float = 4.0
## Giro sobre sí mismo, solo estético.
@export var giro: float = 4.0

@onready var hitbox: Hitbox = $Hitbox
@onready var visual: Node3D = $Visual

var _direccion: Vector3 = Vector3.FORWARD
var _tiempo: float = 0.0
var _lanzado: bool = false


func _ready() -> void:
	hitbox.hit_landed.connect(_al_impactar)
	set_physics_process(false)


## Lo llama el enemigo al disparar. `origen` evita que se golpee a sí mismo.
func lanzar(direccion: Vector3, origen: Node3D) -> void:
	_direccion = direccion.normalized()
	hitbox.source = origen
	look_at(global_position + _direccion, Vector3.UP)
	hitbox.enable()
	_lanzado = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _lanzado:
		return

	_tiempo += delta
	if _tiempo >= vida:
		_desvanecer()
		return

	var paso := _direccion * velocidad * delta
	# Si va a atravesar una pared o el suelo, revienta ahí
	var espacio := get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(global_position, global_position + paso)
	consulta.collision_mask = 1
	if espacio.intersect_ray(consulta).has("position"):
		_desvanecer()
		return

	global_position += paso
	visual.rotate_y(giro * delta)


func _al_impactar(_hurtbox: Hurtbox) -> void:
	CombatFeel.spawn_impact_particles(global_position, Color(0.9, 0.85, 1.0), 14, 0.9)
	_desvanecer()


func _desvanecer() -> void:
	set_physics_process(false)
	hitbox.disable()
	queue_free()
