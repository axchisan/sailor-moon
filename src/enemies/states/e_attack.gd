extends State
## Embestida: hitbox activa mientras avanza, luego recuperacion.

enum Phase { ACTIVE, RECOVERY }

var _phase: int = Phase.ACTIVE
var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	var e := actor as Enemy
	_phase = Phase.ACTIVE
	_timer = 0.0

	e.hitbox.enable(e.attack)

	var lunge: float = e.attack.lunge if e.attack != null else 3.0
	var forward := e.get_forward()
	e.velocity.x = forward.x * lunge
	e.velocity.z = forward.z * lunge


func exit() -> void:
	var e := actor as Enemy
	e.hitbox.disable()
	CombatDirector.release_token(e)


func physics_update(delta: float) -> String:
	var e := actor as Enemy
	var data := e.attack

	e.brake(delta, 7.0)
	_timer += delta

	match _phase:
		Phase.ACTIVE:
			var active: float = data.active if data != null else 0.18
			if _timer >= active:
				_timer -= active
				_phase = Phase.RECOVERY
				e.hitbox.disable()
		Phase.RECOVERY:
			var recovery: float = data.recovery if data != null else 0.7
			if _timer >= recovery:
				return "Approach"

	return ""
