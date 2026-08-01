extends Area3D
class_name Hitbox
## Zona que HACE daño. Apagada por defecto; la enciende el estado de ataque
## durante la fase `active`, y más adelante lo hará la propia animación.
##
## Lleva su propia lista de "ya golpeados" para que un mismo golpe no impacte
## dos veces al mismo enemigo mientras la hitbox está encendida.

signal hit_landed(hurtbox: Hurtbox)

@export var attack: AttackData

## Quién lanza el golpe. Se usa para calcular la dirección del retroceso y para
## no golpearse a uno mismo.
var source: Node3D = null

var _already_hit: Array[int] = []


func _ready() -> void:
	# Diferido: si la hitbox se instancia dentro de una señal de física (un
	# enemigo que aparece desde `body_entered`), Godot bloquea la asignación
	# directa y suelta "Function blocked during in/out signal".
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	area_entered.connect(_on_area_entered)
	if source == null:
		source = owner as Node3D


func enable(new_attack: AttackData = null) -> void:
	if new_attack != null:
		attack = new_attack
	_already_hit.clear()
	# Diferido: cambiar `monitoring` dentro de una llamada de física
	# lanza un error de Godot si se hace directamente.
	set_deferred("monitoring", true)


func disable() -> void:
	set_deferred("monitoring", false)
	_already_hit.clear()


func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null:
		return
	if hurtbox.get_actor() == source:
		return
	var id := hurtbox.get_instance_id()
	if id in _already_hit:
		return
	_already_hit.append(id)

	hurtbox.take_hit(self)
	hit_landed.emit(hurtbox)


## Dirección del retroceso, del atacante hacia el objetivo, sin componente vertical.
func get_knockback_direction(target_position: Vector3) -> Vector3:
	var origin := source.global_position if source != null else global_position
	var direction := target_position - origin
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return Vector3.FORWARD
	return direction.normalized()
