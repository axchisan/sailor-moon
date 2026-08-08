extends Node3D
class_name Companero
## Un gato que acompaña a alguien: Luna con Serena, Artemis con Venus.
##
## No es un personaje jugable ni un enemigo. Su trabajo es **estar ahí**: que
## el mundo no parezca vacío y que, cuando toque hablar, ya haya alguien a
## quien mirar. Nada de él afecta al combate.
##
## ## Cómo sigue
##
## No va pegado detrás, que es lo que hacen los seguidores mal hechos y acaba
## dando empujones y metiéndose en la cámara. Se queda **a un lado y algo
## atrás**, y solo se mueve cuando se ha quedado demasiado lejos. Si estás
## quieta, él también.
##
## ## Sin modelo
##
## Funciona sin `modelo` asignado: coloca una cápsula gris. Así el
## comportamiento se prueba y se ajusta antes de tener el 3D, y cuando llega el
## modelo solo hay que arrastrarlo a la ficha.

@export var id: String = "luna"
## El `.glb` o `.fbx` del gato. Vacío = cápsula de sustitución.
@export var modelo: PackedScene
## A quién sigue. Vacío = a la jugadora.
@export var sigue_a: NodePath

@export_group("Movimiento")
## Distancia a la que se planta. Menos de esto, se queda quieto.
@export var distancia_comoda: float = 2.4
## Si se queda más lejos que esto, corre.
@export var distancia_carrera: float = 6.0
@export var velocidad: float = 3.2
@export var velocidad_carrera: float = 6.0
@export var giro: float = 8.0
## A qué lado se coloca: −1 izquierda, +1 derecha.
@export_range(-1.0, 1.0) var lado: float = -1.0

@export_group("Vida")
## Balanceo al andar y respiración al parar. Un gato inmóvil parece de piedra.
@export var animar: bool = true
@export var altura_salto: float = 0.10

var _objetivo: Node3D = null
var _visual: Node3D = null
var _tiempo: float = 0.0
var _andando: bool = false
var _base_y: float = 0.0


func _ready() -> void:
	_montar_visual()
	_base_y = position.y


func _physics_process(delta: float) -> void:
	var objetivo := _buscar_objetivo()
	if objetivo == null:
		return

	# El sitio al que quiere ir: al lado del acompañado, no encima.
	var frente := -objetivo.global_transform.basis.z
	frente.y = 0.0
	if frente.length_squared() < 0.001:
		frente = Vector3.FORWARD
	frente = frente.normalized()
	var costado := frente.cross(Vector3.UP).normalized()
	var destino := objetivo.global_position + costado * lado * 0.9 - frente * 1.1

	var hacia := destino - global_position
	hacia.y = 0.0
	var distancia := hacia.length()

	_andando = distancia > distancia_comoda
	if _andando:
		var rapido: float = velocidad_carrera if distancia > distancia_carrera else velocidad
		# Cerca del destino afloja, para no quedarse temblando encima del punto.
		var freno: float = clampf((distancia - distancia_comoda * 0.5) / 1.5, 0.0, 1.0)
		global_position += hacia.normalized() * rapido * freno * delta
		var mirando := atan2(-hacia.x, -hacia.z)
		rotation.y = lerp_angle(rotation.y, mirando, minf(delta * giro, 1.0))

	if animar:
		_animar(delta)


## Trotecillo al andar y respiración al pararse. Es todo lo que necesita un
## gato de fondo: una animación de verdad para esto no compensa.
func _animar(delta: float) -> void:
	if _visual == null:
		return
	_tiempo += delta
	if _andando:
		_visual.position.y = absf(sin(_tiempo * 9.0)) * altura_salto
		_visual.rotation.z = sin(_tiempo * 9.0) * 0.06
	else:
		_visual.position.y = lerpf(_visual.position.y,
			sin(_tiempo * 1.8) * 0.02, minf(delta * 6.0, 1.0))
		_visual.rotation.z = lerpf(_visual.rotation.z, 0.0, minf(delta * 6.0, 1.0))


func _montar_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	if modelo != null:
		var toon := Node3D.new()
		toon.name = "ToonRoot"
		toon.set_script(load("res://src/core/toon_root.gd"))
		# Igual que los personajes: los modelos importados miran a +Z.
		toon.rotation.y = PI
		toon.add_child(modelo.instantiate())
		_visual.add_child(toon)
		return

	# Sustituto mientras no hay modelo: una cápsula del tamaño de un gato.
	var malla := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.14
	capsula.height = 0.46
	malla.mesh = capsula
	malla.rotation.x = PI * 0.5
	malla.position.y = 0.16
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.20, 0.26) if id == "luna" \
		else Color(0.92, 0.92, 0.95)
	malla.material_override = material
	_visual.add_child(malla)


func _buscar_objetivo() -> Node3D:
	if _objetivo != null and is_instance_valid(_objetivo):
		return _objetivo
	if not sigue_a.is_empty():
		_objetivo = get_node_or_null(sigue_a) as Node3D
	if _objetivo == null:
		_objetivo = get_tree().get_first_node_in_group("player") as Node3D
	return _objetivo


## Lo llama el nivel al teletransportar: si no, el gato cruza el mapa andando.
func teletransportar_junto_al_objetivo() -> void:
	var objetivo := _buscar_objetivo()
	if objetivo != null:
		global_position = objetivo.global_position
