extends Enemy
class_name GuardianPortal
## El guardián del portal: el jefe que cierra el Acto 1.
##
## ## Qué es
##
## La misma piedra de la ruina, levantándose. No es un enemigo grande: es la
## propia puerta diciendo que todavía no. Por eso lo primero que hace es
## despertar delante de quien llega —cinco segundos largos desde el ovillo hasta
## ponerse de pie— y hasta que no acaba no se pelea. Ese rato es todo lo que hay
## para entender contra qué se está.
##
## ## Cómo pelea
##
## Lo mismo que ya se sabe hacer, pero con más peso. No estrena mecánicas: un
## jefe que pide algo que el nivel no ha enseñado no es difícil, es injusto.
## Pega despacio y avisando —el aviso dura más de un segundo, se le ve cargar el
## brazo— y a cambio el golpe duele y empuja lejos.
##
## Gira lento a propósito (`turn_speed` 2,6 contra los 8-9 de los demás). Ahí
## está toda la pelea: rodearlo funciona, quedarse delante no. Es la lección del
## Cofrecito otra vez, pero contra algo que no se puede matar a base de insistir.
##
## ## Las fases
##
## Al bajar de dos tercios y de un tercio de vida se para, ruge y acelera. Sirve
## para dos cosas: parte una pelea larga en tres tramos —una barra que baja sin
## que pase nada se hace eterna a los ocho años— y avisa de que la cosa cambia
## antes de que cambie, en vez de después.

## Con cuánta vida restante empieza cada fase, en tanto por uno.
const FASES := [0.66, 0.33]
## Cuánto más rápido va en cada fase.
const BRIO := [1.0, 1.22, 1.45]

signal fase_cambiada(fase: int)
## La suelta al caer. El nivel escucha esto para abrir la puerta.
signal derrotado

@export_group("Guardián")
## Lo que tarda en despertar. Mientras dura no se mueve ni se le puede hacer
## daño: es su presentación, no un momento para pegarle por la espalda.
@export var despertar_dura: float = 5.4
## Cuánto sube el aguante en cada fase (menos aturdimiento al recibir).
@export var aguante_por_fase: float = 0.35

var fase: int = 0
var despierto: bool = false

var _animador: AnimadorGuardian = null
var _velocidad_base: float = 0.0
var _giro_base: float = 0.0


func _ready() -> void:
	super()
	_animador = get_node_or_null("Animador") as AnimadorGuardian
	_velocidad_base = move_speed
	_giro_base = turn_speed
	add_to_group("jefes")
	_dormir()


## Dormido: quieto, sin pegar y sin recibir. Empieza así aunque la arena ya
## haya arrancado, y no es un enemigo más hasta que termina de levantarse.
func _dormir() -> void:
	despierto = false
	set_physics_process(false)
	hurtbox.set_deferred("monitorable", false)
	if state_machine != null:
		state_machine.transition_to("Idle")


## Lo llama la arena cuando la jugadora entra. Es el pistoletazo del jefe.
func despertar() -> void:
	if despierto:
		return
	despierto = true
	if _animador != null:
		# `manda` = true: el estado de debajo ya puede estar decidiendo cosas,
		# pero la animación de despertar no se corta por nada.
		_animador.poner("despertar", true)
	EventBus.show_message.emit("El guardián de la puerta despierta…", 3.2)
	CombatFeel.shake(0.5, 0.9)
	await get_tree().create_timer(despertar_dura).timeout
	if defeated:
		return
	set_physics_process(true)
	hurtbox.set_deferred("monitorable", true)
	_aplicar_fase(0)


func _on_hurtbox_hit(player_hitbox: Hitbox) -> void:
	if not despierto or defeated:
		return
	super(player_hitbox)
	if defeated:
		return
	_revisar_fase()


## ¿Toca cambiar de fase? Se mira después de cada golpe recibido.
func _revisar_fase() -> void:
	var resto := float(health) / float(maxi(max_health, 1))
	var toca := 0
	for i in FASES.size():
		if resto <= FASES[i]:
			toca = i + 1
	if toca > fase:
		_aplicar_fase(toca)
		_rugir()


func _aplicar_fase(nueva: int) -> void:
	fase = clampi(nueva, 0, BRIO.size() - 1)
	move_speed = _velocidad_base * BRIO[fase]
	turn_speed = _giro_base * (1.0 + 0.16 * float(fase))
	fase_cambiada.emit(fase)


## El rugido entre fases. Se para, avisa, y entonces va a por ti.
##
## Es tiempo regalado en mitad de la pelea, y por eso funciona: da un respiro
## justo cuando la cosa se pone peor, y hace que ponerse peor se note.
func _rugir() -> void:
	if _animador != null:
		_animador.poner("rugido", true)
	CombatFeel.shake(0.55, 0.75)
	set_color(telegraph_color)
	var t := create_tween()
	t.tween_interval(0.5)
	t.tween_callback(func() -> void: reset_color())
	if fase >= BRIO.size() - 1:
		EventBus.show_message.emit("¡El guardián se enfurece!", 2.2)


func defeat() -> void:
	if defeated:
		return
	super()
	if _animador != null:
		_animador.poner("derrota", true)
	# El temblor largo es lo que dice que ha caído algo grande. Con el mismo
	# golpecito que un peluche, el jefe se muere igual que la morralla.
	CombatFeel.shake(1.2, 1.4)
	EventBus.show_message.emit("El guardián se inclina. La puerta está libre.", 4.0)
	derrotado.emit()
