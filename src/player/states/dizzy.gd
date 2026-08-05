extends State
## "Mareada": lo que pasa en vez de morir.
##
## No hay game over. Se pierden estrellas, se reaparece en el mismo sitio con
## la salud llena y se vuelve a intentar el combate. Nunca se repite el nivel.
##
## Este estado es la traducción directa del primer pilar de diseño.

const DIZZY_TIME := 1.6

var _timer: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	var p := actor as Player
	p.play("dizzy", DIZZY_TIME)
	_timer = 0.0

	var knockback: Vector3 = msg.get("knockback", Vector3.ZERO)
	p.velocity.x = knockback.x
	p.velocity.z = knockback.z
	p.velocity.y = 4.0

	EventBus.player_died.emit()
	# Se pierden algunas chispas, no progreso.
	GameManager.sparkles_this_level = maxi(0, GameManager.sparkles_this_level - 5)
	EventBus.sparkle_collected.emit(GameManager.sparkles_this_level)


func physics_update(delta: float) -> String:
	var p := actor as Player

	p.apply_gravity(delta)
	p.apply_friction(delta, 6.0)

	_timer += delta
	if _timer >= DIZZY_TIME:
		p.respawn()
		return "Idle"

	return ""
