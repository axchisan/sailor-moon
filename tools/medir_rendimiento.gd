extends Node
class_name MedirRendimiento
## Banco de medición automático, para el Mac y para el móvil.
##
## POR QUÉ EXISTE
##
## El banco de pruebas de `F8` va a mano: se pulsa, se mira el panel, se apunta.
## Eso vale para comprobar una sospecha, pero no para comparar catorce
## configuraciones seguidas sin que se muevan ni la cámara ni la posición — y si
## se mueven, los números no se pueden comparar entre sí.
##
## Esto lo hace solo: congela la escena donde esté, aplica una prueba, espera a
## que se asiente, mide un rato, la deshace y pasa a la siguiente. Al final
## imprime una tabla por consola, que en el móvil se pesca con `adb logcat`.
##
## CÓMO SE USA
##
##     var m = load("res://tools/medir_rendimiento.gd").new()
##     get_tree().current_scene.add_child(m)
##
## …y a leer la consola. Termina solo y se borra.
##
## POR QUÉ MIDE fps Y NO «tiempo de GPU»
##
## `viewport_get_measured_render_time_gpu()` devuelve 0 en Metal, así que en el
## Mac no hay tiempo de GPU que leer. Lo que sí se puede es **quitar una cosa y
## ver qué pasa**: si al bajar la resolución los fps se disparan, lo caro es
## pintar píxeles; si no se mueven, el cuello está en la CPU. Esa comparación
## vale igual en cualquier máquina y es la que decide dónde hay que trabajar.

## Cuánto se mide cada prueba. Menos de un segundo y el ruido se come la señal.
const SEGUNDOS_POR_PRUEBA := 1.2
## Lo que se descarta al principio de cada prueba: cambiar un material o una
## sombra obliga a recompilar y los primeros fotogramas salen carísimos.
const SEGUNDOS_DE_ASIENTO := 0.6

## Las pruebas, en orden. Cada una se aplica SOBRE EL ESTADO ORIGINAL, no sobre
## la anterior: así el número de cada una es lo que cuesta ELLA, y no la suma de
## todo lo apagado hasta ahí.
const PRUEBAS: Array[String] = [
	"tal cual",
	"tal cual (2ª vez)",
	"resolución 0.5",
	"resolución 0.25",
	"sin FXAA",
	"sin ajuste de color",
	"sin niebla",
	"sin sombras",
	"sin cielo",
	"sin decorado",
	"sin terreno",
	"sin personajes",
	"sin nada en 3D",
]

var _estado := {}
var _resultados: Array[Dictionary] = []


func _ready() -> void:
	name = "MedirRendimiento"
	# Sin esto, en el Mac todo mide exactamente 60 y no se distingue una prueba
	# de otra: el techo de la pantalla tapa la diferencia entera.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_guardar_estado()
	_correr.call_deferred()


func _guardar_estado() -> void:
	var escena := get_tree().current_scene
	var entorno := escena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var vp := get_viewport()
	_estado = {
		"env": entorno.environment if entorno != null else null,
		"fondo": entorno.environment.background_mode if entorno != null else 0,
		"niebla": entorno.environment.fog_enabled if entorno != null else false,
		"ajuste": entorno.environment.adjustment_enabled if entorno != null else false,
		"sol": escena.get_node_or_null("DirectionalLight3D"),
		"decorado": escena.get_node_or_null("Decorado"),
		"terreno": escena.get_node_or_null("Terreno"),
		"blockout": escena.get_node_or_null("Blockout"),
		"aa": vp.screen_space_aa,
		"escala": vp.scaling_3d_scale,
	}


## Deja todo como estaba. Se llama antes de CADA prueba.
func _restaurar() -> void:
	var vp := get_viewport()
	var env: Environment = _estado["env"]
	if env != null:
		env.background_mode = _estado["fondo"]
		env.fog_enabled = _estado["niebla"]
		env.adjustment_enabled = _estado["ajuste"]
	var sol: DirectionalLight3D = _estado["sol"]
	if sol != null:
		sol.shadow_enabled = true
	vp.screen_space_aa = _estado["aa"]
	vp.scaling_3d_scale = _estado["escala"]
	for clave in ["decorado", "terreno", "blockout"]:
		var nodo: Node3D = _estado[clave]
		if nodo != null:
			nodo.visible = true
	_personajes_visibles(true)


