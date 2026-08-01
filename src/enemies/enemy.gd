extends CharacterBody3D
class_name Enemy
## Enemigo base. El "Peluchín" del GDD: se acerca, avisa y golpea.
##
## Reglas de compasión que implementa este archivo y que NO son negociables:
##   · Nunca ataca sin telegrafiar (mínimo 1,2 s brillando en rojo).
##   · Solo ataca si CombatDirector le da una ficha (máximo 3 a la vez).
##   · Al ser derrotado no muere: se purifica y se queda de adorno saltando.

@export var display_name: String = "Peluchin"
@export var max_health: int = 3
@export var move_speed: float = 2.6
@export var attack_range: float = 1.9
## Distancia a la que orbita mientras espera su turno de ataque.
@export var wait_distance: float = 3.2
@export var detection_range: float = 14.0
@export var turn_speed: float = 7.0
@export var attack: AttackData
@export var sparkles_on_purify: int = 3
@export var knockback_friction: float = 8.0

@export_group("Colores")
@export var base_color: Color = Color(0.62, 0.45, 0.85)
@export var telegraph_color: Color = Color(1.0, 0.35, 0.4)
@export var friend_color: Color = Color(0.6, 0.95, 0.75)

@onready var model: Node3D = $Model
@onready var mesh: MeshInstance3D = $Model/Body
@onready var hitbox: Hitbox = $Model/Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var state_machine: StateMachine = $StateMachine

var health: int = 0
var purified: bool = false
var target: Node3D = null

var _material: StandardMaterial3D = null
var _gravity: float = 24.0


const DEFAULT_ATTACK := "res://assets/data/attacks/enemy_basic.tres"


func _ready() -> void:
	add_to_group("enemies")
	health = max_health

	if attack == null:
		attack = load(DEFAULT_ATTACK) as AttackData

	hitbox.source = self
	hitbox.attack = attack
	hurtbox.hit_taken.connect(_on_hurtbox_hit)

	# Material propio: sin esto, parpadear a un enemigo los parpadea a todos,
	# porque comparten el recurso del .tscn.
	if mesh != null:
		var source_material := mesh.get_active_material(0)
		if source_material != null:
			_material = source_material.duplicate() as StandardMaterial3D
			mesh.set_surface_override_material(0, _material)
			if _material != null:
				_material.albedo_color = base_color

	state_machine.setup(self)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = maxf(velocity.y, -0.1)

	state_machine.physics_update(delta)
	move_and_slide()


# --- Consultas ----------------------------------------------------------------

func get_target() -> Node3D:
	if target != null and is_instance_valid(target):
		return target
	target = get_tree().get_first_node_in_group("player") as Node3D
	return target


func distance_to_target() -> float:
	var t := get_target()
	if t == null:
		return INF
	var delta := t.global_position - global_position
	delta.y = 0.0
	return delta.length()


func direction_to_target() -> Vector3:
	var t := get_target()
	if t == null:
		return Vector3.ZERO
	var delta := t.global_position - global_position
	delta.y = 0.0
	if delta.length_squared() < 0.0001:
		return Vector3.ZERO
	return delta.normalized()


## El jugador solo apunta a enemigos que aún no están purificados.
func is_targetable() -> bool:
	return not purified


# --- Movimiento ---------------------------------------------------------------

func move_towards(direction: Vector3, delta: float, speed_scale: float = 1.0) -> void:
	var target_velocity := direction * move_speed * speed_scale
	velocity.x = move_toward(velocity.x, target_velocity.x, 18.0 * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, 18.0 * delta)


func brake(delta: float, rate: float = -1.0) -> void:
	var f := knockback_friction if rate < 0.0 else rate
	velocity.x = move_toward(velocity.x, 0.0, f * delta)
	velocity.z = move_toward(velocity.z, 0.0, f * delta)


func face_target(delta: float) -> void:
	var direction := direction_to_target()
	if direction.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, turn_speed * delta)


func get_forward() -> Vector3:
	return -model.global_transform.basis.z


# --- Aspecto ------------------------------------------------------------------

func set_color(color: Color) -> void:
	if _material != null:
		_material.albedo_color = color


## Pulso rojo durante la anticipación. Es el aviso visual de "voy a pegar".
func set_telegraph_pulse(ratio: float) -> void:
	if _material == null:
		return
	var pulse := 0.5 + 0.5 * sin(ratio * TAU * 4.0)
	_material.albedo_color = base_color.lerp(telegraph_color, pulse)


func reset_color() -> void:
	set_color(friend_color if purified else base_color)


# --- Daño ---------------------------------------------------------------------

func _on_hurtbox_hit(player_hitbox: Hitbox) -> void:
	if purified:
		return

	var incoming := player_hitbox.attack
	var damage := incoming.damage if incoming != null else 1
	health -= damage

	CombatFeel.impact_from_attack(global_position + Vector3.UP * 0.8, incoming)
	CombatFeel.flash(mesh)

	var direction := player_hitbox.get_knockback_direction(global_position)
	var knockback := incoming.knockback if incoming != null else 4.0
	var knockback_up := incoming.knockback_up if incoming != null else 0.0

	# Suelta la ficha: un enemigo golpeado no bloquea el turno de otro.
	CombatDirector.release_token(self)

	if health <= 0:
		state_machine.transition_to("Purified", {"knockback": direction * knockback, "up": knockback_up})
	else:
		state_machine.transition_to("Stagger", {"knockback": direction * knockback, "up": knockback_up})


## Se limpia de energía oscura y se queda como amigo. No muere nadie.
func purify() -> void:
	if purified:
		return
	purified = true

	remove_from_group("enemies")
	add_to_group("friends")
	CombatDirector.release_token(self)

	hitbox.disable()
	# Diferido: `purify()` se llama desde `area_entered`, y ahí Godot bloquea
	# tocar `monitorable` directamente.
	hurtbox.set_deferred("monitorable", false)
	# Deja de estorbar: el jugador puede atravesarlo.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 1)

	set_color(friend_color)
	CombatFeel.purify(global_position + Vector3.UP * 0.8)

	GameManager.collect_sparkle(sparkles_on_purify)
	GameManager.register_friend(display_name)
