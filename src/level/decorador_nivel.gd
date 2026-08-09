extends Node3D
class_name DecoradorNivel
## Viste el blockout: árboles y arbustos por los bordes, mobiliario de parque
## suelto y el fondo lejano de postal.
##
## Va aparte de `ConstructorNivel` a propósito. El constructor decide **por
## dónde se juega** y esto decide **qué se ve**; mezclarlos convierte cualquier
## retoque de recorrido en una pelea con la decoración. Aquí se puede borrar
## todo y el nivel se sigue jugando igual de bien, que es la prueba de que la
## separación está en el sitio correcto.
##
## ## Nada de esto tiene colisión
##
## Lo caminable ya lo definen los bordes del blockout. Dar cuerpo a un arbusto
## solo añade sitios donde quedarse enganchada; a los 8 años, tropezar con un
## seto invisible se lee como que el juego está roto. Los props van fuera del
## borde o pegados a él, así que nunca hace falta rodearlos.
##
## ## Por qué MultiMesh
##
## Ciento y pico árboles como `MeshInstance3D` sueltos son ciento y pico draw
## calls, y el presupuesto móvil son 150 para el nivel entero
## ([`01-ARQUITECTURA.md`](../../docs/01-ARQUITECTURA.md) §8). Agrupados por
## `MultiMeshInstance3D` son **una por trozo de malla**, da igual cuántos haya.

## De dónde salen las piezas del kit.
const CARPETA := "res://assets/models/props/"

## Cuánto se hunde el disco de hierba respecto del suelo del blockout, y a qué
## cota queda su cara de arriba (es donde se planta el fondo lejano).
##
## Un par de centímetros no bastan: a diez metros el z-buffer ya no distingue
## las dos superficies y el suelo aparece rayado.
const HUNDIDO_FALDON := 0.28
const COTA_FALDON := 0.5 - HUNDIDO_FALDON

## Todo lo que se siembra a lo largo de los tramos.
##
## `cada` son metros entre copias, `desvio` cuánto se le permite moverse al
## azar, `escala` el rango de tamaños y `fase` un desplazamiento a lo largo del
## tramo. `alterna` cambia de lado en cada copia.
##
## El desvío lateral se da de una de dos formas, y la diferencia importa:
##
## - `lado`: fracción del semiancho, para lo que va **dentro** del camino.
## - `fuera`: metros más allá del eje del muro, para lo que va **fuera**.
##
## Con `lado` para todo, un árbol a 1,5 semianchos cae a 5,25 m en el cruce
## (ancho 7) y a 6,75 m en un pasillo (ancho 9): en uno invade el camino y en
## el otro se esconde detrás del muro. En metros desde el muro queda igual en
## los dos, que es lo que se quiere.
##
## El azar es reproducible: misma semilla, mismo parque. Un parque que cambia
## en cada arranque hace imposible decir «la estrella está detrás del banco».
const SIEMBRA: Array[Dictionary] = [
	# Cerezos justo detrás del muro, en dos hileras. Son el techo del pasillo:
	# sin ellos el recorrido se lee como una zanja. A 1,6 m la copa asoma por
	# encima del borde sin meterse en el camino.
	{"pieza": "arbol_cerezo", "cada": 9.0, "fuera": 1.6, "desvio": 1.1,
		"escala": [0.85, 1.25], "alterna": false, "ambos_lados": true,
		"hundir": 0.15},
	# Segunda fila más atrás y más alta: da profundidad al bosque y tapa el
	# canto del faldón. Muy espaciada — con las dos filas juntas el camino
	# queda enterrado en un túnel rosa y no se ve nada de lo que hay delante.
	{"pieza": "arbol_cerezo", "cada": 15.0, "fuera": 5.4, "desvio": 2.2,
		"escala": [1.0, 1.4], "alterna": false, "ambos_lados": true,
		"hundir": 0.15, "fase": 0.37},
	# Arbustos pegados al borde por dentro, rompiendo la línea recta y tapando
	# la base del muro, que si no se lee como una pared de gimnasio
	{"pieza": "arbusto", "cada": 4.0, "lado": 0.9, "desvio": 0.35,
		"escala": [0.8, 1.35], "alterna": true},
	# Rocas sueltas, muchas y pequeñas
	{"pieza": "roca", "cada": 5.5, "lado": 0.66, "desvio": 0.9,
		"escala": [0.6, 1.3], "alterna": true},
	# Vallas por dentro, pegadas al muro: es lo que lo convierte en «linde de
	# parque» en vez de en pared de gimnasio. Encima del muro no valen — se
	# quedarían a 3,3 m del suelo, más altas que un seto y que la propia
	# jugadora. El giro extra es porque la pieza se modeló a lo largo de su eje
	# X y el rumbo del camino orienta el −Z; sin él sale una fila de vallas
	# cruzadas como aspas.
	{"pieza": "valla_madera", "cada": 3.0, "lado": 0.95, "desvio": 0.0,
		"escala": [1.0, 1.0], "alterna": false, "ambos_lados": true,
		"alinear": true, "girar": 90.0},
	# Mobiliario, poco y espaciado. Uno cada pocos metros no es un parque,
	# es un almacén de bancos. Las fases los separan entre sí: sin ellas, en un
	# tramo que solo admite una copia de cada, las tres caen en el mismo punto.
	{"pieza": "banco_parque", "cada": 13.0, "lado": 0.74, "desvio": 0.0,
		"escala": [1.0, 1.0], "alterna": true, "alinear": true,
		"mirar_dentro": true},
	{"pieza": "papelera", "cada": 21.0, "lado": 0.80, "desvio": 0.0,
		"escala": [1.0, 1.0], "alterna": true, "fase": 0.29},
	# Faroles de piedra: los decorativos, no los tres que hay que encender
	{"pieza": "farol_piedra", "cada": 11.0, "lado": 0.88, "desvio": 0.0,
		"escala": [0.9, 1.1], "alterna": true, "fase": 0.61},
	# --- Kit de expansión ---
	# Farolillos de papel jalonando el camino: de noche marcarán la senda, y de
	# día ya dicen «por aquí se va a algún sitio».
	{"pieza": "farolillo", "cada": 16.0, "fuera": 0.4, "desvio": 0.0,
		"escala": [1.0, 1.2], "alterna": false, "ambos_lados": true, "fase": 0.11},
	# Tocones y flores rompiendo el borde del camino
	{"pieza": "tocon", "cada": 19.0, "lado": 0.80, "desvio": 0.8,
		"escala": [0.9, 1.3], "alterna": true, "fase": 0.44},
	{"pieza": "macizo_flores", "cada": 5.0, "lado": 0.78, "desvio": 0.9,
		"escala": [0.8, 1.5], "alterna": true, "fase": 0.17},
]