## Enseña u oculta todo lo que sea un personaje con esqueleto: la jugadora,
## Luna, los encuentros y el guardián. Son las mallas más caras que hay.
func _personajes_visibles(si: bool) -> void:
	var escena := get_tree().current_scene
	for nombre in ["Player", "Luna", "EncuentroMercury"]:
		var nodo := escena.get_node_or_null(nombre) as Node3D
		if nodo != null:
			nodo.visible = si


func _aplicar(prueba: String) -> void:
	var vp := get_viewport()
	var env: Environment = _estado["env"]
	var sol: DirectionalLight3D = _estado["sol"]
	match prueba:
		"tal cual", "tal cual (2ª vez)":
			pass
		"resolución 0.5":
			vp.scaling_3d_scale = 0.5
		"resolución 0.25":
			vp.scaling_3d_scale = 0.25
		"sin FXAA":
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		"sin ajuste de color":
			if env != null:
				env.adjustment_enabled = false
		"sin niebla":
			if env != null:
				env.fog_enabled = false
		"sin sombras":
			if sol != null:
				sol.shadow_enabled = false
		"sin cielo":
			if env != null:
				env.background_mode = Environment.BG_COLOR
		"sin decorado":
			if _estado["decorado"] != null:
				(_estado["decorado"] as Node3D).visible = false
		"sin terreno":
			if _estado["terreno"] != null:
				(_estado["terreno"] as Node3D).visible = false
		"sin personajes":
			_personajes_visibles(false)
		"sin nada en 3D":
			# El suelo de la medición: lo que cuesta el juego sin dibujar mundo.
			# Si aquí los fps no se disparan, el cuello está en la CPU y ninguna
			# optimización de render va a servir de nada.
			if env != null:
				env.background_mode = Environment.BG_COLOR
			for clave in ["decorado", "terreno", "blockout"]:
				var nodo: Node3D = _estado[clave]
				if nodo != null:
					nodo.visible = false
			_personajes_visibles(false)
		_:
			push_warning("MedirRendimiento: prueba sin implementar '%s'" % prueba)


func _correr() -> void:
	print("\n[Medición] empieza — %d pruebas x %.1f s" % [PRUEBAS.size(), SEGUNDOS_POR_PRUEBA])
	for prueba in PRUEBAS:
		_restaurar()
		_aplicar(prueba)
		await get_tree().create_timer(SEGUNDOS_DE_ASIENTO).timeout
		_resultados.append(await _medir(prueba))
	_restaurar()
	_informe()
	queue_free()


func _medir(prueba: String) -> Dictionary:
	var rid := get_viewport().get_viewport_rid()
	var inicio := Time.get_ticks_usec()
	var fotogramas := 0
	var peor := 0
	while Time.get_ticks_usec() - inicio < int(SEGUNDOS_POR_PRUEBA * 1000000.0):
		var antes := Time.get_ticks_usec()
		await get_tree().process_frame
		peor = maxi(peor, Time.get_ticks_usec() - antes)
		fotogramas += 1
	var transcurrido := float(Time.get_ticks_usec() - inicio)
	return {
		"prueba": prueba,
		"fps": 1000000.0 * float(fotogramas) / transcurrido,
		"peor_ms": peor / 1000.0,
		"draws_pantalla": RenderingServer.viewport_get_render_info(rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"draws_sombra": RenderingServer.viewport_get_render_info(rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"tris_pantalla": RenderingServer.viewport_get_render_info(rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		"tris_sombra": RenderingServer.viewport_get_render_info(rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
	}


func _informe() -> void:
	var base: float = _resultados[0]["fps"]
	var lineas: Array[String] = []
	lineas.append("")
	lineas.append("[Medición] %s · %s · %dx%d" % [
		OS.get_name(), RenderingServer.get_video_adapter_name(),
		get_viewport().get_visible_rect().size.x,
		get_viewport().get_visible_rect().size.y])
	lineas.append("prueba                 fps    ganancia   peor ms   draws(p+s)   tris(p+s)")
	lineas.append("-------------------------------------------------------------------------")
	for r in _resultados:
		lineas.append("%-20s %6.1f %+8.0f%%   %7.1f   %4d+%-4d   %6d+%-6d" % [
			r["prueba"], r["fps"], 100.0 * (r["fps"] / base - 1.0), r["peor_ms"],
			r["draws_pantalla"], r["draws_sombra"],
			r["tris_pantalla"], r["tris_sombra"]])
	lineas.append("-------------------------------------------------------------------------")
	lineas.append("La ganancia se mide contra 'tal cual'. Lo que más suba es lo que más costaba.")
	lineas.append("Si 'resolución 0.25' apenas sube, el cuello es la CPU y no el pintado.")
	print("\n".join(lineas))
