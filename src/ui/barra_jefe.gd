extends CanvasLayer
class_name BarraJefe
## La barra de vida del guardián, arriba del todo.
##
## ## Por qué hace falta
##
## Sin ella la pelea no dice nada de sí misma: se pega y se pega sin saber si
## queda mucho o si va bien. En un enemigo de tres golpes da igual, pero en uno
## que aguanta treinta y pico esa falta de información convierte una pelea en un
## trámite largo — y a los ocho años, en el momento de dejarlo.
##
## ## Cómo enseña las fases
##
## La barra va partida en tres tramos con dos marcas, en los mismos puntos donde
## el guardián cambia de fase. No hay que explicárselo a nadie: al llegar a una
## marca pasa algo, y a la segunda vez ya se sabe que la siguiente marca también
## significa algo. Es la forma más barata de contar la estructura de la pelea.
##
## El daño se ve en dos capas — una roja que baja de golpe y otra clara detrás
## que la sigue con retraso — porque un salto seco no deja ver *cuánto* has
## quitado, y ese retraso es justo lo que hace que un buen golpe se sienta bueno.

const ALTO := 22.0
const ROSA := Color(1.0, 0.42, 0.62)
const FONDO := Color(0.10, 0.05, 0.16, 0.88)

var _raiz: Control = null
var _relleno: ColorRect = null
var _estela: ColorRect = null
var _nombre: Label = null
var _ancho: float = 0.0
var _objetivo: float = 1.0


func montar(titulo: String, cortes: Array) -> void:
	layer = 15
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	var caja := Control.new()
	caja.set_anchors_preset(Control.PRESET_TOP_WIDE)
	caja.anchor_left = 0.5
	caja.anchor_right = 0.5
	caja.offset_left = -330.0
	caja.offset_right = 330.0
	caja.offset_top = 74.0
	caja.offset_bottom = 74.0 + ALTO + 30.0
	caja.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(caja)
	_ancho = 660.0

	_nombre = Label.new()
	_nombre.text = titulo
	_nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nombre.add_theme_font_size_override("font_size", 21)
	_nombre.add_theme_color_override("font_color", Color(1.0, 0.93, 0.97))
	_nombre.add_theme_color_override("font_outline_color", Color(0.16, 0.04, 0.12))
	_nombre.add_theme_constant_override("outline_size", 7)
	_nombre.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_nombre.offset_bottom = 26.0
	caja.add_child(_nombre)

	var marco := ColorRect.new()
	marco.color = FONDO
	marco.set_anchors_preset(Control.PRESET_TOP_WIDE)
	marco.offset_top = 28.0
	marco.offset_bottom = 28.0 + ALTO
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(marco)

	# La estela va DEBAJO del relleno y llega más lejos: es lo que se acaba de
	# quitar, y se ve un instante antes de recogerse.
	_estela = ColorRect.new()
	_estela.color = Color(1.0, 0.86, 0.92, 0.55)
	_estela.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_estela.offset_top = 31.0
	_estela.offset_bottom = 28.0 + ALTO - 3.0
	_estela.offset_left = 3.0
	_estela.offset_right = _ancho - 3.0
	_estela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(_estela)

	_relleno = ColorRect.new()
	_relleno.color = ROSA
	_relleno.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_relleno.offset_top = 31.0
	_relleno.offset_bottom = 28.0 + ALTO - 3.0
	_relleno.offset_left = 3.0
	_relleno.offset_right = _ancho - 3.0
	_relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(_relleno)

	for corte in cortes:
		var marca := ColorRect.new()
		marca.color = Color(0.10, 0.05, 0.16, 0.9)
		marca.set_anchors_preset(Control.PRESET_TOP_LEFT)
		marca.offset_top = 28.0
		marca.offset_bottom = 28.0 + ALTO
		marca.offset_left = (_ancho - 6.0) * float(corte) + 3.0
		marca.offset_right = marca.offset_left + 3.0
		marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja.add_child(marca)

	_raiz.modulate.a = 0.0
	create_tween().tween_property(_raiz, "modulate:a", 1.0, 0.5)
	set_process(true)


func poner(actual: int, maxima: int) -> void:
	_objetivo = clampf(float(actual) / float(maxi(maxima, 1)), 0.0, 1.0)
	if _relleno != null:
		_relleno.offset_right = 3.0 + (_ancho - 6.0) * _objetivo


func _process(delta: float) -> void:
	if _estela == null or _relleno == null:
		return
	# La estela persigue al relleno, siempre por detrás y nunca por delante.
	var destino := _relleno.offset_right
	if _estela.offset_right > destino:
		_estela.offset_right = maxf(destino,
			_estela.offset_right - (_ancho * 0.35) * delta)
	else:
		_estela.offset_right = destino


func quitar() -> void:
	if _raiz == null:
		queue_free()
		return
	set_process(false)
	var t := create_tween()
	t.tween_property(_raiz, "modulate:a", 0.0, 0.7)
	await t.finished
	queue_free()
