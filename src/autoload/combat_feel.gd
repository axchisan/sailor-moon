extends Node
## Todo el "jugo" del combate centralizado en un único servicio.
##
## Cuando el combate se sienta flojo, este es el ÚNICO archivo que hay que tocar.
## En un beat 'em up esto importa más que cualquier sistema: un golpe con hit
## stop, sacudida, partículas y sonido se siente diez veces mejor que uno sin
## ellos, aunque el daño sea idéntico.
##
## Truco de trabajo: `set_juice_enabled(false)` lo apaga todo. Jugar un minuto
## sin jugo y otro con jugo es la mejor forma de ver cuánto está aportando.

signal shake_requested(strength: float, duration: float)

const IMPACT_PARTICLES := preload("res://scenes/fx/impact_particles.tscn")

const SFX_HIT := preload("res://assets/audio/sfx/hit.wav")
const SFX_HIT_HEAVY := preload("res://assets/audio/sfx/hit_heavy.wav")
const SFX_HURT := preload("res://assets/audio/sfx/hurt.wav")
const SFX_DEFEAT := preload("res://assets/audio/sfx/purify.wav")
const SFX_BLOCK := preload("res://assets/audio/sfx/block.wav")
const SFX_SPECIAL := preload("res://assets/audio/sfx/special.wav")
## EL GOLPE QUE NO ACIERTA TAMBIÉN SUENA.
##
## Sin esto, fallar es silencio: el botón se pulsa, el brazo se mueve y no pasa
## nada, que se lee como que el juego no ha registrado el toque. El silbido del
## brazo al cortar el aire dice «te he oído, has fallado», que es información
## distinta de «no te he oído».
const SFX_AIRE := [
	preload("res://assets/audio/sfx/combate/aire_1.wav"),
	preload("res://assets/audio/sfx/combate/aire_2.wav"),
	preload("res://assets/audio/sfx/combate/aire_3.wav"),
]


## Lo llama el estado de ataque al arrancar el golpe.
func golpe_al_aire() -> void:
	AudioManager.play_sfx(SFX_AIRE[randi() % SFX_AIRE.size()], -20.0, 0.14)
## La transformación va PRESTADA de momento: no hay sonido propio y hace falta.
##
## Es el momento más importante del juego y suena a ataque especial, que no es
## lo mismo — el especial es un golpe y esto es una aparición. Cuando se genere
## el suyo (campanillas subiendo, un golpe de arpa, algo con brillo), se cambian
## estas dos líneas y ya está.
const SFX_TRANSFORMACION_INICIO := preload("res://assets/audio/sfx/purify.wav")
const SFX_TRANSFORMACION := preload("res://assets/audio/sfx/special.wav")

## Presets de impacto por tipo de golpe.
const IMPACT_LIGHT := {"stop": 0.04, "shake": 0.15, "shake_time": 0.12}
const IMPACT_MEDIUM := {"stop": 0.06, "shake": 0.25, "shake_time": 0.18}
const IMPACT_HEAVY := {"stop": 0.10, "shake": 0.50, "shake_time": 0.30}
const IMPACT_SPECIAL := {"stop": 0.18, "shake": 0.80, "shake_time": 0.50}

var juice_enabled: bool = true

var _hit_stop_active := false
var _fx_root: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# --- API principal -----------------------------------------------------------

## Un impacto completo: congela, sacude, escupe partículas y suena.
func impact(world_position: Vector3, stop: float = 0.06, shake_strength: float = 0.25,
		shake_time: float = 0.18, heavy: bool = false) -> void:
	if not juice_enabled:
		return
	hit_stop(stop)
	shake(shake_strength, shake_time)
	spawn_impact_particles(world_position)
	AudioManager.play_sfx(SFX_HIT_HEAVY if heavy else SFX_HIT, -2.0, 0.12)


## Versión que toma los valores de un AttackData.
func impact_from_attack(world_position: Vector3, attack: AttackData) -> void:
	if attack == null:
		impact(world_position)
		return
	impact(world_position, attack.hit_stop, attack.shake, 0.18, attack.hit_stop >= 0.09)


