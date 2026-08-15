extends Node3D
class_name Repechos
## Los sitios altos del parque: rocas y muretes a los que se puede trepar.
##
## ## Por qué existen
##
## Trepar cornisas está hecho y probado desde la Fase E, y **el parque no tenía
## un solo sitio donde usarlo**. La única plataforma queda a 0,7 m, por debajo
## del mínimo agarrable. Una mecánica que no tiene dónde usarse es trabajo tirado
## y, peor, una promesa que el escenario no cumple.
##
## ## Las tres reglas
##
## 1. **Dentro del rango que se agarra**: de 1,3 a 2,1 m. El jugador agarra entre
##    1,0 y 2,3 (`alto_cornisa_min` y `alto_cornisa_max`), y ceñirse al centro
##    del rango evita que un repecho quede inagarrable por medio palmo de
##    terreno inclinado.
## 2. **Siempre hay algo arriba.** Trepar a un sitio vacío se hace una vez y no
##    se repite. Arriba hay una Estrella, un corazón o —cuando no toca premio—
##    algo que mirar.
## 3. **Van en las explanadas vacías**, no junto al camino. Son la razón para
##    salirse, y puestos al lado del recorrido no hacen desviarse a nadie.
##
## ## Por qué son cajas y no rocas
##
## La cornisa se agarra por un canto horizontal. Una roca de silueta irregular
## no tiene canto: el rayo que busca el borde encuentra una pendiente y no se
## agarra nada. Así que debajo hay una caja de piedra, y encima rocas sueltas
## que le quitan la cara de cubo sin tocar la parte por la que se sube.

## De cuánto a cuánto miden. El rango agarrable es 1,0-2,3, y esto va por dentro.
const ALTO_MIN := 1.3
const ALTO_MAX := 2.1

## Cuántos se intentan colocar.
const CUANTOS := 9
## A qué distancia del centro del parque se buscan sitios.
const DESDE := 30.0
const HASTA := 74.0
## Cuánto tienen que estar separados entre ellos y de todo lo demás.
const AIRE := 11.0

const ROCA := preload("res://assets/models/props/roca.glb")
const LOSA := preload("res://assets/models/props/losa_sendero.glb")

var puestos: Array[Vector3] = []


## Los siembra. `constructor` decide si un sitio está libre; `decorador` da el
## suelo. Devuelve las cimas, para que el nivel ponga algo encima.
func sembrar(constructor: ConstructorNivel, decorador: DecoradorNivel,
		centro: Vector3) -> Array[Vector3]:
	var dado := RandomNumberGenerator.new()
	# Semilla fija: el parque sale igual en cada partida. Un escenario que se
	# recoloca solo hace imposible decir «el de al lado del estanque».
	dado.seed = 71042
	var cimas: Array[Vector3] = []

	for i in CUANTOS:
		var sitio := _buscar_sitio(constructor, decorador, centro, dado)
		if sitio == Vector3.INF:
			continue
		var alto := dado.randf_range(ALTO_MIN, ALTO_MAX)
		var ancho := dado.randf_range(2.4, 3.6)
		var fondo := dado.randf_range(2.2, 3.2)
		var giro := dado.randf() * TAU
		cimas.append(_levantar(sitio, Vector3(ancho, alto, fondo), giro, dado))
		puestos.append(sitio)

	_senderillos(constructor, decorador, centro, dado)
	print("[Repechos] %d sitios altos y %d senderillos" % [puestos.size(), _sendas])
	return cimas


## SENDERILLOS QUE NO LLEVAN A NINGUNA PARTE.
##
## Las explanadas se cruzaban corriendo porque no había nada que sugiriera por
## dónde. Un rastro de losas medio comidas por la hierba no obliga a nada —no es
## un camino de verdad, no lleva a un objetivo— pero **da una dirección**, y una
## dirección es motivo suficiente para desviarse a ver qué hay.
##
## Salen de un repecho y se van hacia el campo: así lo que se encuentra al
## seguirlos es el sitio alto, sin que nadie lo haya señalado.
var _sendas: int = 0


func _senderillos(constructor: ConstructorNivel, decorador: DecoradorNivel,
		centro: Vector3, dado: RandomNumberGenerator) -> void:
	for arranque in puestos:
		if dado.randf() > 0.75:
			continue
		# Hacia fuera del parque, que es a donde no va nadie.
		var rumbo := (arranque - centro)
		rumbo.y = 0.0
		if rumbo.length_squared() < 1.0:
			continue
		rumbo = rumbo.normalized().rotated(Vector3.UP, dado.randf_range(-0.9, 0.9))

		var donde := arranque
		var puestas := 0
		for paso in 14:
			donde += rumbo * dado.randf_range(1.7, 2.6)
			rumbo = rumbo.rotated(Vector3.UP, dado.randf_range(-0.22, 0.22))
			var suelo := constructor.posar_en_el_terreno(donde, 0.0)
			if is_inf(suelo.y):
				break
			if decorador.pisa_el_recorrido_publico(suelo) \
					or decorador.moja_publico(suelo, 1.4, 2.0):
				break
			var l := LOSA.instantiate() as Node3D
			if l == null:
				break
			add_child(l)
			# Medio hundidas y giradas al azar: alineadas y a ras se leen como un
			# camino oficial, y esto es un atajo que ha hecho la gente pisando.
			l.global_position = suelo + Vector3.DOWN * dado.randf_range(0.02, 0.09)
			l.rotation.y = dado.randf() * TAU
			l.scale = Vector3.ONE * dado.randf_range(0.75, 1.15)
			puestas += 1
		if puestas > 3:
			_sendas += 1


