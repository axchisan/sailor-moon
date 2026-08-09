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
## Cuánto se deja subir por las colinas del borde antes de devolver al mapa.
@export var margen_limite: float = 22.0
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
var _terreno: TerrenoNivel = null
var _objetivos: ObjetivosNivel = null
var _portal: PortalSalida = null
var _limpias: int = 0
var _ultimo_suelo: Vector3 = Vector3.ZERO
var _camara_plano: Camera3D = null
var _faroles_totales: int = 0
var _faroles_encendidos: int = 0


## Aplica los recortes del móvil. En cualquier otra plataforma no hace nada.
##
## `OS.has_feature("mobile")` en vez de comparar con "Android": así vale igual
## el día que haya una versión para otro cacharro, y en el editor sigue viéndose
## la calidad completa mientras se trabaja.
func _ajustar_para_el_movil() -> void:
	if not OS.has_feature("mobile"):
		return

	# 1. FXAA fuera. Es el que más costaba de todo lo medido: en el móvil pasó
	#    de 37-45 fps a 60 en la mayoría de sitios. Es un pase que relee el
	#    fotograma entero varias veces por píxel, y ahí el ancho de banda es el
	#    recurso caro. No hay versión barata que imite un antialiasing, pero en
	#    una pantalla de móvil el píxel tampoco se ve.
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED

	var entorno := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if entorno != null and entorno.environment != null:
		# 2. La niebla, cambiada por otra cosa que ya se estaba calculando.
		#
		#    La del Environment se evalúa en CADA píxel de CADA material, y se
		#    notaba en todo el mapa. Pero el terreno ya tiene su propia
		#    perspectiva aérea metida en el shader —el `lejania` que destiñe lo
		#    lejano a morado—, y eso sale gratis porque ya se calcula.
		#
		#    Así que en el móvil se apaga la niebla y se acerca el punto donde
		#    el terreno empieza a desteñirse, que es donde de verdad se veía el
		#    efecto: el fondo del valle. Lo que se pierde es la neblina sobre
		#    los props lejanos, que además ya se apagan solos por distancia.
		entorno.environment.fog_enabled = false
		if _terreno_visual_material() != null:
			var mat := _terreno_visual_material()
			mat.set_shader_parameter("desde",
				_terreno.radio_colinas * MOVIL_NIEBLA_DESDE)

	# 3. La sombra, con menos alcance. No se quita: se acorta de 24 a 18 m, que
	#    sigue cubriendo de sobra lo que se ve de cerca —que es donde una sombra
	#    aporta— y deja de dibujar el mundo otra vez para lo de más allá.
	var sol := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sol != null:
		sol.directional_shadow_max_distance = MOVIL_SOMBRA_ALCANCE

	print("[Nivel] perfil de móvil: sin FXAA, sin niebla, sombra a %.0f m"
		% MOVIL_SOMBRA_ALCANCE)


## El material del terreno, para poder retocarle la perspectiva aérea.
func _terreno_visual_material() -> ShaderMaterial:
	if _terreno == null:
		return null
	for hijo in _terreno.get_children():
		var malla := hijo as MeshInstance3D
		if malla != null:
			return malla.material_override as ShaderMaterial
	return null


## Recortes que solo se aplican en el móvil.
##
## EN EL PC NO SE TOCA NADA. Ahí sobra potencia y el juego se ve como está
## pensado; estos ajustes existen porque el mismo escenario en un Android se
## quedaba en 37-45 fps.
##
## La regla es **limitar, no eliminar**: cada recorte o deja el efecto con menos
## alcance, o lo cambia por otro más barato que hace lo mismo donde se nota. Lo
## único que se apaga del todo es el FXAA, porque de ese no hay versión barata —
## y es el que más costaba con diferencia.
##
## Todos los números salen de medir en el móvil con el banco de pruebas (F8),
## no de suponer. La primera vez que se supuso —«el FXAA cuesta una fracción»—
## se falló justo en el que más costaba.
const MOVIL_SOMBRA_ALCANCE := 18.0
const MOVIL_NIEBLA_DESDE := 0.55


