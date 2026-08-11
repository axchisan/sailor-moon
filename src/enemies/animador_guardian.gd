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

## Qué animación va con cada estado. Lo que no esté aquí se queda en reposo.
const POR_ESTADO := {
	"EIdle": "reposo",
	"EApproach": "andar",
	"EWait": "reposo",
	"ETelegraph": "rugido",
	"EAttack": "golpe",
	"EStagger": "dano",
	"EDefeated": "derrota",
}

## Cuánto tarda en pasar de una animación a otra. Un golem no cambia de postura
## de golpe; sin mezcla se ve el salto y parece un muñeco de juguete.
const MEZCLA := 0.18

## Las que no se repiten: al acabar se vuelve a reposo por su cuenta.
const DE_UNA_VEZ := ["golpe", "golpe_suelo", "dano", "despertar", "rugido"]

@export var reproductor_path: NodePath = ^"../Model/AnimationPlayer"

var _reproductor: AnimationPlayer = null
var _enemigo: Enemy = null
var _actual: String = ""
## Mientras dura una animación que manda —despertar, el golpe al suelo— el
## estado no puede pisarla.
var _bloqueado: bool = false


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
	poner(POR_ESTADO.get(hacia, "reposo"))


## Reproduce una animación por su nombre. `manda` la protege de que el siguiente
## cambio de estado la corte a la mitad — es lo que hace que el despertar se vea
## entero aunque por debajo el guardián ya esté decidiendo a quién pegar.
func poner(nombre: String, manda: bool = false) -> void:
	if _reproductor == null or not _reproductor.has_animation(nombre):
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


func esta_ocupado() -> bool:
	return _bloqueado
