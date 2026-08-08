extends Area3D
class_name EstrellaSueno
## Estrella de Sueño: el coleccionable del juego.
##
## ## Las dos reglas que la hacen justa
##
## **Tiene imán.** A los 8 años, calcular un salto para tocar exactamente un
## objeto flotante es frustrante y se abandona. Si te acercas lo suficiente, la
## estrella viene sola: acercarse ya es acertar.
##
## **No se pone nunca donde puedas caerte por cogerla.** Un coleccionable que
## castiga por intentar alcanzarlo enseña justo lo contrario de lo que
## queremos, que es explorar.
##
## Se ve de lejos porque gira, flota y brilla. Ver una a lo lejos es lo que hace
## que te desvíes del camino.

## Radio en el que empieza a venirse hacia la jugadora.
@export var radio_iman: float = 3.2
## Diferencia de altura máxima para que el imán tire.
##
## Sin este límite, una estrella colocada a 2,5 m sobre una plataforma se
## recoge desde el suelo sin saltar: el imán la baja solo. Se cargaba de un
## plumazo las estrellas secretas, que son justo las que piden explorar.
@export var alcance_vertical: float = 1.3
@export var velocidad_iman: float = 9.0
@export var giro: float = 1.8
## Amplitud del vaivén vertical, en metros.
@export var flotacion: float = 0.18
@export var color: Color = Color(1.0, 0.86, 0.35)
## Las escondidas valen igual pero se anuncian más al cogerlas.
@export var es_secreta: bool = false

var _recogida: bool = false
var _tiempo: float = 0.0
var _altura_base: float = 0.0
var _jugador: Node3D = null
var _visual: Node3D = null


func _ready() -> void:
	add_to_group("estrellas")
	_altura_base = global_position.y
	# Fases distintas para que un grupo de estrellas no lata al unísono, que
	# canta a repetición.
	_tiempo = global_position.x * 0.7 + global_position.z * 0.3
	_visual = get_node_or_null("Visual")
	body_entered.connect(_al_entrar)
	monitoring = true


func _physics_process(delta: float) -> void:
	if _recogida:
		return
	_tiempo += delta

	if _visual != null:
		_visual.rotate_y(giro * delta)
		_visual.position.y = sin(_tiempo * 2.2) * flotacion

	var jugador := _buscar_jugador()
	if jugador == null:
		return

	var hacia := jugador.global_position + Vector3.UP * 0.8 - global_position
	if absf(hacia.y) > alcance_vertical:
		return
	var distancia := hacia.length()
	if distancia < radio_iman:
		# Cuanto más cerca, más rápido: el tirón se nota y se agradece.
		var fuerza: float = velocidad_iman * (1.0 - distancia / radio_iman) + 1.5
		global_position += hacia.normalized() * fuerza * delta
		if distancia < 0.6:
			_recoger()


func _al_entrar(cuerpo: Node3D) -> void:
	if cuerpo.is_in_group("player"):
		_recoger()


func _recoger() -> void:
	if _recogida:
		return
	_recogida = true
	set_deferred("monitoring", false)

	GameManager.collect_star()
	CombatFeel.spawn_impact_particles(global_position, color, 18, 1.2)
	if es_secreta:
		EventBus.show_message.emit("¡Estrella secreta!", 2.0)

	# Se va hacia arriba encogiéndose, en vez de desaparecer de golpe: así se
	# entiende que la has cogido tú y no que se ha roto algo.
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "global_position:y", global_position.y + 1.4, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _visual != null:
		t.tween_property(_visual, "scale", Vector3.ZERO, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(queue_free)


func _buscar_jugador() -> Node3D:
	if _jugador != null and is_instance_valid(_jugador):
		return _jugador
	_jugador = get_tree().get_first_node_in_group("player") as Node3D
	return _jugador
