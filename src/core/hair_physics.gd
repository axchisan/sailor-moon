extends Node3D
class_name HairPhysics
## Monta la física de pelo sobre un modelo importado, en tiempo de ejecución.
##
## Se pone en el nodo padre del `.glb` de Serena. Busca el `Skeleton3D` y le
## cuelga una `SpringBoneChain` por cada coleta.
##
## Se hace por código y no en el `.tscn` porque las escenas instanciadas de un
## `.glb` no dejan añadirles hijos sin marcarlas como editables, y eso se rompe
## cada vez que se reimporta el modelo.

## Primer hueso de cada cadena.
@export var chain_roots: Array[String] = ["Hair_L_1", "Hair_R_1"]
@export_range(1, 12) var chain_length: int = 5

@export_group("Física")
@export_range(0.0, 4.0) var stiffness: float = 1.4
@export_range(0.0, 1.0) var drag: float = 0.45
@export_range(0.0, 4.0) var gravity_power: float = 0.9
@export_range(0.0, 180.0) var max_angle: float = 75.0

var _chains: Array[SpringBoneChain] = []
var _skeleton: Skeleton3D = null


func _ready() -> void:
	_skeleton = _find_skeleton(self)
	if _skeleton == null:
		push_warning("HairPhysics: no se encontró ningún Skeleton3D bajo %s" % name)
		return

	for root in chain_roots:
		if _skeleton.find_bone(root) < 0:
			push_warning("HairPhysics: el esqueleto no tiene el hueso '%s'" % root)
			continue
		var chain := SpringBoneChain.new()
		chain.name = "Spring_" + root
		chain.root_bone = root
		chain.chain_length = chain_length
		chain.stiffness = stiffness
		chain.drag = drag
		chain.gravity_power = gravity_power
		chain.max_angle = max_angle
		_skeleton.add_child(chain)
		_chains.append(chain)


## Devuelve la melena a su sitio. Llamar al teletransportar o al reaparecer:
## si no, el pelo sale disparado por la inercia del salto anterior.
func reset() -> void:
	for chain in _chains:
		chain.reset_chain()


func set_enabled(value: bool) -> void:
	for chain in _chains:
		chain.enabled = value


func get_skeleton() -> Skeleton3D:
	return _skeleton


static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
