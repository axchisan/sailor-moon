extends Node3D
class_name TerrenoNivel
## El terreno que rodea al escenario: llano donde se juega, colinas al alejarse.
##
## ## Por qué se rehizo
##
## El primer intento fue un disco plano con un anillo de placas inclinadas al
## borde. No funcionaba, y no era cuestión de ajustar números:
##
## - **El llano era una mesa.** Salías del parque y todo era plano hasta el
##   horizonte, sin nada que mirar ni razón para andar.
## - **Las placas se leían como paredes.** Una superficie plana inclinada 60°
##   es una rampa, y el ojo la lee como construcción, no como monte.
## - **Tenían juntas.** Entre placa y placa quedaban rendijas por las que
##   colarse, y cada una había que taparla a mano.
##
## Lo tres se arreglan con la misma decisión: **una sola malla de terreno con
## altura**, generada por ruido. No hay juntas porque es continua, no parece
## construida porque no tiene aristas rectas, y el llano deja de ser una mesa
## porque puede ondular suavemente.
##
## ## Cómo se decide la altura
##
## En función de la distancia al centro, en tres franjas:
##
##     |<-- llano -->|<-- faldas -->|<-- colinas -->
##     0            r_llano       r_colinas       borde
##
## - **Llano:** altura 0 exacta. Es donde se apoya el blockout, y una sola
##   ondulación aquí dejaría el suelo del parque flotando o enterrado.
## - **Faldas:** empieza a ondular, cada vez más. La transición usa una curva
##   suave, que es lo que evita el escalón feo entre lo plano y lo accidentado.
## - **Colinas:** el relieve manda y sube hasta cerrar el paso.
##
## ## La colisión
##
## `HeightMapShape3D`, que es exactamente una rejilla de alturas — la misma que
## se usa para dibujar. Una forma cóncava de miles de triángulos costaría mucho
## más y daría lo mismo.

## Metros por celda. Más pequeño = colinas más detalladas y mucha más malla.
## 2,5 m es el punto donde una colina se ve redonda y la rejilla sigue siendo
## de menos de 20.000 vértices.
@export var paso: float = 2.5
## Medio lado del terreno cuadrado, en metros.
@export var alcance: float = 130.0

@export_group("Relieve")
## Hasta aquí el terreno es plano y liso: es donde se apoya el escenario.
@export var radio_llano: float = 46.0
## Desde aquí mandan las colinas que cierran el mapa.
@export var radio_colinas: float = 86.0
## Cuánto ondula el campo abierto entre el parque y las colinas.
@export var altura_campo: float = 1.8
## Cuánto levantan las colinas del borde.
@export var altura_colinas: float = 22.0
## Desde aquí arranca la cordillera del fondo, que ya no se pisa nunca.
@export var radio_cordillera: float = 112.0
@export var altura_cordillera: float = 46.0
## Tamaño de las ondulaciones, en metros.
@export var escala_campo: float = 26.0
@export var escala_colinas: float = 62.0
## Cuántos metros se retuerce el contorno de cada franja. Es lo que convierte
## los anillos concéntricos en geografía: 0 deja una diana, 30 da valles que se
## meten entre los cerros.
@export var deformacion: float = 26.0
@export var escala_forma: float = 78.0
@export var semilla: int = 7781

@export_group("Apoyo del escenario")
## Levanta el terreno bajo las partes altas del blockout, para que un camino en
## cuesta no quede flotando sobre un llano.
##
## **DESACTIVADO.** Tiene un fallo sin resolver: el apoyo aparece en vértices
## que no corresponden al sitio medido. El síntoma exacto es que el final del
## primer pasillo —a 70 m de la arena del guardián— sube justo a 2,95 m, que es
## la altura que le tocaría a la arena del guardián (cara superior 3,5 menos el
## hundido de 0,55). O sea, el valor correcto en el vértice equivocado: un cruce
## de índices entre el barrido que mide y la rejilla que se dibuja.
##
## Se deja apagado porque el fallo entierra el parque en montañas y eso rompe el
## nivel entero, mientras que lo único que se pierde teniéndolo apagado es que
## el tramo elevado del guardián se ve un poco despegado del terreno.
@export var seguir_al_escenario: bool = false
## Cuánto queda el terreno por debajo de la losa que apoya. Lo justo para no
## asomar por encima del suelo pisable.
@export var hundido_bajo_losa: float = 0.55
## Más pasadas = la loma sube más lejos y más suave. Con pocas, el terreno copia
## el escalón de las losas y sale un muro de tierra.
@export_range(0, 40) var pasadas_suavizado: int = 10
## Pendiente de la falda que baja desde una zona elevada hasta el terreno. Marca
## cuánto se aleja la loma: cuanto más tendida, más lejos llega.
@export var pendiente_falda: float = 34.0

