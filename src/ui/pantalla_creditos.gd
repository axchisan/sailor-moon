extends Control
class_name PantallaCreditos
## Quién ha hecho qué, y de dónde salen las cosas prestadas.
##
## No es un trámite legal: buena parte del juego se sostiene en material que
## otros regalaron —tipografías, sonidos, modelos—, y las licencias libres piden
## exactamente esto a cambio. Un juego que no cita lo que usa es un juego que no
## se puede enseñar.

signal cerrada

const LINEAS := [
	["", "Un regalo hecho a mano"],
	["", "para una niña de ocho años"],
	["sep", ""],
	["tit", "Hecho con"],
	["", "Godot Engine 4.7"],
	["", "Blender"],
	["sep", ""],
	["tit", "Tipografías"],
	["", "Baloo 2 y Quicksand — Google Fonts (OFL)"],
	["sep", ""],
	["tit", "Música"],
	["", "Kevin MacLeod — incompetech.com"],
	["", "Licencia Creative Commons BY 4.0"],
	["sep", ""],
	["tit", "Sonido"],
	["", "Freesound — grabaciones con licencia CC0"],
	["", "Kenney.nl — efectos CC0"],
	["sep", ""],
	["tit", "Y sobre todo"],
	["", "Sailor Moon es de Naoko Takeuchi."],
	["", "Esto es un homenaje que no se vende"],
	["", "ni se publica en ninguna parte."],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS

	var titulo := Estilo.texto_con_sombra("Créditos", 40, Estilo.CREMA, true, 700)
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
	marco.offset_left = -300.0
	marco.offset_right = 300.0
	marco.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(marco)

	var hueco := ScrollContainer.new()
	hueco.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	marco.add_child(hueco)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	hueco.add_child(col)

	for fila: Array in LINEAS:
		var tipo: String = fila[0]
		var texto: String = fila[1]
		if tipo == "sep":
			var s := Control.new()
			s.custom_minimum_size = Vector2(0, 16)
			col.add_child(s)
			continue
		var l := Estilo.texto(texto, 21 if tipo == "tit" else 18,
			Estilo.ROSA_CLARO if tipo == "tit" else Estilo.CREMA,
			tipo == "tit", 700 if tipo == "tit" else 500)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)

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
