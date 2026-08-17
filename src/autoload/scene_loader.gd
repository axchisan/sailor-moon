extends Node
## Cambio de escena asíncrono con pantalla de carga.
##
## Analogía backend: el router. Cargar con `change_scene_to_file` congela el
## juego durante la carga; en un móvil eso son varios segundos de pantalla
## muerta. Aquí se carga en un hilo aparte y se informa del progreso.

var _loading_path: String = ""
var _carga: PantallaCarga = null
var _progress: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	EventBus.request_scene_change.connect(change_scene)


func change_scene(scene_path: String) -> void:
	if _loading_path != "":
		push_warning("Ya hay una carga en curso: %s" % _loading_path)
		return
	if not ResourceLoader.exists(scene_path):
		push_error("La escena no existe: %s" % scene_path)
		return

	# LA PANTALLA DE CARGA SE PONE ANTES DE EMPEZAR, Y LA QUITA EL NIVEL.
	#
	# El cargador ya traía la escena en un hilo, pero nadie enseñaba nada: se
	# tocaba JUGAR y el juego se quedaba clavado con la última imagen congelada.
	# Eso no se lee como «cargando», se lee como que se ha roto.
	#
	# No se quita al terminar la carga sino cuando el nivel avisa de que ha
	# acabado de montarse — el tirón de verdad es el `_ready()` del nivel, no
	# traer el archivo.
	if _carga == null:
		_carga = PantallaCarga.new()
		get_tree().get_root().add_child(_carga)

	_loading_path = scene_path
	_progress = []
	ResourceLoader.load_threaded_request(scene_path, "PackedScene")
	EventBus.scene_load_progress.emit(0.0)
	set_process(true)


func _process(_delta: float) -> void:
	if _loading_path == "":
		set_process(false)
		return

	var status := ResourceLoader.load_threaded_get_status(_loading_path, _progress)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not _progress.is_empty():
				EventBus.scene_load_progress.emit(float(_progress[0]))

		ResourceLoader.THREAD_LOAD_LOADED:
			var packed: PackedScene = ResourceLoader.load_threaded_get(_loading_path)
			var path := _loading_path
			_loading_path = ""
			set_process(false)
			EventBus.scene_load_progress.emit(1.0)
			get_tree().change_scene_to_packed(packed)
			EventBus.scene_ready.emit(path)

		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Fallo al cargar la escena: %s" % _loading_path)
			_loading_path = ""
			set_process(false)


func is_loading() -> bool:
	return _loading_path != ""


## Lo llama la escena nueva cuando ha terminado de montarse. Sin esto, la
## pantalla de carga se quedaría puesta para siempre.
func escena_lista() -> void:
	if _carga == null:
		return
	var c := _carga
	_carga = null
	c.listo()


func hay_pantalla_de_carga() -> bool:
	return _carga != null
