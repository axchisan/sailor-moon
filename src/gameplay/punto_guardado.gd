extends Area3D
class_name PuntoGuardado
## Una fuente de luz donde se guarda la partida, se cura y se reaparece.
##
## ## Por qué hace falta uno visible
##
## El punto de reaparición lo ponía cada arena al empezar, en silencio. Funciona,
## pero **no se puede usar a propósito**: no se sabe dónde está, no se sabe
## cuándo se ha guardado, y no hay forma de decir «voy a dejarlo aquí».
##
## Con un sitio que se ve, se toca y responde, esas tres cosas se resuelven a la
## vez. Y aparece en el sitio donde más falta hace: **antes de cada arena**, para
## que perder una pelea nunca cueste volver a cruzar medio parque.
##
## ## Cura del todo, y sin límite de usos
##
## Nada de racionar. A los ocho años, un sitio de curación que se gasta obliga a
## calcular cuándo usarlo, y calcular es exactamente lo que no se quiere pedir
## aquí. Curar siempre convierte este sitio en un refugio, que es lo que tiene
## que ser.

signal usado

@export var id: String = ""
@export var radio: float = 2.6
@export var color_apagado: Color = Color(0.55, 0.62, 0.85)
@export var color_activo: Color = Color(1.0, 0.72, 0.92)

var descubierto: bool = false

var _cristal: MeshInstance3D = null
var _material: StandardMaterial3D = null
var _luz: OmniLight3D = null
var _t: float = 0.0
var _proximo: float = 0.0


func _ready() -> void:
	add_to_group("guardados")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_al_entrar)

	var forma := CollisionShape3D.new()
	var cil := CylinderShape3D.new()
	cil.radius = radio
	cil.height = 4.0
	forma.shape = cil
	forma.position.y = 2.0
	add_child(forma)

	_construir()
	set_process(true)


func _construir() -> void:
	var piedra := StandardMaterial3D.new()
	piedra.albedo_color = Color(0.72, 0.70, 0.78)

	# Un pedestal bajo y un cristal encima. La silueta tiene que leerse de lejos
	# y distinta de todo lo demás del parque: no es un farol ni una estatua.
	var base := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.42
	cil.bottom_radius = 0.62
	cil.height = 0.75
	cil.radial_segments = 10
	base.mesh = cil
	base.material_override = piedra
	base.position.y = 0.37
	add_child(base)

	_material = StandardMaterial3D.new()
	_material.albedo_color = color_apagado
	_material.emission_enabled = true
	_material.emission = color_apagado
	_material.emission_energy_multiplier = 1.2
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_cristal = MeshInstance3D.new()
	var prisma := PrismMesh.new()
	prisma.size = Vector3(0.42, 0.85, 0.42)
	_cristal.mesh = prisma
	_cristal.material_override = _material
	_cristal.position.y = 1.25
	_cristal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cristal)

	_luz = OmniLight3D.new()
	_luz.light_color = color_apagado
	_luz.light_energy = 1.4
	_luz.omni_range = 7.0
	_luz.shadow_enabled = false
	_luz.position.y = 1.4
	add_child(_luz)


func _process(delta: float) -> void:
	_t += delta
	if _cristal != null:
		_cristal.rotation.y += delta * 0.8
		_cristal.position.y = 1.25 + sin(_t * 1.5) * 0.07
	if _luz != null:
		_luz.light_energy = (2.4 if descubierto else 1.4) \
			+ sin(_t * 2.0) * 0.35


func _al_entrar(cuerpo: Node3D) -> void:
	if not cuerpo.is_in_group("player"):
		return
	# Con enfriamiento: quedarse encima o entrar y salir no puede soltar el
	# mismo cartel cinco veces.
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora < _proximo:
		return
	_proximo = ahora + 8.0

	var curaba := GameManager.health < GameManager.MAX_HEALTH
	GameManager.reset_health()
	GameManager.set_checkpoint(global_position)
	PartidasGuardadas.guardar()

	if not descubierto:
		descubierto = true
		_material.albedo_color = color_activo
		_material.emission = color_activo
		_luz.light_color = color_activo
		var t := create_tween()
		t.tween_property(_cristal, "scale", Vector3(1.25, 1.25, 1.25), 0.25)
		t.tween_property(_cristal, "scale", Vector3.ONE, 0.35)

	AudioManager.play_sfx(preload("res://assets/audio/sfx/mundo/farol.wav"),
		-10.0, 0.05)
	CombatFeel.spawn_impact_particles(global_position + Vector3.UP * 1.4, color_activo, 12)
	# Se dice lo que ha pasado, y en este orden: curar es lo que se nota ahora y
	# guardar es lo que tranquiliza. Si no había nada que curar, se calla esa
	# parte en vez de mentir.
	if curaba:
		EventBus.show_message.emit("Descansas aquí · partida guardada", 2.8)
	else:
		EventBus.show_message.emit("Partida guardada", 2.2)
	usado.emit()
