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
			return _que_ataque(e)
		return ""

	e.move_towards(e.direction_to_target(), delta)

	if distance <= e.alcance_de_ataque():
		if CombatDirector.request_token(e):
			return _que_ataque(e)
		return "Wait"

	return ""


## El jefe elige entre su golpe normal y el del suelo; los demás enemigos no
## tienen dónde elegir y van siempre al mismo.
func _que_ataque(e: Enemy) -> String:
	if e.has_method("siguiente_ataque"):
		# Puede devolver "" si a esta distancia no le sirve ningún ataque; "" en
		# la máquina de estados significa «sigue como estás», que es justo lo que
		# hay que hacer.
		return str(e.call("siguiente_ataque"))
	return "Telegraph"
