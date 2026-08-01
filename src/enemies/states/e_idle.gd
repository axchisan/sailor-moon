extends State
## Quieto hasta que el jugador entra en su radio de deteccion.


func physics_update(delta: float) -> String:
	var e := actor as Enemy
	e.brake(delta, 12.0)

	if e.distance_to_target() <= e.detection_range:
		return "Approach"
	return ""
