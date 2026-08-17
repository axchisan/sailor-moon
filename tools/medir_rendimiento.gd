extends Node
class_name MedirRendimiento
## Banco de medición automático, pensado para el MÓVIL.
##
## POR QUÉ EXISTE
##
## El banco de pruebas de `F8` va a mano: se pulsa, se mira el panel, se apunta.
## Eso vale para comprobar una sospecha, pero no para comparar trece
## configuraciones seguidas sin que se muevan ni la cámara ni la posición — y si
## se mueven, los números no se pueden comparar entre sí.
##
## Esto lo hace solo: aplica una prueba, espera a que se asiente, mide, la
## deshace y pasa a la siguiente. Al final imprime una tabla por consola, que en
## el móvil se pesca con `adb logcat`.
##
## LAS DOS TRAMPAS DE MEDIR EN UN TELÉFONO, Y CÓMO SE ESQUIVAN
##
## **1. El vsync no se puede quitar.** `window_set_vsync_mode(DISABLED)` se pide
## y Android lo ignora: `window_get_vsync_mode()` sigue devolviendo 1. O sea que
## el techo son 60 fps pase lo que pase, y una prueba que quitara la mitad del
## trabajo seguiría marcando 60. Sin margen por arriba no se mide nada.
##
## La salida es una LUPA: se sube la resolución de render por encima de la nativa
## hasta que la escena baja del techo, y a partir de ahí las diferencias vuelven
## a verse. `_calibrar()` lo hace solo, subiendo hasta que la referencia cae por
## debajo de `TECHO_UTIL`. La lupa multiplica el coste POR PÍXEL y no toca el de
## CPU ni el de llamadas de dibujado — hay que leer la tabla sabiéndolo, y por
## eso el informe dice con qué lupa se midió.
##
## **2. El teléfono no rinde igual dos minutos seguidos.** En el mismo sitio y
## sin tocar nada, este aparato ha dado 35, 47 y 60 fps: es el gobernador de
## frecuencia y el calentamiento. Esa deriva (±40 %) es MÁS GRANDE que casi todo
## lo que se quiere medir, así que comparar la prueba nº 9 con la nº 1 no
## significa nada.
##
## La salida es intercalar: se vuelve a medir la referencia ENTRE prueba y
## prueba, y cada una se compara con el promedio de la referencia de antes y la
## de después. Así la deriva se cancela en vez de contaminar. El informe imprime
## también las referencias, para que se vea cuánto ha derivado el aparato.
##
## CÓMO SE USA
##
##     var m = load("res://tools/medir_rendimiento.gd").new()
##     get_tree().current_scene.add_child(m)

## Cuánto se mide cada prueba. En un móvil hace falta más ventana que en un PC:
## con menos de dos segundos, un solo tirón de recolección mueve el resultado.
const SEGUNDOS_POR_PRUEBA := 2.5
## Lo que se descarta al principio de cada prueba: cambiar un material o una
## sombra obliga a recompilar, y los primeros fotogramas salen carísimos.
const SEGUNDOS_DE_ASIENTO := 1.2

## Dónde queremos que quede la referencia tras calibrar.
##
## No basta con estar «por debajo de 60»: lo que se mide son MEJORAS, y una
## mejora choca contra el techo del vsync igual que la referencia. Con la
## referencia a 40, todo lo que ganara más de un 50 % marcaba 59,9 y no había
## forma de saber si eran 60 u 85 — pasó en la primera tanda buena: quitar el
## terreno y quitar el decorado dieron los dos «+47 %», que es justo el número
## que sale cuando los dos han chocado con la pared.
##
## A 30 caben mejoras de hasta el doble antes de tocarla.
const TECHO_UTIL := 30.0
## Hasta dónde se deja subir la lupa. Godot admite hasta 2.0, que son cuatro
## veces los píxeles.
const LUPA_MAXIMA := 2.0

