extends State
## El segundo salto, en el aire y con voltereta.
##
## POR QUÉ ESTÁ AQUÍ
##
## Además de que se siente bien —y se siente muy bien—, **abre el diseño del
## nivel**: en cuanto se puede llegar más alto, un saliente deja de ser
## decoración y pasa a ser un sitio donde esconder algo. Las dos Estrellas
## secretas de las plataformas del cruce existen por esto.
##
## CÓMO SE SIENTE
##
## El impulso es algo más corto que el del primer salto. Si fuera igual o mayor,
## el primero sobra: se saltaría siempre a ras de suelo esperando el segundo. Y
## se ANULA la velocidad vertical antes de aplicarlo, así que el segundo salto
## sube lo mismo tanto si se pulsa en lo más alto del primero como si se pulsa
## cayendo a plomo. Sin eso, encadenarlos tarde no levanta del suelo y parece
## que el botón no responde.
##
## La voltereta dura medio segundo y durante ella se sigue teniendo control: una
## acrobacia que bloquea el mando se siente pesada, por vistosa que sea.

## Qué parte del impulso normal tiene el segundo salto.
const FUERZA := 0.85


func enter(_msg: Dictionary = {}) -> void:
	if actor.has_method("sonar_salto"):
		actor.call("sonar_salto")
	var p := actor as Player
	# Se borra lo que hubiera de caída: el segundo salto sube igual se pida
	# arriba del todo o ya cayendo.
	p.velocity.y = 0.0
	p.velocity.y = p.jump_velocity * FUERZA
	p.gasto_doble_salto()
	p.play("double_jump")
	CombatFeel.shake(0.06, 0.03)


func physics_update(delta: float) -> String:
	var p := actor as Player

	# Igual que el primer salto: soltar el botón antes de tiempo lo recorta.
	if Input.is_action_just_released("jump") and p.velocity.y > 0.0:
		p.velocity.y *= 0.45

	p.apply_gravity(delta)
	p.apply_horizontal_movement(p.get_move_direction(), p.get_move_strength(),
		delta, p.air_control)
	p.face_direction(p.get_move_direction(), delta)

	if p.wants_attack():
		return "Attack"
	if p.velocity.y <= 0.0:
		return "Fall"
	return ""
