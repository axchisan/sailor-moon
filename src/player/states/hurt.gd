extends State
## Reacción al daño: retroceso corto y recuperación rápida.
##
## Deliberadamente breve (0,35 s). Los aturdimientos largos frustran, y el
## pilar del juego es que nunca se pierda de forma frustrante. El castigo real
## es perder una estrella, no perder el control.

const STUN_TIME := 0.35


func enter(msg: Dictionary = {}) -> void:
	var p := actor as Player
	p.play("hurt", STUN_TIME)
	var knockback: Vector3 = msg.get("knockback", Vector3.ZERO)
	var up: float = msg.get("up", 1.0)

	p.velocity.x = knockback.x
	p.velocity.z = knockback.z
	if up > 0.0:
		p.velocity.y = up


func physics_update(delta: float) -> String:
	var p := actor as Player

	p.apply_gravity(delta)
	p.apply_friction(delta)

	# El tiempo transcurrido se mide con la invulnerabilidad, que ya corre en
	# Player: cuando queda menos de (invulnerability_time - STUN_TIME), se sale.
	if p.invuln_timer <= p.invulnerability_time - STUN_TIME:
		if not p.is_on_floor():
			return "Fall"
		if p.get_move_direction().length_squared() > 0.0001:
			return "Move"
		return "Idle"

	return ""