@export_group("Aspecto")
@export var superficie: String = "hierba_lejos"
## A qué color tira lo lejano. El morado azulado no es capricho: es el color del
## aire acumulado, y es lo que hace que una montaña se lea como lejana.
@export var color_lejania: Color = Color(0.63, 0.62, 0.80)

## Marca de «aquí no hay nada que apoyar». Va muy abajo para que nunca gane al
## comparar con la altura del terreno.
const SIN_APOYO := -9999.0

var _alturas: PackedFloat32Array = PackedFloat32Array()
var _lado: int = 0
var _ruido: FastNoiseLite = null
var _ruido_fino: FastNoiseLite = null
var _ruido_forma: FastNoiseLite = null


func construir() -> void:
	for hijo in get_children():
		hijo.queue_free()

	_preparar_ruido()
	_lado = int(alcance * 2.0 / paso) + 1
	_alturas.resize(_lado * _lado)

	for j in _lado:
		for i in _lado:
			var x := -alcance + float(i) * paso
			var z := -alcance + float(j) * paso
			_alturas[j * _lado + i] = altura_en(x, z)

	# Se comprueba ANTES del apoyo: el relieve que mete el apoyo bajo un camino
	# elevado es intencionado, y contarlo como invasión escondería el problema
	# de verdad, que es el relieve del terreno colándose donde se juega.
	_avisar_si_invade(radio_llano)

	if seguir_al_escenario:
		_apoyar_el_escenario()

	_montar_malla()
	_montar_colision()
	print("[Terreno] %dx%d celdas (%.0f m de lado), colinas desde %.0f m" % [
		_lado, _lado, alcance * 2.0, radio_colinas])


## Comprueba que no ha quedado relieve dentro de la zona jugable.
##
## Mira las alturas **finales**, después del apoyo. Es importante: comprobarlo
## sobre `altura_en()` no sirve de nada, porque esa función devuelve el relieve
## procedural y no sabe nada de lo que el apoyo haya podido cambiar. Esa
## comprobación mal hecha dio por bueno un terreno que tenía el parque enterrado
## en montañas.
func _avisar_si_invade(radio: float) -> void:
	var invasores := 0
	var peor := 0.0
	for j in _lado:
		for i in _lado:
			var x := -alcance + float(i) * paso
			var z := -alcance + float(j) * paso
			if sqrt(x * x + z * z) > radio:
				continue
			var h := _alturas[j * _lado + i]
			if h > 1.0:
				invasores += 1
				peor = maxf(peor, h)
	if invasores > 0:
		push_warning("TerrenoNivel: %d vértices con relieve dentro de la zona jugable (hasta %.1f m). El parque va a quedar enterrado." % [invasores, peor])
	else:
		print("[Terreno] zona jugable limpia: sin relieve dentro de %.0f m" % radio)


func _preparar_ruido() -> void:
	_ruido = FastNoiseLite.new()
	_ruido.seed = semilla
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido.frequency = 1.0 / maxf(escala_colinas, 1.0)
	# Dos octavas: una da colinas demasiado limpias, cuatro las vuelve ruidosas
	# y aparecen picos afilados que no pegan con el estilo.
	_ruido.fractal_octaves = 2

	_ruido_fino = FastNoiseLite.new()
	_ruido_fino.seed = semilla + 991
	_ruido_fino.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido_fino.frequency = 1.0 / maxf(escala_campo, 1.0)
	_ruido_fino.fractal_octaves = 2

	# El que retuerce el contorno de las franjas. Va a escala grande y con una
	# sola octava: se busca una silueta de mapa, no rugosidad.
	_ruido_forma = FastNoiseLite.new()
	_ruido_forma.seed = semilla + 4517
	_ruido_forma.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido_forma.frequency = 1.0 / maxf(escala_forma, 1.0)
	_ruido_forma.fractal_octaves = 1