## Lo que se siembra por el CAMPO ABIERTO, entre el parque y las colinas.
##
## Antes ahí no había nada: hierba y ya. Con cuatro rincones que visitar, ese
## espacio se recorre de verdad, y recorrer un descampado es aburrido por muy
## bonito que sea el horizonte.
##
## `desde` y `hasta` son metros desde el centro de lo construido: la franja
## donde puede caer cada cosa.
const CAMPO: Array[Dictionary] = [
	{"pieza": "roca_grande", "copias": 26, "desde": 50.0, "hasta": 82.0,
		"escala": [0.9, 1.9]},
	{"pieza": "macizo_flores", "copias": 120, "desde": 46.0, "hasta": 84.0,
		"escala": [0.9, 1.7]},
	{"pieza": "arbol_cerezo", "copias": 34, "desde": 52.0, "hasta": 80.0,
		"escala": [0.9, 1.4], "hundir": 0.15},
	{"pieza": "tocon", "copias": 22, "desde": 48.0, "hasta": 80.0,
		"escala": [0.9, 1.4]},
	{"pieza": "arbusto", "copias": 60, "desde": 46.0, "hasta": 84.0,
		"escala": [1.0, 1.8]},
	{"pieza": "farolillo", "copias": 18, "desde": 50.0, "hasta": 72.0,
		"escala": [1.0, 1.3]},
]

## Detalle menudo: lo que separa un suelo de un campo de golf.
##
## Va aparte del resto porque son MUCHAS copias de piezas diminutas, y porque se
## siembra por todo —camino incluido— en vez de respetar el recorrido: una
## brizna de hierba o cuatro piedrecitas en el borde del sendero es justo lo que
## hace que no parezca recién asfaltado.
##
## Todas son de menos de cien triángulos y van en multimalla, así que quinientas
## matas de hierba cuestan una sola llamada de dibujado.
const DETALLE: Array[Dictionary] = [
	{"pieza": "mata_hierba", "copias": 520, "desde": 6.0, "hasta": 84.0,
		"escala": [0.7, 1.6]},
	{"pieza": "piedrecitas", "copias": 190, "desde": 6.0, "hasta": 84.0,
		"escala": [0.7, 1.5]},
	{"pieza": "ramitas", "copias": 130, "desde": 8.0, "hasta": 80.0,
		"escala": [0.8, 1.4]},
	{"pieza": "hojarasca", "copias": 160, "desde": 6.0, "hasta": 78.0,
		"escala": [0.8, 1.7]},
]

## Lo que rodea a cada arena. Un anillo cerrado de cerezos: encierra la pelea
## sin necesidad de más muros, y de paso tapa lo que hay detrás.
const CORONA_ARENA: Array[Dictionary] = [
	{"pieza": "arbol_cerezo", "copias": 16, "margen": 3.4, "desvio": 1.6,
		"escala": [0.9, 1.3], "hundir": 0.15},
	{"pieza": "arbusto", "copias": 20, "margen": 1.6, "desvio": 0.8,
		"escala": [0.8, 1.3]},
	{"pieza": "roca", "copias": 10, "margen": 1.9, "desvio": 1.2,
		"escala": [0.7, 1.4]},
]

## Qué props tienen cuerpo y con qué forma.
##
## La regla no es «todo sólido»: es **sólido lo que en la vida real pararía a
## una niña de ocho años**. Un tronco para; una rama de flores no, y frenarse
## con un arbusto es de las cosas que más molestan de un juego.
##
## Por eso la copa del cerezo no aparece aquí y el tronco sí: la forma cubre
## solo el palo, y por las flores se pasa.
##
## `centro_y` es la altura del centro de la forma medida desde la base de la
## pieza, antes de escalar.
const CUERPO := {
	"arbol_cerezo": {"forma": "cilindro", "radio": 0.24, "alto": 2.1, "centro_y": 1.05},
	"cerezo_gigante": {"forma": "cilindro", "radio": 0.75, "alto": 5.0, "centro_y": 2.5},
	"roca": {"forma": "esfera", "radio": 0.40, "centro_y": 0.26},
	"banco_parque": {"forma": "caja", "tam": Vector3(1.75, 0.95, 0.62), "centro_y": 0.48},
	"papelera": {"forma": "cilindro", "radio": 0.30, "alto": 0.78, "centro_y": 0.39},
	"farol_piedra": {"forma": "cilindro", "radio": 0.33, "alto": 1.80, "centro_y": 0.90},
	"valla_madera": {"forma": "caja", "tam": Vector3(3.0, 1.15, 0.18), "centro_y": 0.57},
	"torii": {"forma": "caja", "tam": Vector3(0.55, 4.6, 0.55), "centro_y": 2.3},
	# El puente se atravesaba. La caja cubre el tablero entero y su cara de
	# arriba coincide con la tabla (0,30 en el modelo), no con la barandilla: si
	# se pone más alta se camina flotando un palmo por encima de la madera.
	"puente_madera": {"forma": "caja", "tam": Vector3(2.4, 0.6, 14.0), "centro_y": 0.0},
	"roca_grande": {"forma": "esfera", "radio": 1.25, "centro_y": 0.80},
	"tocon": {"forma": "cilindro", "radio": 0.52, "alto": 0.66, "centro_y": 0.33},
	"farolillo": {"forma": "cilindro", "radio": 0.10, "alto": 2.1, "centro_y": 1.05},
	# `macizo_flores` y `nenufar` no llevan: son plantas bajas, se pisan.
	# `arbusto` no está a propósito: son hojas, se pisan y se pasa.
}

