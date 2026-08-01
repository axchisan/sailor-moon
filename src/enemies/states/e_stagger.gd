extends State
## Reaccion al golpe: sale despedido y tarda un momento en recomponerse.
##
## Este tiempo es lo que permite encadenar el combo sin que el enemigo
## contraataque en medio. Si se acorta, el combate se vuelve injusto.

const STAGGER_TIME := 0.30

var _timer: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	var e := actor as Enemy
	_timer = 0.0

	var knockback: Vector3 = msg.get("knockback", Vector3.ZERO)
	var up: float = msg.get("up", 0.0)
	e.velocity.x = knockback.x
	e.velocity.z = knockback.z
	if up > 0.0:
		e.velocity.y = up

	e.hitbox.disable()


func physics_update(delta: float) -> String:
	var e := actor as Enemy
	e.brake(delta)

	_timer += delta
	if _timer >= STAGGER_TIME and e.is_on_floor():
		return "Approach"

	return ""
