extends Node
## Ajustes del jugador, persistidos aparte de la partida.
##
## `assisted_mode` es la palanca de accesibilidad: si el playtest revela que se
## atasca, se activa en silencio desde el menú y el juego se vuelve más amable
## sin decirle nada.

const SETTINGS_PATH := "user://settings.cfg"

var music_volume: float = 0.8
var sfx_volume: float = 1.0
var voice_volume: float = 1.0
var assisted_mode: bool = false
var show_guide_arrow: bool = true
var camera_sensitivity: float = 1.0
var locale: String = "es"


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		apply()
		return

	music_volume = config.get_value("audio", "music", music_volume)
	sfx_volume = config.get_value("audio", "sfx", sfx_volume)
	voice_volume = config.get_value("audio", "voice", voice_volume)
	assisted_mode = config.get_value("gameplay", "assisted_mode", assisted_mode)
	show_guide_arrow = config.get_value("gameplay", "guide_arrow", show_guide_arrow)
	camera_sensitivity = config.get_value("controls", "camera_sensitivity", camera_sensitivity)
	locale = config.get_value("general", "locale", locale)
	apply()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "voice", voice_volume)
	config.set_value("gameplay", "assisted_mode", assisted_mode)
	config.set_value("gameplay", "guide_arrow", show_guide_arrow)
	config.set_value("controls", "camera_sensitivity", camera_sensitivity)
	config.set_value("general", "locale", locale)
	config.save(SETTINGS_PATH)


## Vuelca los ajustes sobre los sistemas que los consumen.
func apply() -> void:
	AudioManager.set_bus_volume("Music", music_volume)
	AudioManager.set_bus_volume("SFX", sfx_volume)
	AudioManager.set_bus_volume("Voice", voice_volume)
	TranslationServer.set_locale(locale)