## Lo que se planta al pie de la ladera que cierra el mundo.
##
## La ladera sola se lee como el borde de un cráter. Lo que la convierte en
## «linde del bosque» es lo que crece delante: una arboleda apretada que tapa la
## cuesta, y montones de rocas que rompen la curva.
##
## `dentro` son metros hacia el interior desde el pie de la cuesta — negativo
## para plantar cuesta arriba, que es lo que hace que el bosque suba por la
## ladera en vez de acabarse justo donde empieza.
const LIMITE: Array[Dictionary] = [
	# Tres filas de arboleda, cada vez más adentro y más pequeña. La de atrás
	# trepa por la cuesta (`dentro` negativo) para que el bosque no se corte de
	# golpe justo donde empieza la ladera.
	{"pieza": "arbol_cerezo", "copias": 54, "dentro": -3.0, "desvio": 2.2,
		"escala": [1.2, 1.8], "hundir": 0.2},
	{"pieza": "arbol_cerezo", "copias": 78, "dentro": 2.0, "desvio": 2.6,
		"escala": [1.2, 1.9], "hundir": 0.2},
	{"pieza": "arbol_cerezo", "copias": 52, "dentro": 7.5, "desvio": 4.0,
		"escala": [0.9, 1.5], "hundir": 0.2},
	# Pedregal al pie: rompe la línea donde el llano se junta con la cuesta,
	# que es justo donde se nota que la ladera es una superficie plana.
	{"pieza": "roca", "copias": 66, "dentro": 0.8, "desvio": 2.4,
		"escala": [1.6, 3.6]},
	{"pieza": "arbusto", "copias": 56, "dentro": 4.5, "desvio": 3.5,
		"escala": [1.1, 2.0]},
]

## El fondo. Nada de esto se pisa nunca: vive lejos, sin colisión y sin sombra.
##
## `radio` se cuenta desde el borde de lo construido, así que sigue quedando
## fuera aunque el nivel crezca. `arco` limita a qué parte del círculo va la
## pieza, en grados, para que la pagoda no aparezca cuatro veces alrededor.
const FONDO: Array[Dictionary] = [
	# Las montañas ya no van aquí: eran conos de seis lados y se les notaba.
	# Ahora las hace el propio terreno subiendo al fondo, con la misma forma
	# irregular que las colinas y desteñidas por la perspectiva aérea.
	{"pieza": "cerezo_gigante", "copias": 16, "radio": 24.0, "desvio": 14.0,
		"escala": [0.9, 1.6], "hundir": 0.6},
	# La pagoda se va a media falda, donde su silueta se recorta contra la
	# cordillera en vez de contra el cielo raso.
	{"pieza": "pagoda_lejana", "copias": 1, "radio": 46.0, "desvio": 0.0,
		"escala": [1.5, 1.5], "arco": [24.0, 24.0]},
	# Los torii ya no van aquí. Un torii es una PUERTA: puesto en dos sitios
	# cualesquiera del horizonte no significa nada, y encima se encaramaba a una
	# colina y quedaba torcido. Ahora hay uno solo, en la entrada del parque,
	# colocado por `_puerta_de_entrada()`.
]

@export_group("Interruptores")
## Para poder mirar el blockout en gris sin borrar nada.
@export var decorar_tramos: bool = true
@export var decorar_arenas: bool = true
@export var montar_fondo: bool = true

## Cuántos metros de respeto se le dejan al recorrido antes de sembrar nada del
## campo. Con poco, aparecen rocas pegadas al camino.
@export var margen_recorrido: float = 6.0

@export_group("Estanque")
@export var radio_estanque: float = 9.0
## Cuánto se cava el vaso del estanque en el terreno.
@export var hondura_vaso: float = 1.5
## Cuánto queda la lámina por debajo del nivel del suelo de alrededor. Poco: lo
## justo para que el agua tenga orilla y no acabe en un canto.
@export var calado: float = 0.35
## Dónde va, en metros desde el centro de lo construido y en grados.
@export var distancia_estanque: float = 62.0
@export var rumbo_estanque: float = 206.0

@export_group("Ajustes")
@export var semilla: int = 19920307
## Metros de hierba desde el borde de lo construido hacia fuera. Sin esto, los
## árboles plantados fuera del muro flotan sobre la nada.
##
## Tiene que pasarse de largo el fondo lejano, no solo cubrir el nivel: si el
## disco acaba antes que las montañas, se ve su canto recortado contra el cielo
## a media altura y el mundo se lee como una maqueta sobre una mesa.
@export var faldon: float = 210.0

var _rng := RandomNumberGenerator.new()
## Dónde está el agua, para que el resto de la siembra la esquive.
var _sitio_estanque := Vector3.ZERO
var _hay_estanque := false
## Una lista de transformadas por cada trozo de malla, agrupadas por pieza.
## Se acumula todo y al final se vuelca en los MultiMesh de una vez: así una
## pieza sembrada desde tres sitios distintos sigue siendo una sola draw call.
var _acumulado: Dictionary = {}
var _cache: Dictionary = {}
## Grosor del muro del blockout. Lo dice el constructor: `fuera` se mide desde
## su eje, así que hay que saber cuánto ocupa.
var _ancho_borde: float = 0.8
## Copia de lo que construyó el constructor, para no sembrar encima.
var _tramos: Array[Dictionary] = []
var _centros_arena: Dictionary = {}
var _radios_arena: Dictionary = {}
## A qué altura queda la cara pisable respecto del eje del tramo. Los tramos se
## registran por su eje, que cae a media losa de profundidad: sembrando ahí
## directamente, todo el parque aparece medio metro enterrado.
var _alto_suelo: float = 0.5


