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
	# Se empieza en una PRADERA, no en un pasillo. Apareciendo entre dos muros a
	# nueve metros el sitio se lee como un laberinto, y estando pegada al borde
	# lo primero que apetece es salirse. Con una pradera de treinta metros
	# alrededor, el parque empieza abriéndose.
	# Una PLACITA, no una explanada. Se probó a 52×54 y luego a 34×46, y las dos
	# veces el problema fue el mismo: una losa cuadrada de ese tamaño en mitad
	# del campo se lee como un bloque puesto encima del mapa, borra el relieve
	# que tenga debajo y desplaza el parque entero lo bastante como para tapar
	# lo que hubiera cerca —el estanque y su puente, entre otras cosas—.
	#
	# Veinte por veintiséis es sitio de sobra para aparecer sin tener el canto
	# del mundo a la espalda, y la siembra de carril la amuebla sola con sus
	# bancos y sus faroles.
	{"tipo": "pradera", "largo": 20.0, "ancho": 26.0, "nodo": "PraderaInicio"},
	# Y el pasillo que sale de ella va abierto por un lado: un camino con muro a
	# ambos lados es un corredor. Con uno solo, es un sendero que bordea un seto.
	{"tipo": "pasillo", "largo": 20.0, "ancho": 9.0, "muros": "derecha"},
	{"tipo": "arena", "radio": 11.0, "nodo": "Arena1"},
	{"tipo": "giro", "grados": -90.0},
	# El tramo B se parte en dos: por la derecha se va directo, por la
	# izquierda se rodea saltando plataformas y se recogen dos Estrellas.
	# Ninguno castiga; el que explora se lleva algo, el que va directo llega
	# antes. Es lo único del nivel donde hay algo que decidir.
	# La separación es generosa a propósito: entre las dos ramas cabe un
	# bosquete, y eso hace que desde una no se vea la otra. Elegir camino tiene
	# gracia solo si el que no coges queda fuera de la vista.
	{"tipo": "cruce", "largo": 30.0, "ancho": 7.0, "separacion": 16.0},
	{"tipo": "arena", "radio": 11.0, "nodo": "Arena2"},
	{"tipo": "giro", "grados": 90.0},
	{"tipo": "pasillo", "largo": 15.0, "ancho": 9.0, "subida": 2.5},
	{"tipo": "arena", "radio": 13.0, "nodo": "Guardian"},
	# A partir de aquí el parque se alarga más allá del guardián. No hay más
	# peleas: es el paseo de vuelta, ancho y tranquilo, que lleva al claro del
	# portal. Después de un jefe hace falta bajar el pulso antes de cambiar de
	# escenario — si el nivel acaba en el mismo golpe que el jefe, la victoria no
	# se saborea.
	{"tipo": "giro", "grados": -90.0},
	{"tipo": "pasillo", "largo": 22.0, "ancho": 11.0},
	{"tipo": "giro", "grados": -90.0},
	{"tipo": "pasillo", "largo": 26.0, "ancho": 12.0, "subida": -2.5},
	{"tipo": "arena", "radio": 12.0, "nodo": "ClaroPortal"},
]

@export_group("Aspecto")
## Qué superficie de [`PaletaTerreno`](paleta_terreno.gd) usa cada parte.
##
## Antes eran colores planos y el escenario parecía una maqueta de plastilina:
## una superficie de un solo color no se lee como dibujada por mucho que la
## silueta acompañe. Ahora son nombres de la paleta, así que cambiar el aspecto
## de todos los caminos del juego es cambiar una receta en un sitio.
@export var suelo: String = "hierba"
## El camino va distinto a propósito: a los 8 años, saber por dónde se va
## importa más que cualquier decoración.
@export var camino: String = "tierra_camino"
@export var arena: String = "tierra_arena"
@export var borde: String = "muro_seto"
@export var plataforma: String = "plataforma"

@export_group("Medidas")
## Cuánto se mete cada losa de suelo dentro de la siguiente.
##
## Sin esto, un pasillo acaba EXACTAMENTE donde empieza el disco de la arena, y
## entre las dos queda una rendija de milímetros por la que se cae del mundo.
## No es un error de cálculo: dos superficies tangentes en coma flotante no
## cierran, y en el Nivel 1 eso dejaba 67 agujeros repartidos por todas las
## juntas. Medio metro de solape los cierra todos y no se ve, porque el suelo
## que sobra queda enterrado bajo el de al lado.
@export var solape: float = 0.6
## Cuánto sobresale la losa de la arena más allá de su anillo.
##
## El solape recto no basta contra un borde curvo: un pasillo de 9 m de ancho
## acaba en una línea, y el disco se le aleja hacia los lados hasta un metro. Los
## agujeros que quedaban estaban todos en esas dos esquinas. Sobresaliendo, la
## losa las cubre y de paso el anillo parece apoyado en una plaza en vez de
## flotar sobre el canto.
@export var margen_arena: float = 1.6
## Cuánto se levanta una superficie sobre la que tiene debajo.
##
## Es EL número contra el z-fighting. El disco de arena y la losa del pasillo
## se solapan a propósito para que no queden agujeros en la junta, pero se
## construían a la misma altura: dos caras exactamente coplanares, que el
## z-buffer no puede ordenar y que parpadean en cuanto se mueve la cámara. La
## franja de camino tenía dos centímetros, que a treinta metros tampoco bastan.
##
## Diez centímetros se suben andando sin enterarse y se ven desde cualquier
## distancia como lo que son: un cambio de pavimento.
@export var desnivel: float = 0.10
@export var grosor_suelo: float = 1.0