func _buscar_sitio(constructor: ConstructorNivel, decorador: DecoradorNivel,
		centro: Vector3, dado: RandomNumberGenerator) -> Vector3:
	for intento in 60:
		var ang := dado.randf() * TAU
		var d := dado.randf_range(DESDE, HASTA)
		var p := centro + Vector3(cos(ang), 0.0, sin(ang)) * d
		p = constructor.posar_en_el_terreno(p, 0.0)
		if is_inf(p.y):
			continue
		# Ni encima del camino, ni en el agua, ni pegado a otra cosa, ni junto a
		# otro repecho: apelotonados dejan de ser un sitio y pasan a ser un muro.
		if decorador.pisa_el_recorrido_publico(p):
			continue
		if decorador.moja_publico(p, 1.4, 6.0):
			continue
		if decorador.estorbo_publico(p, 4.2):
			continue
		var cerca := false
		for otro in puestos:
			if otro.distance_to(p) < AIRE:
				cerca = true
				break
		if cerca:
			continue
		return p
	return Vector3.INF


## Levanta uno y devuelve el punto de encima, donde va el premio.
func _levantar(base: Vector3, tam: Vector3, giro: float,
		dado: RandomNumberGenerator) -> Vector3:
	# EL CANTO SE MIDE CONTRA EL PUNTO MÁS ALTO DE ALREDEDOR, NO CONTRA EL CENTRO.
	#
	# Con un hundido fijo, un repecho puesto donde el terreno sube por un lado
	# queda con el canto a 0,85 m por ese lado — por debajo del mínimo agarrable,
	# así que **no se puede trepar por donde uno se acerca**. Pasaba en tres de
	# los nueve, y solo se ve midiendo: a ojo los nueve parecen iguales.
	#
	# Midiendo el suelo en las cuatro esquinas y levantando la caja desde el
	# punto más alto, el canto queda en rango por todos los lados.
	var mas_alto := base.y
	for esquina in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var d := Vector3(esquina.x * tam.x * 0.5, 0.0,
			esquina.y * tam.z * 0.5).rotated(Vector3.UP, giro)
		var alto_ahi := _suelo_en(base + d)
		if not is_inf(alto_ahi):
			mas_alto = maxf(mas_alto, alto_ahi)

	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Repecho"
	# La cima acaba a `tam.y` sobre el punto más alto del contorno. Lo que sobre
	# por debajo se entierra, que además tapa cualquier hueco del desnivel.
	cuerpo.position = Vector3(base.x, mas_alto + tam.y * 0.5, base.z)
	cuerpo.rotation.y = giro
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	add_child(cuerpo)

	var malla := BoxMesh.new()
	malla.size = tam
	var visual := MeshInstance3D.new()
	visual.mesh = malla
	visual.material_override = PaletaTerreno.obtener("piedra")
	cuerpo.add_child(visual)

	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = tam
	forma.shape = caja
	cuerpo.add_child(forma)

	# ROCAS EN EL CANTO Y EN LA BASE, QUE ES DONDE SE VE EL CUBO.
	#
	# Una caja se delata por dos sitios: la arista de arriba y la línea recta
	# donde se junta con el suelo. Las de arriba van justo en el borde, mordiendo
	# la arista; las de abajo tapan la juntura, que es lo que más grita «esto es
	# un bloque puesto encima del césped».
	#
	# Ninguna en el centro de la cima: ahí es donde se cae al trepar y una roca
	# en medio convierte el premio en un tropiezo.
	var cima_y := tam.y * 0.5
	for i in dado.randi_range(5, 7):
		var r := ROCA.instantiate() as Node3D
		if r == null:
			continue
		cuerpo.add_child(r)
		var lado := dado.randf() * TAU
		r.position = Vector3(
			cos(lado) * tam.x * dado.randf_range(0.48, 0.58),
			cima_y - dado.randf_range(0.10, 0.45),
			sin(lado) * tam.z * dado.randf_range(0.48, 0.58))
		r.rotation = Vector3(dado.randf_range(-0.3, 0.3), dado.randf() * TAU,
			dado.randf_range(-0.3, 0.3))
		r.scale = Vector3.ONE * dado.randf_range(0.8, 1.5)

	for i in dado.randi_range(4, 6):
		var r := ROCA.instantiate() as Node3D
		if r == null:
			continue
		cuerpo.add_child(r)
		var lado := dado.randf() * TAU
		r.position = Vector3(
			cos(lado) * tam.x * dado.randf_range(0.5, 0.72),
			-cima_y + dado.randf_range(0.25, 0.7),
			sin(lado) * tam.z * dado.randf_range(0.5, 0.72))
		r.rotation = Vector3(dado.randf_range(-0.4, 0.4), dado.randf() * TAU,
			dado.randf_range(-0.4, 0.4))
		r.scale = Vector3.ONE * dado.randf_range(1.0, 1.8)

	return Vector3(base.x, mas_alto + tam.y, base.z)


## Dónde está el suelo en un punto. Devuelve INF si no hay nada debajo.
func _suelo_en(donde: Vector3) -> float:
	var espacio := get_world_3d().direct_space_state
	if espacio == null:
		return INF
	var q := PhysicsRayQueryParameters3D.create(
		donde + Vector3.UP * 6.0, donde + Vector3.DOWN * 14.0)
	q.collision_mask = 1
	var hit := espacio.intersect_ray(q)
	if hit.is_empty():
		return INF
	return float(hit["position"].y)
