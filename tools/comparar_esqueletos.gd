extends SceneTree
## Compara la pose de reposo del modelo rigueado con la de las animaciones.
## Si no coinciden, las animaciones deforman mal (personaje tumbado, retorcido…).
##
## Uso: godot --headless --path . --script tools/comparar_esqueletos.gd

const HUESOS := ["mixamorig_Hips", "mixamorig_Spine", "mixamorig_Head",
	"mixamorig_LeftArm", "mixamorig_LeftUpLeg"]


func _init() -> void:
	var modelo := _skeleton_de("res://assets/models/characters/serena_rigged.fbx")
	var animacion := _skeleton_de("res://assets/animations/serena/walk.fbx")

	if modelo == null or animacion == null:
		print("No se pudo cargar alguno de los dos")
		quit()
		return

	print("MODELO   : %d huesos" % modelo.get_bone_count())
	print("ANIMACION: %d huesos" % animacion.get_bone_count())
	print("\ntransform del Skeleton3D:")
	print("  modelo   : ", modelo.transform)
	print("  animacion: ", animacion.transform)
	print("  padre del modelo: ", modelo.get_parent().name, " ",
		(modelo.get_parent() as Node3D).transform if modelo.get_parent() is Node3D else "")

	print("\nposes de reposo:")
	var iguales := true
	for nombre in HUESOS:
		var a := modelo.find_bone(nombre)
		var b := animacion.find_bone(nombre)
		if a < 0 or b < 0:
			print("  %-22s FALTA en alguno" % nombre)
			iguales = false
			continue
		var ra := modelo.get_bone_rest(a)
		var rb := animacion.get_bone_rest(b)
		var d_pos := (ra.origin - rb.origin).length()
		var d_rot := ra.basis.get_rotation_quaternion().angle_to(rb.basis.get_rotation_quaternion())
		var ok := d_pos < 0.001 and d_rot < 0.01
		if not ok:
			iguales = false
		print("  %-22s %s  dpos=%.4f  drot=%.1f grados" % [
			nombre, "OK" if ok else "DISTINTO", d_pos, rad_to_deg(d_rot)])
		if not ok:
			print("      modelo   : %s | %s" % [ra.origin, ra.basis.get_rotation_quaternion()])
			print("      animacion: %s | %s" % [rb.origin, rb.basis.get_rotation_quaternion()])

	print("\nVEREDICTO: ", "esqueletos compatibles" if iguales else "REPOSO DISTINTO -> hace falta retargeting o reexportar")
	quit()


func _skeleton_de(ruta: String) -> Skeleton3D:
	var packed := load(ruta) as PackedScene
	if packed == null:
		return null
	var root := packed.instantiate()
	var sk := _buscar(root)
	return sk


func _buscar(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _buscar(c)
		if r != null:
			return r
	return null
