extends Node3D
class_name ConstructorNivel
## Levanta el blockout de un nivel a partir de la lista de tramos de `recorrido`.
##
## El nivel es una cadena: pasillo → arena → giro → pasillo → arena… Este nodo
## la recorre colocando suelo, bordes y plataformas, y de paso **mueve las
## arenas a su sitio**. Así las medidas viven en un único lugar: cambiar el
## largo de un tramo recoloca todo lo que va detrás, sin tocar la escena.
##
## Se genera por código y no a mano en el `.tscn` porque un blockout se toca
## veinte veces: alargar un pasillo a mano obliga a reposicionar cada pieza
## posterior, y a la tercera vez ya hay algo descuadrado.
##
## ## No usa CSG
##
## [`07-ESCENARIOS.md`](../../docs/07-ESCENARIOS.md) propone CSG, que es lo
## cómodo cuando montas a mano en el editor. Generando por código no aporta
## nada: `MeshInstance3D` + `StaticBody3D` da lo mismo, es más barato en móvil
## y evita que Godot recompile la geometría constructiva en cada arranque.
##
## ## Regla de oro
##
## Esto se juega **en gris, de principio a fin, antes de decorar**. Si el
## recorrido no se entiende sin props, tampoco se va a entender con ellos.

## Un paso del recorrido. `nodo` enlaza un tramo de tipo `arena` con el nodo
## `Arena` que ya está en la escena, para colocarlo y darle su tamaño.
const RECORRIDO: Array[Dictionary] = [
	{"tipo": "pasillo", "largo": 20.0, "ancho": 9.0},
	{"tipo": "arena", "radio": 11.0, "nodo": "Arena1"},
	{"tipo": "giro", "grados": -90.0},
	{"tipo": "pasillo", "largo": 25.0, "ancho": 9.0, "plataformas": true},
	{"tipo": "arena", "radio": 11.0, "nodo": "Arena2"},
	{"tipo": "giro", "grados": 90.0},
	{"tipo": "pasillo", "largo": 15.0, "ancho": 9.0, "subida": 2.5},
	{"tipo": "arena", "radio": 13.0, "nodo": "Guardian"},
]

@export_group("Aspecto")
@export var color_suelo: Color = Color(0.42, 0.55, 0.38)
## El camino va de otro color a propósito: a los 8 años, saber por dónde se va
## importa más que cualquier decoración.
@export var color_camino: Color = Color(0.72, 0.68, 0.52)
@export var color_arena: Color = Color(0.60, 0.52, 0.44)
@export var color_borde: Color = Color(0.35, 0.42, 0.33)
@export var color_plataforma: Color = Color(0.55, 0.48, 0.40)

@export_group("Medidas")
@export var grosor_suelo: float = 1.0
@export var alto_borde: float = 2.2
@export var ancho_borde: float = 0.8
## Ancho de la franja de color que marca el camino.
@export var ancho_camino: float = 3.2
## Hueco que se deja en el borde de la arena para entrar y salir, en grados.
@export var hueco_acceso: float = 46.0

var _origen: Vector3 = Vector3.ZERO
var _direccion: Vector3 = Vector3.FORWARD
var _altura: float = 0.0
var _piezas: int = 0

var punto_inicio: Vector3 = Vector3.ZERO
var centros_arena: Dictionary = {}


func _ready() -> void:
	construir()


