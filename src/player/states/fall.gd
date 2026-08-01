extends State
## Caída. Cubre tanto la bajada del salto como salirse de una plataforma.
##
## El "coyote time" se gestiona en Player: durante 0,12 s tras dejar el suelo
## todavía se puede saltar. Es de las cosas que más ayudan a una niña de 8 años
## sin que se note.


func physics_update(delta: float) -> String:
	var p := actor as Player

	p.apply_gravity(delta)
	p.apply_horizontal_movement(p.get_move_direction(), p.get_move_strength(), delta, p.air_control)
	p.face_direction(p.get_move_direction(), delta)

	if p.wants_attack():
		return "Attack"
	if p.wants_jump():
		return "Jump"

	if p.is_on_floor():
		if p.get_move_direction().length_squared() > 0.0001:
			return "Move"
		return "Idle"

	return ""
