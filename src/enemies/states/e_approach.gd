extends State
## Se acerca al jugador. Al entrar en rango pide su ficha de ataque:
## si la consigue avisa y golpea, si no se va a esperar su turno.


func physics_update(delta: float) -> String:
	var e := actor as Enemy
	var distance := e.distance_to_target()

	if distance > e.detection_range:
		return "Idle"

	e.face_target(delta)

	# Los enemigos a distancia retroceden si te pegas a ellos: obligan a
	# perseguirlos y rompen la monotonia de quedarse machacando el boton.
	if e.huir_si_esta_cerca(delta):
		if CombatDirector.request_token(e):
			return "Telegraph"
		return ""

	e.move_towards(e.direction_to_target(), delta)

	if distance <= e.attack_range:
		if CombatDirector.request_token(e):
			return "Telegraph"
		return "Wait"

	return ""
