extends Node
class_name AnimadorGuardian
## Pone cara al guardián: traduce el estado de la máquina en una animación.
##
## Los enemigos normales del juego no tienen esqueleto — son bolas y se animan
## deformándolas ([`BlobAnimator`](blob_animator.gd)), que para un peluche es
## justo lo que hace falta. El guardián sí lo tiene, con sus ocho animaciones
## hechas en Blender, así que aquí solo hay que elegir cuál suena y cuándo.
##
## Se engancha igual que el otro y por la misma razón: los hijos arrancan antes
## que el padre, así que en `_ready()` el `state_machine` del enemigo todavía no
## existe. Se conecta en el primer fotograma que lo encuentre.

## Qué animación va con cada estado.
##
## Las claves son los NOMBRES DE LOS NODOS del `StateMachine` en la escena
## —«Idle», «Attack»—, que es lo que devuelve `get_state_name()`. Estaban puestos
## los nombres de las clases («EIdle», «EAttack») y no casaba ninguno, así que el
## guardián se pasó su primera pelea entera en reposo: andaba sin mover las
## piernas y pegaba sin mover el brazo.
##
## No dio ningún error, claro. Una clave que no está en un diccionario devuelve
## el valor por defecto tan tranquila.
const POR_ESTADO := {
	"Idle": "reposo",
	"Approach": "andar",
	"Wait": "andar",
	"Telegraph": "rugido",
	"Attack": "golpe",
	# El estado de ataque del jefe elige él mismo su animación según el ataque
	# que toque, así que aquí no se le pone ninguna: mapearlo obligaría a poner
	# una sola y perderíamos las cinco.
	"Stagger": "dano",
	"Defeated": "derrota",
}

## Cuánto tarda en pasar de una animación a otra. Un golem no cambia de postura
## de golpe; sin mezcla se ve el salto y parece un muñeco de juguete.
const MEZCLA := 0.18

## Las que no se repiten: al acabar se vuelve a reposo por su cuenta.
const DE_UNA_VEZ := ["golpe", "golpe_suelo", "dano", "despertar", "rugido",
	"barrido", "gancho", "embestida"]

@export var reproductor_path: NodePath = ^"../Model/AnimationPlayer"

var _reproductor: AnimationPlayer = null
var _enemigo: Enemy = null
var _actual: String = ""
## Mientras dura una animación que manda —despertar, el golpe al suelo— el
## estado no puede pisarla.
var _bloqueado: bool = false
## Lo que se pidió antes de que hubiera reproductor.
var _pendiente: String = ""
var _pendiente_manda: bool = false


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	if _reproductor == null:
		_reproductor = get_node_or_null(reproductor_path) as AnimationPlayer
		if _reproductor == null:
			return
		# Las animaciones vienen del .glb, donde no hay forma de marcar cuáles
		# son cíclicas: si no se marcan aquí, andar da un paso y se queda
		# congelado a media zancada.
		for nombre in _reproductor.get_animation_list():
			if nombre in DE_UNA_VEZ:
				continue
			var a := _reproductor.get_animation(nombre)
			if a != null:
				a.loop_mode = Animation.LOOP_LINEAR
		_reproductor.animation_finished.connect(_al_terminar)
		if not _pendiente.is_empty():
			var q := _pendiente
			var m := _pendiente_manda
			_pendiente = ""
			poner(q, m)
			return

	if _enemigo == null:
		_enemigo = owner as Enemy
		if _enemigo == null or _enemigo.state_machine == null:
			_enemigo = null
			return
		_enemigo.state_machine.state_changed.connect(_al_cambiar_estado)
		_al_cambiar_estado("", _enemigo.state_machine.get_state_name())


func _al_cambiar_estado(_desde: String, hacia: String) -> void:
	if _bloqueado:
		return
	# «Ataque» no está en la tabla a propósito: la pone el propio estado, que es
	# quien sabe cuál de los cinco toca.
	if hacia == "Ataque":
		return
	poner(POR_ESTADO.get(hacia, "reposo"))


## Reproduce una animación por su nombre. `manda` la protege de que el siguiente
## cambio de estado la corte a la mitad — es lo que hace que el despertar se vea
## entero aunque por debajo el guardián ya esté decidiendo a quién pegar.
func poner(nombre: String, manda: bool = false) -> void:
	if _reproductor == null:
		# TODAVÍA NO HAY REPRODUCTOR: SE GUARDA LA PETICIÓN.
		#
		# El jefe se crea y se le manda despertar en el mismo fotograma, antes de
		# que este nodo haya corrido su primer `_process` y haya encontrado el
		# `AnimationPlayer`. Descartar la petición ahí se llevaba por delante
		# justo la animación que más importa: la presentación del guardián.
		_pendiente = nombre
		_pendiente_manda = manda
		return
	if not _reproductor.has_animation(nombre):
		return
	if nombre == _actual and _reproductor.is_playing():
		return
	_actual = nombre
	_bloqueado = manda
	_reproductor.play(nombre, MEZCLA)


func _al_terminar(nombre: String) -> void:
	if nombre == "derrota":
		return
	_bloqueado = false
	# Se vuelve a lo que toque por estado, no siempre a reposo: si el guardián
	# sigue andando hacia ti cuando termina el puñetazo, quedarse plantado un
	# instante en reposo se lee como que se ha quedado pensando.
	if _enemigo != null and _enemigo.state_machine != null:
		poner(POR_ESTADO.get(_enemigo.state_machine.get_state_name(), "reposo"))
	else:
		poner("reposo")


## AJUSTA EL RITMO DEL PASO A LA VELOCIDAD REAL.
##
## La animación de andar está hecha para una velocidad concreta. En cuanto el
## guardián corre más —cada fase acelera— el cuerpo avanza más rápido que las
## piernas y se ve **patinar**: los pies resbalan por el suelo en vez de
## empujarlo. Estirando el ritmo al compás de lo que se mueve de verdad, el paso
## cae donde tiene que caer.
func ritmo_de_paso(velocidad: float, referencia: float) -> void:
	if _reproductor == null or _actual != "andar":
		return
	_reproductor.speed_scale = clampf(velocidad / maxf(referencia, 0.1), 0.45, 2.2)


func ritmo_normal() -> void:
	if _reproductor != null:
		_reproductor.speed_scale = 1.0


func esta_ocupado() -> bool:
	return _bloqueado
