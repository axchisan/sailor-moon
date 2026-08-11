extends Area3D
class_name Encuentro
## Un personaje esperando en el escenario, con su conversación.
##
## Es lo que convierte el nivel en historia en vez de en pasillo: cada
## escenario presenta a alguien del reparto, se habla, y se une. Está pensado
## para ser **configuración y no programación**: los diez encuentros que faltan
## son crear un recurso de diálogo y colocar este nodo.
##
## Mientras se habla, la jugadora no se mueve. No es por capricho técnico: si
## puede andar durante la conversación, se va, y se pierde la escena entera.

signal encuentro_terminado(id: String)

@export var id: String = ""
## Quién espera. Si se pone, se monta su modelo con física de pelo incluida.
@export var personaje: CharacterData
@export var dialogo: Dialogo
## El encuentro solo CUENTA una vez para los objetivos.
##
## Ojo, no es lo mismo que «solo se puede hablar una vez», que es lo que
## significaba antes y estaba mal: bastaba cerrar el cuadro a mitad para
## quedarse sin poder volver a hablar con el personaje nunca más. Y cerrar sin
## querer es facilísimo — el aspa está justo donde se toca para avanzar.
##
## Ahora se puede volver a hablar siempre, saliendo del área y entrando otra
## vez. Lo que no se repite es el aviso a los objetivos: hablar dos veces con
## Mercury no cuenta por dos.
@export var una_sola_vez: bool = true
## Gira hacia la jugadora al hablar.
@export var mirar_al_hablar: bool = true
## A partir de esta distancia deja de seguirla con la mirada.
@export var distancia_atencion: float = 12.0

@export_group("Cuerpo")
## Le da bulto: sin esto se la atraviesa como si fuera un holograma, que es de
## las cosas que más rompen la escena. Va en un `StaticBody3D` aparte del área
## que dispara la conversación, porque son dos cosas distintas: una para y la
## otra escucha.
@export var solido: bool = true
@export var radio_cuerpo: float = 0.32
@export var alto_cuerpo: float = 1.6

@export_group("Aviso")
## Signo flotante que indica que aquí se puede hablar. Sin él, a los 8 años se
## pasa de largo sin enterarse de que había alguien.
@export var mostrar_aviso: bool = true
@export var color_aviso: Color = Color(1.0, 0.85, 0.4)

var _hecho: bool = false
var _hablando: bool = false
var _jugador: Node3D = null
var _visual: PersonajeVisual = null
var _aviso: Node3D = null
var _tiempo: float = 0.0
## Respiro tras cerrar, para que el toque que cierra no vuelva a abrirlo.
var _enfriamiento: float = 0.0
## El primer plano en vivo, solo mientras dura la conversación.
var _retrato: Retrato = null
## A quién está enfocando el retrato ahora mismo.
var _enfocado: Node3D = null

## Cuánto dura ese respiro.
const RESPIRO_TRAS_CERRAR := 0.8


func _ready() -> void:
	body_entered.connect(_al_entrar)
	if personaje != null:
		_montar_personaje()
	if solido:
		_montar_cuerpo()
	if mostrar_aviso:
		_montar_aviso()
	# Hace falta aunque no haya aviso: es lo que la hace girarse.
	set_process(true)


func _process(delta: float) -> void:
	_tiempo += delta
	_enfriamiento = maxf(0.0, _enfriamiento - delta)
	if _aviso != null:
		_aviso.position.y = 2.3 + sin(_tiempo * 3.0) * 0.12
		_aviso.rotate_y(delta * 1.5)
	_seguir_con_la_mirada(delta)


## Gira despacio hacia la jugadora cuando anda cerca, sin esperar a que empiece
## la conversación. Un personaje plantado de espaldas hasta que le hablas
## parece un maniquí; girándose se nota que está esperando a alguien.
func _seguir_con_la_mirada(delta: float) -> void:
	if _visual == null or _hablando:
		return
	var jugador := _buscar_jugador()
	if jugador == null:
		return
	var hacia := jugador.global_position - global_position
	hacia.y = 0.0
	if hacia.length_squared() < 0.01 or hacia.length() > distancia_atencion:
		return
	var objetivo := atan2(-hacia.x, -hacia.z)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, objetivo, minf(delta * 4.0, 1.0))


