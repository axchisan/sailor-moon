extends Node
## Cambio de escena asíncrono con pantalla de carga.
##
## Analogía backend: el router. Cargar con `change_scene_to_file` congela el
## juego durante la carga; en un móvil eso son varios segundos de pantalla
## muerta. Aquí se carga en un hilo aparte y se informa del progreso.

var _loading_path: String = ""
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