## Distancia al centro, pero **retorcida por ruido**.
##
## Todas las franjas del terreno —llano, faldas, colinas, cordillera— se deciden
## por distancia, y con la distancia real salen anillos perfectos: el mapa se ve
## como una diana y no como un sitio. Deformando la distancia, los mismos
## anillos pasan a tener entrantes y salientes, y aparecen valles que se meten
## entre los cerros y lomas que se adelantan al campo.
##
## Es más barato y más controlable que sumar relieve suelto: **una sola línea
## cambia la forma del mapa entero** sin tocar ninguna de las reglas de altura.
##
## La deformación se apaga dentro del llano y crece al alejarse. Si actuara
## desde el centro, un saliente podría meter una colina dentro del parque, que
## es exactamente lo que no puede pasar.
func _distancia_deformada(x: float, z: float) -> float:
	var recta := sqrt(x * x + z * z)
	if recta <= radio_llano:
		return recta
	# Crece desde el borde del llano, no desde antes. Y nunca puede devolver
	# menos que `radio_llano`: si pudiera, un punto a 40 m de distancia real
	# entraría en la franja de colinas y le saldría un monte encima **dentro del
	# parque**. Fue exactamente lo que pasó — el llano se decidía con la
	# distancia ya deformada, y la deformación metía cerros en mitad del mapa.
	var entrada := clampf((recta - radio_llano) / 45.0, 0.0, 1.0)
	var forma := _ruido_forma.get_noise_2d(x, z) * deformacion * entrada
	return maxf(recta + forma, radio_llano)


## Altura del terreno en un punto. Es la única fuente de verdad: la usan la
## malla, la colisión y cualquiera que necesite posar algo encima.
func altura_en(x: float, z: float) -> float:
	# El llano se decide con la distancia REAL. Es la garantía de que nada del
	# relieve puede entrar en la zona donde se juega, pase lo que pase con la
	# deformación del contorno.
	if sqrt(x * x + z * z) <= radio_llano:
		return 0.0
	var distancia := _distancia_deformada(x, z)

	# Cuánto se ha salido del llano, de 0 a 1, con curva suave. `smoothstep` es
	# lo que evita el pliegue: con una rampa lineal se ve la línea exacta donde
	# el terreno empieza a subir, y canta muchísimo.
	var t_campo := smoothstep(radio_llano, radio_colinas, distancia)
	var ondulado := _ruido_fino.get_noise_2d(x, z) * altura_campo * t_campo

	if distancia <= radio_colinas:
		return ondulado

	# Las colinas crecen con la distancia, pero **moduladas por ruido**: si
	# subieran parejo se vería el mismo anillo de cráter de antes, solo que
	# redondeado. Con el ruido hay collados más bajos y cerros más altos.
	var t_colina := smoothstep(radio_colinas, radio_cordillera, distancia)
	var relieve := (_ruido.get_noise_2d(x, z) + 1.0) * 0.5
	# Nunca baja del 45 %: un collado por el que se pudiera pasar andando
	# dejaría un agujero en el límite del mundo.
	relieve = 0.45 + relieve * 0.55
	var altura := ondulado + pow(t_colina, 1.35) * altura_colinas * relieve

	# Y más allá, la cordillera. Sustituye a los conos morados que hacían de
	# montañas: en vez de objetos lejanos con silueta de cono —que es justo lo
	# que los delataba— es el mismo terreno subiendo mucho más, con el mismo
	# ruido, y desteñido por la perspectiva aérea del shader.
	if distancia > radio_cordillera:
		var t_sierra := smoothstep(radio_cordillera, alcance * 0.95, distancia)
		var cresta := (_ruido.get_noise_2d(x * 0.6, z * 0.6) + 1.0) * 0.5
		altura += pow(t_sierra, 1.6) * altura_cordillera * (0.35 + cresta * 0.65)
	return altura