func _ready() -> void:
	_constructor = get_node_or_null("Blockout") as ConstructorNivel
	_jugador = get_tree().get_first_node_in_group("player") as Node3D

	if _jugador != null and _constructor != null:
		_jugador.global_position = _constructor.punto_inicio
		_ultimo_suelo = _constructor.punto_inicio

	# El terreno va PRIMERO de todo lo que se genera: los props se posan con un
	# rayo sobre el suelo, así que el suelo tiene que existir ya.
	#
	var decorador := get_node_or_null("Decorado") as DecoradorNivel

	_terreno = get_node_or_null("Terreno") as TerrenoNivel
	if _terreno != null:
		# EL TERRENO SE CENTRA EN EL PARQUE, no donde lo dejó el editor.
		#
		# Su zona llana y sus colinas se miden desde su propio origen, y ese
		# origen estaba puesto a mano en la escena. Al alargar el recorrido el
		# parque se desplazó treinta metros y el llano dejó de cubrirlo: medio
		# campo quedó en cuesta, y los rincones —que buscan sitio llano— se
		# amontonaron todos en la mitad que aún lo era. Calculándolo aquí, el
		# llano sigue al parque por mucho que cambie el recorrido.
		#
		# Y SE SUBE HASTA LA ALTURA DE LO QUE SE PISA.
		#
		# El llano del terreno nace a cero, pero la superficie por la que se anda
		# es la cara de arriba de las losas, media losa más alta. Con el terreno
		# a cero había que levantarlo bajo cada tramo, y esa faldita de medio
		# metro no cabe en una celda de más de tres: salía un borde aserrado
		# siguiendo la rejilla por todo el parque.
		#
		# Poniendo el llano DIRECTAMENTE a la altura del suelo pisable, en la
		# parte llana —que es casi todo— no hay nada que levantar y no hay
		# escalón que dentar. Solo se trabaja donde el escenario sube de verdad:
		# la cuesta del guardián y el peldaño de las arenas.
		if _constructor != null:
			var medida := _constructor.extension()
			var centro_parque: Vector3 = medida["centro"]
			_terreno.global_position = Vector3(
				centro_parque.x, _constructor.grosor_suelo * 0.5, centro_parque.z)
		# Las hondonadas se piden ANTES de construir: después ya está la malla
		# hecha y cavar sobre ella dejaría la colisión desincronizada.
		if decorador != null and _constructor != null and decorador.radio_estanque > 0.0:
			_terreno.hondonadas.append(decorador.hondonada_estanque(_constructor))
		_terreno.construir()
		if _constructor != null:
			_constructor.radio_limite = _terreno.radio_colinas
		# La física necesita un ciclo para enterarse del cuerpo nuevo. Sin esta
		# espera, los rayos que posan los props salen al vacío y todo el parque
		# vuelve a quedarse flotando.
		await get_tree().physics_frame

	# Después de construir el terreno: el perfil del móvil le retoca el material,
	# y hasta aquí ese material no existe.
	_ajustar_para_el_movil()

	# Decorar va después de construir y antes que nada más: las Estrellas y los
	# faroles se colocan por coordenadas del recorrido, no por lo que haya
	# plantado alrededor, así que el orden entre ellos da igual — pero si el
	# decorador corriera primero, no tendría tramos que consultar.
	if decorador != null and _constructor != null:
		decorador.decorar(_constructor)

	if _constructor != null and escena_estrella != null:
		var puestas := _constructor.sembrar_estrellas(escena_estrella, self)
		print("[Nivel] %d Estrellas de Sueño sembradas" % puestas)

	if _constructor != null and escena_farol != null:
		_faroles_totales = _constructor.sembrar_faroles(escena_farol, self)
		for nodo in get_tree().get_nodes_in_group("faroles"):
			(nodo as Farol).encendido.connect(_al_encender_farol)
		print("[Nivel] %d faroles colocados" % _faroles_totales)

	var bichos := get_node_or_null("Bichos") as Bichos
	if bichos != null and _constructor != null and _terreno != null:
		bichos.poblar(_constructor.extension()["centro"],
			func(p: Vector3) -> float:
				var local := p - _terreno.global_position
				return _terreno.altura_en(local.x, local.z) + _terreno.global_position.y)

	_montar_objetivos()

	EventBus.arena_cleared.connect(_al_limpiar_arena)
	EventBus.star_collected.connect(_al_coger_estrella)
	if mensajes:
		EventBus.arena_started.connect(_al_empezar_arena)

	# El plano de apertura, al final de todo: la escena ya está montada y la
	# cámara puede tomar como destino la posición definitiva de la jugadora.
	var apertura := get_node_or_null("CamaraApertura") as CamaraApertura
	if apertura != null and _constructor != null:
		apertura.arrancar(_constructor.extension()["centro"])