func player_hurt(world_position: Vector3) -> void:
	if not juice_enabled:
		return
	hit_stop(0.08)
	shake(0.45, 0.35)
	spawn_impact_particles(world_position, Color(1.0, 0.45, 0.55))
	AudioManager.play_sfx(SFX_HURT, -1.0, 0.06)


## El escudo aguanta el golpe. Suena metálico y NO congela el juego: un hit stop
## premiaría un golpe que no ha servido de nada. La sacudida es mínima y las
## chispas son doradas, para que se lea distinto de un impacto bueno.
func block(world_position: Vector3) -> void:
	if juice_enabled:
		shake(0.12, 0.10)
	spawn_impact_particles(world_position, Color(1.0, 0.92, 0.5), 12, 0.7)
	AudioManager.play_sfx(SFX_BLOCK, -3.0, 0.08)


## Golpe final. Pega más fuerte que un impacto normal para que se note que el
## enemigo ha caído, no que le has dado uno más.
func defeat(world_position: Vector3) -> void:
	if juice_enabled:
		hit_stop(0.09)
		shake(0.40, 0.28)
	spawn_impact_particles(world_position, Color(1.0, 0.95, 0.6), 40, 1.8)
	AudioManager.play_sfx(SFX_DEFEAT, -2.0, 0.08)


func special(world_position: Vector3) -> void:
	if juice_enabled:
		hit_stop(IMPACT_SPECIAL["stop"])
		shake(IMPACT_SPECIAL["shake"], IMPACT_SPECIAL["shake_time"])
	spawn_impact_particles(world_position, Color(1.0, 0.85, 1.0), 60, 2.2)
	AudioManager.play_sfx(SFX_SPECIAL, 0.0, 0.0)


## La transformación: el momento más importante que tiene el juego.
##
## No es un golpe más, así que no se parece a ninguno. Un impacto va de contarlo
## en dos fotogramas —congelar, sacudir, ya está—; esto va de lo contrario, de
## que dure y se mire. Es la escena que la jugadora va a querer volver a ver.
##
## Tres tandas de partículas encadenadas en vez de un estallido:
##
##   1. Al alzar el broche sube un remolino desde los pies, flojo
##   2. En el destello, el estallido grande y blanco
##   3. Y una lluvia lenta que cae mientras se sostiene la pose
##
## El hit stop va DESPUÉS del destello y no antes: parar el tiempo justo cuando
## la luz llena la pantalla es lo que hace que el momento se sienta importante.
func transformacion(world_position: Vector3, fase: String) -> void:
	var centro := world_position + Vector3.UP * 0.9
	match fase:
		"arranque":
			spawn_impact_particles(centro, Color(1.0, 0.92, 0.55), 22, 1.4)
			if juice_enabled:
				shake(0.05, 0.35)
			AudioManager.play_sfx(SFX_TRANSFORMACION_INICIO, -3.0, 0.0)
		"destello":
			spawn_impact_particles(centro, Color(1.0, 1.0, 1.0), 70, 2.6)
			spawn_impact_particles(centro, Color(1.0, 0.78, 0.95), 45, 2.0)
			if juice_enabled:
				hit_stop(0.16)
				shake(0.35, 0.5)
			AudioManager.play_sfx(SFX_TRANSFORMACION, 0.0, 0.0)
		"pose":
			spawn_impact_particles(centro, Color(1.0, 0.9, 0.7), 30, 1.8)
		_:
			push_warning("CombatFeel: fase de transformación desconocida '%s'" % fase)


# --- Piezas ------------------------------------------------------------------

## Congela el juego un instante al conectar. Es el truco de game feel más
## potente que existe y el más barato de implementar.
func hit_stop(duration: float) -> void:
	if duration <= 0.0 or _hit_stop_active or not juice_enabled:
		return
	_hit_stop_active = true
	Engine.time_scale = 0.05
	# ¡OJO! El cuarto parámetro (ignore_time_scale) DEBE ser true.
	# Si no, el temporizador se congela con el juego y nunca se recupera
	# la velocidad normal. Es el error clásico al implementar hit stop.
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stop_active = false