@export var alto_borde: float = 2.2
@export var ancho_borde: float = 0.8
## Ancho de la franja de color que marca el camino.
@export var ancho_camino: float = 3.2
## Hueco que se deja en el borde de la arena para entrar y salir, en grados.
@export var hueco_acceso: float = 46.0
## Qué tramo cierra la `PuertaGuardian`.
##
## Va explícito y no como «el último»: al alargar el parque con el paseo de
## vuelta, el último tramo pasó a ser el que lleva al portal, y la barrera del
## jefe apareció cerrando la salida del nivel en vez de la entrada del jefe.
@export var tramo_de_la_puerta: int = 3

## Dónde va cada Estrella de Sueño, en coordenadas del recorrido y no del
## mundo: `tramo` es el índice del pasillo, `t` lo avanzado por él (0 a 1),
## `lado` el desvío lateral (−1 = borde izquierdo, +1 = derecho) y `alto` los
## metros sobre el suelo.
##
## Se declaran así para que sigan donde tienen que estar aunque cambien las
## medidas del nivel. Con posiciones absolutas, alargar un tramo deja media
## docena de estrellas flotando en el vacío.
const ESTRELLAS: Array[Dictionary] = [
	# En el camino: enseñan qué son, es imposible no cogerlas
	{"tramo": 1, "t": 0.45, "lado": 0.0, "alto": 1.1},
	{"tramo": 2, "t": 0.09, "lado": 0.0, "alto": 1.1},
	{"tramo": 3, "t": 0.55, "lado": 0.0, "alto": 1.3},
	# A la vista pero fuera del camino: hay que desviarse
	{"tramo": 1, "t": 0.80, "lado": 0.72, "alto": 1.1},
	# Una en la rama directa del cruce: irse por el camino corto no castiga
	{"tramo": 2, "t": 0.50, "lado": 0.0, "alto": 1.1, "rama": 1.0},
	# Las dos secretas, sobre las plataformas de la rama larga. Son la razón de
	# que exista el cruce: el que se desvía se lleva algo que el otro no ve.
	{"tramo": 2, "t": 0.48, "lado": 0.44, "alto": 2.0, "rama": -1.0, "secreta": true},
	{"tramo": 2, "t": 0.67, "lado": -0.44, "alto": 2.3, "rama": -1.0, "secreta": true},
]

## Los tres faroles del tramo antes del jefe. Mismo sistema de coordenadas.
##
## Uno en mitad del camino (imposible no verlo), otro pegado al borde (hay que
## fijarse) y el tercero alto (hay que subir). Así el objetivo se entiende solo:
## el primero se enciende sin querer y ya sabes qué toca.
const FAROLES: Array[Dictionary] = [
	{"id": "farol_1", "tramo": 3, "t": 0.18, "lado": 0.0, "alto": 0.0},
	{"id": "farol_2", "tramo": 3, "t": 0.52, "lado": -0.82, "alto": 0.0},
	{"id": "farol_3", "tramo": 3, "t": 0.78, "lado": 0.80, "alto": 1.6},
]

## Dónde espera cada personaje del reparto, en coordenadas del recorrido.
## Mismo criterio que las estrellas: si cambian las medidas del nivel, siguen
## en su sitio.
const ENCUENTROS: Array[Dictionary] = [
	# Mercury, nada más salir de la Arena 2: se la encuentra escondida a un
	# lado del camino que sube hacia el guardián.
	{"nodo": "EncuentroMercury", "tramo": 3, "t": 0.30, "lado": 0.55, "alto": 0.0},
]

var _origen: Vector3 = Vector3.ZERO
var _direccion: Vector3 = Vector3.FORWARD
var _altura: float = 0.0
var _piezas: int = 0
## Poses de las cajas, agrupadas por superficie. Se vuelca al terminar.
var _lotes: Dictionary = {}

var punto_inicio: Vector3 = Vector3.ZERO
var centros_arena: Dictionary = {}
## Radio de cada arena, con la misma clave. Va aparte de `centros_arena` para
## no cambiarle el tipo de valor, que ya se usa como posición en varios sitios.
var radios_arena: Dictionary = {}
## Un registro por pasillo, en orden, para poder situar cosas encima después.
var tramos: Array[Dictionary] = []
## Los cuerpos que forman el SUELO pisable, apuntados al crearlos.
##
## Hace falta una lista explícita porque **por nombre no se puede**: al añadir
## varios hijos con el mismo nombre, Godot los renombra a `@StaticBody3D@N`, y
## de ochenta y un cuerpos del blockout solo cuatro conservaban un nombre
## reconocible. Filtrar con `begins_with("Suelo")` daba un resultado
## impredecible, y el terreno acababa apoyándose en lo que no debía.
var cuerpos_suelo: Array[StaticBody3D] = []
## Lo que ESTORBA: muros, taludes y plataformas, como rectángulos orientados
## `{centro, mitad, giro}` en el plano.
##
## El decorador los necesita para no plantar dentro de ellos. Antes se apañaba
## midiendo desde el eje del tramo —«tantos metros más allá del muro»— y con el
## desvío al azar la mitad de los farolillos acababa metida en el seto. Aquí
## está la caja de verdad que se construyó, con su giro, así que la pregunta
## «¿este punto está dentro de algo?» tiene una respuesta exacta.
var estorbos: Array[Dictionary] = []
## Dónde empiezan las colinas que cierran el mundo. Lo pone el nivel a partir
## del terreno; el decorador lo usa para plantar la arboleda de la linde.
var radio_limite: float = 0.0
## Por dónde va pintado el camino, para que el terreno lo dibuje encima.
##
## El camino dejó de ser geometría: era una caja elevada sobre la losa del
## suelo, y de ahí salían el escalón, el canto a la vista y el z-fighting. Aquí
## queda solo su FORMA —rectángulos orientados y discos de arena—, que es lo que
## el terreno necesita para pintarse la máscara.
var franjas_camino: Array[Dictionary] = []


