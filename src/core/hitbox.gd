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

	# NO SE GOLPEA A TRAVÉS DE UNA PARED.
	#
	# Las cajas de golpe se tocan por solapamiento, y eso no sabe nada de lo que
	# haya en medio. La barrera de una arena para al guardián pero no paraba los
	# golpes: quedándose fuera del anillo se le remataba sin que pudiera acercarse
	# ni responder. Un jefe al que se mata desde detrás de una valla no es un
	# jefe.
	#
	# El rayo va de cuerpo a cuerpo y solo mira el escenario, así que un enemigo
	# entre medias no tapa a otro — taparse detrás de un compañero es válido,
	# pegar a través de un muro no.
	if _hay_pared_en_medio(hurtbox):
		return

	_already_hit.append(id)
	hurtbox.take_hit(self)
	hit_landed.emit(hurtbox)


func _hay_pared_en_medio(hurtbox: Hurtbox) -> bool:
	var espacio := get_world_3d().direct_space_state
	if espacio == null:
		return false
	var quien: Node3D = source if source != null else self
	# A la altura del pecho: desde los pies el rayo se comería el propio suelo en
	# cualquier cuesta, y no habría golpe que valiera.
	var desde := quien.global_position + Vector3.UP * 1.1
	var hasta := hurtbox.global_position + Vector3.UP * 0.6
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta)
	consulta.collision_mask = 1
	consulta.hit_from_inside = false
	return not espacio.intersect_ray(consulta).is_empty()


## Dirección del retroceso, del atacante hacia el objetivo, sin componente vertical.
func get_knockback_direction(target_position: Vector3) -> Vector3:
	var origin := source.global_position if source != null else global_position
	var direction := target_position - origin
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return Vector3.FORWARD
	return direction.normalized()
