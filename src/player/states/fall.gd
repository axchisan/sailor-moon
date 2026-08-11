extends State
## Caída. Cubre tanto la bajada del salto como salirse de una plataforma.
##
## El "coyote time" se gestiona en Player: durante 0,12 s tras dejar el suelo
## todavía se puede saltar. Es de las cosas que más ayudan a una niña de 8 años
## sin que se note.


## Desde qué velocidad de caída se enseña el aterrizaje. Tiene que coincidir con
## el criterio de `land.gd`; se repite aquí porque los estados no se conocen
## entre sí y no merece la pena una clase global por un número.
const CAIDA_PARA_ATERRIZAR := 9.0


func enter(_msg: Dictionary = {}) -> void:
	(actor as Player).play("fall")


func physics_update(delta: float) -> String:
	var p := actor as Player

	p.apply_gravity(delta)
	p.apply_horizontal_movement(p.get_move_direction(), p.get_move_strength(), delta, p.air_control)
	p.face_direction(p.get_move_direction(), delta)

	if p.wants_attack():
		return "Attack"
	# El salto normal primero: durante el coyote time todavía cuenta como saltar
	# desde el suelo, y gastar ahí el segundo salto sería robárselo.
	if p.wants_jump():
		return "Jump"
	if p.wants_double_jump():
		return "DoubleJump"

	# La cornisa se busca CAYENDO, no subiendo. Mirándola también en la subida,
	# se engancharía en el borde nada más despegar de un saliente bajo y no
	# habría forma de saltar por encima de nada: agarrarse pasaría de ser una
	# ayuda a ser un estorbo.
	if p.velocity.y < 0.0:
		var cornisa := p.buscar_cornisa()
		if not cornisa.is_empty():
			return "LedgeGrab"

	if p.is_on_floor():
		# Aterrizaje solo si se venía cayendo de verdad. Cada bordillo de diez
		# centímetros disparando la animación entera deja al personaje dando
		# respingos por todo el parque.
		if p.caida_al_tocar >= CAIDA_PARA_ATERRIZAR:
			return "Land"
		if p.get_move_direction().length_squared() > 0.0001:
			return "Move"
		return "Idle"

	return ""
