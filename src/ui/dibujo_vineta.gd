extends Control
class_name DibujoVineta

## Las ilustraciones de la cinemática, dibujadas por código.
##
## ## Por qué dibujadas y no ilustradas
##
## Cinco ilustraciones buenas son cinco encargos, y hasta que lleguen la
## cinemática no existe y no se puede probar el montaje: ni los tiempos, ni el
## texto, ni cómo encaja con la música. Dibujadas, la apertura **funciona hoy** y
## las ilustraciones pueden entrar mañana cambiando una línea.
##
## No pretenden ser arte final. Pretenden que se entienda qué se está contando
## —un espejo, una grieta, una lluvia de estrellas— y que se vea bonito con la
## paleta del juego. Los prompts de las cinco están en
## [`16-GUION.md`](../../docs/16-GUION.md).
##
## ## Sustituirlas
##
## `poner()` acepta también una ruta de imagen. En cuanto haya un `.png` por
## viñeta, se cambia el nombre por la ruta y esto deja de dibujarse solo.

const CIELO_ALTO := Color(0.10, 0.06, 0.24)
const CIELO_BAJO := Color(0.30, 0.16, 0.42)
const ORO := Color(1.0, 0.88, 0.62)
const ROSA := Color(1.0, 0.62, 0.80)
const FRIO := Color(0.42, 0.44, 0.78)

var _cual: String = ""
var _imagen: Texture2D = null
var _t: float = 0.0
var _zoom: float = 1.0
var _desliz: float = 0.0
var _estrellas: Array[Vector3] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dado := RandomNumberGenerator.new()
	dado.seed = 9912
	for i in 90:
		_estrellas.append(Vector3(dado.randf(), dado.randf(),
			dado.randf_range(0.7, 2.4)))
	set_process(true)


## Qué se pinta. Si es una ruta a una imagen, se usa esa; si no, se dibuja.
func poner(cual: String) -> void:
	_cual = cual
	_imagen = null
	if cual.begins_with("res://"):
		_imagen = load(cual) as Texture2D
	queue_redraw()


## El movimiento lento de cámara. Es lo que separa una escena de una lámina.
func mover(desde: float, hasta: float, desliz: float, cuanto: float) -> void:
	_zoom = desde
	_desliz = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_method(func(v: float) -> void:
		_zoom = v
		queue_redraw(), desde, hasta, cuanto)
	t.tween_method(func(v: float) -> void:
		_desliz = v
		queue_redraw(), 0.0, desliz, cuanto)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	if s.x < 1.0 or s.y < 1.0:
		return

	if _imagen != null:
		# Con imagen de verdad: se dibuja centrada y con el mismo zoom, para que
		# el movimiento de cámara siga funcionando igual.
		var t := s * _zoom
		draw_texture_rect(_imagen, Rect2(
			(s.x - t.x) * 0.5 + _desliz * s.x, (s.y - t.y) * 0.5, t.x, t.y), false)
		return

	_cielo(s)
	match _cual:
		"espejo_entero": _espejo(s, false)
		"espejo_roto": _espejo(s, true)
		"lluvia": _lluvia(s)
		"dama": _dama(s)
		"serena": _ventana(s)
		_: pass


## El fondo común: noche con estrellas. Sale en las cinco porque las cinco pasan
## de noche, y repetirlo es lo que las hace la misma historia.
func _cielo(s: Vector2) -> void:
	var franjas := 22
	for i in franjas:
		var t := float(i) / float(franjas - 1)
		draw_rect(Rect2(0.0, s.y * t - 1.0, s.x, s.y / float(franjas) + 2.0),
			CIELO_ALTO.lerp(CIELO_BAJO, t))
	for e in _estrellas:
		var brillo := 0.35 + 0.45 * (0.5 + 0.5 * sin(_t * e.z + e.x * 30.0))
		draw_circle(Vector2((e.x + _desliz) * s.x, e.y * s.y * 0.8),
			e.z * 0.8 * _zoom, Color(1.0, 0.96, 0.86, brillo))


