extends State
## Derrota: el enemigo sale despedido, se encoge y desaparece.
##
## Sustituye a la antigua purificación, en la que los enemigos se volvían
## amigos y se quedaban de adorno. El cambio lo pidió la jugadora: quiere que
## los enemigos ataquen de verdad y desaparezcan al vencerlos.
##
## Sigue sin haber nada desagradable: el enemigo sale volando, se encoge y se
## deshace en un estallido de estrellas. Es contundente sin ser desagradable,
## que es justo lo que pide el género.

const DURACION := 0.45
const GIRO := 16.0

var _timer: float = 0.0
var _escala_inicial: Vector3 = Vector3.ONE
var _deform: Node3D = null


func enter(msg: Dictionary = {}) -> void:
	var e := actor as Enemy
	_timer = 0.0
	e.defeat()

	var knockback: Vector3 = msg.get("knockback", Vector3.ZERO)
	# Sale despedido con más fuerza que en un stagger normal: el golpe final
	# tiene que sentirse distinto de los demás.
	e.velocity.x = knockback.x * 1.4
	e.velocity.z = knockback.z * 1.4
	e.velocity.y = 6.0

	_deform = e.get_node_or_null("Model/Deform")
	if _deform == null:
		_deform = e.model
	_escala_inicial = _deform.scale


func physics_update(delta: float) -> String:
	var e := actor as Enemy
	e.brake(delta, 3.0)

	_timer += delta
	var t: float = clampf(_timer / DURACION, 0.0, 1.0)

	# Se encoge acelerando al final, para que el "puf" sea seco
	var k: float = 1.0 - t * t
	_deform.scale = _escala_inicial * maxf(k, 0.001)
	e.model.rotation.y += delta * GIRO

	if t >= 1.0:
		e.queue_free()

	return ""
