extends Area3D
class_name PortalSalida
## La puerta al siguiente escenario. Apagada hasta cumplir todos los objetivos.
##
## Es una **ruina de piedra** con dos pilares, dintel en arco y un cristal
## flotando en medio ([`blender_kit_expansion.py`](../../tools/blender_kit_expansion.py)).
## El primer intento fue un aro de luz montado por código y no decía nada:
## podía ser un charco. Una puerta de piedra vieja se lee sola como algo que
## estaba ahí antes que el parque, que es la sensación que pide el sitio por el
## que se sale hacia otro mundo.
##
## Vive en un **claro apartado, al final del paseo de vuelta** — antes estaba
## pegado al punto de aparición, y una puerta al siguiente mundo a dos pasos de
## donde apareces le quita todo el peso. Hay que ir hasta ella.
##
## Apagada no es invisible: la piedra está desde el primer minuto y el cristal
## dormido. Verla antes de poder usarla es lo que convierte la lista de
## objetivos en un camino hacia algo.

signal usado(destino: String)

const MODELO: PackedScene = preload("res://assets/models/props/portal_antiguo.glb")

@export var destino: String = ""
@export var radio: float = 2.2
@export var color_dormido: Color = Color(0.45, 0.42, 0.58)
@export var color_activo: Color = Color(1.0, 0.72, 0.95)
## Mensaje al encenderse. Vacío = no dice nada.
@export var aviso: String = "¡La puerta antigua ha despertado! Está al final del parque"

var _activo: bool = false
var _aro: MeshInstance3D = null
var _luz: OmniLight3D = null
var _material: StandardMaterial3D = null
var _tiempo: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_al_entrar)
	# ESCUCHA DESDE EL PRINCIPIO, aunque esté dormido.
	#
	# Estaba apagado hasta activarse, así que llegar al portal antes de tiempo no
	# disparaba nada: ni se usaba (correcto) ni avisaba de lo que faltaba (que
	# era el problema). Dormido no sirve para viajar, pero sí para explicarse.
	monitoring = true

	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = radio
	cilindro.height = 4.0
	forma.shape = cilindro
	forma.position.y = 2.0
	add_child(forma)

	_montar_aro()
	_montar_zona_de_aviso()
	set_process(true)


## Cuánto antes de llegar se cuenta lo que falta.
##
## El aro de uso mide un par de metros: hay que pisarlo justo para que salte, y
## a esa distancia ya se está encima. El aviso tiene que llegar mientras se
## camina hacia él, que es cuando se está preguntando qué es eso.
@export var radio_aviso: float = 9.0


func _montar_zona_de_aviso() -> void:
	var zona := Area3D.new()
	zona.name = "ZonaAviso"
	zona.collision_layer = 0
	zona.collision_mask = 2
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = radio_aviso
	forma.shape = esfera
	zona.add_child(forma)
	zona.body_entered.connect(func(cuerpo: Node3D) -> void:
		if _activo or not cuerpo.is_in_group("player"):
			return
		if not _presentado:
			_presentar(cuerpo)
		else:
			_recitar_lo_que_falta())
	add_child(zona)


## Si ya se ha hecho la presentación. Solo la primera vez.
var _presentado: bool = false


## LA PRIMERA VEZ QUE SE LLEGA, EL PORTAL SE PRESENTA.
##
## Un cartel con una lista de recados no basta para lo que esto es. La primera
## vez la cámara sube a mirarlo, se para un momento sobre él, y entonces sí se
## dice lo que falta. Ese par de segundos son lo que convierte la ruina en un
## objetivo: hasta que no se mira, es piedra decorativa.
##
## Y se hace UNA vez. Repetirla cada vez que se pasa por delante sería de las
## cosas que más cansan de un juego.
func _presentar(jugador: Node3D) -> void:
	_presentado = true
	var camara := get_viewport().get_camera_3d()
	if camara == null:
		_recitar_lo_que_falta()
		return

	# Se quita el control mientras dura: si se puede andar, se anda, y la escena
	# se la pierde quien más falta le hace verla.
	if jugador.has_method("set_control_enabled"):
		jugador.call("set_control_enabled", false)

	var camara_escena := Camera3D.new()
	camara_escena.fov = camara.fov
	camara_escena.far = camara.far
	add_child(camara_escena)
	camara_escena.global_transform = camara.global_transform
	camara_escena.make_current()

	# De donde está la cámara a un plano bajo mirando hacia arriba: el ángulo
	# contrapicado es lo que hace que algo se lea como importante.
	var cerca := global_position + Vector3.UP * 1.2 \
		+ (jugador.global_position - global_position).normalized() * 5.0
	var mirar := global_position + Vector3.UP * 2.6

	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		camara_escena.global_position = camara.global_position.lerp(cerca, v)
		camara_escena.look_at(mirar, Vector3.UP),
		0.0, 1.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	await get_tree().create_timer(1.1).timeout

	camara.make_current()
	camara_escena.queue_free()
	if jugador.has_method("set_control_enabled"):
		jugador.call("set_control_enabled", true)
	_recitar_lo_que_falta()


