extends State
## Ataque especial: el momento que va a querer repetir una y otra vez.
##
## Se carga golpeando. Cuando está lista, el botón brilla y suena. Al usarla:
## zoom de cámara, el nombre del ataque en pantalla, y todos los enemigos
## cercanos purificados de golpe.
##
## Es invulnerable durante toda la ejecución, así que también funciona como
## botón de pánico cuando se agobia. Eso es deliberado.

enum Phase { WINDUP, ACTIVE, RECOVERY }

var _attack: AttackData = null
var _phase: int = Phase.WINDUP
var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	var p := actor as Player

	_attack = p.special_attack
	_phase = Phase.WINDUP
	_timer = 0.0

	p.reset_combo()
	GameManager.consume_special()

	# Invulnerable de principio a fin, con margen de sobra.
	var duration := _attack.total_time() if _attack != null else 1.3
	p.invuln_timer = maxf(p.invuln_timer, duration + 0.2)

	p.velocity = Vector3(0.0, p.velocity.y, 0.0)

	var attack_name := _attack.display_name if _attack != null else "Especial"
	EventBus.special_used.emit(GameManager.current_sailor_id, attack_name)
	p.camera_rig.zoom_punch()


func exit() -> void:
	var p := actor as Player
	p.special_hitbox.disable()


func physics_update(delta: float) -> String:
	var p := actor as Player

	p.apply_gravity(delta)
	p.apply_friction(delta, 20.0)

	if _attack == null:
		return "Idle"

	_timer += delta

	match _phase:
		Phase.WINDUP:
			if _timer >= _attack.windup:
				_timer -= _attack.windup
				_phase = Phase.ACTIVE
				p.special_hitbox.enable(_attack)
				CombatFeel.special(p.global_position + Vector3.UP)

		Phase.ACTIVE:
			if _timer >= _attack.active:
				_timer -= _attack.active
				_phase = Phase.RECOVERY
				p.special_hitbox.disable()

		Phase.RECOVERY:
			if _timer >= _attack.recovery:
				if not p.is_on_floor():
					return "Fall"
				if p.get_move_direction().length_squared() > 0.0001:
					return "Move"
				return "Idle"

	return ""
