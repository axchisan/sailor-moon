extends State
## Quieta en el suelo, frenando hasta detenerse.


func enter(_msg: Dictionary = {}) -> void:
	(actor as Player).play("locomocion")


func physics_update(delta: float) -> String:
	var p := actor as Player

	p.apply_gravity(delta)
	p.apply_horizontal_movement(Vector3.ZERO, 0.0, delta)

	if p.wants_special():
		return "Special"
	if p.wants_attack():
		return "Attack"
	if p.wants_jump():
		return "Jump"
	if not p.is_on_floor():
		return "Fall"
	if p.get_move_direction().length_squared() > 0.0001:
		return "Move"

	return ""