## Color de relleno para cuando se prueba el ambiente plano. Es un azul de cielo
## desaturado: lo que aporta el cielo de este juego, promediado.
const AMBIENTE_PLANO := Color(0.62, 0.70, 0.86)

## Las pruebas, en orden. Cada una se aplica SOBRE EL ESTADO ORIGINAL, no sobre
## la anterior: así el número de cada una es lo que cuesta ELLA, y no la suma de
## todo lo apagado hasta ahí.
const PRUEBAS: Array[String] = [
	"media resolución",
	# Estas dos parten el coste del terreno en sus dos mitades. «Sin terreno» ya
	# dice cuánto cuesta ENTERO, pero no si lo caro es tener que pintar tantos
	# píxeles o lo que se hace en cada uno. Con el material liso se pintan
	# exactamente los mismos píxeles con un shader trivial: lo que suba ahí es
	# culpa del shader, y lo que quede es fill rate puro.
	"terreno sin triplanar",
	"terreno sin luz",
	"sin sol",
	# El `Environment` toma la luz ambiente Y los reflejos del CIELO, y eso es
	# una muestra del cubemap de radiancia por píxel iluminado, cada una. Son
	# las dos primeras sospechosas en cuanto se vio que lo caro era iluminar.
	"ambiente de color",
	"sin reflejo de cielo",
	"ambiente de color y sin reflejo",
	"sin FXAA",
	"sin ajuste de color",
	"sin niebla",
	"sin sombras",
	"sin cielo",
	"sin decorado",
	"sin terreno",
	"sin personajes",
	"sin contorno",
	"sin nada en 3D",
]

var _estado := {}
var _lupa := 1.0
var _resultados: Array[Dictionary] = []
var _referencias: Array[float] = []
var _camara_banco: Camera3D = null
var _camara_previa: Camera3D = null


func _ready() -> void:
	name = "MedirRendimiento"
	# El banco tiene que seguir corriendo con el juego congelado.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Se pide igualmente: en el Mac sí funciona y ahí el techo de 60 sí tapa
	# todo. En Android se ignora en silencio, de ahí la lupa.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_guardar_estado()
	_correr.call_deferred()


## Clava la vista para toda la medición.
##
## POR QUÉ HACE FALTA
##
## La primera tanda en el móvil salió inservible y no se vio hasta mirar los
## draw calls: saltaban de 52 a 156 entre pruebas. La jugadora se había
## desplazado once metros mientras se medía —basta un roce en la pantalla táctil,
## que está boca arriba sobre la mesa— y cada prueba estaba mirando a un sitio
## distinto. Comparar eso es comparar dos escenas, no dos configuraciones.
##
## Se copia la cámara del juego tal como está en este instante a una cámara
## propia, y se congela el árbol. A partir de ahí todas las pruebas ven
## exactamente los mismos píxeles, y los draw calls de la tabla tienen que salir
## iguales en todas las filas — si no salen, algo se sigue moviendo y el número
## no vale.
##
## Lo que se pierde: con el árbol congelado las animaciones no avanzan, así que
## no se mide el coste de recalcular el esqueleto. Los triángulos, las llamadas
## y los píxeles —que es lo que se está buscando— salen igual.
func _fijar_la_vista() -> void:
	_camara_previa = get_viewport().get_camera_3d()
	_camara_banco = Camera3D.new()
	get_tree().current_scene.add_child(_camara_banco)
	_camara_banco.name = "CamaraDelBanco"
	if _camara_previa != null:
		_camara_banco.global_transform = _camara_previa.global_transform
		_camara_banco.fov = _camara_previa.fov
		_camara_banco.far = _camara_previa.far
		_camara_banco.near = _camara_previa.near
	_camara_banco.make_current()
	get_tree().paused = true


