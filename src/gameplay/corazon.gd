extends Area3D
class_name Corazon
## Un corazón que cura, de los que sueltan los enemigos al caer.
##
## ## Por qué existe
##
## El GDD lo prometía desde el principio —«los enemigos sueltan corazones a veces
## al caer»— y no estaba. Sin esto, la vida solo se recupera al terminar una
## arena, y una pelea larga se vuelve cuesta abajo sin nada que hacer al
## respecto: cada golpe recibido es definitivo hasta el final del combate.
##
## Con corazones, recibir un golpe deja de ser irreversible y pelear bien tiene
## premio dentro de la propia pelea.
##
## ## Aparece cuando hace falta, no siempre
##
## La probabilidad **sube cuanta menos vida queda**: con la barra llena casi no
## salen y con un corazón salen la mitad de las veces. Así ayudan justo cuando
## se está perdiendo, que es cuando se abandona una partida, y no estorban
## cuando se va sobrado.
##
## Es una ayuda invisible: no se anuncia, no se explica, y quien juega solo nota
## que las peleas difíciles se remontan.

const CURA := 1
## Cuánto vive antes de desvanecerse. Sin límite, una arena larga acaba llena de
## corazones sin recoger y dejan de significar nada.
const DURA := 14.0
## Lo que sube y baja flotando.
const VAIVEN := 0.18

const SFX := preload("res://assets/audio/sfx/mundo/estrella.wav")

var _t: float = 0.0
var _material: StandardMaterial3D = null
var _malla: MeshInstance3D = null
var _altura: float = 0.0


## Probabilidad de que un enemigo suelte uno, según la vida que quede.
static func probabilidad(vida: int, maxima: int) -> float:
	var resto := float(vida) / float(maxi(maxima, 1))
	# De 0,08 con la barra llena a 0,55 con un solo corazón.
	return lerpf(0.55, 0.08, clampf(resto, 0.0, 1.0))


## Suelta uno en un sitio, si toca. Devuelve si lo soltó.
static func quizas_soltar(donde: Vector3, padre: Node) -> bool:
	if GameManager.health >= GameManager.MAX_HEALTH:
		return false
	if randf() > probabilidad(GameManager.health, GameManager.MAX_HEALTH):
		return false
	var c := Corazon.new()
	padre.add_child(c)
	c.global_position = donde + Vector3.UP * 0.7
	return true


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_al_entrar)

	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	# Generoso: un corazón que hay que pisar con precisión en mitad de una pelea
	# no se recoge nunca.
	esfera.radius = 1.15
	forma.shape = esfera
	add_child(forma)

	_construir()
	_altura = global_position.y
	set_process(true)

	# Los de los repechos no caducan. El corazón que suelta un enemigo es del
	# momento —o se coge o se pierde—, pero el que corona un sitio alto es el
	# premio de haber subido: si desaparece a los catorce segundos, quien lo ve
	# desde abajo y va a por él se encuentra la cima vacía.
	if has_meta("permanente"):
		return

	# Se va solo, avisando antes: los últimos dos segundos parpadea.
	var t := create_tween()
	t.tween_interval(DURA - 2.0)
	t.tween_callback(func() -> void: set_meta("acabando", true))
	t.tween_interval(2.0)
	t.tween_callback(queue_free)


func _construir() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(1.0, 0.36, 0.55)
	_material.emission_enabled = true
	_material.emission = Color(1.0, 0.30, 0.48)
	_material.emission_energy_multiplier = 1.8
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Dos esferas y un prisma: un corazón de verdad pediría un modelo, y a este
	# tamaño y con este brillo la silueta ya se lee.
	_malla = MeshInstance3D.new()
	_malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_malla)

	var cuerpo := SphereMesh.new()
	cuerpo.radius = 0.17
	cuerpo.height = 0.34
	cuerpo.radial_segments = 10
	cuerpo.rings = 6
	_malla.mesh = cuerpo
	_malla.material_override = _material

	for lado in [-1.0, 1.0]:
		var bulto := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.13
		m.height = 0.26
		m.radial_segments = 10
		m.rings = 6
		bulto.mesh = m
		bulto.material_override = _material
		bulto.position = Vector3(lado * 0.12, 0.13, 0.0)
		bulto.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_malla.add_child(bulto)

	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.5, 0.62)
	luz.light_energy = 1.1
	luz.omni_range = 3.2
	luz.shadow_enabled = false
	add_child(luz)


func _process(delta: float) -> void:
	_t += delta
	position.y = _altura + sin(_t * 2.6) * VAIVEN
	if _malla != null:
		_malla.rotation.y += delta * 1.5
	if has_meta("acabando"):
		# Parpadeo de aviso. Desaparecer de golpe se lee como que el juego se lo
		# ha comido, no como que se acabó el tiempo.
		var v := 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * 14.0))
		_material.emission_energy_multiplier = 1.8 * v


func _al_entrar(cuerpo: Node3D) -> void:
	if not cuerpo.is_in_group("player"):
		return
	if GameManager.health >= GameManager.MAX_HEALTH:
		return
	GameManager.heal(CURA)
	AudioManager.play_sfx(SFX, -10.0, 0.08)
	CombatFeel.spawn_impact_particles(global_position, Color(1.0, 0.5, 0.65), 8)
	queue_free()
