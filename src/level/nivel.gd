extends Node3D
class_name Nivel
## Coordina un nivel: coloca a la jugadora, lleva la cuenta de las arenas y
## rescata a quien se cae por un borde.
##
## Las arenas ya saben lanzar sus oleadas solas ([`arena.gd`](arena.gd)); esto
## se ocupa de lo que ninguna de ellas puede saber: por dónde va el nivel, si se
## ha terminado, y qué hacer cuando la jugadora acaba fuera del mapa.

@export var level_id: String = "nivel_1"
## En el orden en que se recorren. La última cierra el nivel.
@export var arenas: Array[NodePath] = [^"Arena1", ^"Arena2", ^"Guardian"]
## Por debajo de esta altura se considera que se ha caído.
@export var altura_de_rescate: float = -6.0
@export var mensajes: bool = true

@export_group("Coleccionables")
@export var escena_estrella: PackedScene
## Cuántas hay en total. Al llegar, se anuncia y se guarda en el progreso.
@export var estrellas_del_nivel: int = 7

@export_group("Faroles")
@export var escena_farol: PackedScene
## La barrera que se abre al encenderlos todos.
@export var puerta: NodePath

var _jugador: Node3D = null
var _constructor: ConstructorNivel = null
var _limpias: int = 0
var _ultimo_suelo: Vector3 = Vector3.ZERO
var _camara_plano: Camera3D = null
var _faroles_totales: int = 0
var _faroles_encendidos: int = 0


func _ready() -> void:
	_constructor = get_node_or_null("Blockout") as ConstructorNivel
	_jugador = get_tree().get_first_node_in_group("player") as Node3D

	if _jugador != null and _constructor != null:
		_jugador.global_position = _constructor.punto_inicio
		_ultimo_suelo = _constructor.punto_inicio

	if _constructor != null and escena_estrella != null:
		var puestas := _constructor.sembrar_estrellas(escena_estrella, self)
		print("[Nivel] %d Estrellas de Sueño sembradas" % puestas)

	if _constructor != null and escena_farol != null:
		_faroles_totales = _constructor.sembrar_faroles(escena_farol, self)
		for nodo in get_tree().get_nodes_in_group("faroles"):
			(nodo as Farol).encendido.connect(_al_encender_farol)
		print("[Nivel] %d faroles colocados" % _faroles_totales)

	EventBus.arena_cleared.connect(_al_limpiar_arena)
	EventBus.star_collected.connect(_al_coger_estrella)
	if mensajes:
		EventBus.arena_started.connect(_al_empezar_arena)


func _physics_process(_delta: float) -> void:
	if _jugador == null:
		return
	# Rescate por caída. En un juego para una niña de 8 años, caerse por un
	# borde no puede castigar: devuelve al último sitio firme y sigue.
	if _jugador.global_position.y < altura_de_rescate:
		rescatar()
		return
	var cuerpo := _jugador as CharacterBody3D
	if cuerpo != null and cuerpo.is_on_floor():
		_ultimo_suelo = _jugador.global_position


func rescatar() -> void:
	# El checkpoint lo pone cada arena al empezar; hasta la primera, el último
	# sitio donde se pisó suelo firme.
	var destino := _ultimo_suelo + Vector3.UP * 0.6
	if GameManager.last_checkpoint != Vector3.ZERO:
		destino = GameManager.last_checkpoint + Vector3.UP * 0.6
	_jugador.global_position = destino
	if _jugador is CharacterBody3D:
		(_jugador as CharacterBody3D).velocity = Vector3.ZERO
	# Sin esto el pelo sale disparado con la inercia de la caída.
	for nodo in _jugador.find_children("*", "HairPhysics", true, false):
		(nodo as HairPhysics).reset()
	EventBus.player_respawned.emit(destino)


func _al_encender_farol(_farol: Farol) -> void:
	_faroles_encendidos += 1
	if _faroles_encendidos < _faroles_totales:
		# Se dice cuántos quedan, no cuántos llevas: lo que hace falta saber es
		# si esto se ha acabado o hay que seguir buscando.
		var quedan := _faroles_totales - _faroles_encendidos
		EventBus.show_message.emit(
			"Farol encendido — quedan %d" % quedan, 2.0)
		return

	EventBus.show_message.emit("¡Se abre el camino!", 2.5)
	var barrera := get_node_or_null(puerta) as PuertaMagica
	if barrera != null:
		barrera.abrir()


func _al_coger_estrella(total: int) -> void:
	if total < estrellas_del_nivel:
		return
	EventBus.show_message.emit("¡Todas las Estrellas de Sueño!", 3.0)


func _al_empezar_arena(id: String, oleadas: int) -> void:
	if not id.begins_with(level_id.substr(0, 2)):
		return
	EventBus.show_message.emit("¡Cuidado! %d oleadas" % oleadas, 2.0)


func _al_limpiar_arena(id: String) -> void:
	var esperada := _id_de(_limpias)
	if esperada != "" and id != esperada:
		return
	_limpias += 1
	if _limpias >= arenas.size():
		_terminar()
	elif mensajes:
		EventBus.show_message.emit("¡Camino despejado!", 1.6)


func _terminar() -> void:
	set_physics_process(false)
	EventBus.level_completed.emit(level_id)
	if mensajes:
		EventBus.show_message.emit("¡Nivel completado!", 3.0)
	print("[Nivel] %s completado" % level_id)


## Vista cenital de todo el nivel, con la tecla P.
##
## Un blockout se juzga mirando la planta: si desde arriba no se entiende por
## dónde se va, jugándolo tampoco. La cámara de la jugadora no sirve para esto
## porque cuelga de un `SpringArm3D` que la recoloca cada frame de física —
## moverla desde fuera no tiene ningún efecto.
func alternar_plano() -> void:
	if _camara_plano == null:
		_camara_plano = Camera3D.new()
		_camara_plano.name = "CamaraPlano"
		_camara_plano.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camara_plano.size = 120.0
		_camara_plano.far = 400.0
		_camara_plano.rotation_degrees = Vector3(-90, 0, 0)
		var centro := Vector3(-18, 0, -45)
		if _constructor != null and not _constructor.centros_arena.is_empty():
			centro = Vector3.ZERO
			for punto in _constructor.centros_arena.values():
				centro += punto
			centro /= float(_constructor.centros_arena.size())
		_camara_plano.position = centro + Vector3.UP * 120.0
		add_child(_camara_plano)

	if _camara_plano.current:
		var camara := _jugador.find_children("*", "Camera3D", true, false)
		if not camara.is_empty():
			(camara[0] as Camera3D).make_current()
	else:
		_camara_plano.make_current()


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo \
			and evento.keycode == KEY_P:
		alternar_plano()


func _id_de(indice: int) -> String:
	if indice < 0 or indice >= arenas.size():
		return ""
	var nodo := get_node_or_null(arenas[indice]) as Arena
	return nodo.arena_id if nodo != null else ""
