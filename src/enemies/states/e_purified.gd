extends State
## Purificado: se queda de adorno dando saltitos. Es un amigo, no un cadaver.
##
## Se sustituira por una malla simplificada cuando haya decenas por nivel
## (ver presupuesto de rendimiento en 01-ARQUITECTURA.md).

var _time: float = 0.0
var _base_y: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	var e := actor as Enemy
	e.purify()

	var knockback: Vector3 = msg.get("knockback", Vector3.ZERO)
	e.velocity.x = knockback.x * 0.5
	e.velocity.z = knockback.z * 0.5
	e.velocity.y = 5.0

	_time = 0.0
	_base_y = e.model.position.y


func physics_update(delta: float) -> String:
	var e := actor as Enemy
	e.brake(delta, 5.0)

	_time += delta
	# Saltitos alegres, desfasados por instancia para que no vayan sincronizados.
	var offset := absf(sin(_time * 4.0 + float(e.get_instance_id() % 100) * 0.1)) * 0.18
	e.model.position.y = _base_y + offset
	e.model.rotation.y += delta * 0.8

	return ""
