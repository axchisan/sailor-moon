extends CharacterBody3D
class_name Enemy
## Enemigo base. El "Peluchín" del GDD: se acerca, avisa y golpea.
##
## Reglas de compasión que implementa este archivo y que NO son negociables:
##   · Nunca ataca sin telegrafiar: brilla en rojo antes de cada golpe.
##   · Solo ataca si CombatDirector le da una ficha (varios a la vez, no todos).
##
## Al ser derrotado desaparece en un estallido de estrellas. Antes se convertía
## en amigo y se quedaba de adorno; se cambió a eliminación real a petición de
## la jugadora, que quería enemigos que atacaran de verdad.

@export var display_name: String = "Peluchin"
@export var max_health: int = 3
@export var move_speed: float = 3.4
@export var attack_range: float = 2.0
## Distancia a la que orbita mientras espera su turno de ataque.
@export var wait_distance: float = 2.8
@export var detection_range: float = 14.0
@export var turn_speed: float = 9.0
@export var attack: AttackData
@export var sparkles_on_defeat: int = 3
@export var knockback_friction: float = 8.0

@export_group("Colores")
@export var base_color: Color = Color(0.62, 0.45, 0.85)
@export var telegraph_color: Color = Color(1.0, 0.35, 0.4)

@onready var model: Node3D = $Model
## Se busca sola: sirve tanto la cápsula gris como el modelo importado.
@onready var mesh: MeshInstance3D = get_node_or_null("Model/Body")
@onready var hitbox: Hitbox = $Model/Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var state_machine: StateMachine = $StateMachine

var health: int = 0
var defeated: bool = false
var target: Node3D = null

## Puede ser StandardMaterial3D (cápsula) o ShaderMaterial (MToon).
var _material: Material = null
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
	if mesh == null:
		mesh = _buscar_malla(self)
	if mesh != null:
		var source_material := mesh.get_active_material(0)
		if source_material != null:
			_material = source_material.duplicate()
			mesh.set_surface_override_material(0, _material)
			set_color(base_color)

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


## El jugador solo apunta a enemigos que siguen en pie.
func is_targetable() -> bool:
	return not defeated


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

## Tiñe al enemigo. Funciona con la cápsula gris (StandardMaterial3D) y con el
## modelo real, que lleva MToon (ShaderMaterial) tras pasar por ToonRoot.
##
## Si esto se rompe se pierde el aviso rojo previo al golpe, que es una de las
## reglas de compasión del combate: el enemigo NUNCA pega sin telegrafiar.
func set_color(color: Color) -> void:
	if _material == null:
		return
	var toon := _material as ShaderMaterial
	if toon != null:
		toon.set_shader_parameter("_Color", color)
		toon.set_shader_parameter("_ShadeColor", color * Color(0.62, 0.58, 0.75))
		return
	var pbr := _material as BaseMaterial3D
	if pbr != null:
		pbr.albedo_color = color


static func _buscar_malla(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _buscar_malla(c)
		if r != null:
			return r
	return null


## Pulso rojo durante la anticipación. Es el aviso visual de "voy a pegar".
func set_telegraph_pulse(ratio: float) -> void:
	if _material == null:
		return
	var pulse := 0.5 + 0.5 * sin(ratio * TAU * 4.0)
	set_color(base_color.lerp(telegraph_color, pulse))


func reset_color() -> void:
	set_color(base_color)


# --- Daño ---------------------------------------------------------------------

func _on_hurtbox_hit(player_hitbox: Hitbox) -> void:
	if defeated:
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
		state_machine.transition_to("Defeated", {"knockback": direction * knockback, "up": knockback_up})
	else:
		state_machine.transition_to("Stagger", {"knockback": direction * knockback, "up": knockback_up})


## Derrotado: deja de estorbar y el estado `Defeated` lo hace desaparecer.
##
## Antes esto convertía al enemigo en amigo y lo dejaba de adorno en la arena.
## Se cambió a eliminación real a petición de la jugadora.
func defeat() -> void:
	if defeated:
		return
	defeated = true

	remove_from_group("enemies")
	CombatDirector.release_token(self)

	hitbox.disable()
	# Diferido: `defeat()` se llama desde `area_entered`, y ahí Godot bloquea
	# tocar `monitorable` directamente.
	hurtbox.set_deferred("monitorable", false)
	# Deja de estorbar mientras dura la animación de derrota.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 1)

	CombatFeel.defeat(global_position + Vector3.UP * 0.8)

	GameManager.collect_sparkle(sparkles_on_defeat)
	GameManager.register_defeat(display_name)
