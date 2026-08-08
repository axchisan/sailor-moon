@tool
extends EditorScenePostImport
## Corrige los materiales de los personajes al importarlos.
##
## Se engancha desde el `.import` de cada FBX con `import_script/path`.
##
## ## Por qué existe
##
## Los modelos de hi3d.ai traen un canal alpha que no usan para nada: la malla
## es sólida. Blender lo ignora porque el material va en modo opaco, pero Godot
## lee el FBX crudo, ve el canal y activa **alpha scissor** (`transparency = 2`).
##
## El efecto es desagradable y difícil de diagnosticar: el recorte abre agujeros
## en la melena y deja ver el interior de la cáscara, que sale casi negro. Se
## manifiesta como manchones oscuros en el pelo de Venus, Mars y Pluto — las de
## melena larga, porque son las que tienen suficiente pelo superpuesto.
##
## Cuesta encontrarlo porque el modelo se ve perfecto en Blender y porque
## apagar el contorno, las sombras o el cel shading no cambia nada: el fallo ya
## viene en el material importado, antes de que `ToonMaterial` lo toque.

func _post_import(scene: Node) -> Object:
	var arreglados := _opacar(scene, 0)
	if arreglados > 0:
		print("[importar_personaje] %s: %d materiales pasados a opaco" % [
			scene.name, arreglados])
	return scene


func _opacar(nodo: Node, cuenta: int) -> int:
	if nodo is MeshInstance3D:
		var malla: Mesh = nodo.mesh
		if malla != null:
			for i in malla.get_surface_count():
				var material := malla.surface_get_material(i) as StandardMaterial3D
				if material == null:
					continue
				if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					cuenta += 1
	for hijo in nodo.get_children():
		cuenta = _opacar(hijo, cuenta)
	return cuenta
