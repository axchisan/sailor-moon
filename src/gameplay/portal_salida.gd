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
	monitoring = false

	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = radio
	cilindro.height = 4.0
	forma.shape = cilindro
	forma.position.y = 2.0
	add_child(forma)

	_montar_aro()
	set_process(true)


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
	if not _activo or not cuerpo.is_in_group("player"):
		return
	monitoring = false
	usado.emit(destino)


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
