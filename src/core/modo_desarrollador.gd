extends CanvasLayer
class_name ModoDesarrollador
## Utilidades para probar sin pelearse con el juego.
##
## Existe porque probar el nivel entero muriéndose cada dos por tres es una
## pérdida de tiempo, y porque va a hacer más falta todavía cuando el sistema de
## daño sea de verdad —con corazones que se pierden y checkpoints—. Sin esto,
## cada prueba de la última arena obliga a jugarse las dos anteriores.
##
## **No sale en la versión que se le da a la niña**: se apaga con `activo` y no
## deja nada por medio. Aun así se comprueba `OS.is_debug_build()` antes de
## atender ninguna tecla, para que un despiste no acabe con el modo dios en el
## APK del regalo.
##
## ## Teclas
##
## | Tecla | Qué hace |
## |---|---|
## | `F1` | Muestra u oculta este panel |
## | `F2` | Invulnerable sí/no |
## | `F3` | Cura del todo |
## | `F4` | Carga el especial |
## | `F5` | Salta al siguiente tramo del recorrido |
## | `F6` | Ver las formas de colisión |
## | `F7` | Mata a todos los enemigos que haya |

## Interruptor general. En falso, ni escucha teclas ni dibuja nada.
@export var activo: bool = true
## Empezar con el panel a la vista.
@export var panel_visible: bool = false

var _invulnerable: bool = false
var _panel: PanelContainer = null
var _texto: Label = null
var _tramo: int = 0
var _refresco: float = 0.0


func _ready() -> void:
	# Capa muy alta: esto va por encima del HUD y de los diálogos.
	layer = 128
	if not activo or not OS.is_debug_build():
		queue_free()
		return
	_montar_panel()
	_panel.visible = panel_visible
	set_process(true)


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	# Refrescar sesenta veces por segundo un panel de texto cuesta más que lo
	# que se está midiendo. Cuatro veces por segundo se lee igual de bien.
	_refresco -= delta
	if _refresco > 0.0:
		return
	_refresco = 0.25
	_texto.text = _informe()


func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	match (evento as InputEventKey).keycode:
		KEY_F1: _panel.visible = not _panel.visible
		KEY_F2: _alternar_invulnerable()
		KEY_F3: GameManager.reset_health()
		KEY_F4: GameManager.add_special_charge(99)
		KEY_F5: _saltar_de_tramo()
		KEY_F6: _alternar_colisiones()
		KEY_F7: _limpiar_enemigos()
		_: return
	get_viewport().set_input_as_handled()


## Invulnerabilidad permanente.
##
## No se toca la vida: se le da al `Player` un temporizador de invulnerabilidad
## enorme y se renueva. Así el resto del juego no se entera de nada y no hay que
## meter un `if modo_dios` por cada sitio donde se hace daño.
func _alternar_invulnerable() -> void:
	_invulnerable = not _invulnerable
	var jugador := get_tree().get_first_node_in_group("player")
	if jugador == null:
		return
	if _invulnerable:
		jugador.set("invulnerability_time", 99999.0)
		jugador.set("invuln_timer", 99999.0)
	else:
		jugador.set("invulnerability_time", 1.5)
		jugador.set("invuln_timer", 0.0)


func _saltar_de_tramo() -> void:
	var jugador := get_tree().get_first_node_in_group("player") as Node3D
	var constructor := get_tree().current_scene.get_node_or_null("Blockout") as ConstructorNivel
	if jugador == null or constructor == null or constructor.tramos.is_empty():
		return
	_tramo = (_tramo + 1) % constructor.tramos.size()
	jugador.global_position = constructor.punto_en_tramo(_tramo, 0.15, 0.0, 0.6)
	if jugador is CharacterBody3D:
		(jugador as CharacterBody3D).velocity = Vector3.ZERO
	# El pelo y el gato se quedan atrás si no se les avisa del salto.
	for nodo in jugador.find_children("*", "HairPhysics", true, false):
		(nodo as HairPhysics).reset()
	for gato in get_tree().current_scene.find_children("*", "Companero", true, false):
		(gato as Companero).teletransportar_junto_al_objetivo()


func _alternar_colisiones() -> void:
	var arbol := get_tree()
	arbol.debug_collisions_hint = not arbol.debug_collisions_hint
	# El aviso hace falta: `debug_collisions_hint` solo lo miran los nodos al
	# entrar en el árbol, así que lo que ya está puesto no cambia hasta que se
	# recarga la escena. Mejor decirlo que dejar creer que no funciona.
	EventBus.show_message.emit(
		"Colisiones: %s (recarga la escena)" % ("sí" if arbol.debug_collisions_hint else "no"),
		2.0)


func _limpiar_enemigos() -> void:
	var muertos := 0
	for enemigo in get_tree().get_nodes_in_group("enemies"):
		# `defeat()` es la muerte de verdad: cuenta para la arena, suelta lo que
		# tenga que soltar y avisa por el EventBus. Borrar el nodo a lo bruto
		# dejaría la oleada esperando a un enemigo que ya no existe.
		if enemigo.has_method("defeat"):
			enemigo.call("defeat")
			muertos += 1
	EventBus.show_message.emit("%d enemigos eliminados" % muertos, 1.5)


func _informe() -> String:
	var lineas: Array[String] = []
	lineas.append("FPS %d · %d draw calls · %.1f k tris" % [
		Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0])
	lineas.append("Vida %d/%d · Estrellas %d · Especial %d%%" % [
		GameManager.health, GameManager.MAX_HEALTH, GameManager.stars_this_level,
		int(GameManager.get_special_ratio() * 100.0)])

	var jugador := get_tree().get_first_node_in_group("player") as Node3D
	if jugador != null:
		var p := jugador.global_position
		lineas.append("Pos (%.1f, %.1f, %.1f) · enemigos %d" % [
			p.x, p.y, p.z, get_tree().get_nodes_in_group("enemies").size()])

	lineas.append("Invulnerable: %s" % ("SÍ" if _invulnerable else "no"))
	lineas.append("F1 panel · F2 invuln · F3 vida · F4 especial")
	lineas.append("F5 tramo · F6 colisiones · F7 matar")
	return "\n".join(lineas)


func _montar_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "PanelDev"
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(12, 110)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.0, 0.0, 0.0, 0.62)
	fondo.set_content_margin_all(10.0)
	fondo.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", fondo)

	_texto = Label.new()
	_texto.add_theme_font_size_override("font_size", 14)
	_texto.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_texto)
	add_child(_panel)