func _montar_personaje() -> void:
	_visual = PersonajeVisual.new()
	_visual.name = "Personaje"
	_visual.data = personaje
	# Con animador: es lo que le permite actuar durante la conversación.
	_visual.con_animador = true
	add_child(_visual)


## Cápsula sólida a la altura del personaje, para que se le note el cuerpo.
##
## Cuelga de este nodo y no del visual porque el visual gira siguiendo a la
## jugadora con la mirada: una cápsula girando con él daría empujones raros al
## acercarse por un lado.
func _montar_cuerpo() -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Cuerpo"
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0

	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = radio_cuerpo
	capsula.height = alto_cuerpo
	forma.shape = capsula
	forma.position.y = alto_cuerpo * 0.5
	cuerpo.add_child(forma)
	add_child(cuerpo)


func _montar_aviso() -> void:
	_aviso = Node3D.new()
	_aviso.name = "Aviso"
	var malla := MeshInstance3D.new()
	var prisma := PrismMesh.new()
	prisma.size = Vector3(0.22, 0.4, 0.22)
	malla.mesh = prisma
	var material := StandardMaterial3D.new()
	material.albedo_color = color_aviso
	material.emission_enabled = true
	material.emission = color_aviso
	material.emission_energy_multiplier = 2.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	malla.material_override = material
	_aviso.add_child(malla)
	_aviso.position.y = 2.3
	add_child(_aviso)
	set_process(true)


func _al_entrar(cuerpo: Node3D) -> void:
	# Ya NO se mira `_hecho`: se puede volver a hablar todas las veces que se
	# quiera. Lo único que frena es estar hablando ya, o acabar de cerrar —
	# sin ese respiro, el mismo toque que cierra el cuadro lo reabre.
	if _hablando or _enfriamiento > 0.0:
		return
	if not cuerpo.is_in_group("player"):
		return
	_jugador = cuerpo
	empezar()


func empezar() -> void:
	if dialogo == null:
		push_warning("Encuentro '%s' sin diálogo asignado" % id)
		return

	var panel := _buscar_panel()
	if panel == null:
		push_warning("Encuentro '%s': no hay PanelDialogo en la escena" % id)
		return

	_hablando = true
	_congelar_jugador(true)
	if mirar_al_hablar:
		_mirarse()
	if _aviso != null:
		_aviso.visible = false

	_montar_retrato(panel)
	panel.terminado.connect(_al_terminar, CONNECT_ONE_SHOT)
	if not panel.linea_mostrada.is_connected(_al_mostrar_linea):
		panel.linea_mostrada.connect(_al_mostrar_linea)
	if not panel.mostrar(dialogo):
		_al_terminar("")


## Monta el retrato en vivo y lo mete en el cuadro de diálogo.
##
## Se crea al abrir y se tira al cerrar: es una cámara más renderizando, y no
## tiene por qué existir mientras se corre por el parque. Ver
## [`retrato.gd`](../ui/retrato.gd).
func _montar_retrato(panel: Node) -> void:
	if _visual == null or not panel.has_method("poner_retrato"):
		return
	_retrato = Retrato.new()
	_retrato.name = "Retrato"
	add_child(_retrato)
	_enfocado = _visual
	if _retrato.enfocar(_visual):
		panel.poner_retrato(_retrato.get_texture())
	else:
		_tirar_retrato(panel)


func _tirar_retrato(panel: Node) -> void:
	if panel != null and panel.has_method("poner_retrato"):
		panel.poner_retrato(null)
	if _retrato == null:
		return
	_retrato.soltar(_enfocado)
	_retrato.queue_free()
	_retrato = null
	_enfocado = null


## El bucle base mientras se conversa.
##
## Antes cada línea disparaba un gesto suelto y, entre gesto y gesto, los dos
## personajes se quedaban en la pose de estar de pie: dos estatuas turnándose
## para soltar un manotazo. Con un bucle de hablar por debajo, el gesto pasa a
## ser un ACENTO sobre algo que ya se está moviendo, que es lo que hace que
## parezca una conversación.
const BUCLE_HABLAR := "talk"

