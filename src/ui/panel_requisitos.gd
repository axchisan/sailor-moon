extends CanvasLayer
class_name PanelRequisitos
## La lista de lo que falta, presentada como un objetivo y no como un recado.
##
## ## Por qué existe
##
## Lo que falta para abrir el portal se decía con el mismo cartelito rosa que
## anuncia «¡Aquí vienen!» o «Farol encendido»: una línea de texto a media
## pantalla que se va sola a los cuatro segundos. Para un aviso de paso está
## bien. Para **la lista de todo lo que hay que hacer en el nivel** no: se lee
## por encima, no se retiene, y encima cualquier otro aviso que llegue detrás la
## borra. Lo más importante que el juego tiene que decir se estaba diciendo con
## el formato de lo más pasajero.
##
## Aquí la lista para el mundo: se oscurece lo de detrás, se abre un marco, y
## las líneas van cayendo una a una. Que aparezcan escalonadas no es adorno —
## obliga a leerlas de arriba abajo, que es como se lee una lista.
##
## ## Lo que ya está hecho también se enseña
##
## Podría enseñarse solo lo que falta, y de hecho el aviso rápido del portal
## hace eso a propósito (ver [`portal_salida.gd`](../gameplay/portal_salida.gd)).
## Pero cuando se para el juego y se enseña el mapa entero de la tarea, ver
## tachado lo que ya llevas es la mitad de la razón para mirar: sin eso la lista
## solo dice cuánto queda, y desanima.

signal cerrado

## Cuánto tarda en irse solo, si no se toca nada.
const SOLO := 6.0
## Cuánto tarda cada línea en entrar detrás de la anterior.
const ESCALON := 0.09

const ROSA := Color(1.0, 0.55, 0.82)
const CREMA := Color(1.0, 0.96, 0.98)
const HECHO := Color(0.62, 0.92, 0.70)
const APAGADO := Color(0.72, 0.70, 0.80)

var _fondo: ColorRect = null
var _marco: PanelContainer = null
var _cerrando: bool = false
var _reloj: float = 0.0


## Enseña la lista. `entradas` son fichas de `ObjetivosNivel.resumen()`.
##
## Es `async`: se puede esperar a que termine para devolver el control justo
## cuando se cierra, que es lo que hace el portal.
func mostrar(titulo: String, subtitulo: String,
		entradas: Array[Dictionary]) -> void:
	layer = 20
	_montar(titulo, subtitulo, entradas)
	set_process(true)
	set_process_input(true)
	await cerrado


func _montar(titulo: String, subtitulo: String,
		entradas: Array[Dictionary]) -> void:
	# El oscurecido es la mitad del efecto: sin él el marco flota sobre el
	# parque y se lee como un elemento más del HUD, no como una pausa.
	_fondo = ColorRect.new()
	_fondo.color = Color(0.04, 0.02, 0.09, 0.0)
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fondo)
	create_tween().tween_property(_fondo, "color:a", 0.62, 0.35)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	_marco = PanelContainer.new()
	_marco.add_theme_stylebox_override("panel", _estilo_marco())
	_marco.custom_minimum_size = Vector2(720, 0)
	_marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(_marco)

	var margen := MarginContainer.new()
	for lado in ["left", "right"]:
		margen.add_theme_constant_override("margin_" + lado, 46)
	for lado in ["top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 34)
	_marco.add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 6)
	margen.add_child(columna)

	var rotulo := _texto(titulo, 40, ROSA, 8)
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(rotulo)

	if not subtitulo.is_empty():
		var bajo := _texto(subtitulo, 20, APAGADO, 5)
		bajo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		columna.add_child(bajo)

	var raya := HSeparator.new()
	var linea := StyleBoxFlat.new()
	linea.bg_color = Color(ROSA.r, ROSA.g, ROSA.b, 0.35)
	linea.content_margin_top = 2.0
	raya.add_theme_stylebox_override("separator", linea)
	raya.add_theme_constant_override("separation", 22)
	columna.add_child(raya)

	var animables: Array[Control] = []
	for ficha in entradas:
		var fila := _fila(ficha)
		columna.add_child(fila)
		animables.append(fila)

	var pie := _texto("Toca para continuar", 17, Color(0.6, 0.58, 0.68), 4)
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(pie)
	animables.append(pie)

	# El marco entra creciendo desde un pelín más pequeño. Aparecer ya montado se
	# lee como un tirón; venir de más cerca da la sensación de que se abre.
	_marco.modulate.a = 0.0
	_marco.pivot_offset = _marco.size * 0.5
	_marco.scale = Vector2(0.94, 0.94)
	var t := create_tween().set_parallel(true)
	t.tween_property(_marco, "modulate:a", 1.0, 0.28)
	t.tween_property(_marco, "scale", Vector2.ONE, 0.42) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Y las líneas detrás, en cascada, para que se lean en orden.
	for i in animables.size():
		var fila := animables[i]
		fila.modulate.a = 0.0
		fila.position.x += 26.0
		var paso := create_tween().set_parallel(true)
		paso.tween_property(fila, "modulate:a", 1.0, 0.22) \
			.set_delay(0.24 + ESCALON * float(i))
		paso.tween_property(fila, "position:x", fila.position.x - 26.0, 0.32) \
			.set_delay(0.24 + ESCALON * float(i)) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Una línea de la lista: marca, texto y —si lleva cuenta— cuántos van.
