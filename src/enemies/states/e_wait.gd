extends State
## Orbita alrededor del jugador esperando turno.
##
## Este estado es la mitad visible del sistema de fichas: los enemigos sin
## ficha no se quedan clavados como estatuas, dan vueltas amenazando. Se ve
## intenso pero solo pueden pegar tres a la vez.

var _orbit_dir: float = 1.0
var _retry: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_orbit_dir = 1.0 if randf() < 0.5 else -1.0
	_retry = 0.0


func physics_update(delta: float) -> String:
	var e := actor as Enemy
	e.face_target(delta)

	var to_player := e.direction_to_target()
	var distance := e.distance_to_target()

	# Se mantiene a `wait_distance`: si esta muy cerca retrocede, si lejos avanza.
	var radial := to_player * signf(distance - e.wait_distance)
	var tangent := Vector3(-to_player.z, 0.0, to_player.x) * _orbit_dir
	e.move_towards((radial + tangent * 0.9).normalized(), delta, 0.55)

	_retry += delta
	if _retry >= 0.4:
		_retry = 0.0
		if distance <= e.attack_range + 0.6 and CombatDirector.request_token(e):
			return "Telegraph"

	if distance > e.detection_range:
		return "Idle"

	return ""
