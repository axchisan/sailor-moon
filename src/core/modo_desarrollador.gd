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
## | `F8` | Siguiente prueba del banco de rendimiento |
##
## ## El banco de pruebas (F8, o un toque en la esquina superior DERECHA)
##
## Sirve para averiguar **por dónde se va el rendimiento** sin exportar un APK
## por cada corazonada. Va apagando una cosa cada vez, siempre desde el juego
## completo, y se anota lo que marcan los fps en cada paso: lo que más suba es
## lo que más costaba.
##
## Se mide en el móvil y de pie en el mismo sitio, sin moverse, porque el número
## cambia mucho según a dónde mires.
##
## La prueba de **media resolución** no es una opción de calidad —está descartada
## por la trampa 63— sino la pregunta decisiva: si al bajarla los fps se
## disparan, lo caro es pintar píxeles (shaders, transparencias, sombras); si no
## se mueven, el cuello está en la CPU y no sirve de nada tocar nada de esto.

## Interruptor general. En falso, ni escucha teclas ni dibuja nada.
@export var activo: bool = true
## Empezar con el panel a la vista.
@export var panel_visible: bool = false

var _invulnerable: bool = false
var _panel: PanelContainer = null
var _texto: Label = null
var _tramo: int = 0
var _refresco: float = 0.0

## Los pasos del banco de pruebas. El 0 es el juego tal cual, y cada uno de los
## demás apaga UNA sola cosa —no se acumulan— para que la diferencia de fps se
## pueda atribuir a algo concreto.
const PRUEBAS := [
	"— tal cual —",
	"sin cielo",
	"sin shader de terreno",
	"sin sombras",
	"sin niebla",
	"sin decorado",
	"sin FXAA",
	"sin ajuste de color",
	"a media resolución",
]

var _prueba: int = 0
## Lo que había antes de tocar nada, para poder devolverlo tal cual.
var _original: Dictionary = {}


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


## Toques seguidos en la esquina, para abrir el panel sin teclado.
##
## En el móvil no hay F1, y las cifras de rendimiento hacen falta JUSTO ahí: en
## el escritorio todo va a sesenta y el problema no se ve. Tres toques en un
## rincón que no usa ningún control del juego bastan y no se dan sin querer.
const ESQUINA_DEV := Vector2(96.0, 96.0)
const TOQUES_PARA_ABRIR := 3
const VENTANA_TOQUES := 1.6

var _toques: int = 0
var _ultimo_toque: float = 0.0


func _atajo_tactil(evento: InputEvent) -> void:
	var toque := evento as InputEventScreenTouch
	if toque == null or not toque.pressed:
		return

	# Esquina superior DERECHA: siguiente prueba del banco. Va a la derecha a
	# propósito — el joystick flotante se queda con todo lo que se toque en la
	# mitad izquierda (`touch_controls.gd`), así que un atajo ahí competiría con
	# él. Los contadores del HUD que hay en esa esquina no estorban: todo el HUD
	# va con `MOUSE_FILTER_IGNORE` y deja pasar el toque.
	var ancho := get_viewport().get_visible_rect().size.x
	if _panel.visible and toque.position.x > ancho - ESQUINA_DEV.x \
			and toque.position.y < ESQUINA_DEV.y:
		_siguiente_prueba()
		return

	if toque.position.x > ESQUINA_DEV.x or toque.position.y > ESQUINA_DEV.y:
		return
	var ahora := Time.get_ticks_msec() / 1000.0
	_toques = 1 if ahora - _ultimo_toque > VENTANA_TOQUES else _toques + 1
	_ultimo_toque = ahora
	if _toques >= TOQUES_PARA_ABRIR:
		_toques = 0
		_panel.visible = not _panel.visible


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventScreenTouch:
		_atajo_tactil(evento)
		return
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
		KEY_F8: _siguiente_prueba()
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


# --- Banco de pruebas de rendimiento ------------------------------------------

## Los nodos que hay que tocar para las pruebas, buscados una sola vez.
##
## Se cachean en `_original` junto con su valor de partida: así restaurar es
## devolver lo guardado, y no hace falta acordarse de cuál era el valor «bueno»
## de cada cosa en cada sitio del código.
func _preparar_banco() -> void:
	if not _original.is_empty():
		return
	var escena := get_tree().current_scene
	var entorno := escena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sol := escena.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	var terreno := escena.get_node_or_null("Terreno")
	var visual: MeshInstance3D = null
	if terreno != null:
		for hijo in terreno.get_children():
			if hijo is MeshInstance3D:
				visual = hijo
				break

	_original = {
		"entorno": entorno,
		"env": entorno.environment if entorno != null else null,
		"fondo": entorno.environment.background_mode if entorno != null else 0,
		"niebla": entorno.environment.fog_enabled if entorno != null else false,
		"ajuste": entorno.environment.adjustment_enabled if entorno != null else false,
		"sol": sol,
		"sombra": sol.shadow_enabled if sol != null else false,
		"terreno_visual": visual,
		"material": visual.material_override if visual != null else null,
		"decorado": escena.get_node_or_null("Decorado"),
		"aa": get_viewport().screen_space_aa,
		"escalado": get_viewport().scaling_3d_scale,
	}