func _fila(ficha: Dictionary) -> Control:
	var hecho: bool = ficha["hecho"]
	var cuantos: int = ficha["cuantos"]
	var meta: int = ficha["meta"]

	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 16)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var marca := "✦"
	var tono := CREMA
	if hecho:
		marca = "✓"
		tono = HECHO
	var icono := _texto(marca, 26, tono, 5)
	icono.custom_minimum_size.x = 34
	icono.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(icono)

	var texto := _texto(str(ficha["texto"]), 25, tono, 6)
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(texto)

	# Los contadores solo donde hay algo que contar. «Encuentra a Amy (0 de 1)»
	# no informa de nada y ensucia la línea.
	if meta > 1:
		var cuenta := _texto("%d / %d" % [cuantos, meta], 25, tono, 6)
		cuenta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cuenta.custom_minimum_size.x = 96
		caja.add_child(cuenta)

	if hecho:
		caja.modulate = Color(1, 1, 1, 0.72)
	return caja


func _texto(cadena: String, tam: int, color: Color, contorno: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = cadena
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_size_override("font_size", tam)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_color_override("font_outline_color",
		Color(0.12, 0.04, 0.16, 0.9))
	etiqueta.add_theme_constant_override("outline_size", contorno)
	return etiqueta


func _estilo_marco() -> StyleBoxFlat:
	var caja := StyleBoxFlat.new()
	# Morado muy oscuro, no negro: el negro plano parece un menú de sistema, y
	# esto tiene que seguir pareciendo del mismo juego que el parque.
	caja.bg_color = Color(0.09, 0.05, 0.16, 0.94)
	caja.border_color = Color(ROSA.r, ROSA.g, ROSA.b, 0.85)
	for lado in ["left", "right", "top", "bottom"]:
		caja.set("border_width_" + lado, 3)
	caja.corner_radius_top_left = 20
	caja.corner_radius_top_right = 20
	caja.corner_radius_bottom_left = 20
	caja.corner_radius_bottom_right = 20
	caja.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	caja.shadow_size = 16
	return caja


func _process(delta: float) -> void:
	_reloj += delta
	if _reloj >= SOLO:
		cerrar()


func _input(evento: InputEvent) -> void:
	# No antes de medio segundo: si se cierra con el mismo toque que venía de
	# antes, la lista aparece y desaparece sin que dé tiempo a verla.
	if _reloj < 0.5:
		return
	var vale := evento is InputEventScreenTouch or evento is InputEventMouseButton
	if evento is InputEventKey or evento is InputEventJoypadButton:
		vale = true
	if vale and evento.is_pressed():
		cerrar()


func cerrar() -> void:
	if _cerrando:
		return
	_cerrando = true
	set_process(false)
	set_process_input(false)
	var t := create_tween().set_parallel(true)
	t.tween_property(_fondo, "color:a", 0.0, 0.3)
	t.tween_property(_marco, "modulate:a", 0.0, 0.25)
	t.tween_property(_marco, "scale", Vector2(0.96, 0.96), 0.3)
	await t.finished
	cerrado.emit()
	queue_free()