func _ready() -> void:
	construir()


func construir() -> void:
	for hijo in get_children():
		hijo.queue_free()
	_origen = Vector3.ZERO
	_direccion = Vector3.FORWARD
	_altura = 0.0
	_piezas = 0
	_lotes.clear()
	tramos.clear()
	cuerpos_suelo.clear()
	radio_limite = 0.0
	centros_arena.clear()
	radios_arena.clear()
	# Un par de metros DENTRO del primer tramo: el recorrido arranca en el
	# origen y avanza hacia −Z, así que empezar en +Z es empezar en el aire.
	# La altura es la cara superior de la losa (grosor/2) más un margen.
	# Bien DENTRO de la pradera, no en su primer metro. Apareciendo al principio
	# del tramo, por mucho que la pradera sea grande, lo que se tiene detrás es
	# el canto — y lo primero que hace cualquiera al empezar es girarse.
	punto_inicio = Vector3(0.0, grosor_suelo * 0.5 + 0.8, -8.5)

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
			# Faltaba, y el `match` se lo tragaba sin decir nada: la pradera de
			# arranque llevaba desde que se escribió sin construirse. Se veía en
			# el sitio equivocado —el nivel entero cincuenta metros más corto—,
			# se aparecía pegada al canto del primer pasillo, y la corona de la
			# primera arena caía justo encima del camino de salida.
			"pradera":
				_pradera(paso)
			"cruce":
				_cruce(paso)
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
			# El comodín va EL ÚLTIMO. Puesto en medio se traga los casos que
			# vienen detrás —«giro» y «arena»— y el nivel se queda en un pasillo
			# suelto con una sola arena.
			_:
				push_warning("ConstructorNivel: paso de tipo '%s' desconocido"
					% paso.get("tipo", ""))
		i += 1

	var lotes := _volcar_lotes()
	_colocar_encuentros()
	print("[Nivel] blockout construido: %d piezas en %d lotes, %d arenas" % [
		_piezas, lotes, centros_arena.size()])


## Lleva cada encuentro a su punto del recorrido. Los nodos ya están en la
## escena (para poder configurar diálogo y personaje en el inspector); lo único
## que se decide aquí es dónde caen.
func _colocar_encuentros() -> void:
	for ficha in ENCUENTROS:
		var nodo := get_parent().get_node_or_null(ficha["nodo"]) as Node3D
		if nodo == null:
			continue
		nodo.global_position = punto_en_tramo(
			ficha["tramo"], ficha["t"], ficha["lado"], ficha.get("alto", 0.0),
			ficha.get("rama", 0.0))

	# La puerta va cruzada al final del último pasillo, tapando la entrada del
	# guardián.
	#
	# El giro es el rumbo del camino a secas, SIN los 90° que uno esperaría:
	# la cortina se construye a lo largo de su eje X local
	# ([`puerta_magica.gd`](../gameplay/puerta_magica.gd)), y `atan2(−d.x, −d.z)`
	# orienta el −Z hacia el avance, que deja la X justo atravesada. Añadiendo
	# 90° queda paralela al pasillo, pegada a un muro y sin cortar nada.
	var barrera := get_parent().get_node_or_null("PuertaGuardian") as Node3D
	if barrera != null and tramo_de_la_puerta < tramos.size():
		var cual: int = tramo_de_la_puerta
		barrera.global_position = punto_en_tramo(cual, 0.99, 0.0, 0.0)
		var direccion: Vector3 = tramos[cual]["direccion"]
		barrera.rotation.y = atan2(-direccion.x, -direccion.z)


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

	_losa("Suelo", centro, Vector3(ancho, grosor_suelo, largo_real + solape * 2.0),
		suelo, giro, inclinacion)
	# Franja de camino, por encima del suelo lo justo para que no pelee con él.
	# La caja es más gruesa que el desnivel para que su cara de abajo siga
	# enterrada: si asoma, se ve el canto flotando sobre la hierba.
	#
	# Y CON COLISIÓN. Al subirla diez centímetros para quitar el z-fighting se
	# convirtió en un escalón por el que se caminaba por dentro: el personaje
	# seguía pisando el suelo de abajo y la franja le tapaba las botas. Si algo
	# sobresale, hay que poder subirse encima.
	_losa("Camino", centro + Vector3.UP * (grosor_suelo * 0.5 + desnivel * 0.5),
		Vector3(ancho_camino, desnivel + 0.06, largo_real + solape * 2.0), camino,
		giro, inclinacion, true)

	var lado := _direccion.cross(Vector3.UP).normalized()
	# Los muros son opcionales y por lado. Un camino encajonado entre dos setos
	# es un corredor, y un nivel entero así se lee como un laberinto por muchos
	# árboles que se le pongan encima. Dejando abierto un costado, el mismo
	# camino pasa a ser un sendero que bordea algo.
	var muros: String = paso.get("muros", "ambos")
	for signo: float in [-1.0, 1.0]:
		if muros == "ninguno":
			continue
		if muros == "izquierda" and signo > 0.0:
			continue
		if muros == "derecha" and signo < 0.0:
			continue
		_losa("Borde", centro + lado * signo * (ancho * 0.5 + ancho_borde * 0.5)
			+ Vector3.UP * (alto_borde * 0.5 + grosor_suelo * 0.5),
			Vector3(ancho_borde, alto_borde, largo_real), borde, giro, inclinacion)

	if paso.get("plataformas", false):
		_plataformas(largo, ancho)

	tramos.append({
		"origen": _origen + Vector3.UP * _altura,
		"direccion": _direccion,
		"largo": largo, "ancho": ancho, "subida": subida,
	})

	_origen += _direccion * largo
	_altura += subida