func decorar(constructor: ConstructorNivel) -> void:
	if constructor == null:
		push_warning("DecoradorNivel: sin constructor, no hay nada que decorar")
		return

	for hijo in get_children():
		hijo.queue_free()
	_acumulado.clear()
	_rng.seed = semilla
	_ancho_borde = constructor.ancho_borde
	_tramos = constructor.tramos
	_centros_arena = constructor.centros_arena
	_radios_arena = constructor.radios_arena
	_alto_suelo = constructor.grosor_suelo * 0.5

	var medida := constructor.extension()

	if decorar_tramos:
		for carril in constructor.carriles():
			_sembrar_carril(carril)
	if decorar_arenas:
		# El radio se pide arena por arena: la del guardián mide 13 y las otras
		# 11, y con uno fijo la corona le cae dentro del ruedo.
		for nombre: String in constructor.centros_arena:
			_coronar_arena(constructor.centros_arena[nombre],
				constructor.radios_arena.get(nombre, 11.0))
	# Se apunta antes de sembrar nada: el campo y el detalle tienen que saber
	# esquivar el agua, y ellos corren antes de que el estanque exista.
	_sitio_estanque = sitio_del_estanque(constructor) if radio_estanque > 0.0 \
		else Vector3.ZERO
	_hay_estanque = radio_estanque > 0.0

	_puerta_de_entrada(constructor)
	_poblar_campo(medida["centro"], medida["radio"])
	_sembrar_detalle(medida["centro"])
	if radio_estanque > 0.0:
		_estanque(sitio_del_estanque(constructor))
	if constructor.radio_limite > 0.0:
		_vestir_limite(medida["centro"], constructor.radio_limite)
	if montar_fondo:
		_fondo(medida["centro"], medida["radio"])

	var instancias := _volcar()
	print("[Nivel] decorado: %d props en %d draw calls" % [
		instancias, get_child_count()])


# --- Siembra --------------------------------------------------------------------

func _sembrar_carril(tramo: Dictionary) -> void:
	var largo: float = tramo["largo"]
	var ancho: float = tramo["ancho"]
	var direccion: Vector3 = tramo["direccion"]
	var costado := direccion.cross(Vector3.UP).normalized()
	var origen: Vector3 = tramo["origen"]
	var subida: float = tramo.get("subida", 0.0)
	var rumbo := atan2(-direccion.x, -direccion.z)

	for receta in SIEMBRA:
		var cada: float = receta["cada"]
		var copias := int(largo / cada)
		if copias <= 0:
			continue
		var lados: Array = [1.0, -1.0] if receta.get("ambos_lados", false) else [0.0]
		for i in copias:
			# Medio hueco de margen por delante y por detrás, si no la primera
			# copia cae justo en la junta con el tramo anterior y se solapan.
			var t := fmod((float(i) + 0.5) / float(copias)
				+ receta.get("fase", 0.0), 1.0)
			for fijo: float in lados:
				var signo: float = fijo
				if signo == 0.0:
					signo = 1.0 if (i % 2 == 0) else -1.0
					if not receta.get("alterna", true):
						signo = 1.0
				var lateral: float
				if receta.has("fuera"):
					lateral = (ancho * 0.5 + _ancho_borde * 0.5
						+ receta["fuera"]) * signo
				else:
					lateral = receta["lado"] * ancho * 0.5 * signo
				var avance := largo * t
				var desvio: float = receta.get("desvio", 0.0)
				if desvio > 0.0:
					avance += _rng.randf_range(-desvio, desvio)
					lateral += _rng.randf_range(-desvio, desvio) * signo
				var sitio := origen + direccion * avance + costado * lateral \
					+ Vector3.UP * (_alto_suelo + subida * t)
				_plantar(receta, sitio, rumbo, costado * signo)


func _coronar_arena(centro: Vector3, radio: float) -> void:
	for receta in CORONA_ARENA:
		var copias: int = receta["copias"]
		var distancia: float = radio + receta["margen"]
		for i in copias:
			var angulo := TAU * float(i) / float(copias) \
				+ _rng.randf_range(-0.09, 0.09)
			var r := distancia + _rng.randf_range(0.0, receta.get("desvio", 0.0))
			var sitio := centro + Vector3(cos(angulo), 0.0, sin(angulo)) * r \
				+ Vector3.UP * _alto_suelo
			_plantar(receta, sitio, 0.0, Vector3.ZERO)


## El torii de la entrada, cruzando el camino justo detrás del punto de partida.
##
## Un torii marca **por dónde se entra a un sitio**. Repartidos por el horizonte
## no dicen nada; plantado a la espalda del arranque, lo primero que se ve al
## girarse es la puerta por la que se acaba de pasar, y el parque empieza a
## tener una entrada en vez de un borde.
##
## Va detrás y no delante para no tapar la vista del camino en el primer
## fotograma de la partida.
func _puerta_de_entrada(constructor: ConstructorNivel) -> void:
	var partes := _partes("torii")
	if partes.is_empty() or constructor.tramos.is_empty():
		return
	var tramo: Dictionary = constructor.tramos[0]
	var direccion: Vector3 = tramo["direccion"]
	# Un poco por detrás del inicio, sobre el eje del camino.
	# Al fondo de la pradera, no a cuatro metros: si está encima del punto de
	# aparición, la cámara arranca metida entre sus patas.
	var sitio := constructor.punto_inicio - direccion * 16.0
	sitio.y = 0.0
	# El torii se modeló a lo ancho de su eje X, así que hay que atravesarlo al
	# camino igual que la puerta del guardián: rumbo a secas, sin los 90°.
	var rumbo := atan2(-direccion.x, -direccion.z)
	var receta := {"pieza": "torii", "escala": [2.0, 2.0], "alinear": true}
	_plantar(receta, _posar(sitio), rumbo, Vector3.ZERO)