func _physics_process(_delta: float) -> void:
	if _jugador == null:
		return
	# Rescate por caída. En un juego para una niña de 8 años, caerse por un
	# borde no puede castigar: devuelve al último sitio firme y sigue.
	if _jugador.global_position.y < altura_de_rescate:
		rescatar()
		return
	if _fuera_del_mundo():
		rescatar()
		return
	var cuerpo := _jugador as CharacterBody3D
	if cuerpo != null and cuerpo.is_on_floor():
		_ultimo_suelo = _jugador.global_position


## Enchufa la lista de objetivos con lo que la va cumpliendo.
##
## Los faroles, los rincones y los encuentros no tienen señal propia en el
## `EventBus`, así que se conectan aquí uno a uno. Las arenas y las Estrellas sí
## la tienen y se enteran solas.
func _montar_objetivos() -> void:
	_objetivos = get_node_or_null("Objetivos") as ObjetivosNivel
	if _objetivos == null:
		return

	for nodo in get_tree().get_nodes_in_group("faroles"):
		(nodo as Farol).encendido.connect(func(_f: Farol) -> void:
			_objetivos.anotar("faroles"))

	for nodo in find_children("*", "Encuentro", true, false):
		(nodo as Encuentro).encuentro_terminado.connect(func(_id: String) -> void:
			_objetivos.anotar("mercury"))

	for nodo in find_children("*", "Rincon", true, false):
		(nodo as Rincon).visitado.connect(func(_id: String) -> void:
			_objetivos.anotar("rincones"))

	_portal = get_node_or_null("PortalSalida") as PortalSalida
	if _portal != null:
		_objetivos.todos_cumplidos.connect(_portal.activar)
		_portal.usado.connect(_al_usar_portal)
		# El portal va en el claro del final, no en el arranque: una puerta al
		# siguiente mundo a dos pasos de donde apareces no tiene ningún peso.
		if _constructor != null:
			var claro: Vector3 = _constructor.centros_arena.get(
				"ClaroPortal", Vector3.ZERO)
			if claro != Vector3.ZERO:
				_portal.global_position = claro
				# Mirando hacia donde se llega, para entrar de frente.
				if not _constructor.tramos.is_empty():
					var ultimo: Vector3 = _constructor.tramos[
						_constructor.tramos.size() - 1]["direccion"]
					_portal.rotation.y = atan2(-ultimo.x, -ultimo.z)


func _al_usar_portal(destino: String) -> void:
	EventBus.level_completed.emit(level_id)
	if destino.is_empty():
		EventBus.show_message.emit("Aquí acaba lo que hay construido, por ahora", 3.0)
		return
	SceneLoader.change_scene(destino)


## Red de seguridad del límite del mapa.
##
## Las colinas frenan, pero un límite que depende solo de la geometría acaba
## burlándose: basta un collado bajo, un rebote raro contra una roca o un salto
## desde algo alto. Y salirse del mundo en un juego para una niña de ocho años
## no es un secretito que descubrir, es un sitio del que no se sabe volver.
##
## Se mide en el plano y no en 3D a propósito: importa lo lejos que se está del
## centro, no la altura — subirse a una colina es legítimo, cruzarla no.
##
## Vale igual para los escenarios que vengan: mientras haya un `Terreno`, el
## radio sale de él y no hay que configurar nada.
func _fuera_del_mundo() -> bool:
	if _terreno == null:
		return false
	var aqui := _jugador.global_position
	var centro := _terreno.global_position
	var distancia := Vector2(aqui.x - centro.x, aqui.z - centro.z).length()
	# Un margen por encima de donde arrancan las colinas: hay que poder subirse
	# a ellas y asomarse, que es de las pocas cosas que premian explorar.
	return distancia > _terreno.radio_colinas + margen_limite


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