## Una extensión abierta de césped con el camino cruzándola.
##
## Es el antídoto contra el «laberinto de pasillos». Un parque no es una
## sucesión de corredores: tiene explanadas donde se puede correr en cualquier
## dirección, y son ellas las que dan la sensación de sitio. Aquí no hay muros
## en los costados — quien quiera irse al campo, que se vaya.
##
## Se usa sobre todo para EMPEZAR. Apareciendo en un pasillo de nueve metros de
## ancho, con muro a los dos lados y el borde del mundo a la espalda, lo primero
## que apetece es salirse a ver qué hay fuera. Apareciendo en mitad de una
## pradera, lo que apetece es mirar alrededor.
func _pradera(paso: Dictionary) -> void:
	var largo: float = paso["largo"]
	var ancho: float = paso["ancho"]
	var giro := _giro_actual()
	var centro := _origen + _direccion * (largo * 0.5) + Vector3.UP * _altura

	_losa("Suelo", centro, Vector3(ancho, grosor_suelo, largo + solape * 2.0),
		suelo, giro)
	# El camino la cruza de lado a lado, más estrecho que la pradera: se ve por
	# dónde se va sin que el resto deje de ser pisable.
	_losa("Camino", centro + Vector3.UP * (grosor_suelo * 0.5 + desnivel * 0.5),
		Vector3(ancho_camino, desnivel + 0.06, largo + solape * 2.0), camino,
		giro, 0.0, true)

	# Aquí había tres «manchas de tierra sueltas» para que la explanada no se
	# leyera como un campo de fútbol. La idea era buena y la ejecución no: eran
	# losas RECTANGULARES, con sus cuatro esquinas en ángulo recto y su canto
	# perfectamente recto, puestas encima del césped. No parecían calvas de
	# tierra; parecían bloques cuadrados pegados al mapa, y de paso borraban el
	# relieve que hubiera debajo.
	#
	# Una calva de tierra se hace con lo que ya hay para eso —piedrecitas,
	# hojarasca, matas ralas del decorador—, no con una caja.

	if paso.get("nodo", "") != "":
		centros_arena[paso["nodo"]] = centro
		radios_arena[paso["nodo"]] = ancho * 0.5

	tramos.append({
		"origen": _origen + Vector3.UP * _altura,
		"direccion": _direccion,
		"largo": largo, "ancho": ancho, "subida": 0.0,
	})
	_origen += _direccion * largo


