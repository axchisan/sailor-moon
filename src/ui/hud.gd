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
var _aviso: Label = null
var _aviso_timer: float = 0.0


## EL AVISO VA APARTE DEL CARTEL DE COMBATE.
##
## Podrían compartir el `Banner` y salía más barato, pero entonces «¡Aquí
## vienen!» y «Faltan 3 faroles» se pisan: el que llega segundo borra al primero,
## y llegar a una arena es justo el momento en que los dos tienen algo que decir.
## Separados, el de pelea manda arriba y el informativo abajo, y los dos caben.
##
## Y es más pequeño a propósito. El cartel de combate grita porque anuncia algo
## que pasa ahora mismo; esto explica, y lo que explica se lee, no se grita.
func _montar_aviso() -> void:
	_aviso = Label.new()
	_aviso.name = "Aviso"
	_aviso.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_aviso.anchor_top = 0.72
	_aviso.anchor_bottom = 0.72
	_aviso.offset_left = -420.0
	_aviso.offset_right = 420.0
	_aviso.offset_top = -60.0
	_aviso.offset_bottom = 60.0
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aviso.add_theme_font_size_override("font_size", 27)
	_aviso.add_theme_color_override("font_color", Color(1.0, 0.96, 0.99))
	_aviso.add_theme_color_override("font_outline_color", Color(0.28, 0.08, 0.24))
	_aviso.add_theme_constant_override("outline_size", 9)
	_aviso.modulate.a = 0.0
	add_child(_aviso)


## Un aviso de paso, abajo. Para la lista completa de objetivos está
## [`PanelRequisitos`](panel_requisitos.gd), que para eso para el juego.
func mostrar_aviso(texto: String, duracion: float = 3.0) -> void:
	if _aviso == null:
		return
	_aviso.text = texto
	_aviso_timer = duracion
	var t := create_tween()
	t.tween_property(_aviso, "modulate:a", 1.0, 0.18)


func _ready() -> void:
	EventBus.health_changed.connect(_on_health_changed)
	EventBus.special_charge_changed.connect(_on_special_charge_changed)
	EventBus.special_ready.connect(_on_special_ready)
	EventBus.special_used.connect(_on_special_used)
	EventBus.sparkle_collected.connect(_on_counters_changed)
	EventBus.star_collected.connect(_on_counters_changed)
	EventBus.enemy_defeated.connect(_on_enemy_defeated)
	EventBus.arena_started.connect(_on_arena_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.arena_cleared.connect(_on_arena_cleared)
	EventBus.player_died.connect(_on_player_died)
	# NADIE ESCUCHABA ESTA SEÑAL.
	#
	# `show_message` es por donde hablan el portal, las puertas mágicas, los
	# faroles y los objetivos: veintiún sitios del juego emitiéndola, y el HUD
	# nunca se conectó. Todos esos avisos llevaban desde siempre gritando al
	# vacío, y por eso llegar a una puerta cerrada no explicaba nada — el aviso
	# se escribía, sencillamente no lo mostraba nadie.
	#
	# Se ve al probar los mensajes uno a uno y no se ve nunca leyendo el código
	# que los emite, que estaba bien: la señal existía y el `emit` era correcto.
	EventBus.show_message.connect(mostrar_aviso)

	banner.modulate.a = 0.0
	special_label.visible = false
	_montar_aviso()
	_refresh_all()


func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			var tween := create_tween()
			tween.tween_property(banner, "modulate:a", 0.0, 0.4)

	if _aviso_timer > 0.0:
		_aviso_timer -= delta
		if _aviso_timer <= 0.0 and _aviso != null:
			create_tween().tween_property(_aviso, "modulate:a", 0.0, 0.45)

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


func _on_enemy_defeated(_enemy_name: String, total: int) -> void:
	_update_counters()
	show_banner("¡%d derrotados!" % total, 1.0)


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
	counters.text = "★ %d    ✦ %d    ⚔ %d" % [
		GameManager.stars_this_level,
		GameManager.sparkles_this_level,
		GameManager.defeated_this_level,
	]


func show_banner(text: String, duration: float = 1.5) -> void:
	banner.text = text
	banner.modulate.a = 1.0
	_banner_timer = duration
