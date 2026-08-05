extends SceneTree
## Consolida los FBX de Mixamo en una única AnimationLibrary.
##
## Cada FBX de Mixamo trae su animación con el nombre interno `mixamo_com`.
## Este script las extrae, les pone el nombre que usa el juego, marca cuáles
## son bucles y guarda todo en un solo recurso.
##
## Uso:
##   godot --headless --path . --script tools/construir_libreria_animaciones.gd

const ORIGEN := "res://assets/animations/serena/%s.fbx"
const DESTINO := "res://assets/animations/serena/serena_animaciones.res"

## nombre -> ¿es bucle?
const ANIMACIONES := {
	"idle": true,
	"walk": true,
	"run": true,
	"jump_start": false,
	"jump_loop": true,
	"land": false,
	"attack_1": false,
	"attack_2": false,
	"attack_3": false,
	"special": false,
	"hurt": false,
	"dizzy": true,
	"victory": false,
	"transform_pose": false,
	"talk_idle": true,
}


func _init() -> void:
	var libreria := AnimationLibrary.new()
	var informe: Array[String] = []

	for nombre in ANIMACIONES:
		var ruta: String = ORIGEN % nombre
		var packed := load(ruta) as PackedScene
		if packed == null:
			push_error("No se pudo cargar %s" % ruta)
			continue

		var root := packed.instantiate()
		var reproductor := _buscar_animation_player(root)
		if reproductor == null:
			push_error("%s no tiene AnimationPlayer" % ruta)
			root.free()
			continue

		var anim: Animation = null
		for interna in reproductor.get_animation_list():
			if interna == "RESET":
				continue
			anim = reproductor.get_animation(interna).duplicate(true)
			break

		if anim == null:
			push_error("%s no contiene animaciones" % ruta)
			root.free()
			continue

		anim.loop_mode = Animation.LOOP_LINEAR if ANIMACIONES[nombre] else Animation.LOOP_NONE
		libreria.add_animation(nombre, anim)
		informe.append("  %-16s %6.2f s  %3d pistas  %s" % [
			nombre, anim.length, anim.get_track_count(),
			"bucle" if ANIMACIONES[nombre] else ""])
		root.free()

	var error := ResourceSaver.save(libreria, DESTINO)
	print("=== BIBLIOTECA DE ANIMACIONES ===")
	for linea in informe:
		print(linea)
	print("\nanimaciones: %d" % libreria.get_animation_list().size())
	print("guardada en: %s  (error=%d)" % [DESTINO, error])
	quit()


func _buscar_animation_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _buscar_animation_player(c)
		if r != null:
			return r
	return null