## Dos caminos que salen del mismo sitio y se vuelven a juntar.
##
## Se construye como un pasillo corto de entrada, dos ramas paralelas y otro
## pasillo corto de salida. El registro de `tramos` solo guarda la rama
## **derecha**: es la directa, y es la que sirve de referencia para colocar
## cosas «a lo largo del tramo B». La izquierda se sitúa a partir de ella.
##
## Las dos ramas son suelo firme y ninguna castiga. La gracia no es acertar,
## es que haya algo que elegir.
func _cruce(paso: Dictionary) -> void:
	var largo: float = paso["largo"]
	var ancho: float = paso["ancho"]
	var separacion: float = paso["separacion"]
	var entrada: float = largo * 0.18
	var salida: float = largo * 0.18
	var ramas: float = largo - entrada - salida

	var lado := _direccion.cross(Vector3.UP).normalized()
	var giro := _giro_actual()
	var alto_base := _altura + grosor_suelo * 0.5

	# Bocas de entrada y salida: anchas, para que se vean las dos ramas de un
	# vistazo y no haya que adivinar que el camino se parte.
	var ancho_boca := separacion + ancho
	for boca: Array in [[entrada * 0.5, entrada], [largo - salida * 0.5, salida]]:
		var eje: float = boca[0]
		var fondo: float = boca[1]
		_losa("SueloCruce", _origen + _direccion * eje + Vector3.UP * _altura,
			Vector3(ancho_boca, grosor_suelo, fondo + solape * 2.0), suelo, giro)
		_losa("CaminoCruce", _origen + _direccion * eje
			+ Vector3.UP * (_altura + grosor_suelo * 0.5 + 0.02),
			Vector3(ancho_boca * 0.8, 0.08, fondo + solape * 2.0), camino,
			giro, 0.0, false)
		# Los costados de la boca dan al vacío: sin muro se cae por ellos justo
		# en el punto donde hay que pararse a mirar por dónde tirar.
		for costado: float in [-1.0, 1.0]:
			_losa("BordeCruce",
				_origen + _direccion * eje
					+ lado * costado * (ancho_boca * 0.5 + ancho_borde * 0.5)
					+ Vector3.UP * (_altura + alto_borde * 0.5 + grosor_suelo * 0.5),
				Vector3(ancho_borde, alto_borde, fondo), borde, giro)

	# Las dos ramas
	for signo: float in [1.0, -1.0]:
		var centro_rama: Vector3 = _origen + _direccion * (entrada + ramas * 0.5) \
			+ lado * signo * (separacion * 0.5) + Vector3.UP * _altura
		_losa("SueloRama", centro_rama,
			Vector3(ancho, grosor_suelo, ramas + solape * 2.0), suelo, giro)
		_losa("CaminoRama", centro_rama + Vector3.UP * (grosor_suelo * 0.5 + 0.02),
			Vector3(ancho_camino, 0.08, ramas + solape * 2.0), camino,
			giro, 0.0, false)
		# Bordes: solo el exterior y el interior de cada rama, para que el hueco
		# del medio se lea como un vacío y no como un tercer camino.
		for costado: float in [-1.0, 1.0]:
			_losa("BordeRama",
				centro_rama + lado * costado * (ancho * 0.5 + ancho_borde * 0.5)
					+ Vector3.UP * (alto_borde * 0.5 + grosor_suelo * 0.5),
				Vector3(ancho_borde, alto_borde, ramas), borde, giro)

	# Tapones a la entrada y a la salida del hueco central. Sin ellos se cruza la
	# boca en línea recta y se cae al vacío entre las dos ramas — que es
	# exactamente lo que hace cualquiera la primera vez, porque venía corriendo.
	# El hueco tiene que verse; caerse en él, no.
	var hueco := separacion - ancho
	if hueco > 0.5:
		for extremo: float in [entrada, entrada + ramas]:
			_losa("BordeHueco",
				_origen + _direccion * extremo
					+ Vector3.UP * (_altura + alto_borde * 0.5 + grosor_suelo * 0.5),
				Vector3(hueco + ancho_borde, alto_borde, ancho_borde),
				borde, giro)

	# La rama de la izquierda lleva plataformas: es la que cuesta y la que paga.
	var base_izq := _origen + _direccion * entrada - lado * (separacion * 0.5)
	for i in 3:
		var t := (float(i) + 0.6) / 3.4
		var pos := base_izq + _direccion * (ramas * t) \
			+ lado * (-1.0 if i % 2 == 0 else 1.0) * (ancho * 0.22) \
			+ Vector3.UP * (alto_base + 0.55 + 0.3 * float(i))
		_losa("Plataforma", pos, Vector3(2.8, 0.5, 2.8), plataforma, giro)

	# El origen se registra en el EJE del cruce, entre las dos ramas, no sobre
	# ninguna de ellas: así `rama` −1/+1 elige una u otra y `rama` 0 sigue siendo
	# el centro, que es donde caen las bocas de entrada y salida.
	tramos.append({
		"origen": _origen + Vector3.UP * _altura,
		"direccion": _direccion,
		"largo": largo, "ancho": ancho, "subida": 0.0,
		"separacion": separacion, "entrada": entrada, "ramas": ramas,
	})
	_origen += _direccion * largo


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
		_losa("Plataforma", centro, Vector3(3.0, 0.5, 3.0), plataforma, giro)


func _arena(paso: Dictionary, salida_dir: Vector3) -> void:
	var radio: float = paso["radio"]
	var centro := _origen + _direccion * radio + Vector3.UP * _altura
	var nombre: String = paso.get("nodo", "")

	# La arena va un escalón por encima del pasillo. Con los dos a la misma
	# altura, la zona de solape —que existe para que no haya agujeros— son dos
	# caras coplanares peleándose, y es justo donde se veían los parpadeos al
	# entrar en la primera arena.
	_disco("SueloArena", centro + Vector3.UP * desnivel, radio + margen_arena,
		arena)
	# Y su superficie de tierra la pinta el terreno, igual que la del camino.
	franjas_camino.append({
		"centro": centro,
		"radio": radio + margen_arena,
	})

	# Anillo con dos huecos: por donde se entra y por donde se sale. El ángulo
	# es el POLAR del anillo (posición `(cos θ, 0, sin θ)`), no una rotación:
	# se entra por el punto opuesto al avance y se sale por el de la dirección
	# siguiente, que puede no ser la misma si hay un giro de por medio.
	var entrada := atan2(-_direccion.z, -_direccion.x)
	var salida := atan2(salida_dir.z, salida_dir.x)
	_anillo(centro, radio, [entrada, salida])

	if nombre != "":
		centros_arena[nombre] = centro
		radios_arena[nombre] = radio
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

