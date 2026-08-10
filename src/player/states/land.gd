extends State
## El golpe de pies contra el suelo, justo al terminar una caída.
##
## POR QUÉ ES UN ESTADO Y NO UN GESTO SUELTO
##
## La animación de aterrizaje estaba en la librería y en la máquina de animación
## desde que se montó el `AnimationTree`, pero **no la pedía nadie**: al tocar
## suelo se pasaba directamente a `Idle` o a `Move`, y el personaje llegaba de
## una caída de cinco metros como si hubiera bajado un escalón. Reproducirla sin
## un estado propio tampoco vale: el `enter()` del estado siguiente pide
## `locomocion` en el mismo fotograma y se la come.
##
## DURA MENOS QUE LA ANIMACIÓN, A PROPÓSITO
##
## La de Mixamo dura más de un segundo, con su agacharse y su recomponerse. Un
## segundo sin control después de cada salto es una eternidad para quien está
## jugando —y este juego es para una niña de ocho años que va a saltar todo el
## rato—. Se acelera para que quepa en `DURACION` y se puede cancelar en cuanto
## haga falta: moverse, saltar otra vez o pegar salen de aquí inmediatamente.
##
## Así el aterrizaje se NOTA sin llegar a estorbar, que es justo lo que se busca.

## Cuánto dura el aterrizaje antes de devolver el control por su cuenta.
const DURACION := 0.22
## Desde qué velocidad de caída merece la pena enseñarlo.
##
## Sin esto, cada bordillo de diez centímetros dispara la animación completa y
## el personaje va dando respingos por todo el parque.
const CAIDA_MINIMA := 9.0

var _tiempo := 0.0


func enter(_msg: Dictionary = {}) -> void:
	var p := actor as Player
	_tiempo = 0.0
	p.velocity.x = 0.0
	p.velocity.z = 0.0
	p.play("land", DURACION)
	# Al llegar aquí la velocidad vertical ya la ha puesto a cero el suelo, así
	# que lo deprisa que se venía cayendo hay que consultarlo en `Player`, que
	# lo guarda justo antes de borrarlo.
	if p.caida_al_tocar > 14.0:
		CombatFeel.shake(0.12, 0.06)


func physics_update(delta: float) -> String:
	var p := actor as Player
	_tiempo += delta

	p.apply_gravity(delta)
	# Se puede corregir la dirección mientras se recompone, pero despacio: es lo
	# que hace que el aterrizaje se sienta como un peso y no como un frenazo.
	p.apply_horizontal_movement(p.get_move_direction(), p.get_move_strength() * 0.45,
		delta, 1.0)

	# Cancelaciones: cualquier cosa que quiera hacer la jugadora manda.
	if p.wants_attack():
		return "Attack"
	if p.wants_jump():
		return "Jump"
	if not p.is_on_floor():
		return "Fall"

	if _tiempo >= DURACION:
		if p.get_move_direction().length_squared() > 0.0001:
			return "Move"
		return "Idle"
	return ""
