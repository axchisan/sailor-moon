extends CanvasLayer
class_name Cinematica
## Reproduce una cinemática de viñetas: imagen, movimiento de cámara y texto.
##
## ## Por qué viñetas y no vídeo
##
## Un vídeo de minuto y medio a resolución de móvil son treinta megas y no se
## puede tocar: cambiar una frase obliga a renderizarlo todo otra vez. Con
## viñetas, cada una es una imagen y su texto — se corrige una línea y ya está.
##
## Y **se puede saltar en cualquier momento**, que en un vídeo hay que montarlo
## aparte. Quien ya ha visto la apertura tres veces no tiene que volver a verla.
##
## ## El movimiento es lo que la hace cinemática
##
## Una imagen fija con texto debajo es un libro. La misma imagen acercándose muy
## despacio mientras se lee es una escena. Cada viñeta define de dónde a dónde va
## la cámara —un acercamiento, un desplazamiento— y eso, con lo lento que va,
## hace la mitad del trabajo.
##
## ## El texto entra escrito, no aparece
##
## Se escribe letra a letra al ritmo de la lectura. No es un adorno: marca el
## tiempo. Una frase que aparece entera se lee en un segundo y deja seis de
## espera incómoda; escribiéndose, el tiempo de la viñeta y el de leerla son el
## mismo.

signal terminada

## Cuánto tarda en escribirse cada letra.
const POR_LETRA := 0.045
## Cuánto se queda la última frase antes de pasar de viñeta.
const RESPIRO := 1.6
## El fundido entre viñetas.
const FUNDIDO := 0.8

var _viñetas: Array[Dictionary] = []
var _cual: int = 0
var _lienzo: Control = null
var _dibujo: DibujoVineta = null
var _texto: Label = null
var _saltar: Button = null
var _velo: ColorRect = null
var _cortada: bool = false


## Arranca. `viñetas` es una lista de `{dibujo, camara, lineas}`:
## - `dibujo`: qué se pinta (ver `DibujoVineta.TIPOS`)
## - `camara`: `[zoom_inicio, zoom_fin, desliz_x]` — el movimiento lento
## - `lineas`: las frases, en orden
func reproducir(viñetas: Array[Dictionary]) -> void:
	_viñetas = viñetas
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	await _pasar_todas()
	terminada.emit()


func _montar() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.04, 0.02, 0.08)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	_lienzo = Control.new()
	_lienzo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.clip_contents = true
	add_child(_lienzo)

	_dibujo = DibujoVineta.new()
	_lienzo.add_child(_dibujo)

	# EL TEXTO SOBRE UNA BANDA OSCURA, NO SUELTO SOBRE LA IMAGEN.
	#
	# Una ilustración tiene zonas claras y oscuras, y un texto encima acaba
	# ilegible en alguna de ellas por muy grueso que sea el contorno. La banda
	# garantiza que se lee siempre, y de paso encuadra la imagen como un plano de
	# cine.
	var banda := ColorRect.new()
	banda.color = Color(0.04, 0.02, 0.08, 0.82)
	banda.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	banda.anchor_top = 1.0
	banda.offset_top = -196.0
	banda.offset_bottom = 0.0
	banda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banda)

	_texto = Estilo.texto("", 27, Estilo.CREMA, false, 500)
	_texto.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texto.offset_left = 90.0
	_texto.offset_right = -90.0
	_texto.offset_top = 34.0
	_texto.offset_bottom = -34.0
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banda.add_child(_texto)

	_saltar = Estilo.boton("Saltar", 150.0)
	_saltar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_saltar.offset_left = -186.0
	_saltar.offset_right = -30.0
	_saltar.offset_top = 30.0
	_saltar.offset_bottom = 88.0
	_saltar.modulate.a = 0.55
	_saltar.pressed.connect(func() -> void: _cortada = true)
	add_child(_saltar)

	_velo = ColorRect.new()
	_velo.color = Color(0.04, 0.02, 0.08, 1.0)
	_velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_velo)


func _pasar_todas() -> void:
	for i in _viñetas.size():
		if _cortada:
			break
		_cual = i
		await _una(_viñetas[i])
	await _cerrar()


func _una(v: Dictionary) -> void:
	_dibujo.poner(str(v.get("dibujo", "")))
	_texto.text = ""

	# El movimiento arranca ANTES del fundido de entrada. Si empieza cuando la
	# imagen ya se ve, se nota el tirón del primer fotograma.
	var camara: Array = v.get("camara", [1.0, 1.12, 0.0])
	_dibujo.mover(float(camara[0]), float(camara[1]), float(camara[2]),
		_duracion(v))

	var t := create_tween()
	t.tween_property(_velo, "color:a", 0.0, FUNDIDO)
	await t.finished

	for linea: String in v.get("lineas", []):
		if _cortada:
			return
		await _escribir(linea)
		if _cortada:
			return
		await _esperar(RESPIRO)

	var s := create_tween()
	s.tween_property(_velo, "color:a", 1.0, FUNDIDO)
	await s.finished


## Cuánto dura una viñeta: lo que se tarda en leerla, más los respiros.
func _duracion(v: Dictionary) -> float:
	var letras := 0
	for linea: String in v.get("lineas", []):
		letras += linea.length()
	return FUNDIDO * 2.0 + float(letras) * POR_LETRA \
		+ RESPIRO * float(v.get("lineas", []).size())


func _escribir(linea: String) -> void:
	_texto.text = ""
	var puestas := 0
	while puestas < linea.length():
		if _cortada:
			_texto.text = linea
			return
		puestas += 1
		_texto.text = linea.substr(0, puestas)
		# Las pausas de la puntuación son lo que hace que suene a alguien
		# contando y no a una máquina escribiendo.
		var espera := POR_LETRA
		var ultima := linea[puestas - 1]
		if ultima == "," or ultima == ";":
			espera += 0.18
		elif ultima == "." or ultima == "!" or ultima == "?":
			espera += 0.34
		await get_tree().create_timer(espera).timeout


func _esperar(cuanto: float) -> void:
	var pasado := 0.0
	while pasado < cuanto:
		if _cortada:
			return
		await get_tree().process_frame
		pasado += get_process_delta_time()


func _cerrar() -> void:
	var t := create_tween()
	t.tween_property(_velo, "color:a", 1.0, 0.5)
	await t.finished
	queue_free()


func _input(evento: InputEvent) -> void:
	# Tocar la pantalla adelanta el texto que se está escribiendo; para saltarla
	# entera está el botón. Así no se salta la cinemática sin querer al tocar.
	var toque := evento is InputEventScreenTouch or evento is InputEventMouseButton
	if toque and evento.is_pressed():
		_adelantar = true


var _adelantar: bool = false
