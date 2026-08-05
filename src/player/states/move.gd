extends State
## Desplazamiento por el suelo. Camina o corre según la intensidad del joystick;
## con teclado siempre corre.


func enter(_msg: Dictionary = {}) -> void:
	(actor as Player).play("locomocion")


func physics_update(delta: float) -> String:
	var p := actor as Player
	var direction := p.get_move_direction()
	var strength := p.get_move_strength()

	p.apply_gravity(delta)
	p.apply_horizontal_movement(direction, strength, delta)
	p.face_direction(direction, delta)

	if p.wants_special():
		return "Special"
	if p.wants_attack():
		return "Attack"
	if p.wants_jump():
		return "Jump"
	if not p.is_on_floor():
		return "Fall"
	if direction.length_squared() < 0.0001 and p.get_horizontal_speed() < 0.1:
		return "Idle"

	return ""
