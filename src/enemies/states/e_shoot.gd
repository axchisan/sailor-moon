extends State
## Disparo: la Hadita lanza una esquirla en vez de embestir.
##
## Sustituye al estado Attack en los enemigos a distancia. La FSM es la misma:
## Telegraph sigue transicionando a "Attack", solo cambia el script del nodo.

enum Phase { DISPARO, RECOVERY }

var _phase: int = Phase.DISPARO
var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	var e := actor as Enemy
	_phase = Phase.DISPARO
	_timer = 0.0
	# Se para en seco al disparar: telegrafiar y moverse a la vez confunde
	e.velocity.x = 0.0
	e.velocity.z = 0.0
	e.disparar()


func exit() -> void:
	CombatDirector.release_token(actor as Enemy)


func physics_update(delta: float) -> String:
	var e := actor as Enemy
	var data := e.attack

	e.face_target(delta)
	e.brake(delta, 8.0)
	_timer += delta

	match _phase:
		Phase.DISPARO:
			var activo: float = data.active if data != null else 0.15
			if _timer >= activo:
				_timer -= activo
				_phase = Phase.RECOVERY
		Phase.RECOVERY:
			var recuperacion: float = data.recovery if data != null else 0.8
			if _timer >= recuperacion:
				return "Approach"

	return ""