func _process(delta: float) -> void:
	_tiempo += delta
	if _aro == null:
		return
	# Solo late el cristal. La piedra no se mueve: es una ruina, no una noria.
	if _aro != null:
		var latido := 1.0 + sin(_tiempo * (3.0 if _activo else 1.1)) * (0.08 if _activo else 0.03)
		_aro.scale = Vector3.ONE * latido
	if _activo and _luz != null:
		_luz.light_energy = 3.0 + sin(_tiempo * 3.2) * 0.9


## Lo llama el nivel cuando la lista de objetivos está completa.
func activar() -> void:
	if _activo:
		return
	_activo = true
	monitoring = true
	if _material != null:
		var t := create_tween().set_parallel(true)
		t.tween_property(_material, "albedo_color", color_activo, 0.8)
		t.tween_property(_material, "emission", color_activo, 0.8)
		t.tween_property(_material, "emission_energy_multiplier", 4.0, 0.8)
	if _luz != null:
		_luz.light_color = color_activo
		create_tween().tween_property(_luz, "light_energy", 3.0, 0.8)
	if not aviso.is_empty():
		EventBus.show_message.emit(aviso, 4.0)


func _al_entrar(cuerpo: Node3D) -> void:
	if not cuerpo.is_in_group("player"):
		return
	# Dormido NO se calla: dice qué falta.
	#
	# Llegar al portal antes de tiempo y que no pase nada deja a la jugadora
	# mirando una piedra sin saber si está rota, si es decorado o si hace algo.
	# Enseñarle aquí mismo la lista de lo que queda convierte ese viaje en el
	# momento en que se entera de a qué está jugando — y este es el sitio donde
	# más ganas tiene de saberlo.
	if not _activo:
		_recitar_lo_que_falta()
		return
	monitoring = false
	usado.emit(destino)


## Cuánto se espera antes de volver a recitar la lista.
const REPETIR_LISTA := 8.0

var _proxima_lista: float = 0.0


func _recitar_lo_que_falta() -> void:
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora < _proxima_lista:
		return
	_proxima_lista = ahora + REPETIR_LISTA

	var objetivos := get_tree().get_first_node_in_group("objetivos") as ObjetivosNivel
	if objetivos == null:
		EventBus.show_message.emit("La puerta sigue dormida…", 2.5)
		return

	# Solo lo que falta, y de una en una cosa. La lista entera con lo hecho
	# tachado se lee como deberes; lo que queda por hacer se lee como un plan.
	var pendientes: Array[String] = []
	for ficha: Dictionary in objetivos.resumen():
		if not ficha["hecho"]:
			var cuantos: int = ficha["cuantos"]
			var meta: int = ficha["meta"]
			if meta > 1:
				pendientes.append("%s (%d de %d)" % [ficha["texto"], cuantos, meta])
			else:
				pendientes.append(str(ficha["texto"]))

	if pendientes.is_empty():
		EventBus.show_message.emit("La puerta sigue dormida…", 2.5)
		return
	EventBus.show_message.emit(
		"Para despertar la puerta falta:\n· %s" % "\n· ".join(pendientes), 4.5)


## Monta la ruina y se queda con el material del cristal, que es lo único que
## se enciende. El resto de la piedra no cambia: una ruina que se ilumina entera
## parece un juguete, y lo que tiene que despertar es lo que hay dentro.
func _montar_aro() -> void:
	var pieza: Node3D = MODELO.instantiate()
	pieza.name = "Ruina"
	add_child(pieza)

	# El cristal es la malla más pequeña y más alta de las tres; buscarla por
	# tamaño evita depender del orden en que el exportador las dejó.
	var mejor: MeshInstance3D = null
	var mejor_alto := -1.0
	for nodo in pieza.find_children("*", "MeshInstance3D", true, false):
		var malla := nodo as MeshInstance3D
		var caja := malla.get_aabb()
		var alto := caja.position.y + caja.size.y
		if caja.size.length() < 3.0 and alto > mejor_alto:
			mejor = malla
			mejor_alto = alto
	if mejor != null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = color_dormido
		_material.emission_enabled = true
		_material.emission = color_dormido
		_material.emission_energy_multiplier = 0.6
		mejor.material_override = _material
		_aro = mejor

	_luz = OmniLight3D.new()
	_luz.light_color = color_dormido
	_luz.light_energy = 0.4
	_luz.omni_range = 8.0
	_luz.shadow_enabled = false
	_luz.position.y = 2.3
	add_child(_luz)