func construir() -> void:
	for hijo in get_children():
		hijo.queue_free()
	_origen = Vector3.ZERO
	_direccion = Vector3.FORWARD
	_altura = 0.0
	_piezas = 0
	# Un par de metros DENTRO del primer tramo: el recorrido arranca en el
	# origen y avanza hacia −Z, así que empezar en +Z es empezar en el aire.
	# La altura es la cara superior de la losa (grosor/2) más un margen.
	punto_inicio = Vector3(0.0, grosor_suelo * 0.5 + 0.8, -2.5)

	# Se recorre con índice, no con `for`, porque una arena necesita mirar el
	# paso siguiente: si detrás viene un giro, su salida va en la dirección YA
	# girada. Sin eso el hueco del anillo queda en el lado contrario al pasillo
	# y la arena se convierte en una trampa sin salida.
	var i := 0
	while i < RECORRIDO.size():
		var paso := RECORRIDO[i]
		match paso.get("tipo", ""):
			"pasillo":
				_pasillo(paso)
			"giro":
				_direccion = _direccion.rotated(Vector3.UP, deg_to_rad(paso["grados"]))
			"arena":
				var salida := _direccion
				var consumido := false
				if i + 1 < RECORRIDO.size() and RECORRIDO[i + 1].get("tipo", "") == "giro":
					salida = _direccion.rotated(
						Vector3.UP, deg_to_rad(RECORRIDO[i + 1]["grados"]))
					consumido = true
				_arena(paso, salida)
				_direccion = salida
				if consumido:
					i += 1
		i += 1

	print("[Nivel] blockout construido: %d piezas, %d arenas" % [
		_piezas, centros_arena.size()])


# --- Tramos --------------------------------------------------------------------

func _pasillo(paso: Dictionary) -> void:
	var largo: float = paso["largo"]
	var ancho: float = paso["ancho"]
	var subida: float = paso.get("subida", 0.0)
	var centro := _origen + _direccion * (largo * 0.5) + Vector3.UP * (_altura + subida * 0.5)
	var giro := _giro_actual()

	# Un pasillo en cuesta se hace inclinando la losa: para el blockout es
	# suficiente y se recorre igual de bien que una rampa de verdad.
	var inclinacion := atan2(subida, largo) if subida > 0.0 else 0.0
	var largo_real := sqrt(largo * largo + subida * subida)

	_losa("Suelo", centro, Vector3(ancho, grosor_suelo, largo_real), color_suelo,
		giro, inclinacion)
	# Franja de camino, un pelo por encima para que no pelee con el suelo
	_losa("Camino", centro + Vector3.UP * (grosor_suelo * 0.5 + 0.02),
		Vector3(ancho_camino, 0.08, largo_real), color_camino, giro, inclinacion, false)

	var lado := _direccion.cross(Vector3.UP).normalized()
	for signo in [-1.0, 1.0]:
		_losa("Borde", centro + lado * signo * (ancho * 0.5 + ancho_borde * 0.5)
			+ Vector3.UP * (alto_borde * 0.5 + grosor_suelo * 0.5),
			Vector3(ancho_borde, alto_borde, largo_real), color_borde, giro, inclinacion)

	if paso.get("plataformas", false):
		_plataformas(largo, ancho)

	_origen += _direccion * largo
	_altura += subida


## Tres plataformas bajas alternando lados. Enseñan a saltar sin castigar:
## caerse no mata, solo devuelve al suelo del pasillo.
func _plataformas(largo: float, ancho: float) -> void:
	var lado := _direccion.cross(Vector3.UP).normalized()
	var giro := _giro_actual()
	for i in 3:
		var t := (float(i) + 1.0) / 4.0
		var signo := 1.0 if i % 2 == 0 else -1.0
		var centro := _origen + _direccion * (largo * t) \
			+ lado * signo * (ancho * 0.22) \
			+ Vector3.UP * (_altura + 0.55 + 0.25 * float(i))
		_losa("Plataforma", centro, Vector3(3.0, 0.5, 3.0), color_plataforma, giro)


func _arena(paso: Dictionary, salida_dir: Vector3) -> void:
	var radio: float = paso["radio"]
	var centro := _origen + _direccion * radio + Vector3.UP * _altura
	var nombre: String = paso.get("nodo", "")

	_disco("SueloArena", centro, radio, color_arena)

	# Anillo con dos huecos: por donde se entra y por donde se sale. El ángulo
	# es el POLAR del anillo (posición `(cos θ, 0, sin θ)`), no una rotación:
	# se entra por el punto opuesto al avance y se sale por el de la dirección
	# siguiente, que puede no ser la misma si hay un giro de por medio.
	var entrada := atan2(-_direccion.z, -_direccion.x)
	var salida := atan2(salida_dir.z, salida_dir.x)
	_anillo(centro, radio, [entrada, salida])

	if nombre != "":
		centros_arena[nombre] = centro
		_colocar_arena(nombre, centro, radio)

	_origen = centro + salida_dir * radio