## Una caja del blockout: suelo, muro, camino o plataforma.
##
## La malla NO se crea aquí. Se apunta la pose en el lote de su color y se
## vuelca al final en un `MultiMeshInstance3D` por color: ochenta cajas sueltas
## son ochenta draw calls, y el nivel entero tiene un presupuesto de 150
## ([`01-ARQUITECTURA.md`](../../docs/01-ARQUITECTURA.md) §8). Agrupadas son
## cuatro.
##
## La colisión sí sigue siendo un cuerpo por pieza: un `MultiMesh` no colisiona,
## y de todas formas los `StaticBody3D` sin malla no cuestan dibujado.
func _losa(nombre: String, centro: Vector3, tam: Vector3, superficie: String,
		giro: float, inclinacion: float = 0.0, con_colision: bool = true,
		peralte: float = 0.0) -> void:
	# El CAMINO ya no se construye: se pinta sobre el terreno.
	#
	# Era una caja de dieciséis centímetros encima de la losa del suelo, y de ahí
	# salían tres problemas a la vez: un escalón por el que se tropezaba, un
	# canto a la vista que hacía que el sendero pareciera una cinta de cartón
	# puesta sobre la hierba, y dos caras casi coplanares peleándose por el
	# z-buffer. Se apunta dónde va y de eso se encarga la máscara del terreno.
	if nombre.begins_with("Camino"):
		franjas_camino.append({
			"centro": centro,
			"mitad": Vector2(tam.x * 0.5, tam.z * 0.5),
			"giro": giro,
		})
		return

	# `peralte` es el vuelco lateral, sobre el eje que sigue al camino. Lo usan
	# los taludes: una losa de suelo volcada 58° deja de ser suelo y pasa a ser
	# ladera, sin necesidad de otra malla ni de otra forma de colisión.
	#
	# El SUELO tampoco se dibuja ya. Sigue existiendo como cuerpo —da una
	# superficie plana exacta, que la rejilla del terreno no puede garantizar—
	# pero lo que se ve es el terreno, que ahora sube hasta su cara de arriba.
	# Un cuerpo sin malla no cuesta ni un triángulo ni una llamada de dibujado.
	if not nombre.begins_with("Suelo"):
		var pose := Transform3D(
			Basis.from_euler(Vector3(inclinacion, giro, peralte)) * Basis.from_scale(tam),
			centro)
		var lote: Array = _lotes.get(superficie, [])
		lote.append(pose)
		_lotes[superficie] = lote
		_piezas += 1

	if not con_colision:
		return

	var cuerpo := StaticBody3D.new()
	cuerpo.name = nombre
	cuerpo.position = centro
	cuerpo.rotation = Vector3(inclinacion, giro, peralte)
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0

	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = tam
	forma.shape = caja
	cuerpo.add_child(forma)

	add_child(cuerpo)
	if nombre.begins_with("Suelo") or nombre.begins_with("Camino"):
		cuerpos_suelo.append(cuerpo)
	elif nombre.begins_with("Borde") or nombre.begins_with("Plataforma") \
			or nombre.begins_with("Talud"):
		estorbos.append({
			"centro": centro,
			"mitad": Vector2(tam.x * 0.5, tam.z * 0.5),
			"giro": giro,
		})
		# Y hace de TAPADERA: lo que queda detrás de este muro no se dibuja.
		#
		# Un seto de dos metros y pico tapa medio parque cuando se mira desde el
		# camino, y sin esto el motor dibujaba igualmente los cien árboles del
		# otro lado. Solo los muros: los suelos son planos y desde arriba no
		# tapan nada, y cada tapadera cuesta CPU al rasterizarse.
		var tapadera := OccluderInstance3D.new()
		var bulto := BoxOccluder3D.new()
		bulto.size = tam
		tapadera.occluder = bulto
		tapadera.position = centro
		tapadera.rotation = Vector3(inclinacion, giro, peralte)
		add_child(tapadera)


## Crea los `MultiMeshInstance3D` de las cajas, uno por color. Devuelve cuántos.
func _volcar_lotes() -> int:
	# Cubo unitario: cada instancia lleva su tamaño real en la escala de su
	# transformada, así que una sola malla sirve para suelos, muros y caminos.
	var cubo := BoxMesh.new()
	cubo.size = Vector3.ONE

	var hechos := 0
	for superficie: String in _lotes:
		var poses: Array = _lotes[superficie]
		if poses.is_empty():
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = cubo
		multi.instance_count = poses.size()
		for i in poses.size():
			multi.set_instance_transform(i, poses[i])

		var nodo := MultiMeshInstance3D.new()
		nodo.name = "Cajas_%s" % superficie
		nodo.multimesh = multi
		nodo.material_override = PaletaTerreno.obtener(superficie)
		add_child(nodo)
		hechos += 1
	return hechos


