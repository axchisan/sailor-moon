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
## Solo puede ocurrir una vez por partida.
@export var una_sola_vez: bool = true
## Gira hacia la jugadora al hablar.
@export var mirar_al_hablar: bool = true
## A partir de esta distancia deja de seguirla con la mirada.
@export var distancia_atencion: float = 12.0

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


func _ready() -> void:
	body_entered.connect(_al_entrar)
	if personaje != null:
		_montar_personaje()
	if mostrar_aviso:
		_montar_aviso()
	# Hace falta aunque no haya aviso: es lo que la hace girarse.
	set_process(true)


func _process(delta: float) -> void:
	_tiempo += delta
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
	_visual.reproducir_idle = true
	add_child(_visual)


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
	if _hablando or (_hecho and una_sola_vez):
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
	_hecho = true
	_congelar_jugador(true)
	if mirar_al_hablar:
		_mirarse()
	if _aviso != null:
		_aviso.visible = false

	panel.terminado.connect(_al_terminar, CONNECT_ONE_SHOT)
	if not panel.mostrar(dialogo):
		_al_terminar("")


func _al_terminar(_id_dialogo: String) -> void:
	_hablando = false
	_congelar_jugador(false)
	encuentro_terminado.emit(id)


## Se apaga el procesado del jugador, no el nodo entero: apagar el nodo pararía
## también las animaciones y el pelo, y la jugadora se quedaría como una
## estatua en mitad de la escena.
func _congelar_jugador(congelado: bool) -> void:
	if _jugador == null:
		return
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