## Reparte cosas por el campo abierto, entre el parque y las colinas.
##
## En anillos con desvío al azar y no en rejilla: una cuadrícula se nota
## enseguida por muy grande que sea, y lo que se busca es que parezca que
## crecieron ahí.
func _poblar_campo(centro: Vector3, _radio_nivel: float) -> void:
	for receta in CAMPO:
		var copias: int = receta["copias"]
		for i in copias:
			# El ángulo avanza con un número irracional de vueltas para que las
			# copias no se alineen entre recetas: sembrando todo con el mismo
			# reparto regular, las rocas acaban cada una junto a un árbol.
			var theta := TAU * fmod(float(i) * 0.618034, 1.0) \
				+ _rng.randf_range(-0.25, 0.25)
			var r: float = _rng.randf_range(receta["desde"], receta["hasta"])
			var sitio := centro + Vector3(cos(theta), 0.0, sin(theta)) * r
			# Nada del campo puede caer sobre el recorrido. El parque no es un
			# círculo: la pradera del arranque se aleja del centro tanto como el
			# campo, así que sembrar «a partir de tantos metros del centro»
			# plantaba peñascos en mitad del camino de salida.
			if _pisa_el_recorrido(sitio):
				continue
			# Y nada del campo puede caer en el agua ni en la ladera del vaso:
			# el peñasco que salía flotando en mitad del estanque venía de aquí.
			if _moja(sitio, 1.18, 2.2):
				continue
			_plantar(receta, sitio, 0.0, Vector3.ZERO)


## Siembra el detalle menudo por todas partes, camino incluido.
##
## A diferencia del campo, esto SÍ puede caer sobre el recorrido: unas briznas
## en el borde del sendero o unas piedrecitas sueltas son exactamente lo que
## hace que el camino no parezca recién asfaltado. Nada de esto tiene cuerpo,
## así que no estorba.
func _sembrar_detalle(centro: Vector3) -> void:
	for receta in DETALLE:
		var copias: int = receta["copias"]
		for i in copias:
			var theta := TAU * fmod(float(i) * 0.618034, 1.0) \
				+ _rng.randf_range(-0.4, 0.4)
			var r: float = _rng.randf_range(receta["desde"], receta["hasta"])
			var sitio := centro + Vector3(cos(theta), 0.0, sin(theta)) * r
			# Salvo dentro del agua: unas briznas de hierba asomando en mitad
			# del estanque delatan que el agua es una lámina puesta encima.
			if _moja(sitio, BORDE_AGUA, 0.3):
				continue
			_plantar(receta, sitio, 0.0, Vector3.ZERO)


## ¿Este punto cae dentro del estanque?
##
## `factor` escala el contorno —1,0 es el borde del agua y 1,18 el del vaso
## cavado— y `margen` añade metros por fuera.
func _moja(sitio: Vector3, factor: float, margen: float) -> bool:
	if not _hay_estanque:
		return false
	var hacia := Vector2(sitio.x - _sitio_estanque.x, sitio.z - _sitio_estanque.z)
	var angulo := atan2(hacia.y, hacia.x)
	return hacia.length() <= _radio_contorno(angulo) * factor + margen


## ¿Este punto cae sobre alguna parte por la que se juega?
##
## Mira los tramos como rectángulos y las arenas como círculos, con un margen de
## respeto. Es más barato y más predecible que consultar la física, y aquí lo
## que importa es que **nunca** aparezca un peñasco en el camino.
func _pisa_el_recorrido(sitio: Vector3) -> bool:
	for tramo in _tramos:
		var origen: Vector3 = tramo["origen"]
		var direccion: Vector3 = tramo["direccion"]
		var hacia := sitio - origen
		var avance := hacia.dot(direccion)
		if avance < -margen_recorrido or avance > float(tramo["largo"]) + margen_recorrido:
			continue
		var lateral := absf(hacia.dot(direccion.cross(Vector3.UP).normalized()))
		var mitad: float = float(tramo["ancho"]) * 0.5 \
			+ float(tramo.get("separacion", 0.0)) * 0.5 + margen_recorrido
		if lateral <= mitad:
			return true
	for nombre: String in _radios_arena:
		var centro_arena: Vector3 = _centros_arena[nombre]
		var d := Vector2(sitio.x - centro_arena.x, sitio.z - centro_arena.z).length()
		if d <= float(_radios_arena[nombre]) + margen_recorrido:
			return true
	return false


## El estanque del campo, con su puente y sus nenúfares.
##
## Es el sitio que convierte el campo abierto en «un sitio con cosas» en vez de
## una pradera grande. Un estanque se ve desde lejos, da una referencia para
## orientarse, y el puente invita a cruzarlo aunque se pueda rodear — que es
## exactamente lo que se busca en una zona opcional.
##
## El agua NO es un disco puesto encima. El terreno lleva cavado un vaso con el
## mismo contorno ondulado (`hondonada_estanque()`), y la lámina se posa dentro
## a la altura de la orilla menos el calado. Así el borde del agua lo dibuja el
## propio terreno al asomar, en vez de acabarse en el canto del disco — que era
## justo lo que la delataba como calcomanía.
## Dónde va el estanque. Lo pregunta el nivel ANTES de construir el terreno,
## para cavarle el vaso, y luego lo usa el propio decorador para poner el agua.
## Un solo sitio decide, o el agua acaba en un sitio y el hoyo en otro.
func sitio_del_estanque(constructor: ConstructorNivel) -> Vector3:
	var medida := constructor.extension()
	var rumbo := deg_to_rad(rumbo_estanque)
	return medida["centro"] + Vector3(cos(rumbo), 0.0, sin(rumbo)) * distancia_estanque


## La hondonada que hay que cavar para este estanque.
func hondonada_estanque(constructor: ConstructorNivel) -> Dictionary:
	return {
		"centro": sitio_del_estanque(constructor),
		"radio": radio_estanque * 1.18,
		"hondura": hondura_vaso,
		"irregular": true,
	}


