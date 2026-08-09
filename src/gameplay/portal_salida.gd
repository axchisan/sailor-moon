extends Area3D
class_name PortalSalida
## La puerta al siguiente escenario. Apagada hasta cumplir todos los objetivos.
##
## Va en el torii de la entrada a propósito: **por donde se entra es por donde
## se sale**, y eso hace que el parque tenga una puerta en vez de un borde. Es
## además el sitio que la jugadora ya conoce, así que cuando se enciende sabe
## adónde volver sin que nadie se lo explique.
##
## Apagado no es invisible: se ve el aro dormido desde el primer minuto. Que se
## vea desde el principio es lo que convierte la lista de objetivos en un
## camino hacia algo, en vez de en una sorpresa al final.

signal usado(destino: String)

@export var destino: String = ""
@export var radio: float = 2.6
@export var color_dormido: Color = Color(0.45, 0.42, 0.58)
@export var color_activo: Color = Color(1.0, 0.72, 0.95)
## Mensaje al encenderse. Vacío = no dice nada.
@export var aviso: String = "¡El camino se ha abierto! Vuelve a la entrada del parque"

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
	_aro.rotate_y(delta * (1.4 if _activo else 0.25))
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


func _montar_aro() -> void:
	_aro = MeshInstance3D.new()
	_aro.name = "Aro"
	var toro := TorusMesh.new()
	toro.inner_radius = radio * 0.72
	toro.outer_radius = radio
	toro.rings = 20
	toro.ring_segments = 8
	_aro.mesh = toro
	# Tumbado: es un charco de luz en el suelo por el que se pasa, no una puerta
	# vertical que tape la vista del parque durante toda la partida.
	_aro.rotation.x = 0.0
	_aro.position.y = 0.25

	_material = StandardMaterial3D.new()
	_material.albedo_color = color_dormido
	_material.emission_enabled = true
	_material.emission = color_dormido
	_material.emission_energy_multiplier = 0.7
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aro.material_override = _material
	_aro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aro)

	_luz = OmniLight3D.new()
	_luz.light_color = color_dormido
	_luz.light_energy = 0.5
	_luz.omni_range = 7.0
	_luz.shadow_enabled = false
	_luz.position.y = 1.2
	add_child(_luz)