func _disco(nombre: String, centro: Vector3, radio: float, superficie: String) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = nombre
	cuerpo.position = centro
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0

	# El suelo de una arena tampoco se dibuja: es el terreno el que sube hasta
	# él y el que pinta su tierra. Lo que queda es el cuerpo, que da una
	# superficie perfectamente plana para pelear encima.
	if not nombre.begins_with("Suelo"):
		var malla := CylinderMesh.new()
		malla.top_radius = radio
		malla.bottom_radius = radio
		malla.height = grosor_suelo
		malla.radial_segments = 24

		var visual := MeshInstance3D.new()
		visual.mesh = malla
		visual.material_override = PaletaTerreno.obtener(superficie)
		cuerpo.add_child(visual)

	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = radio
	cilindro.height = grosor_suelo
	forma.shape = cilindro
	cuerpo.add_child(forma)

	add_child(cuerpo)
	if nombre.begins_with("Suelo") or nombre.begins_with("Camino"):
		cuerpos_suelo.append(cuerpo)
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
		_losa("Borde_arena", pos, Vector3(ancho_seg, alto_borde, ancho_borde),
			borde, PI * 0.5 - angulo)


# --- Sitios del recorrido -------------------------------------------------------

## Un punto sobre un tramo, en sus propias coordenadas.
##
## `t` es lo avanzado por el pasillo (0 a 1), `lado` el desvío lateral en
## fracción del semiancho (0 = centro del camino, ±1 = justo en el borde) y
## `alto` los metros sobre el suelo del tramo.
##
## `rama` solo pinta en los cruces: −1 es la rama larga (la de las plataformas),
## +1 la directa y 0 el eje, por donde pasan las bocas de entrada y salida.
func punto_en_tramo(indice: int, t: float, lado: float, alto: float,
		rama: float = 0.0) -> Vector3:
	if indice < 0 or indice >= tramos.size():
		return Vector3.ZERO
	var tramo: Dictionary = tramos[indice]
	var direccion: Vector3 = tramo["direccion"]
	var costado := direccion.cross(Vector3.UP).normalized()
	var subida: float = tramo["subida"] * t
	var desvio: float = lado * tramo["ancho"] * 0.5 \
		+ rama * tramo.get("separacion", 0.0) * 0.5
	return tramo["origen"] \
		+ direccion * (tramo["largo"] * t) \
		+ costado * desvio \
		+ Vector3.UP * (grosor_suelo * 0.5 + subida + alto)


## Coloca los faroles del nivel. Devuelve cuántos puso.
##
## El tercero va sobre una peana: sin ella estaría flotando, y colgar un
## objetivo en el aire sin nada que lo sostenga se lee como un error.
func sembrar_faroles(escena: PackedScene, destino: Node) -> int:
	if escena == null:
		return 0
	var puestos := 0
	for ficha in FAROLES:
		var farol := escena.instantiate() as Node3D
		if farol == null:
			continue
		destino.add_child(farol)
		# El nombre se pone a mano: instanciando la misma escena varias veces,
		# Godot renombra las copias a `@Area3D@388` y compañía, y con eso no hay
		# quien depure ni quien las referencie desde fuera.
		farol.name = ficha["id"].capitalize()
		var sitio := punto_en_tramo(
			ficha["tramo"], ficha["t"], ficha["lado"], ficha["alto"],
			ficha.get("rama", 0.0))
		farol.global_position = sitio
		if "id" in farol:
			farol.set("id", ficha["id"])
		if ficha["alto"] > 0.1:
			_peana(sitio, ficha["alto"])
		puestos += 1
	return puestos


## Bloque que sostiene un farol colgado en alto.
##
## Se apoya en el SUELO REAL, no a `altura` por debajo del farol: en el pasillo
## que sube al guardián el terreno de al lado está más bajo que el camino, y
## restando a ojo la peana quedaba en el aire con el farol encima. Era el farol
## flotante.
func _peana(cima: Vector3, sobre_el_camino: float) -> void:
	var espacio := get_world_3d().direct_space_state
	var base := cima.y - sobre_el_camino
	if espacio != null:
		var consulta := PhysicsRayQueryParameters3D.create(
			cima + Vector3.UP * 1.0, cima + Vector3.DOWN * 12.0)
		consulta.collision_mask = 1
		var choque := espacio.intersect_ray(consulta)
		if not choque.is_empty():
			base = choque["position"].y
	var alto := maxf(cima.y - base, 0.4)
	_losa("Peana", Vector3(cima.x, base + alto * 0.5, cima.z),
		Vector3(2.2, alto, 2.2), plataforma, 0.0)


## Siembra las Estrellas de Sueño. Devuelve cuántas colocó.
func sembrar_estrellas(escena: PackedScene, destino: Node) -> int:
	if escena == null:
		return 0
	var puestas := 0
	for ficha in ESTRELLAS:
		var estrella := escena.instantiate() as Node3D
		if estrella == null:
			continue
		destino.add_child(estrella)
		estrella.name = "Estrella%d" % (puestas + 1)
		estrella.global_position = punto_en_tramo(
			ficha["tramo"], ficha["t"], ficha["lado"], ficha["alto"],
			ficha.get("rama", 0.0))
		if ficha.get("secreta", false) and "es_secreta" in estrella:
			estrella.set("es_secreta", true)
		puestas += 1
	return puestas


