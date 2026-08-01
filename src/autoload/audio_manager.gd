extends Node
## Buses de audio, música con crossfade y pool de reproductores de SFX.
##
## El pool existe porque instanciar un AudioStreamPlayer por cada golpe
## generaría basura constante en un beat 'em up. Se crean N y se reciclan.

const SFX_POOL_SIZE := 16
const CROSSFADE_TIME := 1.0

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # el audio sigue durante la pausa
	_ensure_buses()

	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_active_music = _music_a

	for i in SFX_POOL_SIZE:
		_sfx_pool.append(_make_player("SFX"))


func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _make_player(bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


# --- Música ------------------------------------------------------------------

func play_music(stream: AudioStream, crossfade: bool = true) -> void:
	if stream == null:
		return
	if _active_music.stream == stream and _active_music.playing:
		return

	var incoming := _music_b if _active_music == _music_a else _music_a
	incoming.stream = stream
	incoming.volume_db = -40.0 if crossfade else 0.0
	incoming.play()

	if crossfade:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(incoming, "volume_db", 0.0, CROSSFADE_TIME)
		tween.tween_property(_active_music, "volume_db", -40.0, CROSSFADE_TIME)
		tween.chain().tween_callback(_active_music.stop)
	else:
		_active_music.stop()

	_active_music = incoming


func stop_music(fade: bool = true) -> void:
	if not fade:
		_active_music.stop()
		return
	var tween := create_tween()
	tween.tween_property(_active_music, "volume_db", -40.0, CROSSFADE_TIME)
	tween.tween_callback(_active_music.stop)


# --- Efectos -----------------------------------------------------------------

## Reproduce un SFX. `pitch_variation` desafina ligeramente cada repetición
## para que machacar el botón de ataque no suene a metralleta.
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_variation: float = 0.1) -> void:
	if stream == null:
		return
	var player := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


# --- Volumen -----------------------------------------------------------------

func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))
	AudioServer.set_bus_mute(idx, is_zero_approx(linear))


func get_bus_volume(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))