## Cuánto se espera tras un gesto antes de volver al bucle.
##
## No hay señal fiable de «este gesto terminó» —el `AnimationTree` mezcla y no
## avisa por estado— así que se pregunta a la librería cuánto dura y se espera
## eso. Es lo mismo que hace el combate para encajar los golpes.
const MARGEN_GESTO := 0.15


## Lanza el gesto que lleve la línea, sobre el bucle de hablar. Es lo que separa
## una conversación de dos estatuas: en la transformación de Ami se ve el brazo
## alzado en vez de leer que se transforma.
func _al_mostrar_linea(indice: int) -> void:
	if dialogo == null or indice < 0 or indice >= dialogo.lineas.size():
		return
	var linea: LineaDialogo = dialogo.lineas[indice]

	# MANDA `hablante`, NO `actua`.
	#
	# `actua` era opcional y casi nunca estaba puesto, así que todo caía por
	# defecto en el personaje del encuentro: hablara quien hablara —Luna,
	# Serena— la que gesticulaba era Amy, y Serena se quedaba tiesa cuando le
	# tocaba a ella. Quién habla ya lo dice cada línea; no hacía falta un
	# segundo campo para lo mismo.
	var quien := linea.hablante
	var habla_el_jugador := quien == "serena" or quien == "jugador"
	# Luna no tiene librería de animaciones —es el gato, con su esqueleto a
	# mano— así que cuando habla ella no se anima nadie. Es lo correcto: mover a
	# Amy mientras habla Luna es justamente lo que se veía mal.
	var nadie_actua := not habla_el_jugador and not _habla_el_personaje(quien)

	_seguir_al_que_habla(quien)
	# El que NO habla vuelve a estar de pie. Sin esto se queda gesticulando
	# mientras habla el otro, que es la mitad del problema de que «siempre se
	# mueve Amy»: no es que se moviera de más, es que no paraba nunca.
	if habla_el_jugador or nadie_actua:
		_animar(false, "locomocion")
	if not habla_el_jugador or nadie_actua:
		_animar(true, "locomocion")
	if nadie_actua:
		return

	if linea.animacion.is_empty():
		_animar(habla_el_jugador, BUCLE_HABLAR)
		return

	_animar(habla_el_jugador, linea.animacion)
	await _esperar_gesto(habla_el_jugador, linea.animacion)
	# Y de vuelta al bucle, si la conversación sigue viva. Sin esto, el
	# personaje se queda clavado en la última pose del gesto hasta la línea
	# siguiente.
	if _hablando:
		_animar(habla_el_jugador, BUCLE_HABLAR)


## ¿Habla el personaje de este encuentro?
##
## La comparación es tolerante a propósito. Los diálogos dicen `"mercury"` y el
## recurso del personaje se llama `"sailor_mercury"`: comparándolos por igualdad
## no coincidían NUNCA, así que Amy no gesticulaba ni salía en el retrato — se
## quedaba muda en su propia conversación.
##
## Podría arreglarse renombrando uno de los dos, pero entonces habría que
## acordarse cada vez que se añada un personaje, y este es exactamente el tipo
## de detalle que no se recuerda. Que uno contenga al otro basta y no falla.
func _habla_el_personaje(quien: String) -> bool:
	if personaje == null or quien.is_empty():
		return false
	var suyo: String = personaje.id
	return suyo == quien or suyo.contains(quien) or quien.contains(suyo)


## Mueve el retrato al que está hablando.
##
## Antes enfocaba siempre al personaje del encuentro, así que salía Amy con el
## nombre de Luna debajo. El retrato tiene que decir QUIÉN habla, que es
## justamente para lo que sirve.
func _seguir_al_que_habla(quien: String) -> void:
	if _retrato == null:
		return
	var objetivo: Node3D = null
	if quien == "serena" or quien == "jugador":
		objetivo = _jugador.get_node_or_null("Model") if _jugador != null else null
	elif _habla_el_personaje(quien):
		objetivo = _visual
	elif quien == "luna":
		# Luna anda suelta por el parque siguiendo a Serena; se la busca por el
		# grupo en vez de guardarla, porque puede no estar en esta escena.
		for gato in get_tree().current_scene.find_children("*", "Companero", true, false):
			objetivo = gato
			break

	if objetivo == null:
		return
	_retrato.soltar(_enfocado)
	if _retrato.enfocar(objetivo):
		_enfocado = objetivo