func _espejo(s: Vector2, roto: bool) -> void:
	var c := Vector2(s.x * 0.5 + _desliz * s.x, s.y * 0.46)
	var r := minf(s.x, s.y) * 0.26 * _zoom

	# Marco dorado: dos óvalos, uno dentro de otro.
	_ovalo(c, r * 1.14, r * 1.42, Color(0.86, 0.68, 0.32))
	_ovalo(c, r * 1.05, r * 1.32, Color(1.0, 0.86, 0.52))
	_ovalo(c, r, r * 1.26, Color(0.62, 0.70, 0.92, 0.92))
	# El reflejo: unas manchas suaves que se leen como gente durmiendo.
	for i in 5:
		var a := TAU * float(i) / 5.0 + _t * 0.1
		_ovalo(c + Vector2(cos(a), sin(a) * 1.2) * r * 0.42,
			r * 0.17, r * 0.13, Color(1.0, 0.92, 0.78, 0.24))

	if not roto:
		return

	# La grieta, y la luz escapándose por ella. Es lo único que cambia entre la
	# viñeta 1 y la 2: la misma imagen rota cuenta el antes y el después mejor
	# que dos dibujos distintos.
	var puntos := PackedVector2Array([
		c + Vector2(-r * 0.72, -r * 1.16), c + Vector2(-r * 0.18, -r * 0.36),
		c + Vector2(-r * 0.42, r * 0.12), c + Vector2(r * 0.12, r * 0.72),
		c + Vector2(r * 0.02, r * 1.2),
	])
	for i in puntos.size() - 1:
		draw_line(puntos[i], puntos[i + 1], Color(1.0, 0.98, 0.88, 0.95),
			maxf(2.0, r * 0.045))
	for i in 16:
		var t := float(i) / 15.0
		var p := puntos[mini(int(t * 4.0), 3)].lerp(
			puntos[mini(int(t * 4.0) + 1, 4)], fposmod(t * 4.0, 1.0))
		draw_circle(p, r * 0.05 * (0.4 + sin(_t * 2.0 + float(i)) * 0.3),
			Color(1.0, 0.94, 0.72, 0.5))


func _lluvia(s: Vector2) -> void:
	# La ciudad abajo, como una silueta de tejados. Rectángulos de distinta
	# altura: a esta escala una ciudad no es más que eso.
	var base := s.y * 0.78
	var dado := RandomNumberGenerator.new()
	dado.seed = 3311
	var x := -20.0
	while x < s.x + 20.0:
		var an := dado.randf_range(26.0, 78.0)
		var al := dado.randf_range(30.0, 130.0)
		draw_rect(Rect2(x + _desliz * s.x * 0.4, base - al, an, al + s.y),
			Color(0.13, 0.09, 0.24))
		# Ventanas encendidas, pocas: es de noche y la gente duerme.
		if dado.randf() < 0.5:
			draw_rect(Rect2(x + _desliz * s.x * 0.4 + an * 0.3,
				base - al * 0.65, an * 0.22, an * 0.18),
				Color(1.0, 0.88, 0.6, 0.5))
		x += an + dado.randf_range(4.0, 16.0)

	# Y las estrellas cayendo, con estela.
	for i in 40:
		var f := fposmod(_t * 0.16 + float(i) * 0.137, 1.0)
		var px := fposmod(float(i) * 0.191 + 0.05, 1.0) * s.x
		var py := f * base
		draw_line(Vector2(px, py - 26.0 * _zoom), Vector2(px, py),
			Color(1.0, 0.86, 0.5, 0.35), 2.0)
		draw_circle(Vector2(px, py), 3.4 * _zoom, ORO)