func _estanque(centro: Vector3) -> void:
	# El nivel del agua se mide en la ORILLA, no en el fondo del vaso. Posando
	# la lámina sobre el centro, el rayo encuentra el fondo cavado y el agua
	# queda enterrada metro y medio por debajo del hoyo, invisible.
	#
	# Se promedian cuatro puntos del borde para que un socavón suelto no
	# incline la referencia.
	var suma := 0.0
	for i in 4:
		var angulo := TAU * float(i) / 4.0
		var borde := centro + Vector3(cos(angulo), 0.0, sin(angulo)) \
			* (radio_estanque * 1.35)
		suma += _posar(borde).y
	var sitio := Vector3(centro.x, suma * 0.25, centro.z)

	# La lámina se construye a mano y con el MISMO contorno ondulado que el
	# vaso: un disco perfecto encima de un hoyo irregular deja media orilla de
	# agua flotando sobre la hierba.
	var lamina := MeshInstance3D.new()
	lamina.name = "Estanque"
	lamina.mesh = _malla_de_agua()
	lamina.material_override = load("res://src/level/agua.tres")
	lamina.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Un poco por debajo del borde del vaso: es lo que hace que el agua tenga
	# orilla en vez de acabarse en un canto.
	lamina.position = sitio + Vector3.DOWN * calado
	add_child(lamina)

	# El puente cruza por donde el estanque es MÁS ESTRECHO. Con un rumbo al
	# azar caía casi siempre en un través ancho y se quedaba corto, flotando en
	# mitad del agua sin tocar ninguna orilla — que es exactamente lo que pasaba
	# con el puentecito de tres metros.
	var rumbo := _eje_mas_estrecho()
	var delante := _radio_contorno(rumbo)
	var detras := _radio_contorno(rumbo + PI)
	var cruce := (delante + detras) * BORDE_AGUA
	# El contorno es asimétrico, así que el centro del estanque no es el punto
	# medio del cruce. Puesto en el centro, un extremo apoyaba dos metros dentro
	# de la hierba y el otro se quedaba mojando el agua.
	var eje_puente := Vector3(cos(rumbo), 0.0, sin(rumbo))
	var medio := sitio + eje_puente * (delante - detras) * BORDE_AGUA * 0.5
	# Un metro de apoyo en cada punta. La escala es uniforme (engorda también el
	# ancho), pero como el modelo ya mide el través típico, se queda cerca de 1.
	var escala_puente := (cruce + 2.0) / LARGO_PUENTE
	var receta_puente := {"pieza": "puente_madera",
		"escala": [escala_puente, escala_puente], "alinear": true,
		# Sin `posar`: el rayo caería al fondo del vaso y hundiría el puente.
		"posar": false}
	# El modelo mira a lo largo de +Z, y el rumbo es un ángulo en el plano XZ.
	_plantar(receta_puente, medio, rumbo + PI * 0.5, Vector3.ZERO)

	# Nenúfares flotando, apartados del pasillo del puente para no atravesarlo.
	var ancho_libre := 2.2 * escala_puente
	for i in 9:
		var angulo := TAU * float(i) / 9.0 + 0.4
		var r := _rng.randf_range(radio_estanque * 0.30, radio_estanque * 0.78)
		var punto := sitio + Vector3(cos(angulo), 0.0, sin(angulo)) * r
		# Distancia al eje del puente: si el nenúfar cae dentro del pasillo, se
		# aparta de lado en vez de saltárselo (nueve son pocos para perder uno).
		var lado := (punto - medio) - eje_puente * (punto - medio).dot(eje_puente)
		if lado.length() < ancho_libre:
			var empuje: float = ancho_libre + 0.6 - lado.length()
			punto += (lado.normalized() if lado.length() > 0.01
				else Vector3(-eje_puente.z, 0.0, eje_puente.x)) * empuje
		punto.y = sitio.y - calado + 0.02
		var pose := Transform3D(
			Basis.from_euler(Vector3(0.0, _rng.randf_range(0.0, TAU), 0.0))
				* Basis.from_scale(Vector3.ONE * _rng.randf_range(0.8, 1.4)),
			punto)
		_acumular("nenufar", pose, false)

	# Piedras en la orilla: es lo que hace que el agua tenga un borde en vez de
	# acabarse contra la hierba.
	for i in 14:
		var angulo := TAU * float(i) / 14.0 + 0.2
		# Sobre el contorno de verdad, no sobre el radio nominal: donde la
		# orilla se ensancha un 30 %, una piedra al radio nominal cae al agua.
		var punto := sitio + Vector3(cos(angulo), 0.0, sin(angulo)) \
			* (_radio_contorno(angulo) * 1.18 + _rng.randf_range(0.4, 1.8))
		_plantar({"pieza": "roca", "escala": [0.9, 1.9]},
			_posar(punto), 0.0, Vector3.ZERO)


## La lámina de agua: un abanico de triángulos con el borde ondulado.
##
## Se hace a mano en vez de con un `CylinderMesh` porque el contorno tiene que
## ser **el mismo** que el del vaso cavado en el terreno — con las mismas dos
## ondas y los mismos coeficientes. Si uno es redondo y el otro no, media orilla
## queda con agua flotando sobre la hierba y la otra media con el vaso a la
## vista.
##
## Va bastante subdividida a propósito: el shader mueve los vértices, y con
## pocos la ondulación se ve como un mantel doblándose.
## Hasta dónde llega la lámina de agua, en múltiplos del contorno nominal.
##
## El vaso se cava a 1,18 (ver `hondonada_estanque()`) y el agua tiene que morir
## DENTRO de esa ladera, cerca del borde. Con la lámina al 1,00 quedaba un
## anillo de vaso seco alrededor del agua, el charco se leía como una mancha
## flotando en un hoyo y la espuma de orilla solo salía por el lado donde el
## terreno subía antes. Pasarse de 1,18 es peor: el agua asomaría por encima de
## la hierba.
const BORDE_AGUA := 1.14


## Largo del modelo de puente, tal como sale de Blender. Debe coincidir con
## `PUENTE_LARGO` de `tools/blender_kit_expansion.py`.
const LARGO_PUENTE := 14.0


## El radio del estanque en una dirección dada.
##
## Es LA fórmula del contorno: la usan la lámina de agua, el vaso que se cava en
## el terreno (`terreno_nivel.gd`, con estos mismos coeficientes) y el cálculo
## de por dónde cruza el puente. Si se toca aquí hay que tocarla allí, o media
## orilla se queda con el agua flotando sobre la hierba.
func _radio_contorno(angulo: float) -> float:
	return radio_estanque * (1.0 + 0.20 * sin(angulo * 3.0 + 1.3)
		+ 0.11 * sin(angulo * 5.0 - 0.6))


