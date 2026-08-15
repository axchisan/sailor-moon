extends Control
class_name PantallaPartidas
## Elegir con cuál de las tres partidas se juega.
##
## Cada ranura enseña **lo que se ha hecho**, no un número de archivo: cuántas
## Estrellas se llevan, cuántos niveles cerrados y cuánto tiempo. Un «Partida 2 —
## 14/08/2026» no dice nada de quién es esa partida; «12 Estrellas · 1 nivel» sí.
##
## Y borrar pide confirmación. Es el único botón de todo el juego que destruye
## algo, así que es el único que pregunta.

signal cerrada

var _lista: VBoxContainer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()


func _montar() -> void:
	var titulo := Estilo.texto_con_sombra("Tus partidas", 40, Estilo.CREMA, true, 700)
	titulo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	titulo.anchor_top = 0.07
	titulo.offset_left = -300.0
	titulo.offset_right = 300.0
	titulo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(titulo)

	_lista = VBoxContainer.new()
	_lista.set_anchors_preset(Control.PRESET_CENTER)
	_lista.anchor_top = 0.20
	_lista.anchor_bottom = 0.78
	_lista.offset_left = -300.0
	_lista.offset_right = 300.0
	_lista.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_lista.alignment = BoxContainer.ALIGNMENT_CENTER
	_lista.add_theme_constant_override("separation", 16)
	add_child(_lista)

	_pintar()

	var volver := Estilo.boton("Volver", 260.0)
	volver.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	volver.anchor_top = 1.0
	volver.offset_top = -96.0
	volver.offset_left = -130.0
	volver.offset_right = 130.0
	volver.offset_bottom = -38.0
	volver.grow_horizontal = Control.GROW_DIRECTION_BOTH
	volver.pressed.connect(func() -> void:
		cerrada.emit()
		queue_free())
	add_child(volver)


func _pintar() -> void:
	for h in _lista.get_children():
		h.queue_free()
	for i in PartidasGuardadas.CUANTAS:
		_lista.add_child(_tarjeta(i))


func _tarjeta(cual: int) -> Control:
	var r := PartidasGuardadas.resumen(cual)
	var vacia := bool(r.get("vacia", true))

	var marco := PanelContainer.new()
	marco.add_theme_stylebox_override("panel",
		Estilo.panel(Estilo.PANEL if not vacia else Color(Estilo.PANEL, 0.55)))
	marco.custom_minimum_size = Vector2(0, 108)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 16)
	marco.add_child(fila)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	fila.add_child(col)

	col.add_child(Estilo.texto("Partida %d" % (cual + 1), 26,
		Estilo.CREMA if not vacia else Estilo.TENUE, true, 700))

	if vacia:
		col.add_child(Estilo.texto("Vacía — toca para empezar", 17, Estilo.TENUE))
	else:
		col.add_child(Estilo.texto("★ %d Estrellas · %d %s" % [
			int(r.get("estrellas", 0)), int(r.get("niveles", 0)),
			"nivel" if int(r.get("niveles", 0)) == 1 else "niveles",
		], 18, Estilo.ORO))
		var m := int(r.get("minutos", 0))
		var tiempo := "%d min" % m
		if m >= 60:
			tiempo = "%dh %dmin" % [m / 60, m % 60]
		col.add_child(Estilo.texto("%s jugados · %s" % [
			tiempo, str(r.get("cuando", ""))], 15, Estilo.TENUE))

	var jugar := Estilo.boton("Jugar" if not vacia else "Empezar", 150.0, not vacia)
	jugar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	jugar.pressed.connect(func() -> void: _abrir(cual))
	fila.add_child(jugar)

	if not vacia:
		var borrar := Estilo.boton("🗑", 64.0)
		borrar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		borrar.pressed.connect(func() -> void: _preguntar_borrado(cual))
		fila.add_child(borrar)

	return marco


func _abrir(cual: int) -> void:
	PartidasGuardadas.cargar(cual)
	SceneLoader.change_scene(MenuPrincipal.RUTA_NIVEL)


## BORRAR ES LO ÚNICO QUE PREGUNTA.
##
## Es el único botón del juego que destruye algo que ha costado horas, y a los
## ocho años se pulsa por curiosidad. La confirmación no es burocracia: es la
## diferencia entre perder la tarde o no.
func _preguntar_borrado(cual: int) -> void:
	var velo := ColorRect.new()
	velo.color = Color(0.06, 0.02, 0.12, 0.75)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(velo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	velo.add_child(centro)

	var marco := PanelContainer.new()
	marco.add_theme_stylebox_override("panel", Estilo.panel(Estilo.PANEL))
	marco.custom_minimum_size = Vector2(460, 0)
	centro.add_child(marco)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	marco.add_child(col)

	var q := Estilo.texto("¿Borrar la partida %d?" % (cual + 1), 28,
		Estilo.CREMA, true, 700)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(q)
	var a := Estilo.texto("Lo que llevas en ella se pierde.", 17, Estilo.TENUE)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(a)

	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 12)
	col.add_child(botones)

	# «Mejor no» va primero y como principal: la salida segura es la que está
	# más a mano, no la destructiva.
	var no := Estilo.boton("Mejor no", 190.0, true)
	no.pressed.connect(func() -> void: velo.queue_free())
	botones.add_child(no)

	var si := Estilo.boton("Borrar", 150.0)
	si.pressed.connect(func() -> void:
		PartidasGuardadas.borrar(cual)
		velo.queue_free()
		_pintar())
	botones.add_child(si)
