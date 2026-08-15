extends Control
class_name FondoMenu
## El fondo del menú: cielo, luna, estrellas y pétalos cayendo.
##
## ## Por qué dibujado y no una imagen
##
## Una ilustración de fondo pesaría dos megas, habría que rehacerla para cada
## proporción de pantalla —y los móviles tienen todas— y estaría quieta. Esto
## ocupa nada, se adapta solo a cualquier tamaño y **se mueve**, que es la mitad
## de que una pantalla de inicio parezca viva en vez de un cartel.
##
## ## Lo que se mueve, y a qué velocidad
##
## Tres capas a ritmos distintos: los pétalos delante y rápidos, las estrellas
## detrás y casi quietas, la luna sin moverse. Esa diferencia de velocidades es
## lo que da sensación de profundidad sin tener nada en 3D.
##
## Todo va **lento**. Es la pantalla que se mira mientras se decide jugar, y una
## animación rápida ahí agobia y cansa a los dos minutos.

const ESTRELLAS := 46
const PETALOS := 22

## De arriba abajo del cielo. Morado hondo arriba y rosa amanecer abajo — es la
## paleta del parque al atardecer, para que el menú y el juego sean el mismo
## sitio.
const CIELO_ALTO := Color(0.16, 0.09, 0.32)
const CIELO_MEDIO := Color(0.38, 0.20, 0.48)
const CIELO_BAJO := Color(0.96, 0.62, 0.68)

var _t: float = 0.0
var _estrellas: Array[Dictionary] = []
var _petalos: Array[Dictionary] = []


func _ready() -> void:
	# CON OFFSETS, no solo con anchors: `set_anchors_preset` deja los márgenes
	# como estaban, y con todos a cero el rectángulo mide 0x0 por mucho que los
	# anchors digan «pantalla entera». El fondo se dibujaba en un rectángulo
	# vacío y no se veía nada.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dado := RandomNumberGenerator.new()
	# Semilla fija: el fondo sale igual cada vez que se abre el juego. Un fondo
	# que cambia de sitio en cada arranque se nota, y no para bien.
	dado.seed = 20260814
	for i in ESTRELLAS:
		_estrellas.append({
			"p": Vector2(dado.randf(), dado.randf() * 0.72),
			"r": dado.randf_range(1.2, 2.8),
			"f": dado.randf() * TAU,
			"v": dado.randf_range(0.5, 1.4),
		})
	for i in PETALOS:
		_petalos.append({
			"x": dado.randf(),
			"y": dado.randf(),
			"r": dado.randf_range(5.0, 11.0),
			"v": dado.randf_range(0.020, 0.055),
			"g": dado.randf() * TAU,
			"b": dado.randf_range(0.05, 0.14),
		})
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	for p: Dictionary in _petalos:
		var y: float = p["y"]
		var v: float = p["v"]
		p["y"] = fposmod(y + v * delta, 1.15)
	queue_redraw()


func _draw() -> void:
	var s := size
	if s.x < 1.0 or s.y < 1.0:
		return

	# El cielo, en franjas. Un degradado de verdad pediría un shader y otro
	# material; con veintiséis franjas y suavizado no se distingue.
	var franjas := 26
	for i in franjas:
		var t := float(i) / float(franjas - 1)
		var c := CIELO_ALTO.lerp(CIELO_MEDIO, minf(t * 1.7, 1.0))
		if t > 0.58:
			c = CIELO_MEDIO.lerp(CIELO_BAJO, (t - 0.58) / 0.42)
		draw_rect(Rect2(0.0, s.y * t - 1.0, s.x, s.y / float(franjas) + 2.0), c)

	# Estrellas: parpadean a distinto ritmo cada una. Con el mismo ritmo se ve
	# el pulso general y parece un fallo de la pantalla.
	for e: Dictionary in _estrellas:
		var vel: float = e["v"]
		var fase: float = e["f"]
		var rad: float = e["r"]
		var brillo := 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * vel + fase))
		var punto: Vector2 = e["p"]
		var pos := Vector2(punto.x * s.x, punto.y * s.y)
		draw_circle(pos, rad, Color(1.0, 0.97, 0.88, brillo * 0.9))

	# La luna, arriba a la derecha. Es el emblema del personaje: si el fondo
	# tiene que decir de qué va esto sin una palabra, lo dice la luna.
	var luna := Vector2(s.x * 0.80, s.y * 0.20)
	var radio := minf(s.x, s.y) * 0.11
	# Halo en capas, de fuera adentro
	for i in range(6, 0, -1):
		draw_circle(luna, radio * (1.0 + i * 0.16),
			Color(1.0, 0.92, 0.72, 0.045 - i * 0.004))
	draw_circle(luna, radio, Color(1.0, 0.96, 0.84, 0.97))
	# El creciente se hace tapando con el color del cielo, no dibujando una luna
	# recortada: así encaja exactamente con lo que tiene detrás.
	draw_circle(luna + Vector2(radio * 0.42, -radio * 0.22), radio * 0.94,
		CIELO_ALTO.lerp(CIELO_MEDIO, 0.34))

	# Pétalos, delante de todo. Caen girando y con vaivén: en línea recta
	# parecen lluvia.
	for p: Dictionary in _petalos:
		var py: float = p["y"]
		var y := py * (s.y + 80.0) - 40.0
		var px: float = p["x"]
		var pg: float = p["g"]
		var x := px * s.x + sin(_t * 0.55 + pg) * s.x * 0.035
		var r: float = p["r"]
		var gir: float = p["g"]
		var giro := _t * 0.7 + gir
		# Cada pétalo es un óvalo hecho con cuatro puntos: más barato que una
		# textura y a este tamaño no se distingue.
		var puntos := PackedVector2Array([
			Vector2(0, -r), Vector2(r * 0.62, 0),
			Vector2(0, r * 0.85), Vector2(-r * 0.62, 0),
		])
		var giradas := PackedVector2Array()
		for q: Vector2 in puntos:
			giradas.append(Vector2(x, y) + q.rotated(giro))
		var alfa: float = p["b"]
		draw_colored_polygon(giradas, Color(1.0, 0.76, 0.86, alfa + 0.5))