## Los tramos abiertos en carriles: cada rama de un cruce pasa a ser un tramo
## normal e independiente.
##
## Existe para el decorador. Sembrando por `tramos` a secas, un cruce recibiría
## una sola hilera de árboles por el eje, justo por el hueco donde no hay suelo.
func carriles() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for tramo in tramos:
		var separacion: float = tramo.get("separacion", 0.0)
		if separacion <= 0.0:
			lista.append(tramo)
			continue
		var direccion: Vector3 = tramo["direccion"]
		var costado: Vector3 = direccion.cross(Vector3.UP).normalized()
		for signo: float in [-1.0, 1.0]:
			var carril := tramo.duplicate()
			# El carril cubre SOLO la franja de las ramas, no las bocas: estas
			# son una losa ancha que va de lado a lado, y sembrarlas con las
			# medidas de una rama planta los árboles en mitad del paso.
			carril["origen"] = tramo["origen"] \
				+ direccion * float(tramo["entrada"]) \
				+ costado * signo * separacion * 0.5
			carril["largo"] = tramo["ramas"]
			carril.erase("separacion")
			lista.append(carril)
	return lista


## Por dónde tiene que subir el terreno para quedar a ras del escenario.
##
## Cada zona es una forma en el plano con una altura. Las hay de dos clases:
## `{centro, mitad, giro, altura}` es un rectángulo orientado —los tramos— y
## `{centro, radio, altura}` un círculo —las arenas—.
##
## **La altura es la de la superficie por la que se anda**, no la del apoyo. Es
## el cambio que hace que el suelo del blockout ya no haga falta dibujarlo: el
## terreno llega justo a su cara de arriba, lo tapa, y lo que se ve es una
## superficie continua en vez de una losa apoyada encima del mapa.
##
## Antes solo entraban aquí las partes ELEVADAS, porque el resto ya se apoyaba
## en el terreno plano. Ahora entran todas, incluidas las de altura cero: su
## superficie está medio metro por encima del cero y el terreno tiene que
## alcanzarla igual.
##
## Se calculan de la geometría que este nodo acaba de construir, y no midiendo
## el mundo con rayos como se intentó primero. Aquello daba el valor correcto en
## el vértice equivocado —el final del primer pasillo subía a la altura de la
## arena del guardián, a setenta metros de allí— y localizar el cruce costaba
## más que quitar el problema de en medio. Aquí no hay rejilla, ni índices, ni
## física: solo los sitios que este código ya sabe dónde están.
func zonas_elevadas() -> Array[Dictionary]:
	var zonas: Array[Dictionary] = []
	for indice in tramos.size():
		var tramo: Dictionary = tramos[indice]
		# Un tramo en cuesta se trocea: cada trozo aporta su propia altura, y
		# entre todos dibujan la rampa.
		#
		# Cada trozo es un RECTÁNGULO, no un círculo. Con círculos el terreno
		# subía en festón —redondeado por los lados y sin llegar a las esquinas—
		# y por ahí asomaba el canto de la losa: ese era el «bloque cuadrado
		# puesto encima del mapa». Un tramo es un rectángulo, así que la zona que
		# lo sostiene tiene que serlo también.
		var trozos := maxi(int(tramo["largo"] / 3.0), 1)
		var largo_trozo: float = tramo["largo"] / float(trozos)
		var direccion: Vector3 = tramo["direccion"]
		var giro := atan2(-direccion.x, -direccion.z)
		for i in trozos + 1:
			var t := float(i) / float(trozos)
			var punto := punto_en_tramo(indice, t, 0.0, 0.0)
			zonas.append({
				"centro": punto,
				# A lo ancho llega hasta pasado el muro; a lo largo, medio trozo
				# por lado más un solape, para que entre trozo y trozo no quede
				# una muesca sin levantar.
				"mitad": Vector2(tramo["ancho"] * 0.5 + ancho_borde,
					largo_trozo * 0.6),
				"giro": giro,
				"altura": punto.y,
			})
	for nombre: String in centros_arena:
		var centro: Vector3 = centros_arena[nombre]
		zonas.append({
			"centro": centro,
			"radio": float(radios_arena.get(nombre, 11.0)) + margen_arena,
			# La superficie del disco de la arena: su eje va un `desnivel` por
			# encima del pasillo, y de ahí media losa hasta la cara de arriba.
			"altura": centro.y + desnivel + grosor_suelo * 0.5,
		})
	return zonas


## Centro y radio de todo lo construido, en el plano. El decorador lo usa para
## saber a qué distancia poner el fondo lejano sin que se meta en el nivel.
func extension() -> Dictionary:
	var puntos: Array[Vector3] = []
	for tramo in tramos:
		puntos.append(tramo["origen"])
		puntos.append(tramo["origen"] + tramo["direccion"] * tramo["largo"])
	for centro in centros_arena.values():
		puntos.append(centro)
	if puntos.is_empty():
		return {"centro": Vector3.ZERO, "radio": 40.0}

	var minimo := puntos[0]
	var maximo := puntos[0]
	for punto in puntos:
		minimo = minimo.min(punto)
		maximo = maximo.max(punto)
	var centro := (minimo + maximo) * 0.5
	centro.y = 0.0
	var radio := maxf((maximo - minimo).length() * 0.5, 20.0)
	return {"centro": centro, "radio": radio}


func _giro_actual() -> float:
	return atan2(-_direccion.x, -_direccion.z)