## Pide una animación a quien corresponda. El jugador y el personaje del
## encuentro se animan por vías distintas, y esto lo deja en un solo sitio.
func _animar(al_jugador: bool, estado: String) -> void:
	if al_jugador:
		if _jugador != null and _jugador.has_method("play"):
			_jugador.call("play", estado)
	elif _visual != null:
		_visual.reproducir(estado)


func _esperar_gesto(del_jugador: bool, estado: String) -> void:
	var animador: CharacterAnimator = null
	if del_jugador and _jugador != null:
		animador = _jugador.get("animator") as CharacterAnimator
	elif _visual != null:
		animador = _visual.get("_animador") as CharacterAnimator
	var duracion := 0.9
	if animador != null:
		var largo := animador.get_length(
			CharacterAnimator.ANIMACION_DE.get(estado, estado))
		if largo > 0.0:
			duracion = largo
	await get_tree().create_timer(duracion + MARGEN_GESTO).timeout


func _al_terminar(_id_dialogo: String) -> void:
	_hablando = false
	_tirar_retrato(_buscar_panel())
	_enfriamiento = RESPIRO_TRAS_CERRAR
	# Los dos vuelven a estar de pie. Sin esto se quedan gesticulando solos
	# después de que el cuadro de diálogo se haya cerrado.
	_animar(true, "locomocion")
	_animar(false, "locomocion")
	_congelar_jugador(false)
	# El aviso vuelve, para que se vea que aquí se puede seguir hablando.
	if _aviso != null:
		_aviso.visible = true
	# Pero a los objetivos solo se les avisa la primera vez: hablar dos veces
	# con Mercury no cuenta por dos.
	if _hecho and una_sola_vez:
		return
	_hecho = true
	encuentro_terminado.emit(id)


## Quitar el control es más que apagar el proceso de física: hay que parar la
## animación y descartar las pulsaciones pendientes. Lo hace `Player`, que es
## quien conoce su animador y su máquina de estados.
func _congelar_jugador(congelado: bool) -> void:
	if _jugador == null:
		return
	if _jugador.has_method("set_control_enabled"):
		_jugador.call("set_control_enabled", not congelado)
		return
	# Sustituto para cualquier cosa que no sea el Player (pruebas, cápsulas).
	_jugador.set_physics_process(not congelado)
	if congelado and _jugador is CharacterBody3D:
		(_jugador as CharacterBody3D).velocity = Vector3.ZERO


func _mirarse() -> void:
	if _jugador == null:
		return
	# Cada uno gira hacia el otro, pero solo en horizontal: mirando también en
	# vertical, con estaturas distintas, acaban inclinados hacia el suelo.
	#
	# El signo importa: en Godot el frente de un nodo es −Z, así que para mirar
	# hacia `d` el ángulo es `atan2(−d.x, −d.z)`. Con `atan2(d.x, d.z)` queda
	# justo del revés, dando la espalda a quien le habla.
	if _visual != null:
		var hacia := _jugador.global_position - global_position
		hacia.y = 0.0
		if hacia.length_squared() > 0.001:
			_visual.rotation.y = atan2(-hacia.x, -hacia.z)

	var modelo := _jugador.get_node_or_null("Model") as Node3D
	if modelo != null:
		var hacia_mi := global_position - _jugador.global_position
		hacia_mi.y = 0.0
		if hacia_mi.length_squared() > 0.001:
			modelo.rotation.y = atan2(-hacia_mi.x, -hacia_mi.z)


func _buscar_jugador() -> Node3D:
	if _jugador != null and is_instance_valid(_jugador):
		return _jugador
	_jugador = get_tree().get_first_node_in_group("player") as Node3D
	return _jugador


func _buscar_panel() -> PanelDialogo:
	var encontrados := get_tree().get_nodes_in_group("panel_dialogo")
	if not encontrados.is_empty():
		return encontrados[0] as PanelDialogo
	return null
