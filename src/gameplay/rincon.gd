extends Area3D
class_name Rincon
## Un sitio apartado del parque que cuenta como visitado al llegar.
##
## Son los que dan razón de ser al campo abierto. Sin ellos, todo lo que hay
## fuera del camino es decorado: bonito, pero no hay motivo para pisarlo.
##
## Se marcan con algo **que se vea de lejos** —una luz alta— porque un sitio al
## que hay que ir sin saber que existe no es exploración, es adivinanza. La
## gracia está en llegar, no en enterarse.

signal visitado(id: String)

@export var id: String = ""
@export var radio: float = 4.0
## Color de la baliza. Apagada cuando ya se ha visitado.
@export var color: Color = Color(1.0, 0.86, 0.45)
@export var alto_baliza: float = 5.0

var _visitado: bool = false
var _baliza: Node3D = null
var _luz: OmniLight3D = null
var _tiempo: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # solo la jugadora
	body_entered.connect(_al_entrar)

	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = radio
	forma.shape = esfera
	add_child(forma)

	_montar_baliza()
	set_process(true)


func _process(delta: float) -> void:
	if _baliza == null:
		return
	_tiempo += delta
	if _visitado:
		return
	# Sube y baja despacio. Un punto de luz quieto se confunde con decoración;
	# moviéndose se lee como «aquí hay algo».
	_baliza.position.y = alto_baliza + sin(_tiempo * 1.6) * 0.35
	if _luz != null:
		_luz.light_energy = 2.2 + sin(_tiempo * 2.4) * 0.6


func _al_entrar(cuerpo: Node3D) -> void:
	if _visitado or not cuerpo.is_in_group("player"):
		return
	_visitado = true
	visitado.emit(id)
	_apagar()


## Al visitarlo, la baliza baja y se apaga. Es lo que distingue de un vistazo lo
## que falta de lo que ya está: sin apagarse, a la cuarta vuelta no se sabe cuál
## queda por ver.
func _apagar() -> void:
	if _baliza == null:
		return
	var t := create_tween().set_parallel(true)
	t.tween_property(_baliza, "position:y", 0.6, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_baliza, "scale", Vector3.ONE * 0.4, 0.5)
	if _luz != null:
		t.tween_property(_luz, "light_energy", 0.0, 0.4)


func _montar_baliza() -> void:
	_baliza = Node3D.new()
	_baliza.name = "Baliza"
	_baliza.position.y = alto_baliza

	var malla := MeshInstance3D.new()
	var forma := SphereMesh.new()
	forma.radius = 0.42
	forma.height = 0.84
	forma.radial_segments = 12
	forma.rings = 6
	malla.mesh = forma

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	malla.material_override = material
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_baliza.add_child(malla)

	_luz = OmniLight3D.new()
	_luz.light_color = color
	_luz.light_energy = 2.2
	_luz.omni_range = 9.0
	# Sin sombras: son cuatro luces sueltas por el mapa y las sombras que
	# proyectarían no aportan nada al presupuesto móvil.
	_luz.shadow_enabled = false
	_baliza.add_child(_luz)

	add_child(_baliza)
