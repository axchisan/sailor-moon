extends Control
## HUD de combate. Todo lo que muestra le llega por EventBus: no conoce ni al
## jugador ni a los enemigos.
##
## Los corazones son texto por ahora; se sustituyen por sprites en la Fase 2
## sin tocar esta lógica.

@onready var hearts: Label = %Hearts
@onready var special_bar: ProgressBar = %SpecialBar
@onready var special_label: Label = %SpecialLabel
@onready var counters: Label = %Counters
@onready var banner: Label = %Banner
@onready var wave_label: Label = %WaveLabel

var _banner_timer: float = 0.0


func _ready() -> void:
	EventBus.health_changed.connect(_on_health_changed)
	EventBus.special_charge_changed.connect(_on_special_charge_changed)
	EventBus.special_ready.connect(_on_special_ready)
	EventBus.special_used.connect(_on_special_used)
	EventBus.sparkle_collected.connect(_on_counters_changed)
	EventBus.star_collected.connect(_on_counters_changed)
	EventBus.enemy_purified.connect(_on_enemy_purified)
	EventBus.arena_started.connect(_on_arena_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.arena_cleared.connect(_on_arena_cleared)
	EventBus.player_died.connect(_on_player_died)

	banner.modulate.a = 0.0
	special_label.visible = false
	_refresh_all()


func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			var tween := create_tween()
			tween.tween_property(banner, "modulate:a", 0.0, 0.4)

	# El botón del especial late cuando está listo. Es imposible no verlo.
	if GameManager.is_special_ready():
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.006)
		special_bar.modulate = Color(1.0, pulse, 0.4)
	else:
		special_bar.modulate = Color.WHITE


func _refresh_all() -> void:
	_on_health_changed(GameManager.health, GameManager.MAX_HEALTH)
	_on_special_charge_changed(GameManager.get_special_ratio())
	_update_counters()


func _on_health_changed(current: int, maximum: int) -> void:
	var text := ""
	for i in maximum:
		text += "♥ " if i < current else "♡ "
	hearts.text = text.strip_edges()


func _on_special_charge_changed(ratio: float) -> void:
	special_bar.value = ratio * 100.0
	if ratio < 1.0:
		special_label.visible = false


func _on_special_ready() -> void:
	special_label.visible = true
	special_label.text = "¡ESPECIAL LISTO!"


func _on_special_used(_sailor_id: String, attack_name: String) -> void:
	special_label.visible = false
	show_banner("¡%s!" % attack_name.to_upper(), 2.0)


func _on_counters_changed(_total: int) -> void:
	_update_counters()


func _on_enemy_purified(_enemy_name: String, total: int) -> void:
	_update_counters()
	show_banner("¡%d amigos!" % total, 1.0)


func _on_arena_started(_arena_id: String, wave_count: int) -> void:
	wave_label.text = "Oleada 1 / %d" % wave_count
	show_banner("¡Aquí vienen!", 1.5)


func _on_wave_cleared(index: int) -> void:
	wave_label.text = "Oleada %d" % (index + 2)


func _on_arena_cleared(_arena_id: String) -> void:
	wave_label.text = ""
	show_banner("¡Arena limpia!", 2.5)


func _on_player_died() -> void:
	show_banner("¡Uy! Vuelve a intentarlo", 1.5)


func _update_counters() -> void:
	counters.text = "★ %d    ✦ %d    ☺ %d" % [
		GameManager.stars_this_level,
		GameManager.sparkles_this_level,
		GameManager.friends_this_level,
	]


func show_banner(text: String, duration: float = 1.5) -> void:
	banner.text = text
	banner.modulate.a = 1.0
	_banner_timer = duration
