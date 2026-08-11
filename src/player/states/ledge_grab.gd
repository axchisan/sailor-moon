extends State
## Colgada del canto de una cornisa, esperando a que se decida qué hacer.
##
## POR QUÉ SE PARA DEL TODO
##
## Al agarrarse se anula la velocidad y se apaga la gravedad: la jugadora se
## queda quieta, colgando. Eso da el respiro que hace que trepar se entienda —
## si subiera de golpe, sería un salto más alto y no se leería como agarrarse a
## nada.
##
## Y aquí no hay prisa: no se cae sola, no hay temporizador. A los ocho años,
## descubrir que te has agarrado a un borde y decidir qué hacer lleva su tiempo.
##
## LAS DOS SALIDAS
##
##   `jump`         → sube (`LedgeClimb`)
##   ir hacia atrás → se suelta y cae
##
## Se suelta yendo hacia atrás en vez de con un botón propio porque no hay más
## botones: el móvil tiene joystick, salto y golpe, y no cabe uno de «soltar».
## Tirar del joystick hacia el lado contrario de la pared es lo que se intenta
## de forma natural cuando uno quiere bajarse.

## Cuánto hay que empujar hacia atrás para soltarse. Alto a propósito: con un
## roce se soltaría sin querer al intentar orientarse.
const SOLTARSE := 0.55
## A qué distancia del canto se queda colgada, hacia dentro de la pared.
const AGARRE_FONDO := 0.42
## Cuánto por debajo del canto quedan los pies.
const AGARRE_ALTO := 1.55

var _canto := Vector3.ZERO
var _normal := Vector3.FORWARD


func enter(msg: Dictionary = {}) -> void:
	var p := actor as Player
	# La cornisa se vuelve a buscar aquí en vez de recibirla en el mensaje: la
	# máquina de estados transiciona por nombre y no lleva datos, y en el mismo
	# fotograma en que se decidió entrar el personaje sigue exactamente donde
	# estaba, así que la respuesta es la misma. Pasarla por el mensaje obligaría
	# a que todo el que quiera mandar aquí sepa cómo se busca una cornisa.
	var cornisa: Dictionary = msg if msg.has("borde") else p.buscar_cornisa()
	if cornisa.is_empty():
		# Se escapó entre la comprobación y la entrada. Mejor caer que quedarse
		# colgada de la nada.
		_canto = p.global_position
		_normal = -p.global_transform.basis.z
		return
	_canto = cornisa["borde"]
	_normal = cornisa["normal"]

	# Quieta y sin gravedad: de esto se sale por decisión, no por caerse.
	p.velocity = Vector3.ZERO
	# Y se olvida la caída con la que se llegó. Si no, al llegar arriba el juego
	# cree que se viene de un porrazo de cuatro metros y saca el aterrizaje
	# completo después de haber trepado tan tranquilamente.
	p.caida_maxima = 0.0
	p.caida_al_tocar = 0.0
	# Colgada del canto: un poco por debajo y separada de la pared, para que las
	# manos caigan sobre el borde y el cuerpo no atraviese el muro.
	p.global_position = Vector3(
		_canto.x, _canto.y - AGARRE_ALTO, _canto.z) + _normal * AGARRE_FONDO
	# Mirando a la pared. `look_at` con el −Z del modelo: se le pasa el punto de
	# detrás para que el frente quede contra el muro.
	var hacia := -_normal
	hacia.y = 0.0
	if hacia.length_squared() > 0.001:
		p.model.rotation.y = atan2(-hacia.x, -hacia.z)
	p.play("ledge_grab")


func physics_update(_delta: float) -> String:
	var p := actor as Player
	p.velocity = Vector3.ZERO

	if p.wants_jump() or Input.is_action_just_pressed("jump"):
		p.consume_jump()
		return "LedgeClimb"

	# Hacia atrás es hacia donde mira la pared: alejarse de ella.
	var direccion := p.get_move_direction()
	if direccion.length_squared() > 0.01 and direccion.dot(_normal) > SOLTARSE:
		# Un empujoncito para despegarse, o se vuelve a enganchar en el acto.
		p.velocity = _normal * 2.0
		return "Fall"

	return ""


func exit() -> void:
	# El segundo salto se repone al agarrarse: una cornisa es tan buen sitio de
	# apoyo como el suelo, y sin esto trepar y saltar seguido no sale.
	(actor as Player).doble_salto_disponible = true