## Deshacerlo todo aunque la tanda se corte por medio.
##
## POR QUÉ HACE FALTA
##
## Si el banco muere a mitad —se corta la conexión, se cierra el juego, se
## interrumpe— la escena se queda con la última prueba puesta: el cielo apagado,
## el terreno con el material de mentira, el árbol congelado. Y lo peor es lo
## siguiente: la tanda que venga detrás llama a `_guardar_estado()` sobre ESA
## escena y se apunta el estropicio como si fuera el original, así que ya no hay
## forma de volver. Pasó: una captura salió con el terreno gris y el cielo liso,
## y no era ningún cambio nuestro, era una tanda anterior sin deshacer.
func _exit_tree() -> void:
	if not _estado.is_empty():
		_restaurar()
		get_viewport().scaling_3d_scale = _estado["escala"]
	_soltar_la_vista()


func _soltar_la_vista() -> void:
	get_tree().paused = false
	if _camara_previa != null:
		_camara_previa.make_current()
	if _camara_banco != null:
		_camara_banco.queue_free()


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
		"ambiente": entorno.environment.ambient_light_source if entorno != null else 0,
		"ambiente_color": entorno.environment.ambient_light_color if entorno != null else Color.BLACK,
		"reflejo": entorno.environment.reflected_light_source if entorno != null else 0,
	}
	if _LISO == null:
		_LISO = StandardMaterial3D.new()
		_LISO.albedo_color = Color(0.45, 0.6, 0.38)
		# SIN SOMBREADO. Un `StandardMaterial3D` por defecto trae difuso Burley y
		# especular GGX, que cuestan MÁS que el `diffuse_lambert,
		# specular_disabled` del shader del terreno: la primera versión de esta
		# prueba salió un 11 % más lenta que la referencia, y no era el terreno,
		# era que el sustituto costaba más que el sustituido. Para medir «cuánto
		# cuesta iluminar» el sustituto tiene que costar cero.
		_LISO.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# El material propio de cada malla del terreno, para poder devolvérselo.
	var originales := {}
	for malla in _mallas_de_terreno():
		originales[malla] = malla.material_override
	_estado["materiales_terreno"] = originales


## Sube la resolución de render hasta que la escena deja de tocar el techo del
## vsync. Sin esto, en el móvil la mitad de la tabla sale a 60,0 y no dice nada.
func _calibrar() -> void:
	_lupa = _estado["escala"]
	while true:
		get_viewport().scaling_3d_scale = _lupa
		await get_tree().create_timer(SEGUNDOS_DE_ASIENTO).timeout
		var r := await _medir("calibrando")
		if r["fps"] < TECHO_UTIL or _lupa >= LUPA_MAXIMA:
			break
		_lupa = minf(_lupa * 1.35, LUPA_MAXIMA)
	get_viewport().scaling_3d_scale = _estado["escala"]
	print("[Medición] lupa de %.2f (%.1fx los píxeles nativos)" % [_lupa, _lupa * _lupa])


## Deja todo como estaba, con la lupa puesta. Se llama antes de CADA prueba.
func _restaurar() -> void:
	var vp := get_viewport()
	var env: Environment = _estado["env"]
	if env != null:
		env.background_mode = _estado["fondo"]
		env.fog_enabled = _estado["niebla"]
		env.adjustment_enabled = _estado["ajuste"]
		env.ambient_light_source = _estado["ambiente"]
		env.ambient_light_color = _estado["ambiente_color"]
		env.reflected_light_source = _estado["reflejo"]
	var sol: DirectionalLight3D = _estado["sol"]
	if sol != null:
		sol.shadow_enabled = true
	vp.screen_space_aa = _estado["aa"]
	vp.scaling_3d_scale = _lupa
	vp.debug_draw = Viewport.DEBUG_DRAW_DISABLED
	var luz: DirectionalLight3D = _estado["sol"]
	if luz != null:
		luz.visible = true
	for clave in ["decorado", "terreno", "blockout"]:
		var nodo: Node3D = _estado[clave]
		if nodo != null:
			nodo.visible = true
	_personajes_visibles(true)
	_contorno(true)
	var originales: Dictionary = _estado.get("materiales_terreno", {})
	for malla in originales:
		var mi := malla as MeshInstance3D
		if mi.material_override != originales[malla]:
			mi.material_override = originales[malla]
		var m := mi.material_override as ShaderMaterial
		if m != null and m.get_shader_parameter("solo_plano"):
			m.set_shader_parameter("solo_plano", false)


