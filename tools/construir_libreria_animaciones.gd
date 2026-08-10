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
##
## Es bucle lo que tiene que poder durar indefinidamente: estar de pie, andar,
## caer, colgarse de una cornisa, pensar. NO lo son los gestos que empiezan y
## acaban — un golpe, un asentimiento, subir a un saliente. Poner en bucle algo
## que acaba deja al personaje repitiendo el gesto como un tic.
const ANIMACIONES := {
	# Locomoción y aire
	"idle": true,
	"walk": true,
	"run": true,
	"jump_start": false,
	"jump_loop": true,
	"land": false,
	"double_jump": false,
	# Trepar cornisas
	"ledge_grab": true,
	"ledge_climb": false,
	# Combate
	"attack_1": false,
	"attack_2": false,
	"attack_3": false,
	"special": false,
	"hurt": false,
	"dizzy": true,
	"victory": false,
	# Transformación
	"transform_start": false,
	"transform_pose": false,
	# Conversación
	"talk_idle": true,
	"talk_gesture": false,
	"nod": false,
	"shake_head": false,
	"point": false,
	"surprised": false,
	"thinking": true,
}


## Deja todas las pistas apuntando a `Skeleton3D:hueso`, venga como venga el FBX.
##
## ESTO ES LO QUE DEJABA A SERENA EN POSE T
##
## Las animaciones viejas traían sus pistas como `Skeleton3D:mixamorig_Hips`.
## Las nuevas, bajadas meses después, vienen con un nodo de más:
## `Armature/Skeleton3D:mixamorig_Hips`. Mixamo no exporta siempre igual.
##
## El `AnimationPlayer` del jugador cuelga del padre del esqueleto, así que
## busca `Skeleton3D` justo debajo. Con el `Armature/` delante no encuentra
## nada — y una pista que no encuentra su hueso no se queja: simplemente no
## mueve nada. Las 56 pistas fallaban a la vez y el personaje se quedaba en la
## pose de reposo del modelo, que en un rigueado de Mixamo es la T.
##
## Es de la misma familia que la trampa 16 (Godot renombra `mixamorig:Hips` a
## `mixamorig_Hips`): el hueso está, el esqueleto está, y lo que no cuadra es
## **cómo se le llama desde la pista**. Por eso no da ningún error.
##
## Aquí se recorta todo lo que haya antes de `Skeleton3D:` y se acabó el
## problema para cualquier FBX que venga en el futuro.
func _normalizar_rutas(anim: Animation) -> int:
	var cambiadas := 0
	for i in anim.get_track_count():
		var ruta := String(anim.track_get_path(i))
		var corte := ruta.find("Skeleton3D:")
		if corte > 0:
			anim.track_set_path(i, NodePath(ruta.substr(corte)))
			cambiadas += 1
	return cambiadas


## Altura a la que va la cadera con el personaje de pie, en metros.
##
## Sale de medir `idle`, que es la pose de referencia: ahí la cadera se queda
## entre 0,90 y 0,92 sin moverse.
const CADERA_DE_PIE := 0.91
## Cuánto se le deja bajar para amortiguar un aterrizaje.
const CADERA_MARGEN := 0.30


## Quita de la animación el movimiento que le toca hacer a la física.
##
## POR QUÉ SERENA ATRAVESABA EL SUELO AL ATERRIZAR
##
## Las animaciones de Mixamo se bajaron con *In Place*, que quita el avance
## HORIZONTAL — pero no el vertical. Midiendo la pista de posición de la cadera:
##
##     idle          0,90 → 0,92     (quieta, es la referencia)
##     land          0,57 → 1,44
##     double_jump   0,64 → 2,15
##
## O sea, la animación de doble salto sube el modelo un metro y cuarto por su
## cuenta, y la de aterrizaje lo baja 35 cm por debajo de donde se está de pie.
## Pero **la altura del personaje ya la lleva la física**: el salto es
## `velocity.y`, y el suelo lo pone el `CharacterBody3D`. Las dos cosas se
## sumaban, así que en el salto subía de más y al aterrizar se hundía — que es
## exactamente lo que se veía.
##
## Aquí la cadera se ancla a su altura de pie. Se le deja BAJAR un poco, porque
## flexionar al caer es parte del gesto y sin eso el aterrizaje se ve rígido,
## pero no se le deja subir: de subir ya se encarga el juego. Y de paso se
## anulan la X y la Z, que es el *In Place* que Mixamo dice hacer y no siempre
## hace del todo.
func _anclar_la_cadera(anim: Animation) -> void:
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		if not String(anim.track_get_path(i)).ends_with("Hips"):
			continue
		for k in anim.track_get_key_count(i):
			var v: Vector3 = anim.track_get_key_value(i, k)
			anim.track_set_key_value(i, k, Vector3(
				0.0,
				clampf(v.y, CADERA_DE_PIE - CADERA_MARGEN, CADERA_DE_PIE),
				0.0))


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

		var recolocadas := _normalizar_rutas(anim)
		_anclar_la_cadera(anim)
		anim.loop_mode = Animation.LOOP_LINEAR if ANIMACIONES[nombre] else Animation.LOOP_NONE
		libreria.add_animation(nombre, anim)
		if recolocadas > 0:
			print("  (%s: %d pistas recolocadas)" % [nombre, recolocadas])
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
