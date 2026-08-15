extends CanvasLayer
class_name PantallaPausa
## La pausa: parar, mirar los objetivos, cambiar ajustes o dejarlo.
##
## ## Lo que tiene que resolver
##
## Una pausa no es solo un botón de parar. Es donde se va cuando **no se sabe
## qué hacer** — y ahí es donde tiene que estar la lista de objetivos, no
## escondida en otro sitio. Por eso «Qué me falta» es lo primero después de
## seguir jugando.
##
## ## Guarda al salir
##
## Salir al menú guarda la partida sin preguntar. Preguntar «¿quieres guardar?»
## traslada a quien juega una decisión que no debería tener que tomar: nadie
## quiere perder lo que lleva hecho.

const SFX := preload("res://assets/audio/sfx/mundo/estrella.wav")

var _velo: ColorRect = null


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	get_tree().paused = true


func _montar() -> void:
	_velo = ColorRect.new()
	_velo.color = Color(0.08, 0.03, 0.15, 0.0)
	_velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_velo)
	create_tween().tween_property(_velo, "color:a", 0.78, 0.25)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_velo.add_child(centro)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	centro.add_child(col)

	var t := Estilo.texto_con_sombra("En pausa", 44, Estilo.CREMA, true, 700)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)

	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(0, 18)
	col.add_child(hueco)

	col.add_child(_boton("Seguir jugando", _seguir, true))
	col.add_child(_boton("Qué me falta", _objetivos))
	col.add_child(_boton("Ajustes", _ajustes))
	col.add_child(_boton("Guardar y salir", _salir))


func _boton(cadena: String, alpulsar: Callable, principal: bool = false) -> Button:
	var b := Estilo.boton(cadena, 380.0, principal)
	b.pressed.connect(func() -> void:
		AudioManager.play_sfx(SFX, -16.0, 0.06)
		alpulsar.call())
	return b


func _seguir() -> void:
	get_tree().paused = false
	queue_free()


## La lista de objetivos, la misma que enseña el portal. Se reutiliza entera:
## dos formas distintas de enseñar lo mismo acabarían diciendo cosas distintas.
func _objetivos() -> void:
	var o := get_tree().get_first_node_in_group("objetivos") as ObjetivosNivel
	if o == null:
		return
	var panel := PanelRequisitos.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(panel)
	await panel.mostrar("LO QUE TE FALTA",
		"Todo esto abre la puerta del final del parque.", o.resumen())


func _ajustes() -> void:
	var p := PantallaAjustes.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	_velo.visible = false
	var capa := Control.new()
	capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fondo := ColorRect.new()
	fondo.color = Color(0.10, 0.05, 0.18, 0.96)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(fondo)
	capa.add_child(p)
	add_child(capa)
	p.cerrada.connect(func() -> void:
		capa.queue_free()
		_velo.visible = true)


func _salir() -> void:
	PartidasGuardadas.guardar()
	get_tree().paused = false
	SceneLoader.change_scene("res://scenes/ui/menu_principal.tscn")
	queue_free()