## Enseña u oculta todo lo que sea un personaje con esqueleto: la jugadora,
## Luna, los encuentros y el guardián. Son las mallas más caras que hay.
func _personajes_visibles(si: bool) -> void:
	var escena := get_tree().current_scene
	for nombre in ["Player", "Luna", "EncuentroMercury"]:
		var nodo := escena.get_node_or_null(nombre) as Node3D
		if nodo != null:
			nodo.visible = si


## Pone o quita el contorno de TODOS los materiales MToon de la escena.
##
## El contorno se dibuja con la malla entera otra vez, del revés e inflada. Es
## la única prueba de la tabla que quita GEOMETRÍA de personaje sin quitar al
## personaje, así que es la que dice cuánto cuesta el estilo.
## OJO: solo se toca si de verdad cambia. Escribir `next_pass` invalida el
## pipeline del material y obliga a recompilarlo, y hacerlo antes de CADA prueba
## —aunque fuera para dejarlo igual— metía una tanda de recompilaciones dentro
## de la ventana de medida. La prueba del contorno llegó a marcar 17 fps contra
## 40 de referencia, o sea que quitar trabajo salía «un 57 % más lento»: eso no
## era el contorno, era el compilador de shaders.
var _hay_contorno := true


func _contorno(si: bool) -> void:
	if si == _hay_contorno:
		return
	_hay_contorno = si
	for material in _materiales_mtoon():
		if si:
			if material.has_meta("contorno_guardado"):
				material.next_pass = material.get_meta("contorno_guardado")
		else:
			if material.next_pass != null:
				material.set_meta("contorno_guardado", material.next_pass)
			material.next_pass = null


## Material de sustitución para la prueba del terreno liso. Se crea una vez: si
## se creara por prueba, cada una estrenaría material y pagaría su compilación
## dentro de la ventana de medida.
static var _LISO: StandardMaterial3D = null

## Las mallas que llevan el shader del terreno con su material propio. Son la
## superficie grande y las piezas que la acompañan.
func _mallas_de_terreno() -> Array[MeshInstance3D]:
	var encontradas: Array[MeshInstance3D] = []
	var terreno: Node = _estado["terreno"]
	if terreno == null:
		return encontradas
	for hijo in terreno.get_children():
		var malla := hijo as MeshInstance3D
		if malla != null:
			encontradas.append(malla)
	return encontradas


func _materiales_mtoon() -> Array[ShaderMaterial]:
	var encontrados: Array[ShaderMaterial] = []
	var pila: Array[Node] = [get_tree().current_scene]
	while not pila.is_empty():
		var nodo: Node = pila.pop_back()
		var malla := nodo as MeshInstance3D
		if malla != null and malla.mesh != null:
			for s in malla.mesh.get_surface_count():
				var m := malla.get_active_material(s) as ShaderMaterial
				if m != null and m.shader != null and "mtoon" in str(m.shader.resource_path):
					encontrados.append(m)
		for hijo in nodo.get_children():
			pila.append(hijo)
	return encontrados


