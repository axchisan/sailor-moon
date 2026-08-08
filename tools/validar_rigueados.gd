@tool
extends SceneTree
## Comprueba que los FBX rigueados en Mixamo sirven para el juego.
##
## Se ejecuta con:
##   Godot --headless --path . --script tools/validar_rigueados.gd
##
## Verifica lo que de verdad rompe el montaje de un personaje:
##   · que exista el esqueleto `mixamorig_*` que espera la AnimationLibrary.
##     OJO: Mixamo los nombra `mixamorig:Hips` con DOS PUNTOS, pero Godot los
##     renombra a `mixamorig_Hips` al importar. Buscar por el nombre de Mixamo
##     no encuentra nada y parece que el modelo no está rigueado.
##   · que estén los huesos del NÚCLEO humanoide, que son los que mueven las
##     animaciones. Los dedos NO están en la lista a propósito: Mixamo deja
##     elegir cuántas falanges genera y Godot ignora sin quejarse las pistas
##     de un hueso que no existe. Un personaje sin dedos anima igual de bien.
##   · que `Hips` no venga con 90° de más, que es el síntoma de haberlo bajado
##     de Mixamo en glTF en vez de en FBX: el personaje aparece tumbado

const CARPETA := "res://assets/models/characters/"

## Lo mínimo para que la AnimationLibrary compartida funcione.
const NUCLEO: PackedStringArray = [
	"mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2",
	"mixamorig_Neck", "mixamorig_Head",
	"mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand",
	"mixamorig_RightShoulder", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
	"mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot", "mixamorig_LeftToeBase",
	"mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot", "mixamorig_RightToeBase",
]


func _init() -> void:
	var dir := DirAccess.open(CARPETA)
	var archivos: PackedStringArray = []
	for f in dir.get_files():
		if f.ends_with("_rigged.fbx"):
			archivos.append(f)
	archivos.sort()

	print("Núcleo humanoide exigido: %d huesos\n" % NUCLEO.size())
	for archivo in archivos:
		_revisar(archivo)
	print("\n(dedos = falanges que generó Mixamo; pelo = huesos añadidos a mano)")
	quit()


func _revisar(archivo: String) -> void:
	var escena := load(CARPETA + archivo) as PackedScene
	if escena == null:
		print("%-28s ✗ no se pudo cargar" % archivo)
		return
	var raiz := escena.instantiate()
	var esqueleto := _buscar_esqueleto(raiz)
	if esqueleto == null:
		print("%-28s ✗ SIN ESQUELETO — no se rigueó" % archivo)
		raiz.free()
		return

	var huesos := _nombres(esqueleto)
	var faltan: PackedStringArray = []
	for h in NUCLEO:
		if not huesos.has(h):
			faltan.append(h)

	var dedos := 0
	var pelo := 0
	for h in huesos:
		if h.contains("Hand") and h != "mixamorig_LeftHand" and h != "mixamorig_RightHand":
			dedos += 1
		elif not h.begins_with("mixamorig_"):
			pelo += 1

	# Hips tumbado: el error clásico de exportar desde Mixamo en glTF
	var i_hips := esqueleto.find_bone("mixamorig_Hips")
	var pitch := 0.0
	if i_hips >= 0:
		pitch = rad_to_deg(esqueleto.get_bone_rest(i_hips).basis.get_euler().x)

	var animaciones := 0
	var reproductor := _buscar_animplayer(raiz)
	if reproductor != null:
		animaciones = reproductor.get_animation_list().size()

	var estado := "✓"
	var notas: PackedStringArray = []
	if faltan.size() > 0:
		estado = "✗"
		notas.append("faltan %d huesos (%s…)" % [faltan.size(), faltan[0]])
	if absf(pitch) > 45.0:
		estado = "✗"
		notas.append("Hips girado %.0f° — ¿bajado en glTF?" % pitch)

	print("%-28s %s  %3d huesos (%2d dedos, %d pelo) · %d anim · Hips %+.1f°  %s" % [
		archivo, estado, huesos.size(), dedos, pelo, animaciones, pitch, " | ".join(notas)])
	raiz.free()


func _nombres(esqueleto: Skeleton3D) -> PackedStringArray:
	var r: PackedStringArray = []
	for i in esqueleto.get_bone_count():
		r.append(esqueleto.get_bone_name(i))
	return r


func _buscar_esqueleto(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _buscar_esqueleto(c)
		if r != null:
			return r
	return null


func _buscar_animplayer(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _buscar_animplayer(c)
		if r != null:
			return r
	return null