## Mueve el `Arena` de la escena a su sitio y le ajusta el tamaño.
##
## Las oleadas y los enemigos se siguen configurando en el inspector; lo único
## que manda desde aquí es dónde está y cómo de grande es, que es justo lo que
## tiene que cuadrar con la geometría.
func _colocar_arena(nombre: String, centro: Vector3, radio: float) -> void:
	var arena := get_parent().get_node_or_null(nombre) as Arena
	if arena == null:
		push_warning("ConstructorNivel: no encuentro el nodo de arena '%s'" % nombre)
		return
	arena.global_position = centro
	arena.barrier_radius = radio
	arena.spawn_radius = radio * 0.68
	var forma := arena.get_node_or_null("Shape") as CollisionShape3D
	if forma != null and forma.shape is CylinderShape3D:
		var cilindro := forma.shape as CylinderShape3D
		cilindro.radius = radio * 0.55
		cilindro.height = 4.0


# --- Piezas --------------------------------------------------------------------

func _losa(nombre: String, centro: Vector3, tam: Vector3, color: Color,
		giro: float, inclinacion: float = 0.0, con_colision: bool = true) -> void:
	var malla := BoxMesh.new()
	malla.size = tam

	var visual := MeshInstance3D.new()
	visual.mesh = malla
	visual.material_override = _material(color)

	if not con_colision:
		visual.name = nombre
		visual.position = centro
		visual.rotation = Vector3(inclinacion, giro, 0.0)
		add_child(visual)
		_piezas += 1
		return

	var cuerpo := StaticBody3D.new()
	cuerpo.name = nombre
	cuerpo.position = centro
	cuerpo.rotation = Vector3(inclinacion, giro, 0.0)
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	cuerpo.add_child(visual)

	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = tam
	forma.shape = caja
	cuerpo.add_child(forma)

	add_child(cuerpo)
	_piezas += 1


func _disco(nombre: String, centro: Vector3, radio: float, color: Color) -> void:
	var malla := CylinderMesh.new()
	malla.top_radius = radio
	malla.bottom_radius = radio
	malla.height = grosor_suelo
	malla.radial_segments = 24

	var visual := MeshInstance3D.new()
	visual.mesh = malla
	visual.material_override = _material(color)

	var cuerpo := StaticBody3D.new()
	cuerpo.name = nombre
	cuerpo.position = centro
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	cuerpo.add_child(visual)

	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = radio
	cilindro.height = grosor_suelo
	forma.shape = cilindro
	cuerpo.add_child(forma)

	add_child(cuerpo)
	_piezas += 1


## Borde de la arena, en segmentos, saltándose los que caen en los accesos.
func _anillo(centro: Vector3, radio: float, aberturas: Array) -> void:
	var segmentos := 24
	var ancho_seg := TAU * radio / float(segmentos) * 1.06
	for i in segmentos:
		var angulo := TAU * float(i) / float(segmentos)
		var libre := false
		for hueco in aberturas:
			var diferencia: float = absf(angle_difference(angulo, hueco))
			if diferencia < deg_to_rad(hueco_acceso) * 0.5:
				libre = true
				break
		if libre:
			continue
		var pos := centro + Vector3(cos(angulo), 0.0, sin(angulo)) * radio \
			+ Vector3.UP * (alto_borde * 0.5 + grosor_suelo * 0.5)
		# El segmento tiene que quedar TANGENTE al círculo: su eje largo (X)
		# a lo largo del borde y su cara ancha mirando al centro. Rotando `Y`
		# un ángulo φ, el eje Z local va a (sin φ, 0, cos φ); igualándolo a la
		# normal del círculo (cos θ, 0, sin θ) sale φ = 90° − θ. Con `−θ` a
		# secas los paneles quedan radiales, como los radios de una rueda.
		_losa("BordeArena", pos, Vector3(ancho_seg, alto_borde, ancho_borde),
			color_borde, PI * 0.5 - angulo)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material


func _giro_actual() -> float:
	return atan2(-_direccion.x, -_direccion.z)
