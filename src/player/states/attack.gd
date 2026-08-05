extends State
## Combo de 3 golpes. Machacar el botón encadena; no hay direcciones que
## memorizar ni timings que clavar.
##
## Estructura de cada golpe: anticipación → hitbox activa → recuperación.
## La hitbox la enciende y apaga este estado; cuando lleguen las animaciones
## reales (Fase 2) lo hará el AnimationPlayer con call method tracks y bastará
## con sustituir las dos llamadas de aquí.

enum Phase { WINDUP, ACTIVE, RECOVERY }

var _index: int = 1
var _attack: AttackData = null
var _phase: int = Phase.WINDUP
var _timer: float = 0.0
var _buffered: bool = false


func enter(_msg: Dictionary = {}) -> void:
	var p := actor as Player

	_index = p.advance_combo()
	_attack = p.get_attack(_index)
	_phase = Phase.WINDUP
	_timer = 0.0
	_buffered = false

	# La animación se encaja en la duración del golpe: manda el combate, que ya
	# está ajustado, y la animación se adapta.
	p.play("attack_%d" % _index, _attack.total_time() if _attack != null else 0.0)

	# Auto-orientación: se gira sola hacia el enemigo más cercano.
	var target := p.get_attack_target()
	if target != null:
		p.snap_face_to(target.global_position)

	EventBus.combo_hit.emit(_index)


func exit() -> void:
	var p := actor as Player
	p.hitbox.disable()


func physics_update(delta: float) -> String:
	var p := actor as Player

	p.apply_gravity(delta)
	p.apply_friction(delta, 14.0)

	# El botón pulsado en cualquier momento del golpe cuenta para el siguiente.
	# Ser generoso aquí es lo que hace que machacar "funcione siempre".
	if p.wants_attack():
		_buffered = true

	if _attack == null:
		return _finish(p)

	_timer += delta

	match _phase:
		Phase.WINDUP:
			if _timer >= _attack.windup:
				_timer -= _attack.windup
				_phase = Phase.ACTIVE
				p.hitbox.enable(_attack)
				# El impulso hacia delante da sensación de peso y ayuda a
				# alcanzar al enemigo aunque estés un poco lejos.
				var forward := p.get_forward()
				p.velocity.x += forward.x * _attack.lunge
				p.velocity.z += forward.z * _attack.lunge

		Phase.ACTIVE:
			if _timer >= _attack.active:
				_timer -= _attack.active
				_phase = Phase.RECOVERY
				p.hitbox.disable()

		Phase.RECOVERY:
			if _timer >= _attack.recovery:
				if _buffered:
					return "Attack"
				return _finish(p)

	if p.wants_special():
		return "Special"

	return ""


func _finish(p: Player) -> String:
	if not p.is_on_floor():
		return "Fall"
	if p.get_move_direction().length_squared() > 0.0001:
		return "Move"
	return "Idle"
