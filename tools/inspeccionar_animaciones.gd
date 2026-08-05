extends SceneTree
## Inspecciona la estructura de los FBX de animación y del modelo rigueado.
## Uso: godot --headless --path . --script tools/inspeccionar_animaciones.gd

func _init() -> void:
	print("=== MODELO RIGUEADO ===")
	_describir("res://assets/models/characters/serena_rigged.glb")

	print("\n=== ANIMACIONES (muestra) ===")
	for f in ["idle", "walk", "attack_1", "special"]:
		_describir("res://assets/animations/serena/%s.fbx" % f)

	quit()


func _describir(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		print("  NO SE PUDO CARGAR: ", path)
		return
	var root := packed.instantiate()
	print("\n--- ", path.get_file(), " ---")
	_arbol(root, 0)

	var ap := _buscar(root, "AnimationPlayer") as AnimationPlayer
	if ap != null:
		for nombre in ap.get_animation_list():
			var anim := ap.get_animation(nombre)
			print("    animacion: '%s'  dur=%.2fs  pistas=%d  loop=%d" % [
				nombre, anim.length, anim.get_track_count(), anim.loop_mode])
			for i in mini(3, anim.get_track_count()):
				print("       pista[%d]: %s" % [i, anim.track_get_path(i)])

	var sk := _buscar(root, "Skeleton3D") as Skeleton3D
	if sk != null:
		print("    esqueleto: %d huesos, primeros: %s" % [
			sk.get_bone_count(),
			[sk.get_bone_name(0), sk.get_bone_name(1)] if sk.get_bone_count() > 1 else []])
		var pelo := []
		for i in sk.get_bone_count():
			if sk.get_bone_name(i).begins_with("Hair_"):
				pelo.append(sk.get_bone_name(i))
		if not pelo.is_empty():
			print("    huesos de pelo: ", pelo)

	root.free()


func _arbol(n: Node, nivel: int) -> void:
	print("  ".repeat(nivel + 1), n.name, " (", n.get_class(), ")")
	if nivel < 2:
		for c in n.get_children():
			_arbol(c, nivel + 1)


func _buscar(n: Node, clase: String) -> Node:
	if n.get_class() == clase:
		return n
	for c in n.get_children():
		var r := _buscar(c, clase)
		if r != null:
			return r
	return null
