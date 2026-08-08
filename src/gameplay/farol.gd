extends Area3D
class_name Farol
## Farol de piedra que se enciende al acercarse.
##
## Es el objetivo que **no se resuelve peleando**: en el tramo antes del jefe
## hay tres apagados y hasta que no estén los tres encendidos no se abre el
## paso. Uno está a la vista, otro escondido y el tercero arriba.
##
## Rompe el ritmo de arena-arena-arena, que era el problema del nivel: da un
## respiro entre el último combate y el jefe, y obliga a mirar el escenario en
## vez de a los enemigos.
##
## Se enciende **al acercarse**, no al golpear. Pegarle a un farol para que se
## encienda enseña que todo se resuelve pegando, que es justo lo contrario de
## lo que este trozo del nivel quiere enseñar.

signal encendido(farol: Farol)

@export var id: String = ""
@export var color_llama: Color = Color(1.0, 0.82, 0.42)
## Alcance de la luz cuando está encendido.
@export var alcance: float = 7.0
## Fuerza de la luz. En un parque al atardecer no hace falta más.
@export var potencia: float = 2.2

var esta_encendido: bool = false

var _luz: OmniLight3D = null
var _llama: MeshInstance3D = null
var _materiales: Array[StandardMaterial3D] = []
var _tiempo: float = 0.0


func _ready() -> void:
	add_to_group("faroles")
	body_entered.connect(_al_entrar)
	_preparar_visual()
	set_process(false)


func _process(delta: float) -> void:
	if not esta_encendido:
		return
	_tiempo += delta
	# Parpadeo suave, de dos frecuencias: con una sola se nota el bucle.
	var titileo := 1.0 + sin(_tiempo * 7.0) * 0.06 + sin(_tiempo * 11.3) * 0.04
	if _luz != null:
		_luz.light_energy = potencia * titileo
	if _llama != null:
		_llama.scale = Vector3.ONE * (0.9 + 0.12 * titileo)


func _preparar_visual() -> void:
	# La caja de luz del tōrō es un material propio del modelo. Se busca para
	# poder encenderla sin tocar el resto de la piedra.
	for malla in _buscar_mallas(self):
		if malla.mesh == null:
			continue
		for i in malla.mesh.get_surface_count():
			var original := malla.get_active_material(i) as StandardMaterial3D
			if original == null:
				continue
			# El material se duplica: sin esto, encender un farol enciende los
			# tres, porque comparten el recurso del `.glb`.
			var propio := original.duplicate() as StandardMaterial3D
			malla.set_surface_override_material(i, propio)
			if _es_cristal(propio.albedo_color):
				propio.emission_enabled = true
				propio.emission = color_llama
				propio.emission_energy_multiplier = 0.0
				_materiales.append(propio)

	_luz = OmniLight3D.new()
	_luz.light_color = color_llama
	_luz.light_energy = 0.0
	_luz.omni_range = alcance
	_luz.position.y = 1.35
	add_child(_luz)

	_llama = MeshInstance3D.new()
	var bola := SphereMesh.new()
	bola.radius = 0.09
	bola.height = 0.18
	bola.radial_segments = 8
	bola.rings = 4
	_llama.mesh = bola
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color_llama
	mat.emission_enabled = true
	mat.emission = color_llama
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_llama.material_override = mat
	_llama.position.y = 1.35
	_llama.visible = false
	add_child(_llama)


func _al_entrar(cuerpo: Node3D) -> void:
	if esta_encendido or not cuerpo.is_in_group("player"):
		return
	encender()


func encender() -> void:
	if esta_encendido:
		return
	esta_encendido = true
	set_process(true)
	if _llama != null:
		_llama.visible = true

	# Prende con un golpe de luz y baja: un encendido instantáneo y plano no
	# se nota, y esto es la recompensa de haberlo encontrado.
	var t := create_tween()
	t.tween_method(_ajustar_brillo, 0.0, 1.6, 0.18)
	t.tween_method(_ajustar_brillo, 1.6, 1.0, 0.35)

	CombatFeel.spawn_impact_particles(
		global_position + Vector3.UP * 1.35, color_llama, 14, 0.9)
	encendido.emit(self)


func _ajustar_brillo(factor: float) -> void:
	if _luz != null:
		_luz.light_energy = potencia * factor
	for material in _materiales:
		material.emission_energy_multiplier = 1.6 * factor


## La caja de luz es la pieza clara del farol; la piedra es gris. Se distingue
## por el color en vez de por el nombre del material porque el nombre lo pone
## el exportador y cambia entre versiones.
static func _es_cristal(color: Color) -> bool:
	return color.r > 0.85 and color.g > 0.80 and color.b > 0.55


static func _buscar_mallas(nodo: Node, salida: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	if nodo is MeshInstance3D:
		salida.append(nodo)
	for hijo in nodo.get_children():
		_buscar_mallas(hijo, salida)
	return salida
