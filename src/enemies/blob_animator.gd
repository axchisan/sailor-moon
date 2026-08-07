extends Node
class_name BlobAnimator
## Animación procedural para enemigos sin esqueleto.
##
## POR QUÉ NO SE RIGUEAN: el Peluchín es una bola con patitas y el Cofrecito un
## cofre. Mixamo solo riguea humanoides, y aunque pudiera, un esqueleto para una
## bola es desperdiciar trabajo: se ve mejor con *squash & stretch*, que es el
## recurso clásico de la animación de dibujos y encaja con la estética.
##
## Coste: unas cuentas de seno por enemigo y frame. Con 8 en pantalla es nada,
## comparado con evaluar 8 esqueletos.
##
## Cada instancia arranca con un desfase aleatorio para que no reboten todas a
## la vez como un coro, que es lo que delata que es procedural.

## Nodo visual que se deforma. Debe ser el padre de la malla, nunca la malla.
@export var modelo_path: NodePath = ^"../Model"

@export_group("Reposo")
## Altura del rebote al respirar, en metros.
@export var rebote: float = 0.035
@export var velocidad_rebote: float = 2.2

@export_group("Movimiento")
@export var rebote_andando: float = 0.075
@export var velocidad_andando: float = 7.0
## Inclinación hacia delante al avanzar, en grados.
@export var inclinacion: float = 10.0

@export_group("Combate")
## Cuánto se aplasta al preparar el golpe (0.7 = al 70% de alto).
@export var aplastado: float = 0.72
## Cuánto se estira al golpear.
@export var estirado: float = 1.28
@export var vibracion: float = 0.012

var _modelo: Node3D = null
var _enemigo: Enemy = null
var _estado: String = "Idle"
var _t: float = 0.0
var _fase: float = 0.0
var _escala_base: Vector3 = Vector3.ONE
var _y_base: float = 0.0
## Progreso 0-1 dentro del estado actual, para animaciones de un solo uso.
var _progreso: float = 0.0


func _ready() -> void:
	_modelo = get_node_or_null(modelo_path) as Node3D
	if _modelo == null:
		push_warning("BlobAnimator: no encuentro el modelo en '%s'" % modelo_path)
		set_process(false)
		return

	_escala_base = _modelo.scale
	_y_base = _modelo.position.y
	_fase = randf() * TAU
	# La conexión NO se puede hacer aquí: los hijos se inicializan antes que el
	# padre, así que `Enemy.state_machine` (que es @onready) todavía es null.
	# Se engancha en el primer _process, cuando el enemigo ya está listo.


func _enganchar() -> bool:
	_enemigo = owner as Enemy
	if _enemigo == null or _enemigo.state_machine == null:
		return false
	_enemigo.state_machine.state_changed.connect(_on_estado_cambiado)
	_estado = _enemigo.state_machine.get_state_name()
	return true


func _on_estado_cambiado(_desde: String, hacia: String) -> void:
	_estado = hacia
	_progreso = 0.0


func _process(delta: float) -> void:
	if _modelo == null:
		return
	if _enemigo == null and not _enganchar():
		return
	_t += delta
	_progreso += delta

	var escala := Vector3.ONE
	var desplazamiento := 0.0
	var giro := 0.0
	var cabeceo := 0.0

	match _estado:
		"Idle":
			desplazamiento = absf(sin(_t * velocidad_rebote + _fase)) * rebote

		"Approach":
			desplazamiento = absf(sin(_t * velocidad_andando + _fase)) * rebote_andando
			cabeceo = deg_to_rad(inclinacion)
			# Se ensancha al aterrizar de cada saltito
			var golpe := absf(cos(_t * velocidad_andando + _fase))
			escala = Vector3(1.0 + golpe * 0.06, 1.0 - golpe * 0.06, 1.0 + golpe * 0.06)

		"Wait":
			desplazamiento = absf(sin(_t * velocidad_andando * 0.6 + _fase)) * rebote_andando * 0.7
			# Balanceo lateral: parece que ronda impaciente
			giro = sin(_t * 1.8 + _fase) * deg_to_rad(9.0)

		"Telegraph":
			# Se agacha y vibra: es el aviso de "voy a pegar"
			var t := clampf(_progreso / 0.75, 0.0, 1.0)
			var k := aplastado + (1.0 - aplastado) * (1.0 - t)
			escala = Vector3(1.0 + (1.0 - k) * 0.8, k, 1.0 + (1.0 - k) * 0.8)
			desplazamiento = sin(_t * 45.0) * vibracion * t

		"Attack":
			# Estirón hacia delante que se deshincha
			var t2 := clampf(_progreso / 0.28, 0.0, 1.0)
			var s := estirado - (estirado - 1.0) * t2
			escala = Vector3(2.0 - s, s, 2.0 - s)
			cabeceo = deg_to_rad(inclinacion * 2.2 * (1.0 - t2))

		"Stagger":
			# Vuelta de campana al recibir el golpe
			giro = _progreso * 14.0
			escala = Vector3(1.12, 0.88, 1.12)

		"Defeated":
			# El encogido lo lleva `e_defeated.gd`. Si aquí se tocara la escala,
			# los dos se pisarían y el enemigo no llegaría a desaparecer.
			return

	_modelo.scale = _escala_base * escala
	_modelo.position.y = _y_base + desplazamiento
	_modelo.rotation.x = cabeceo
	# El giro se suma al que ya aplica el enemigo para mirar al jugador.
	if not is_zero_approx(giro):
		_modelo.rotation.z = giro
	else:
		_modelo.rotation.z = 0.0
