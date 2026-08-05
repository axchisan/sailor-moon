@tool
extends SkeletonModifier3D
class_name SpringBoneChain
## Física de muelle para cadenas de huesos: coletas, faldas, colas, lazos.
##
## POR QUÉ EXISTE: Mixamo riguea solo el esqueleto humanoide. El pelo de Serena
## queda pegado al hueso `Head` y se mueve como un bloque rígido, que con unas
## coletas que llegan a las rodillas se ve fatal.
##
## Este nodo coge una cadena de huesos (`Hair_L_1` … `Hair_L_5`) y la mueve con
## inercia, elasticidad y gravedad. Las animaciones de Mixamo NO tocan estos
## huesos, así que no hay conflicto: la animación mueve el cuerpo y el pelo
## reacciona.
##
## Es el algoritmo estándar de VRM SpringBone, simplificado. Con 10 huesos el
## coste es despreciable incluso en móvil.
##
## USO: hijo del Skeleton3D, uno por coleta.
##      root_bone = "Hair_L_1", chain_length = 5

## Primer hueso de la cadena. Los siguientes se toman como hijos suyos.
@export var root_bone: String = "":
	set(value):
		root_bone = value
		_dirty = true

## Cuántos huesos de la cadena, contando el primero.
@export_range(1, 12) var chain_length: int = 5:
	set(value):
		chain_length = value
		_dirty = true

@export_group("Física")
## Fuerza con la que vuelve a su posición de reposo. Más alto = más rígido.
@export_range(0.0, 4.0) var stiffness: float = 1.4
## Rozamiento. Más alto = se para antes. Bajo = se columpia mucho tiempo.
@export_range(0.0, 1.0) var drag: float = 0.45
## Cuánto pesa el pelo. 0 = flota, alto = cae a plomo.
@export_range(0.0, 4.0) var gravity_power: float = 0.9
@export var gravity_dir: Vector3 = Vector3.DOWN
## Límite de separación respecto al reposo. Evita que se doble del revés.
@export_range(0.0, 180.0) var max_angle: float = 75.0

@export_group("Depuración")
@export var enabled: bool = true

var _bones: PackedInt32Array = []
var _lengths: PackedFloat32Array = []
## Eje del hueso en el espacio de su padre, en reposo.
var _axes: Array[Vector3] = []
## Posición mundial de la punta de cada hueso, del frame anterior.
var _prev_tails: Array[Vector3] = []
var _tails: Array[Vector3] = []
var _dirty: bool = true
var _initialised: bool = false
## Separación en grados de cada hueso respecto a su reposo. Solo para depurar.
var debug_angles: PackedFloat32Array = []


func _ready() -> void:
	_dirty = true


func _process_modification() -> void:
	if not enabled or Engine.is_editor_hint():
		return

	var skeleton := get_skeleton()
	if skeleton == null:
		return

	if _dirty:
		_build(skeleton)

	if not _initialised or _bones.is_empty():
		return

	var delta := get_physics_process_delta_time()
	if delta <= 0.0:
		return
	# Con hit stop el delta se hace minúsculo; limitarlo evita que la
	# simulación explote al volver a la velocidad normal.
	delta = clampf(delta, 0.0, 1.0 / 30.0)

	_simulate(skeleton, delta)


func _build(skeleton: Skeleton3D) -> void:
	_bones.clear()
	_lengths.clear()
	_axes.clear()
	_prev_tails.clear()
	_tails.clear()
	_initialised = false
	_dirty = false

	if root_bone.is_empty():
		return
	var idx := skeleton.find_bone(root_bone)
	if idx < 0:
		push_warning("SpringBoneChain: no existe el hueso '%s'" % root_bone)
		return

	# Recorre la cadena siguiendo el primer hijo de cada hueso
	while idx >= 0 and _bones.size() < chain_length:
		_bones.append(idx)
		var children := skeleton.get_bone_children(idx)
		idx = children[0] if children.size() > 0 else -1

	# Eje y longitud en reposo de cada hueso
	for i in _bones.size():
		var rest_next: Vector3
		if i + 1 < _bones.size():
			rest_next = skeleton.get_bone_rest(_bones[i + 1]).origin
		else:
			# El último no tiene hijo: se le da una punta virtual siguiendo
			# la dirección del anterior, para que también se mueva.
			var previous_length: float = _lengths[i - 1] if i > 0 else 0.1
			rest_next = Vector3(0, previous_length, 0)
		var length := maxf(rest_next.length(), 0.0001)
		_lengths.append(length)
		_axes.append(rest_next / length)

	# Estado inicial: las puntas donde las pone la pose actual
	debug_angles.resize(_bones.size())
	for i in _bones.size():
		var tail := _world_tail(skeleton, i)
		_tails.append(tail)
		_prev_tails.append(tail)

	_initialised = _bones.size() > 0