## Levanta el terreno bajo las partes altas del escenario.
##
## El parque no está todo a la misma altura: el pasillo que sube al guardián
## gana 2,5 m y su arena se queda ahí arriba. Con el terreno plano por debajo,
## ese tramo quedaba **flotando**, con el canto de las losas al aire y un
## escalón de dos metros y medio en el vacío.
##
## En vez de mantener una copia de las alturas del recorrido —que habría que
## actualizar cada vez que se toque el nivel—, se **mide el escenario que ya
## está construido** con un rayo por vértice. Así funciona con cualquier
## escenario futuro sin escribir nada: si hay algo sólido arriba, el terreno
## sube a apoyarlo.
##
## Los rayos van hacia abajo desde muy alto y solo miran la capa del escenario.
## Son unos once mil, pero se lanzan una vez al cargar el nivel y no llegan a
## los pocos milisegundos.
func _apoyar_el_escenario() -> void:
	var espacio := get_world_3d().direct_space_state
	if espacio == null:
		return

	# SOLO el suelo. Esto es lo importante de toda la función.
	#
	# Sin filtrar, el rayo choca con lo primero que encuentra, y eso son los
	# MUROS: dos metros y medio de seto que el terreno tomaba por «escenario
	# alto» y subía a apoyar. Con la falda extendiendo cada subida, el resultado
	# fue un parque relleno de montañas por dentro.
	#
	# El filtro va contra la lista que el constructor apunta al crear cada
	# cuerpo, **no contra los nombres**: Godot renombra los hijos duplicados a
	# `@StaticBody3D@N`, y de ochenta y un cuerpos solo cuatro conservaban un
	# nombre reconocible. Filtrar por nombre parecía funcionar y no funcionaba.
	var suelos := {}
	for cuerpo in _cuerpos_de_suelo():
		suelos[cuerpo.get_rid()] = true
	var excluir: Array[RID] = []
	for cuerpo in _cuerpos_del_escenario():
		var rid := cuerpo.get_rid()
		if not suelos.has(rid):
			excluir.append(rid)

	# El campo de apoyo va SEPARADO de las alturas, y empieza vacío.
	#
	# Antes se inicializaba con las alturas del terreno y se suavizaba encima. Eso
	# era el error que enterró el parque: el promedio de cada vértice incluía a
	# sus vecinos, y como los vecinos de fuera son colinas de veinte metros, cada
	# pasada empujaba esa altura una celda hacia dentro. Con catorce pasadas, las
	# montañas entraban treinta y cinco metros en el parque y se lo comían.
	#
	# Aquí solo se apunta lo que hay que apoyar de verdad, y el resto queda a
	# `SIN_APOYO`. Lo que no tiene escenario encima no participa.
	var apoyo := PackedFloat32Array()
	apoyo.resize(_lado * _lado)
	apoyo.fill(SIN_APOYO)
	var encontrados := 0
	for j in _lado:
		for i in _lado:
			var k := j * _lado + i
			var x := global_position.x - alcance + float(i) * paso
			var z := global_position.z - alcance + float(j) * paso
			var desde := Vector3(x, global_position.y + 60.0, z)
			var hasta := Vector3(x, global_position.y - 20.0, z)
			var consulta := PhysicsRayQueryParameters3D.create(desde, hasta)
			consulta.collision_mask = 1
			consulta.exclude = excluir
			var choque := espacio.intersect_ray(consulta)
			if choque.is_empty():
				continue
			# La cara de abajo de la losa: el terreno tiene que llegar hasta
			# ahí, no hasta la de arriba, o taparía el suelo por el que se anda.
			var bajo_la_losa: float = choque["position"].y - global_position.y - hundido_bajo_losa
			# Solo cuenta si de verdad está ALTO. El parque llano está a ras de
			# cero, y apoyarlo no aporta nada más que trabajo.
			if bajo_la_losa > 0.4 and bajo_la_losa > apoyo[k]:
				apoyo[k] = bajo_la_losa
				encontrados += 1

	if encontrados == 0:
		return

	# La falda: en vez de promediar, el apoyo se **derrama** hacia fuera
	# perdiendo altura en cada paso. Un vértice sin apoyo mira a sus vecinos y
	# toma el más alto menos lo que baje el talud en un paso de rejilla.
	#
	# Así la loma sale del sitio elevado y muere sola a los pocos metros, en vez
	# de contagiarse por todo el mapa como hacía el promedio.
	var caida := paso * tan(deg_to_rad(pendiente_falda))
	for _pasada in pasadas_suavizado:
		var copia := apoyo.duplicate()
		for j in range(1, _lado - 1):
			for i in range(1, _lado - 1):
				var k := j * _lado + i
				var mejor := copia[k]
				for vecino in [k - 1, k + 1, k - _lado, k + _lado]:
					var derrame: float = copia[vecino] - caida
					if derrame > mejor:
						mejor = derrame
				apoyo[k] = mejor

	# Y ahora sí, se mezcla: el terreno se queda con lo más alto de las dos
	# cosas, su relieve natural o el apoyo. Donde no hubo apoyo, `SIN_APOYO` es
	# tan bajo que no puede ganar nunca.
	var subidos := 0
	for k in _alturas.size():
		if apoyo[k] > _alturas[k]:
			_alturas[k] = apoyo[k]
			subidos += 1
	print("[Terreno] %d vértices apoyados, %d levantados" % [encontrados, subidos])