## Por dónde es más corto cruzar el estanque de orilla a orilla.
func _eje_mas_estrecho() -> float:
	var mejor := 0.0
	var minimo := INF
	# Medio giro basta: el eje de θ y el de θ+π son el mismo cruce.
	for i in 48:
		var angulo := PI * float(i) / 48.0
		var ancho := _radio_contorno(angulo) + _radio_contorno(angulo + PI)
		if ancho < minimo:
			minimo = ancho
			mejor = angulo
	return mejor


func _malla_de_agua() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()
	var indices := PackedInt32Array()
	var lados := 40
	var anillos := 5

	vertices.append(Vector3.ZERO)
	normales.append(Vector3.UP)
	for anillo in anillos:
		var t := float(anillo + 1) / float(anillos)
		for i in lados:
			var angulo := TAU * float(i) / float(lados)
			var radio := _radio_contorno(angulo) * BORDE_AGUA * t
			vertices.append(Vector3(cos(angulo) * radio, 0.0, sin(angulo) * radio))
			normales.append(Vector3.UP)

	# Abanico del centro al primer anillo
	for i in lados:
		indices.append_array([0, 1 + i, 1 + (i + 1) % lados])
	# Y bandas entre anillos
	for anillo in anillos - 1:
		var base := 1 + anillo * lados
		var siguiente := base + lados
		for i in lados:
			var j := (i + 1) % lados
			indices.append_array([base + i, siguiente + i, base + j,
				base + j, siguiente + i, siguiente + j])

	var datos := []
	datos.resize(Mesh.ARRAY_MAX)
	datos[Mesh.ARRAY_VERTEX] = vertices
	datos[Mesh.ARRAY_NORMAL] = normales
	datos[Mesh.ARRAY_INDEX] = indices
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, datos)
	return malla


## Apunta una copia ya colocada, saltándose el cálculo de pose de `_plantar`.
func _acumular(pieza: String, pose: Transform3D, lejano: bool) -> void:
	var partes := _partes(pieza)
	if partes.is_empty():
		return
	var destino: Dictionary = _acumulado.get(pieza, {})
	if destino.is_empty():
		destino = {"lejano": lejano, "poses": {}, "base": []}
		_acumulado[pieza] = destino
	(destino["base"] as Array).append(pose)
	for indice in partes.size():
		var lista: Array = destino["poses"].get(indice, [])
		lista.append(pose * partes[indice]["local"])
		destino["poses"][indice] = lista


## Arboleda y pedregal alrededor de todo, al pie de la ladera.
##
## Va con el mismo ondulado que la ladera del constructor —las mismas dos ondas,
## los mismos coeficientes— para que el bosque siga a la cuesta en vez de
## cruzarla. Si algún día se cambia el contorno allí, hay que cambiarlo aquí.
func _vestir_limite(centro: Vector3, radio: float) -> void:
	for receta in LIMITE:
		var copias: int = receta["copias"]
		for i in copias:
			var theta := TAU * float(i) / float(copias) + _rng.randf_range(-0.05, 0.05)
			var ondulado := 1.0 + 0.085 * sin(theta * 3.0 + 0.7) \
				+ 0.045 * sin(theta * 7.0 + 2.1)
			var r: float = radio * ondulado - receta["dentro"] \
				+ _rng.randf_range(-1.0, 1.0) * receta.get("desvio", 0.0)
			var sitio := centro + Vector3(cos(theta), 0.0, sin(theta)) * r
			_plantar(receta, sitio, 0.0, Vector3.ZERO)


func _fondo(centro: Vector3, radio_nivel: float) -> void:
	for receta in FONDO:
		var copias: int = receta["copias"]
		var arco: Array = receta.get("arco", [])
		for i in copias:
			var angulo: float
			if arco.size() == 2:
				angulo = deg_to_rad(lerpf(arco[0], arco[1],
					0.0 if copias < 2 else float(i) / float(copias - 1)))
			else:
				angulo = TAU * float(i) / float(copias) + _rng.randf_range(-0.16, 0.16)
			var r: float = radio_nivel + receta["radio"] \
				+ _rng.randf_range(-1.0, 1.0) * receta.get("desvio", 0.0)
			var sitio := centro + Vector3(cos(angulo), 0.0, sin(angulo)) * r \
				+ Vector3.UP * COTA_FALDON
			# Miran al centro del nivel: la pagoda de perfil no se lee, y la
			# silueta es todo lo que se ve a esa distancia.
			_plantar(receta, sitio, angulo + PI * 0.5, Vector3.ZERO, true)


## Apunta una copia de la pieza. No crea nada todavía: solo guarda dónde va.
func _plantar(receta: Dictionary, sitio: Vector3, rumbo: float,
		hacia_fuera: Vector3, lejano: bool = false) -> void:
	var pieza: String = receta["pieza"]
	var partes := _partes(pieza)
	if partes.is_empty():
		return

	var rango: Array = receta.get("escala", [1.0, 1.0])
	var escala := _rng.randf_range(rango[0], rango[1])

	var giro := rumbo
	if receta.get("alinear", false):
		# Vallas y bancos van paralelos al camino; si giran al azar se cruzan.
		if receta.get("mirar_dentro", false) and hacia_fuera.length_squared() > 0.01:
			giro = atan2(hacia_fuera.x, hacia_fuera.z)
		giro += deg_to_rad(receta.get("girar", 0.0))
	elif not lejano:
		giro = _rng.randf_range(0.0, TAU)

	# Casi todo se posa en el suelo de debajo. El puente no: el rayo caería al
	# fondo del vaso del estanque y lo hundiría bajo el agua.
	var base := _posar(sitio) if receta.get("posar", true) else sitio
	var pose := Transform3D(Basis.from_euler(Vector3(0.0, giro, 0.0)) * escala,
		base - Vector3.UP * receta.get("hundir", 0.0) * escala)

	var destino: Dictionary = _acumulado.get(pieza, {})
	if destino.is_empty():
		destino = {"lejano": lejano, "poses": {}, "base": []}
		_acumulado[pieza] = destino
	# La pose de la pieza entera, sin la transformada interna de cada trozo de
	# malla: es la que necesita la colisión, que va contra el objeto completo y
	# no contra el tronco y la copa por separado.
	(destino["base"] as Array).append(pose)
	for indice in partes.size():
		var lista: Array = destino["poses"].get(indice, [])
		lista.append(pose * partes[indice]["local"])
		destino["poses"][indice] = lista


