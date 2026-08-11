extends SubViewport
class_name Retrato
## Un primer plano EN VIVO del personaje que está hablando.
##
## POR QUÉ NO SE RENDERIZAN EN BLENDER
##
## El plan era sacar los retratos como imágenes: un primer plano por personaje y
## por gesto, renderizado aparte. Eso son once personajes por tres gestos, que
## hay que generar, guardar, importar, y volver a generar entera cada vez que se
## le cambie algo a un modelo. Y once personajes es lo que hay hoy.
##
## Aquí el retrato es el personaje DE VERDAD, mirado de cerca por otra cámara.
## Sale idéntico al del juego porque es el del juego, no hay archivos que
## mantener, y de propina **gesticula**: si el personaje está diciendo su frase
## con la animación de hablar, el retrato la dice con él.
##
## POR QUÉ NO CUESTA UN RENDER DEL MUNDO ENTERO
##
## Sería carísimo dibujar el parque dos veces. La cámara del retrato lleva un
## `cull_mask` que **solo ve la capa del personaje**, así que de toda la escena
## dibuja un modelo y nada más. El fondo lo pone el propio panel.
##
## Y solo existe mientras hay conversación: se monta al abrir el cuadro y se
## tira al cerrarlo.

## Capa de render reservada para lo que sale en los retratos.
##
## El personaje va en la suya Y en la de siempre: la cámara del juego lo ve por
## la normal y esta solo mira la reservada, así que el retrato sale limpio sin
## tener que mover nada de sitio.
const CAPA_RETRATO := 10

## Tamaño del render. Pequeño a propósito: es un recuadro en una esquina, y cada
## píxel de más se paga en el móvil.
const LADO := 256

## A qué altura del personaje está la cara, en fracción de su altura total.
##
## Sale así y no en metros porque los personajes miden cosas muy distintas:
## Serena 1,6 m y Luna cuarenta centímetros. Un número fijo enfocaba a la una y
## le apuntaba al aire por encima de la otra.
const PROPORCION_CARA := 0.88
## Altura de emergencia si el modelo no da su caja envolvente.
const ALTURA_CARA := 1.42

var _camara: Camera3D = null


func _init() -> void:
	size = Vector2i(LADO, LADO)
	transparent_bg = true
	# Se dibuja cuando se le pide, no sesenta veces por segundo por si acaso.
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# El mundo es el mismo que el del juego: el personaje que se enfoca es el
	# que está ahí plantado, no una copia.
	own_world_3d = false


func _ready() -> void:
	_camara = Camera3D.new()
	_camara.name = "CamaraRetrato"
	# LO QUE HACE QUE ESTO SEA BARATO: de toda la escena, solo la capa del
	# retrato. Sin esto se dibujaría el parque entero una segunda vez.
	_camara.cull_mask = 1 << (CAPA_RETRATO - 1)
	_camara.fov = 38.0
	_camara.near = 0.05
	_camara.far = 4.0
	add_child(_camara)
	_camara.make_current()

	# Luz propia, porque la del parque puede dejarle la cara en sombra según la
	# hora a la que se hable. Un retrato mal iluminado no se entiende.
	var luz := DirectionalLight3D.new()
	luz.light_energy = 1.15
	luz.light_color = Color(1.0, 0.97, 0.92)
	luz.rotation_degrees = Vector3(-18.0, 145.0, 0.0)
	luz.light_cull_mask = 1 << (CAPA_RETRATO - 1)
	add_child(luz)


## Enfoca a un personaje. Se le pasa su nodo visual.
##
## Lo pone en la capa del retrato —además de en la suya— y coloca la cámara
## delante de su cara. Devuelve `false` si no hay nada que enfocar, para que
## quien llama pueda esconder el recuadro en vez de enseñar un hueco.
func enfocar(visual: Node3D) -> bool:
	if visual == null or _camara == null:
		return false

	var mallas := visual.find_children("*", "MeshInstance3D", true, false)
	if mallas.is_empty():
		return false

	for malla in mallas:
		(malla as MeshInstance3D).layers |= 1 << (CAPA_RETRATO - 1)

	# LA CARA SE BUSCA POR EL HUESO DE LA CABEZA.
	#
	# El primer intento la sacaba de la caja envolvente del modelo, y salió mal
	# de una forma muy tonta: a estos personajes se les pone un `custom_aabb`
	# enorme a propósito —2,6 m— para que no desaparezcan por frustum culling
	# cuando la animación se sale de la caja de reposo (trampa 11). Preguntarle
	# la altura a esa caja es preguntársela a un número inventado, así que el
	# encuadre salía por las nubes y se veían los pies.
	#
	# El hueso de la cabeza no miente y además vale para cualquiera: Serena mide
	# 1,6 y Luna cuarenta centímetros, y a las dos se les enfoca la cara.
	var cara := _donde_esta_la_cara(visual)

	# Delante y un poco de lado. El frente del personaje es su −Z.
	var frente := -visual.global_transform.basis.z.normalized()
	var costado := visual.global_transform.basis.x.normalized()
	# La distancia se mide desde los pies hasta la cara: a un gato se le enfoca
	# de más cerca que a una persona, o sale de cuerpo entero y diminuto.
	var talla := maxf(cara.y - visual.global_position.y, 0.3)
	var lejos := clampf(talla * 0.55, 0.3, 0.95)
	_camara.global_position = cara + frente * lejos + costado * (lejos * 0.38)
	_camara.look_at(cara, Vector3.UP)
	return true


## Dónde tiene la cara este personaje, en coordenadas del mundo.
##
## Por el hueso si lo hay; si no —modelos sin esqueleto, o con los huesos
## nombrados de otra manera— se cae a una fracción de lo que mide la malla, que
## para eso sí sirve la caja envolvente: lo que no vale es la del personaje
## principal, que va inflada.
func _donde_esta_la_cara(visual: Node3D) -> Vector3:
	for nodo in visual.find_children("*", "Skeleton3D", true, false):
		var esqueleto := nodo as Skeleton3D
		for nombre in ["mixamorig_Head", "Head", "cabeza", "Cabeza"]:
			var hueso := esqueleto.find_bone(nombre)
			if hueso >= 0:
				var pose := esqueleto.global_transform * esqueleto.get_bone_global_pose(hueso)
				return pose.origin
	return visual.global_position + Vector3.UP * ALTURA_CARA


## Deja al personaje como estaba. Sin esto se queda en la capa del retrato para
## siempre y el siguiente que hable saldría con él dentro del recuadro.
func soltar(visual: Node3D) -> void:
	if visual == null:
		return
	for malla in visual.find_children("*", "MeshInstance3D", true, false):
		(malla as MeshInstance3D).layers &= ~(1 << (CAPA_RETRATO - 1))