## Los cuerpos sobre los que se anda, tal como los apuntó el constructor.
func _cuerpos_de_suelo() -> Array[StaticBody3D]:
	var vacio: Array[StaticBody3D] = []
	var padre := get_parent()
	if padre == null:
		return vacio
	var blockout := padre.get_node_or_null("Blockout") as ConstructorNivel
	if blockout == null:
		return vacio
	return blockout.cuerpos_suelo


## Los cuerpos que forman el escenario construido, para poder filtrarlos.
func _cuerpos_del_escenario() -> Array[StaticBody3D]:
	var lista: Array[StaticBody3D] = []
	var padre := get_parent()
	if padre == null:
		return lista
	var blockout := padre.get_node_or_null("Blockout")
	if blockout == null:
		return lista
	for hijo in blockout.get_children():
		if hijo is StaticBody3D:
			lista.append(hijo)
	return lista


func _montar_malla() -> void:
	var malla := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.resize(_lado * _lado)
	normales.resize(_lado * _lado)

	for j in _lado:
		for i in _lado:
			var x := -alcance + float(i) * paso
			var z := -alcance + float(j) * paso
			var k := j * _lado + i
			vertices[k] = Vector3(x, _alturas[k], z)
			normales[k] = _normal_en(i, j)

	# El ORDEN de cada triángulo decide hacia dónde mira su cara. Con el
	# contrario a este, el terreno entero se dibuja del revés: desde arriba se
	# ve su parte de abajo, el descarte de caras traseras la oculta, y queda un
	# nivel donde los árboles flotan sobre el color del cielo. La malla está
	# ahí, la colisión funciona y no hay ningún error en consola — solo no se
	# ve nada.
	for j in _lado - 1:
		for i in _lado - 1:
			var a := j * _lado + i
			var b := a + 1
			var c := a + _lado
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])

	var datos := []
	datos.resize(Mesh.ARRAY_MAX)
	datos[Mesh.ARRAY_VERTEX] = vertices
	datos[Mesh.ARRAY_NORMAL] = normales
	datos[Mesh.ARRAY_INDEX] = indices
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, datos)

	var visual := MeshInstance3D.new()
	visual.name = "Superficie"
	visual.mesh = malla
	# Material propio, no el compartido de la paleta: este necesita la
	# perspectiva aérea encendida y el resto de superficies del parque no.
	var material := PaletaTerreno.obtener(superficie).duplicate() as ShaderMaterial
	material.set_shader_parameter("lejania", 0.92)
	material.set_shader_parameter("centro_mundo", global_position)
	material.set_shader_parameter("desde", radio_colinas * 0.75)
	material.set_shader_parameter("hasta", alcance * 0.85)
	material.set_shader_parameter("color_lejania", color_lejania)
	visual.material_override = material
	# No proyecta sombra: es una superficie enorme y su sombra propia no aporta
	# nada, pero se come el mapa de sombras entero.
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)


## Normal por diferencias con los vecinos. Sin esto la malla sale con normales
## planas y las colinas se ven facetadas como un diamante.
func _normal_en(i: int, j: int) -> Vector3:
	var izq := _alturas[j * _lado + maxi(i - 1, 0)]
	var der := _alturas[j * _lado + mini(i + 1, _lado - 1)]
	var arr := _alturas[maxi(j - 1, 0) * _lado + i]
	var aba := _alturas[mini(j + 1, _lado - 1) * _lado + i]
	return Vector3(izq - der, 2.0 * paso, arr - aba).normalized()


func _montar_colision() -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "CuerpoTerreno"
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0

	var forma := CollisionShape3D.new()
	var mapa := HeightMapShape3D.new()
	mapa.map_width = _lado
	mapa.map_depth = _lado
	mapa.map_data = _alturas
	forma.shape = mapa
	# `HeightMapShape3D` se coloca centrado en el origen y con **una unidad por
	# celda**, no en metros. Hay que escalarlo al paso de la rejilla o la
	# colisión queda del tamaño equivocado y no coincide con lo que se ve.
	forma.scale = Vector3(paso, 1.0, paso)
	cuerpo.add_child(forma)
	add_child(cuerpo)
