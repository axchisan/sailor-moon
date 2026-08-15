extends Control
class_name PantallaAjustes
## Los ajustes: volúmenes y las ayudas de juego.
##
## ## Todo lo que hay aquí hace algo
##
## Nada de opciones puestas «para que haya opciones». Cada línea cambia algo que
## se nota, y se nota **al momento**: mover el volumen de efectos suena un golpe
## de prueba en ese instante, sin darle a aceptar. Una barra que no responde
## hasta salir de la pantalla no se entiende a los ocho años — ni a los treinta.
##
## ## Por qué no hay «Aceptar» ni «Cancelar»
##
## Se guarda solo al tocar cada cosa. Un menú de ajustes que puede perder lo que
## acabas de cambiar por salir mal es una trampa; y «Cancelar» obliga a recordar
## un estado anterior por cada opción para poder deshacerlo.

signal cerrada

const SFX_PRUEBA := preload("res://assets/audio/sfx/hit.wav")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()


func _montar() -> void:
	var titulo := Estilo.texto_con_sombra("Ajustes", 40, Estilo.CREMA, true, 700)
	titulo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	titulo.anchor_top = 0.07
	titulo.offset_left = -300.0
	titulo.offset_right = 300.0
	titulo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(titulo)

	var marco := PanelContainer.new()
	marco.add_theme_stylebox_override("panel", Estilo.panel(Estilo.PANEL))
	marco.set_anchors_preset(Control.PRESET_CENTER)
	marco.anchor_top = 0.18
	marco.anchor_bottom = 0.78
	marco.offset_left = -320.0
	marco.offset_right = 320.0
	marco.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(marco)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	marco.add_child(col)

	col.add_child(_rotulo("Sonido"))
	col.add_child(_volumen("Música", Settings.music_volume, func(v: float) -> void:
		Settings.music_volume = v
		AudioManager.set_bus_volume("Music", v)
		Settings.save_settings()))
	col.add_child(_volumen("Efectos", Settings.sfx_volume, func(v: float) -> void:
		Settings.sfx_volume = v
		AudioManager.set_bus_volume("SFX", v)
		Settings.save_settings()
		# Suena al soltar: es la única forma de saber si el volumen que has
		# puesto es el que quieres sin salir a probarlo.
		AudioManager.play_sfx(SFX_PRUEBA, -4.0, 0.05)))
	col.add_child(_volumen("Voces", Settings.voice_volume, func(v: float) -> void:
		Settings.voice_volume = v
		AudioManager.set_bus_volume("Voice", v)
		Settings.save_settings()))

	col.add_child(_separador())
	col.add_child(_rotulo("Cómo se juega"))
	col.add_child(_interruptor("Modo tranquilo", Settings.assisted_mode,
		"Los enemigos pegan menos y esperan más",
		func(v: bool) -> void:
			Settings.assisted_mode = v
			Settings.save_settings()))
	col.add_child(_interruptor("Flecha de ayuda", Settings.show_guide_arrow,
		"Señala a dónde ir cuando te pierdes",
		func(v: bool) -> void:
			Settings.show_guide_arrow = v
			Settings.save_settings()))
	col.add_child(_barra_libre("Sensibilidad de la cámara",
		Settings.camera_sensitivity / 2.0, func(v: float) -> void:
			Settings.camera_sensitivity = maxf(v * 2.0, 0.2)
			Settings.save_settings()))

	var volver := Estilo.boton("Volver", 260.0, true)
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


func _rotulo(cadena: String) -> Control:
	var l := Estilo.texto(cadena, 21, Estilo.ROSA_CLARO, true, 700)
	return l


func _separador() -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, 14)
	return s


## Una fila de volumen: nombre, barra y el número en porcentaje.
##
## El número importa: sin él, «un poco más bajo» es imposible de repetir mañana.
func _volumen(nombre: String, valor: float, alcambiar: Callable) -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)

	var l := Estilo.texto(nombre, 20, Estilo.CREMA)
	l.custom_minimum_size.x = 130
	fila.add_child(l)

	var barra := Estilo.barra(valor)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(barra)

	var cifra := Estilo.texto("%d%%" % int(valor * 100.0), 18, Estilo.TENUE)
	cifra.custom_minimum_size.x = 54
	cifra.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fila.add_child(cifra)

	barra.value_changed.connect(func(v: float) -> void:
		cifra.text = "%d%%" % int(v * 100.0)
		alcambiar.call(v))
	return fila


func _barra_libre(nombre: String, valor: float, alcambiar: Callable) -> Control:
	return _volumen(nombre, valor, alcambiar)


## Un interruptor con su explicación debajo.
##
## La línea pequeña no es decoración: «Modo tranquilo» no dice qué hace, y una
## opción que no se entiende no se toca — o se toca y luego no se sabe deshacer.
func _interruptor(nombre: String, valor: bool, explica: String,
		alcambiar: Callable) -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	col.add_child(Estilo.texto(nombre, 20, Estilo.CREMA))
	col.add_child(Estilo.texto(explica, 15, Estilo.TENUE))
	fila.add_child(col)

	var b := Estilo.boton("Sí" if valor else "No", 96.0, valor)
	b.pressed.connect(func() -> void:
		var nuevo := b.text == "No"
		b.text = "Sí" if nuevo else "No"
		# Se rehace el estilo: el botón encendido va en rosa y el apagado en
		# morado, que es lo que dice de un vistazo cómo está sin leerlo.
		var rehecho := Estilo.boton(b.text, 96.0, nuevo)
		for parte in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(parte,
				rehecho.get_theme_stylebox(parte))
		b.add_theme_color_override("font_color",
			rehecho.get_theme_color("font_color"))
		rehecho.queue_free()
		alcambiar.call(nuevo))
	fila.add_child(b)
	return fila
