extends State
## Anticipacion: brilla en rojo y se para antes de pegar.
##
## Dura lo que diga `attack.windup` (1,2 s por defecto). Es la regla de
## compasion mas importante del combate: nunca pega sin avisar.

var _timer: float = 0.0
var _duration: float = 1.2


func enter(_msg: Dictionary = {}) -> void:
	var e := actor as Enemy
	_timer = 0.0
	_duration = e.attack.windup if e.attack != null else 1.2


func exit() -> void:
	var e := actor as Enemy
	e.reset_color()


func physics_update(delta: float) -> String:
	var e := actor as Enemy

	e.face_target(delta)
	e.brake(delta, 10.0)

	_timer += delta
	e.set_telegraph_pulse(_timer / maxf(_duration, 0.01))

	if _timer >= _duration:
		return "Attack"

	# Si el jugador se aleja mucho, cancela y suelta la ficha.
	if e.distance_to_target() > e.attack_range * 2.5:
		CombatDirector.release_token(e)
		return "Approach"

	return ""