## La cámara escucha esta señal. CombatFeel no conoce a la cámara.
func shake(strength: float, duration: float) -> void:
	if strength <= 0.0 or not juice_enabled:
		return
	shake_requested.emit(strength, duration)


## Cuántos estallidos pueden verse a la vez. Con vidas de un segundo escaso, doce
## sobran incluso en la última arena; si se pasaran, el más viejo se corta y no
## se nota entre el resto del combate.
const RESERVA_PARTICULAS := 12

var _particulas: Array[Node3D] = []
var _siguiente_particula: int = 0


## Estallido de partículas en un punto del mundo.
##
## Coge el siguiente emisor de la reserva en vez de instanciar uno nuevo. Los
## tirones al coger una Estrella o al pegar venían de aquí: instanciar la escena
## y duplicar su material en mitad de la acción obliga a crear recursos de GPU
## justo en el fotograma donde más falta hace no hacerlo.
func spawn_impact_particles(world_position: Vector3, color: Color = Color(1.0, 0.65, 0.85),
		amount: int = 18, scale_factor: float = 1.0) -> void:
	if not juice_enabled:
		return
	_asegurar_reserva()
	if _particulas.is_empty():
		return
	var fx := _particulas[_siguiente_particula]
	_siguiente_particula = (_siguiente_particula + 1) % _particulas.size()
	fx.global_position = world_position
	if fx.has_method("burst"):
		fx.call("burst", color, amount, scale_factor)


## Monta la reserva la primera vez, y otra vez si se ha cambiado de escena.
##
## No se hace en `_ready` porque este autoload arranca antes que el nivel: los
## emisores tienen que colgar de la escena en curso para que se limpien solos al
## cambiar de nivel.
func _asegurar_reserva() -> void:
	if not _particulas.is_empty() and is_instance_valid(_particulas[0]) \
			and _particulas[0].is_inside_tree():
		return
	_particulas.clear()
	_siguiente_particula = 0
	var root := _get_fx_root()
	if root == null:
		return
	for i in RESERVA_PARTICULAS:
		var fx: Node3D = IMPACT_PARTICLES.instantiate()
		fx.name = "Particulas%d" % i
		root.add_child(fx)
		# Lejos y bajo tierra: el precalentado tiene que compilar el shader sin
		# que se vea un chispazo en mitad del parque al empezar la partida.
		fx.global_position = Vector3(0.0, -500.0, 0.0)
		if fx.has_method("precalentar"):
			fx.call("precalentar")
		_particulas.append(fx)


## Destello blanco sobre un MeshInstance3D. Requiere material propio por
## instancia; de lo contrario destellarían todos los enemigos a la vez.
##
## Acepta materiales PBR (cápsulas de prototipo) y MToon (modelos reales). Sin
## esta doble ruta, los enemigos con modelo se quedaban sin destello al recibir
## el golpe y el impacto perdía la mitad de su fuerza.
func flash(mesh: MeshInstance3D, duration: float = 0.09) -> void:
	if not juice_enabled or mesh == null:
		return
	var material := mesh.get_active_material(0)
	if material == null:
		return

	var toon := material as ShaderMaterial
	var pbr := material as BaseMaterial3D
	var original: Color

	if toon != null:
		original = toon.get_shader_parameter("_Color")
		toon.set_shader_parameter("_Color", Color.WHITE)
	elif pbr != null:
		original = pbr.albedo_color
		pbr.albedo_color = Color(1, 1, 1, original.a)
	else:
		return

	await get_tree().create_timer(duration, true, false, true).timeout
	if not is_instance_valid(mesh):
		return
	if toon != null:
		toon.set_shader_parameter("_Color", original)
	elif pbr != null:
		pbr.albedo_color = original


func set_juice_enabled(enabled: bool) -> void:
	juice_enabled = enabled
	if not enabled:
		Engine.time_scale = 1.0


func _get_fx_root() -> Node:
	if _fx_root != null and is_instance_valid(_fx_root):
		return _fx_root
	_fx_root = get_tree().current_scene
	return _fx_root