func _dama(s: Vector2) -> void:
	# El espejo roto detrás, en frío.
	var c := Vector2(s.x * 0.62 + _desliz * s.x, s.y * 0.42)
	var r := minf(s.x, s.y) * 0.3 * _zoom
	_ovalo(c, r, r * 1.3, Color(0.22, 0.24, 0.46, 0.95))
	for i in 7:
		var a := TAU * float(i) / 7.0
		draw_line(c, c + Vector2(cos(a), sin(a) * 1.3) * r,
			Color(0.55, 0.60, 0.92, 0.5), 2.0)

	# Ella de espaldas: silueta, sin cara. Lo que la hace dar pena es que no se
	# le ve — una villana con cara de mala sería otra historia.
	var pies := s.y * 0.92
	var alto := s.y * 0.52 * _zoom
	var cx := s.x * 0.36 + _desliz * s.x
	var falda := PackedVector2Array([
		Vector2(cx - alto * 0.30, pies), Vector2(cx + alto * 0.30, pies),
		Vector2(cx + alto * 0.10, pies - alto * 0.62),
		Vector2(cx - alto * 0.10, pies - alto * 0.62),
	])
	draw_colored_polygon(falda, Color(0.16, 0.13, 0.30))
	draw_circle(Vector2(cx, pies - alto * 0.74), alto * 0.11,
		Color(0.16, 0.13, 0.30))
	# El brazo levantado, recogiendo una estrella.
	draw_line(Vector2(cx + alto * 0.07, pies - alto * 0.58),
		Vector2(cx + alto * 0.30, pies - alto * 0.86),
		Color(0.16, 0.13, 0.30), maxf(3.0, alto * 0.05))
	var estrella := Vector2(cx + alto * 0.34, pies - alto * 0.92)
	draw_circle(estrella, alto * 0.05 + sin(_t * 3.0) * 1.5, ORO)
	draw_circle(estrella, alto * 0.10, Color(1.0, 0.88, 0.62, 0.22))


func _ventana(s: Vector2) -> void:
	# La luna llena, grande, y la gata recortada contra ella.
	var luna := Vector2(s.x * 0.68 + _desliz * s.x, s.y * 0.32)
	var r := minf(s.x, s.y) * 0.19 * _zoom
	for i in range(5, 0, -1):
		draw_circle(luna, r * (1.0 + i * 0.2),
			Color(1.0, 0.94, 0.78, 0.05 - i * 0.005))
	draw_circle(luna, r, Color(1.0, 0.96, 0.86, 0.98))

	# El marco de la ventana, en primer plano y oscuro.
	var m := 14.0
	draw_rect(Rect2(s.x * 0.12, s.y * 0.08, s.x * 0.76, m), Color(0.10, 0.06, 0.18))
	draw_rect(Rect2(s.x * 0.12, s.y * 0.08, m, s.y * 0.76), Color(0.10, 0.06, 0.18))
	draw_rect(Rect2(s.x * 0.88 - m, s.y * 0.08, m, s.y * 0.76), Color(0.10, 0.06, 0.18))
	draw_rect(Rect2(s.x * 0.12, s.y * 0.62, s.x * 0.76, m), Color(0.10, 0.06, 0.18))

	# Luna, sentada en el alféizar. Dos orejas y una cola: con eso ya es un gato.
	var g := Vector2(s.x * 0.30 + _desliz * s.x, s.y * 0.62)
	var alto := s.y * 0.16 * _zoom
	draw_colored_polygon(PackedVector2Array([
		Vector2(g.x - alto * 0.32, g.y), Vector2(g.x + alto * 0.32, g.y),
		Vector2(g.x + alto * 0.20, g.y - alto * 0.72),
		Vector2(g.x - alto * 0.20, g.y - alto * 0.72),
	]), Color(0.06, 0.04, 0.12))
	draw_circle(Vector2(g.x, g.y - alto * 0.86), alto * 0.22, Color(0.06, 0.04, 0.12))
	for lado in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(g.x + lado * alto * 0.20, g.y - alto * 0.98),
			Vector2(g.x + lado * alto * 0.05, g.y - alto * 1.04),
			Vector2(g.x + lado * alto * 0.17, g.y - alto * 1.26),
		]), Color(0.06, 0.04, 0.12))
	# La luna creciente de su frente, que es quien es.
	draw_arc(Vector2(g.x, g.y - alto * 0.92), alto * 0.10, PI * 0.2, PI * 1.3,
		10, ORO, 2.0)


## Un óvalo relleno. `draw_circle` solo hace círculos y un espejo es ovalado.
func _ovalo(c: Vector2, rx: float, ry: float, color: Color) -> void:
	var puntos := PackedVector2Array()
	for i in 30:
		var a := TAU * float(i) / 30.0
		puntos.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(puntos, color)
