extends State
## Impulso hacia arriba. Salto de altura variable: si se suelta el botón antes
## de llegar arriba, el salto se corta. Da mucho control sin explicar nada.

## Cuánto se recorta la subida al soltar el botón (0 = corte seco, 1 = sin corte).
const RELEASE_DAMPING := 0.45


func enter(_msg: Dictionary = {}) -> void:
	if actor.has_method("sonar_salto"):
		actor.call("sonar_salto")
	var p := actor as Player
	p.play("jump")
	p.do_jump()


func physics_update(delta: float) -> String:
	var p := actor as Player

	if Input.is_action_just_released("jump") and p.velocity.y > 0.0:
		p.velocity.y *= RELEASE_DAMPING

	p.apply_gravity(delta)
	p.apply_horizontal_movement(p.get_move_direction(), p.get_move_strength(), delta, p.air_control)
	p.face_direction(p.get_move_direction(), delta)

	# Atacar en el aire vale: machacar mientras saltas es lo natural a los 8 años.
	if p.wants_attack():
		return "Attack"
	# Y encadenar el segundo salto sin esperar a empezar a caer: pulsando deprisa
	# se sube más, que es lo que uno intenta la primera vez que lo descubre.
	if p.wants_double_jump():
		return "DoubleJump"
	if p.velocity.y <= 0.0:
		return "Fall"

	return ""