## Baja el punto hasta el suelo que haya realmente debajo.
##
## Hace falta porque la altura calculada desde el tramo solo vale ENCIMA del
## tramo. En el pasillo que sube al guardián, un árbol plantado fuera del muro
## se calcula a la altura del camino —hasta 2,5 m— mientras que el terreno de
## al lado es el disco de hierba, plano. Resultado: árboles, rocas y un farol
## flotando en el aire a media cuesta.
##
## Con un rayo se acabó el problema para siempre, y además vale para cualquier
## escenario futuro con desniveles sin tener que pensar en ellos. Se lanza antes
## de crear los cuerpos de los props, así que solo puede chocar con el blockout
## y con la hierba, nunca con otro árbol.
func _posar(sitio: Vector3) -> Vector3:
	var espacio := get_world_3d().direct_space_state
	if espacio == null:
		return sitio
	var consulta := PhysicsRayQueryParameters3D.create(
		sitio + Vector3.UP * 4.0, sitio + Vector3.DOWN * 8.0)
	consulta.collision_mask = 1
	var choque := espacio.intersect_ray(consulta)
	if choque.is_empty():
		return sitio
	return Vector3(sitio.x, choque["position"].y, sitio.z)


## Crea los MultiMesh de verdad, uno por trozo de malla. Devuelve cuántas
## copias se plantaron en total.
func _volcar() -> int:
	var total := 0
	for pieza in _acumulado:
		var ficha: Dictionary = _acumulado[pieza]
		var partes := _partes(pieza)
		var lejano: bool = ficha["lejano"]
		for indice in ficha["poses"]:
			var poses: Array = ficha["poses"][indice]
			if poses.is_empty():
				continue
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = partes[indice]["mesh"]
			multi.instance_count = poses.size()
			for i in poses.size():
				multi.set_instance_transform(i, poses[i])

			var nodo := MultiMeshInstance3D.new()
			nodo.name = "%s_%d" % [pieza, indice]
			nodo.multimesh = multi
			# Sin `material_override`: cada malla ya trae el suyo del `.glb`, y
			# forzar uno solo le pondría la corteza a las flores del cerezo.
			if lejano:
				# El fondo no proyecta ni recibe sombra: no aporta nada a 100 m
				# y el mapa de sombras se gastaría entero en montañas.
				nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				nodo.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			add_child(nodo)
		if not lejano:
			_dar_cuerpo(pieza, ficha["base"])
		total += _copias(ficha)
	return total


## Un `StaticBody3D` por tipo de pieza, con una forma primitiva por copia.
##
## No se puede sacar la colisión de la malla: van en `MultiMesh`, que no
## colisiona. Y tampoco haría falta — una cápsula por tronco para igual de bien
## que la geometría exacta de la corteza y cuesta una milésima.
##
## Un solo cuerpo con muchas formas, en vez de un cuerpo por árbol: al motor le
## da igual cuántas formas cuelguen, pero cada cuerpo suelto es un nodo más que
## procesar.
func _dar_cuerpo(pieza: String, poses: Array) -> void:
	if not CUERPO.has(pieza) or poses.is_empty():
		return
	var receta: Dictionary = CUERPO[pieza]
	var forma := _forma(receta)
	if forma == null:
		return

	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Cuerpo_%s" % pieza
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	# Sube la forma desde la base de la pieza hasta su centro. Va dentro de la
	# pose para que la escala de cada copia también le afecte: un cerezo al 1,3
	# tiene el tronco más alto.
	var alzar := Transform3D(Basis(), Vector3(0.0, receta["centro_y"], 0.0))
	for pose: Transform3D in poses:
		var nodo := CollisionShape3D.new()
		# La misma `Shape` para todas: es un recurso compartido, y la escala de
		# la copia la pone el transform del nodo.
		nodo.shape = forma
		nodo.transform = pose * alzar
		cuerpo.add_child(nodo)
	add_child(cuerpo)


static func _forma(receta: Dictionary) -> Shape3D:
	match receta.get("forma", ""):
		"cilindro":
			var cilindro := CylinderShape3D.new()
			cilindro.radius = receta["radio"]
			cilindro.height = receta["alto"]
			return cilindro
		"esfera":
			var esfera := SphereShape3D.new()
			esfera.radius = receta["radio"]
			return esfera
		"caja":
			var caja := BoxShape3D.new()
			caja.size = receta["tam"]
			return caja
	return null


static func _copias(ficha: Dictionary) -> int:
	return (ficha["base"] as Array).size()


# --- Piezas del kit -------------------------------------------------------------

## Abre un `.glb` y devuelve sus trozos de malla con la transformada que cada
## uno tiene dentro de la pieza.
##
## Se recorre el árbol entero en vez de coger la primera malla porque las
## piezas de dos materiales (el cerezo: corteza, flor y flor clara) vienen como
## varios `MeshInstance3D` hermanos. Cogiendo solo el primero se plantarían
## troncos pelados.
func _partes(nombre: String) -> Array:
	if _cache.has(nombre):
		return _cache[nombre]

	var partes: Array = []
	var ruta := CARPETA + nombre + ".glb"
	var escena := load(ruta) as PackedScene
	if escena == null:
		push_warning("DecoradorNivel: no encuentro la pieza '%s'" % ruta)
		_cache[nombre] = partes
		return partes

	var raiz := escena.instantiate()
	_recoger(raiz, Transform3D.IDENTITY, partes)
	raiz.queue_free()
	_cache[nombre] = partes
	return partes


static func _recoger(nodo: Node, acumulada: Transform3D, salida: Array) -> void:
	var propia := acumulada
	if nodo is Node3D:
		propia = acumulada * (nodo as Node3D).transform
	if nodo is MeshInstance3D:
		var malla := (nodo as MeshInstance3D).mesh
		if malla != null:
			salida.append({"mesh": malla, "local": propia})
	for hijo in nodo.get_children():
		_recoger(hijo, propia, salida)
