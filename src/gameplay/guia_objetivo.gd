extends Node3D
class_name GuiaObjetivo
## La flecha que señala hacia dónde está lo que se está buscando.
##
## ## Por qué hace falta
##
## La lista dice **qué** falta —seis faroles, cuatro rincones— pero no **dónde**,
## y el parque son doscientos sesenta metros de lado. A los ocho años, «busca
## seis faroles repartidos» sin más pista que esa es dar vueltas hasta cansarse
## y dejarlo.
##
## No es un mapa ni un minimapa: es una flecha que apunta y ya. Enseña la
## dirección y la distancia, no el camino — llegar sigue siendo cosa de quien
## juega, y por el camino se encuentran otras cosas.
##
## ## Se elige, no aparece sola
##
## La flecha solo sale cuando se ha tocado un objetivo en la lista para
## seguirlo. Una flecha permanente convierte el juego en ir detrás de una flecha,
## y entonces el parque deja de mirarse.
##
## Y se apaga sola al cumplir lo que señalaba: quedarse apuntando a algo que ya
## está hecho es peor que no apuntar.

## A qué altura flota sobre la jugadora.
##
## A 2,45 quedaba casi fuera del encuadre: la cámara va baja y detrás, así que
## dos metros y medio sobre la cabeza se salen por arriba. A la altura del pecho
## y por delante se ve sin levantar la vista.
const ALTURA := 1.55
## A qué distancia del centro orbita. Más lejos que antes: así se lee como algo
## que va por delante enseñando el camino, no como un sombrero.
const RADIO := 1.9

var objetivo: String = ""

var _malla: MeshInstance3D = null
var _material: StandardMaterial3D = null
var _jugador: Node3D = null
var _t: float = 0.0
var _destino: Vector3 = Vector3.ZERO
var _hay_destino: bool = false


func _ready() -> void:
	_construir()
	visible = false
	set_process(true)


func _construir() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(1.0, 0.82, 0.42)
	_material.emission_enabled = true
	_material.emission = Color(1.0, 0.72, 0.35)
	_material.emission_energy_multiplier = 2.4
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Se ve por encima de todo: una flecha guía tapada por un seto no guía nada.
	_material.no_depth_test = true

	# UN CONO, NO UN TRIÁNGULO PLANO.
	#
	# El prisma se leía como un pentágono amarillo: visto de lado es una figura
	# plana y no dice hacia dónde apunta. Un cono tiene punta desde cualquier
	# ángulo, que es lo único que esta cosa tiene que comunicar.
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = 0.24
	m.height = 0.78
	m.radial_segments = 10

	_malla = MeshInstance3D.new()
	_malla.mesh = m
	_malla.material_override = _material
	_malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# El cono apunta a +Y. Tras `look_at` el frente del nodo es -Z, así que se
	# tumba -90 grados para que la punta y el frente coincidan.
	_malla.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(_malla)


## Empieza a seguir un objetivo. Con cadena vacía, se apaga.
func seguir(cual: String) -> void:
	objetivo = cual
	visible = not cual.is_empty()


func _process(delta: float) -> void:
	if objetivo.is_empty():
		visible = false
		return
	if _jugador == null:
		_jugador = get_tree().get_first_node_in_group("player") as Node3D
		if _jugador == null:
			return

	_t += delta
	_buscar_destino()
	if not _hay_destino:
		visible = false
		return
	visible = true

	var desde := _jugador.global_position + Vector3.UP * ALTURA
	var hacia := _destino - desde
	hacia.y = 0.0
	if hacia.length_squared() < 0.01:
		return
	hacia = hacia.normalized()

	# La flecha orbita alrededor de la cabeza, del lado hacia el que hay que ir.
	# Puesta fija encima no dice tanto: así el sitio donde está ya es la mitad
	# de la información, antes de mirar hacia dónde apunta.
	global_position = desde + hacia * RADIO + Vector3.UP * sin(_t * 2.2) * 0.09
	look_at(global_position + hacia, Vector3.UP)

	# Cuanto más cerca, más pequeña y más apagada: es lo que dice «ya casi» sin
	# escribir una distancia en pantalla.
	var d := _jugador.global_position.distance_to(_destino)
	var cerca := clampf(remap(d, 4.0, 30.0, 0.0, 1.0), 0.0, 1.0)
	var escala := 0.7 + 0.4 * cerca
	scale = Vector3.ONE * escala
	_material.emission_energy_multiplier = 1.2 + 1.6 * cerca
	_material.albedo_color.a = 0.35 + 0.65 * cerca


## Dónde está lo más cercano de lo que se busca.
##
## Se recalcula cada fotograma en vez de guardarse: los faroles se apagan, las
## Estrellas se recogen y las arenas se limpian, así que un destino guardado
## apuntaría a algo que ya no cuenta.
func _buscar_destino() -> void:
	_hay_destino = false
	var candidatos: Array[Vector3] = []

	match objetivo:
		"faroles":
			for n in get_tree().get_nodes_in_group("faroles"):
				var f := n as Farol
				if f != null and not f.esta_encendido:
					candidatos.append(f.global_position)
		"estrellas":
			for n in get_tree().get_nodes_in_group("estrellas"):
				var e := n as Node3D
				if e != null and e.visible:
					candidatos.append(e.global_position)
		"rincones":
			for n in get_tree().current_scene.find_children("*", "Rincon", true, false):
				var r := n as Rincon
				if r != null and not r.ya_visitado():
					candidatos.append(r.global_position)
		"arenas", "guardian":
			for n in get_tree().get_nodes_in_group("arenas"):
				var a := n as Arena
				if a == null or a.cleared or a.waves.is_empty():
					continue
				if objetivo == "guardian" and not a.arena_id.ends_with("guardian"):
					continue
				if objetivo == "arenas" and a.arena_id.ends_with("guardian"):
					# La del guardián cuenta en los dos objetivos, pero si aún
					# está cerrada señalarla manda a una pared.
					if a.bloqueada:
						continue
				candidatos.append(a.global_position)
		"mercury":
			for n in get_tree().current_scene.find_children("*", "Encuentro", true, false):
				var e := n as Node3D
				if e != null:
					candidatos.append(e.global_position)

	if candidatos.is_empty():
		return
	var yo := _jugador.global_position
	var mejor := candidatos[0]
	var corta := yo.distance_squared_to(mejor)
	for c in candidatos:
		var d := yo.distance_squared_to(c)
		if d < corta:
			corta = d
			mejor = c
	_destino = mejor
	_hay_destino = true