func _aplicar(prueba: String) -> void:
	var vp := get_viewport()
	var env: Environment = _estado["env"]
	var sol: DirectionalLight3D = _estado["sol"]
	match prueba:
		"referencia":
			pass
		"media resolución":
			vp.scaling_3d_scale = _lupa * 0.5
		"terreno sin luz":
			# El terreno con los mismos píxeles y CERO iluminación. Lo que suba
			# aquí es lo que cuesta iluminar el suelo.
			for malla in _mallas_de_terreno():
				malla.material_override = _LISO
		"ambiente de color":
			if env != null:
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				env.ambient_light_color = AMBIENTE_PLANO
		"sin reflejo de cielo":
			if env != null:
				env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		"ambiente de color y sin reflejo":
			if env != null:
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				env.ambient_light_color = AMBIENTE_PLANO
				env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		"sin sol":
			if sol != null:
				sol.visible = false
		"terreno sin triplanar":
			# El mismo shader, pero leyendo el patrón por UNA sola proyección en
			# vez de tres. En la superficie del suelo la normal apunta casi
			# siempre hacia arriba, así que las otras dos apenas pesan y se están
			# pagando enteras.
			for malla in _mallas_de_terreno():
				var m := malla.material_override as ShaderMaterial
				if m != null:
					m.set_shader_parameter("solo_plano", true)
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
		"sin contorno":
			_contorno(false)
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
	_fijar_la_vista()
	print("\n[Medición] vista congelada, calibrando…")
	await _calibrar()
	print("[Medición] %d pruebas, intercalando referencia" % PRUEBAS.size())

	# La referencia se vuelve a medir ENTRE prueba y prueba. Cada una se compara
	# con el promedio de la de antes y la de después, y así la deriva térmica del
	# teléfono se cancela en vez de contaminar el resultado.
	_restaurar()
	await get_tree().create_timer(SEGUNDOS_DE_ASIENTO).timeout
	_referencias.append((await _medir("referencia"))["fps"])

	for prueba in PRUEBAS:
		_restaurar()
		_aplicar(prueba)
		# El contorno recompila materiales al ponerlo y al quitarlo, y una
		# recompilación dentro de la ventana de medida arruina el número. Se le
		# da margen de sobra a esa y solo a esa.
		var asiento := SEGUNDOS_DE_ASIENTO
		if prueba == "sin contorno":
			asiento *= 3.0
		await get_tree().create_timer(asiento).timeout
		_resultados.append(await _medir(prueba))

		_restaurar()
		await get_tree().create_timer(SEGUNDOS_DE_ASIENTO).timeout
		_referencias.append((await _medir("referencia"))["fps"])

	_restaurar()
	get_viewport().scaling_3d_scale = _estado["escala"]
	_soltar_la_vista()
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
	var lineas: Array[String] = []
	lineas.append("")
	lineas.append("[Medición] %s · %s · %dx%d · lupa %.2f" % [
		OS.get_name(), RenderingServer.get_video_adapter_name(),
		get_viewport().get_visible_rect().size.x,
		get_viewport().get_visible_rect().size.y, _lupa])

	var menor: float = _referencias[0]
	var mayor: float = _referencias[0]
	for r in _referencias:
		menor = minf(menor, r)
		mayor = maxf(mayor, r)
	lineas.append("referencia entre pruebas: %.1f – %.1f fps (deriva del aparato: %.0f %%)"
		% [menor, mayor, 100.0 * (mayor / maxf(menor, 0.01) - 1.0)])
	lineas.append("prueba                 fps    contra ref   peor ms   draws(p+s)   tris(p+s)")
	lineas.append("----------------------------------------------------------------------------")
	for i in _resultados.size():
		var r := _resultados[i]
		# La referencia local: promedio de la de antes y la de después.
		var base: float = (_referencias[i] + _referencias[i + 1]) * 0.5
		lineas.append("%-20s %6.1f %+9.0f%%   %7.1f   %4d+%-4d   %6d+%-6d" % [
			r["prueba"], r["fps"], 100.0 * (r["fps"] / maxf(base, 0.01) - 1.0),
			r["peor_ms"], r["draws_pantalla"], r["draws_sombra"],
			r["tris_pantalla"], r["tris_sombra"]])
	lineas.append("----------------------------------------------------------------------------")
	lineas.append("Cada prueba se compara con la referencia medida JUSTO ANTES Y DESPUÉS de ella.")
	lineas.append("Lo que más suba es lo que más costaba. La lupa multiplica el coste por PÍXEL,")
	lineas.append("no el de CPU ni el de llamadas de dibujado: leer la tabla sabiéndolo.")
	print("\n".join(lineas))
