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
## Una lista de transformadas por cada trozo de malla, agrupadas por pieza.
## Se acumula todo y al final se vuelca en los MultiMesh de una vez: así una
## pieza sembrada desde tres sitios distintos sigue siendo una sola draw call.
var _acumulado: Dictionary = {}
var _cache: Dictionary = {}
## Grosor del muro del blockout. Lo dice el constructor: `fuera` se mide desde
## su eje, así que hay que saber cuánto ocupa.
var _ancho_borde: float = 0.8
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
	_puerta_de_entrada(constructor)
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
	var sitio := constructor.punto_inicio - direccion * 4.5
	sitio.y = 0.0
	# El torii se modeló a lo ancho de su eje X, así que hay que atravesarlo al
	# camino igual que la puerta del guardián: rumbo a secas, sin los 90°.
	var rumbo := atan2(-direccion.x, -direccion.z)
	var receta := {"pieza": "torii", "escala": [2.0, 2.0], "alinear": true}
	_plantar(receta, _posar(sitio), rumbo, Vector3.ZERO)


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

	var pose := Transform3D(Basis.from_euler(Vector3(0.0, giro, 0.0)) * escala,
		_posar(sitio) - Vector3.UP * receta.get("hundir", 0.0) * escala)

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
