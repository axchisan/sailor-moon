extends Node3D
class_name CharacterAnimator
## Monta el AnimationTree sobre un modelo importado y da una API sencilla
## para que la máquina de estados del jugador pida animaciones.
##
## Se construye por código, no en el `.tscn`, porque las escenas instanciadas
## de un `.glb` no admiten hijos nuevos sin marcarlas como editables, y eso se
## rompe en cada reimportación del modelo.
##
## ESTRUCTURA QUE CREA
##   BlendTree
##     ├── maquina  (StateMachine: locomocion, jump, fall, attack_1…)
##     └── escala   (TimeScale, para encajar la animación en el tiempo que
##                   dicta el combate)
##
## El TimeScale existe porque las animaciones de Mixamo duran ~1–2 s y nuestros
## golpes duran 0,29 s. El combate ya está ajustado y se siente bien, así que
## manda el código y la animación se adapta (ver docs/08-ANIMACIONES-MIXAMO.md).

signal animation_finished(anim_name: String)

const LIBRERIA := preload("res://assets/animations/serena/serena_animaciones.res")
const NOMBRE_LIBRERIA := "serena"

## Estados de la máquina. El primero es el de arranque.
const ESTADOS := [
	"locomocion", "jump", "fall", "land",
	"attack_1", "attack_2", "attack_3", "special",
	"hurt", "dizzy", "victory", "transform",
]

## Qué animación reproduce cada estado (locomocion es un blend space aparte).
const ANIMACION_DE := {
	"jump": "jump_start", "fall": "jump_loop", "land": "land",
	"attack_1": "attack_1", "attack_2": "attack_2", "attack_3": "attack_3",
	"special": "special", "hurt": "hurt", "dizzy": "dizzy",
	"victory": "victory", "transform": "transform_pose",
}

## Transición por defecto entre estados, en segundos.
@export var fundido: float = 0.12
## Los golpes entran más secos: un fundido largo se come el impacto.
@export var fundido_golpe: float = 0.04
## Velocidad a la que la mezcla de locomoción pasa a correr del todo.
@export var velocidad_correr: float = 6.5
## Tope de aceleración de una animación. Por encima se ve como un borrón.
@export var escala_maxima: float = 5.0

var tree: AnimationTree = null
var player: AnimationPlayer = null

var _playback: AnimationNodeStateMachinePlayback = null
var _duraciones: Dictionary = {}
var _estado_actual: String = "locomocion"


func _ready() -> void:
	var skeleton := _buscar_skeleton(self)
	if skeleton == null:
		push_warning("CharacterAnimator: no hay Skeleton3D bajo %s" % name)
		return

	# El AnimationPlayer debe colgar del padre del esqueleto: las pistas de
	# Mixamo apuntan a "Skeleton3D:hueso", así que la raíz tiene que ser el
	# nodo que contiene al Skeleton3D.
	var contenedor := skeleton.get_parent()

	player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	contenedor.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library(NOMBRE_LIBRERIA, LIBRERIA)

	for nombre in LIBRERIA.get_animation_list():
		_duraciones[nombre] = LIBRERIA.get_animation(nombre).length

	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	contenedor.add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.tree_root = _construir_arbol()
	tree.active = true

	_playback = tree.get("parameters/maquina/playback")
	player.animation_finished.connect(func(a: StringName) -> void: animation_finished.emit(String(a)))


# --- API para la máquina de estados -------------------------------------------

## Cambia de estado con fundido. `duracion_objetivo` encaja la animación en el
## tiempo que marca el juego; 0 la deja a velocidad natural.
func travel(estado: String, duracion_objetivo: float = 0.0) -> void:
	if _playback == null or estado == _estado_actual and duracion_objetivo <= 0.0:
		if _playback == null:
			return
	_estado_actual = estado

	var escala := 1.0
	if duracion_objetivo > 0.0:
		var anim: String = ANIMACION_DE.get(estado, "")
		var duracion: float = _duraciones.get(anim, 0.0)
		if duracion > 0.0:
			escala = minf(duracion / duracion_objetivo, escala_maxima)
	tree.set("parameters/escala/scale", escala)
	_playback.travel(estado)


## Mezcla parado ↔ andar ↔ correr según la velocidad real del personaje.
func set_locomotion_speed(velocidad: float) -> void:
	if tree == null:
		return
	tree.set("parameters/maquina/locomocion/blend_position",
		clampf(velocidad / maxf(velocidad_correr, 0.01), 0.0, 1.0))


func get_state() -> String:
	return _estado_actual


func get_length(anim: String) -> float:
	return _duraciones.get(anim, 0.0)


# --- Construcción del árbol ---------------------------------------------------

func _construir_arbol() -> AnimationNodeBlendTree:
	var maquina := AnimationNodeStateMachine.new()

	# Locomoción: una mezcla continua parado → andar → correr, en vez de tres
	# estados sueltos. Así no hay saltos al acelerar.
	var locomocion := AnimationNodeBlendSpace1D.new()
	locomocion.min_space = 0.0
	locomocion.max_space = 1.0
	locomocion.add_blend_point(_anim("idle"), 0.0)
	locomocion.add_blend_point(_anim("walk"), 0.4)
	locomocion.add_blend_point(_anim("run"), 1.0)
	maquina.add_node("locomocion", locomocion, Vector2(0, 0))

	var columna := 1
	for estado in ESTADOS:
		if estado == "locomocion":
			continue
		maquina.add_node(estado, _anim(ANIMACION_DE[estado]), Vector2(columna * 220, 0))
		columna += 1

	# Transiciones de todos con todos: así `travel()` siempre llega en un paso.
	for origen in ESTADOS:
		for destino in ESTADOS:
			if origen == destino:
				continue
			var t := AnimationNodeStateMachineTransition.new()
			t.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
			t.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_DISABLED
			t.xfade_time = fundido_golpe if destino.begins_with("attack") else fundido
			maquina.add_transition(origen, destino, t)

	var arbol := AnimationNodeBlendTree.new()
	arbol.add_node("maquina", maquina, Vector2(0, 0))
	var escala := AnimationNodeTimeScale.new()
	arbol.add_node("escala", escala, Vector2(320, 0))
	arbol.connect_node("escala", 0, "maquina")
	arbol.connect_node("output", 0, "escala")
	return arbol


func _anim(nombre: String) -> AnimationNodeAnimation:
	var nodo := AnimationNodeAnimation.new()
	nodo.animation = "%s/%s" % [NOMBRE_LIBRERIA, nombre]
	nodo.resource_name = nombre
	return nodo


static func _buscar_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _buscar_skeleton(c)
		if r != null:
			return r
	return null
