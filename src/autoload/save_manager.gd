extends Node
## Persistencia en JSON.
##
## Analogía backend: repositorio + migraciones. `SAVE_VERSION` existe para poder
## cambiar el formato más adelante sin romper la partida de tu prima.
## En Android `user://` va a la carpeta privada de la app.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

var _dirty := false


func _ready() -> void:
	load_game()


func save_game() -> void:
	var data := {
		"save_version": SAVE_VERSION,
		"current_sailor_id": GameManager.current_sailor_id,
		"unlocked_sailors": GameManager.unlocked_sailors,
		"unlocked_outfits": GameManager.unlocked_outfits,
		"equipped_outfit": GameManager.equipped_outfit,
		"level_progress": GameManager.level_progress,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo escribir la partida: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_dirty = false


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("No se pudo leer la partida: %s" % error_string(FileAccess.get_open_error()))
		return false

	var raw := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Partida corrupta, se ignora.")
		return false

	var data: Dictionary = parsed
	data = _migrate(data)

	GameManager.current_sailor_id = data.get("current_sailor_id", "moon")
	GameManager.unlocked_outfits.assign(data.get("unlocked_outfits", ["default"]))
	GameManager.unlocked_sailors.assign(data.get("unlocked_sailors", ["moon"]))
	GameManager.equipped_outfit = data.get("equipped_outfit", "default")
	GameManager.level_progress = data.get("level_progress", {})
	return true


## Punto único donde se adaptan partidas de versiones antiguas.
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("save_version", 0))
	if version == SAVE_VERSION:
		return data
	# Cuando SAVE_VERSION suba a 2, aquí va: if version < 2: ...
	data["save_version"] = SAVE_VERSION
	return data


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