## Posición mundial de la punta del hueso i, según la pose actual.
func _world_tail(skeleton: Skeleton3D, i: int) -> Vector3:
	var pose := skeleton.global_transform * skeleton.get_bone_global_pose(_bones[i])
	return pose * (_axes[i] * _lengths[i])


func _simulate(skeleton: Skeleton3D, delta: float) -> void:
	var skeleton_xform := skeleton.global_transform

	for i in _bones.size():
		var bone := _bones[i]
		var parent := skeleton.get_bone_parent(bone)

		# La pose del padre YA incluye la animación y los huesos de la cadena
		# resueltos antes que este, porque vamos de la raíz a la punta.
		var parent_world: Transform3D = skeleton_xform
		if parent >= 0:
			parent_world = skeleton_xform * skeleton.get_bone_global_pose(parent)

		var head: Vector3 = (skeleton_xform * skeleton.get_bone_global_pose(bone)).origin
		var rest_dir: Vector3 = (parent_world.basis * (skeleton.get_bone_rest(bone).basis * _axes[i])).normalized()

		# --- Integración ---
		var inertia: Vector3 = (_tails[i] - _prev_tails[i]) * (1.0 - drag)
		var elastic: Vector3 = rest_dir * stiffness * delta
		var weight: Vector3 = gravity_dir.normalized() * gravity_power * delta

		var next_tail: Vector3 = _tails[i] + inertia + elastic + weight

		# El hueso no se estira: la punta siempre a la misma distancia
		var dir: Vector3 = next_tail - head
		if dir.length_squared() < 0.000001:
			dir = rest_dir
		dir = dir.normalized()

		# Tope angular para que no se doble del revés
		var limit := deg_to_rad(max_angle)
		if rest_dir.angle_to(dir) > limit:
			var axis := rest_dir.cross(dir)
			if axis.length_squared() > 0.000001:
				dir = rest_dir.rotated(axis.normalized(), limit)

		next_tail = head + dir * _lengths[i]

		_prev_tails[i] = _tails[i]
		_tails[i] = next_tail

		# --- Convertir la dirección resultante en rotación local del hueso ---
		var target_local: Vector3 = (parent_world.basis.inverse() * dir).normalized()
		var rest_local: Vector3 = (skeleton.get_bone_rest(bone).basis * _axes[i]).normalized()
		# `swing` está expresado en el espacio del PADRE, así que se aplica
		# DESPUÉS de la rotación de reposo: swing * rest, no rest * swing.
		# Con el orden invertido el giro se interpreta en el espacio del propio
		# hueso y el resultado sale casi constante.
		var swing := _from_to(rest_local, target_local)
		var rest_quat := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(bone, swing * rest_quat)

		debug_angles[i] = rad_to_deg(rest_dir.angle_to(dir))


## Rotación mínima que lleva el vector `from` sobre `to`.
static func _from_to(from: Vector3, to: Vector3) -> Quaternion:
	var dot := clampf(from.dot(to), -1.0, 1.0)
	if dot > 0.99999:
		return Quaternion.IDENTITY
	if dot < -0.99999:
		# Opuestos: cualquier eje perpendicular sirve
		var axis := from.cross(Vector3.UP)
		if axis.length_squared() < 0.000001:
			axis = from.cross(Vector3.RIGHT)
		return Quaternion(axis.normalized(), PI)
	return Quaternion(from.cross(to).normalized(), acos(dot))


## Devuelve la cadena a su posición de reposo. Útil al teletransportar al
## personaje: sin esto, el pelo sale disparado por la inercia del salto.
func reset_chain() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or not _initialised:
		return
	for i in _bones.size():
		skeleton.set_bone_pose_rotation(_bones[i], skeleton.get_bone_rest(_bones[i]).basis.get_rotation_quaternion())
	for i in _bones.size():
		var tail := _world_tail(skeleton, i)
		_tails[i] = tail
		_prev_tails[i] = tail
