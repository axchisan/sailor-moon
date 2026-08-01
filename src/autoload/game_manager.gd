extends Node
## Estado de la partida en memoria.
##
## Analogía backend: el contexto de sesión. No persiste nada por sí mismo;
## de eso se encarga SaveManager leyendo y escribiendo este estado.

const MAX_HEALTH := 5
const SPECIAL_HITS_TO_CHARGE := 12

# --- Estado de la partida ---
var current_sailor_id: String = "moon"
var unlocked_sailors: Array[String] = ["moon"]
var unlocked_outfits: Array[String] = ["default"]
var equipped_outfit: String = "default"

# --- Estado del nivel en curso ---
var current_level_id: String = ""
var health: int = MAX_HEALTH
var special_charge: int = 0
var stars_this_level: int = 0
var sparkles_this_level: int = 0
var friends_this_level: int = 0
var last_checkpoint: Vector3 = Vector3.ZERO

# --- Progreso persistente: { level_id: { stars, sparkles, friends } } ---
var level_progress: Dictionary = {}


## Registra un enemigo purificado. Lo llama el propio enemigo al limpiarse,
## para que el contador y la señal salgan siempre sincronizados.
func register_friend(enemy_name: String) -> void:
	friends_this_level += 1
	EventBus.enemy_purified.emit(enemy_name, friends_this_level)


# --- Salud -------------------------------------------------------------------

func take_damage(amount: int = 1) -> void:
	health = maxi(0, health - amount)
	EventBus.health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		EventBus.player_died.emit()


func heal(amount: int = 1) -> void:
	health = mini(MAX_HEALTH, health + amount)
	EventBus.health_changed.emit(health, MAX_HEALTH)


func reset_health() -> void:
	health = MAX_HEALTH
	EventBus.health_changed.emit(health, MAX_HEALTH)


# --- Carga del especial -------------------------------------------------------

func add_special_charge(hits: int = 1) -> void:
	var was_ready := is_special_ready()
	special_charge = mini(SPECIAL_HITS_TO_CHARGE, special_charge + hits)
	EventBus.special_charge_changed.emit(get_special_ratio())
	if not was_ready and is_special_ready():
		EventBus.special_ready.emit()


func consume_special() -> void:
	special_charge = 0
	EventBus.special_charge_changed.emit(0.0)


func is_special_ready() -> bool:
	return special_charge >= SPECIAL_HITS_TO_CHARGE


func get_special_ratio() -> float:
	return float(special_charge) / float(SPECIAL_HITS_TO_CHARGE)


# --- Coleccionables ----------------------------------------------------------

func collect_star() -> void:
	stars_this_level += 1
	EventBus.star_collected.emit(stars_this_level)


func collect_sparkle(amount: int = 1) -> void:
	sparkles_this_level += amount
	EventBus.sparkle_collected.emit(sparkles_this_level)


# --- Ciclo de nivel ----------------------------------------------------------

func start_level(level_id: String) -> void:
	current_level_id = level_id
	stars_this_level = 0
	sparkles_this_level = 0
	friends_this_level = 0
	special_charge = 0
	last_checkpoint = Vector3.ZERO
	reset_health()


func finish_level() -> void:
	var previous: Dictionary = level_progress.get(current_level_id, {})
	level_progress[current_level_id] = {
		"stars": maxi(previous.get("stars", 0), stars_this_level),
		"sparkles": maxi(previous.get("sparkles", 0), sparkles_this_level),
		"friends": maxi(previous.get("friends", 0), friends_this_level),
	}
	EventBus.level_completed.emit(current_level_id)
	SaveManager.save_game()


func set_checkpoint(position: Vector3) -> void:
	last_checkpoint = position
	EventBus.checkpoint_reached.emit(position)
	SaveManager.save_game()


# --- Sailors -----------------------------------------------------------------

func unlock_sailor(sailor_id: String) -> void:
	if sailor_id in unlocked_sailors:
		return
	unlocked_sailors.append(sailor_id)
	EventBus.sailor_unlocked.emit(sailor_id)
	SaveManager.save_game()


func set_current_sailor(sailor_id: String) -> void:
	if sailor_id not in unlocked_sailors:
		push_warning("Sailor no desbloqueada: %s" % sailor_id)
		return
	current_sailor_id = sailor_id
	EventBus.sailor_changed.emit(sailor_id)