## Deja el juego como estaba y aplica solo la prueba actual.
func _aplicar_prueba() -> void:
	_preparar_banco()
	var env: Environment = _original["env"]
	var sol: DirectionalLight3D = _original["sol"]
	var visual: MeshInstance3D = _original["terreno_visual"]
	var decorado: Node = _original["decorado"]
	var vp := get_viewport()

	# Primero se devuelve TODO a su sitio. Sin esto las pruebas se acumularían y
	# el número dejaría de significar nada a partir de la segunda.
	if env != null:
		env.background_mode = _original["fondo"]
		env.fog_enabled = _original["niebla"]
		env.adjustment_enabled = _original["ajuste"]
	if sol != null:
		sol.shadow_enabled = _original["sombra"]
	if visual != null:
		visual.material_override = _original["material"]
	if decorado != null:
		decorado.visible = true
	vp.screen_space_aa = _original["aa"]
	vp.scaling_3d_scale = _original["escalado"]

	match PRUEBAS[_prueba]:
		"— tal cual —":
			pass
		"sin cielo":
			# Fondo de color plano: el degradado y las nubes dejan de calcularse,
			# pero se siguen pintando los mismos píxeles.
			if env != null:
				env.background_mode = Environment.BG_COLOR
		"sin shader de terreno":
			# El terreno sigue ahí con sus triángulos; lo que se va es el coste
			# de pintarlo. Si sube mucho, el problema es el shader y no la malla.
			if visual != null:
				var liso := StandardMaterial3D.new()
				liso.albedo_color = Color(0.45, 0.6, 0.38)
				visual.material_override = liso
		"sin sombras":
			if sol != null:
				sol.shadow_enabled = false
		"sin niebla":
			if env != null:
				env.fog_enabled = false
		"sin decorado":
			if decorado != null:
				decorado.visible = false
		"sin FXAA":
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		"sin ajuste de color":
			if env != null:
				env.adjustment_enabled = false
		"a media resolución":
			vp.scaling_3d_scale = 0.5
		_:
			push_warning("ModoDesarrollador: prueba sin implementar '%s'"
				% PRUEBAS[_prueba])


func _siguiente_prueba() -> void:
	_prueba = (_prueba + 1) % PRUEBAS.size()
	_aplicar_prueba()
	_panel.visible = true
	EventBus.show_message.emit("Prueba: %s" % PRUEBAS[_prueba], 2.0)


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
	# Pantalla y sombra por separado. Es LA cifra para saber por dónde se va el
	# rendimiento: el pase de sombra llegó a costar el triple que la pantalla, y
	# mirando solo el total no había forma de verlo.
	var vp := get_viewport().get_viewport_rid()
	lineas.append("  pantalla %.1f k · sombra %.1f k" % [
		RenderingServer.viewport_get_render_info(vp,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME) / 1000.0,
		RenderingServer.viewport_get_render_info(vp,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME) / 1000.0])
	lineas.append("Vida %d/%d · Estrellas %d · Especial %d%%" % [
		GameManager.health, GameManager.MAX_HEALTH, GameManager.stars_this_level,
		int(GameManager.get_special_ratio() * 100.0)])

	var jugador := get_tree().get_first_node_in_group("player") as Node3D
	if jugador != null:
		var p := jugador.global_position
		lineas.append("Pos (%.1f, %.1f, %.1f) · enemigos %d" % [
			p.x, p.y, p.z, get_tree().get_nodes_in_group("enemies").size()])

	lineas.append("Invulnerable: %s" % ("SÍ" if _invulnerable else "no"))
	# La prueba activa, bien visible: mirar unos fps sin saber qué está apagado
	# es la mejor forma de sacar una conclusión equivocada.
	lineas.append("PRUEBA %d/%d: %s" % [
		_prueba, PRUEBAS.size() - 1, PRUEBAS[_prueba]])
	lineas.append("F1 panel · F2 invuln · F3 vida · F4 especial")
	lineas.append("F5 tramo · F6 colisiones · F7 matar · F8 prueba")
	lineas.append("(móvil: 3 toques aquí · 1 arriba a la derecha = prueba)")
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
