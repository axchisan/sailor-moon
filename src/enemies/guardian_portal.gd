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
## Para la barra de vida.
signal vida_cambiada(actual: int, maxima: int)

## Cada cuántos golpes normales mete uno al suelo, por fase.
##
## En la primera es raro —uno de cada cuatro— y a partir de ahí se va cerrando.
## Es lo que hace que la pelea deje de resolverse rodeándolo: el golpe normal se
## esquiva girando, este obliga a salir corriendo, y cuanto más avanza más hay
## que moverse de verdad.
## EL REPERTORIO. Añadir un ataque es añadir una fila aquí.
##
## Cada uno pide una respuesta DISTINTA, que es lo único que hace que una pelea
## larga siga teniendo interés en el minuto tres:
##
## - `puno` — corto y de frente. Se rodea.
## - `barrido` — a ras de suelo y ancho. **Se salta**; apartarse no basta.
## - `gancho` — alto, con las dos manos. Saltar es lo peor que se puede hacer:
##   hay que salir de delante.
## - `suelo` — círculo entero a su alrededor. Hay que **irse lejos**.
## - `embestida` — desde lejos, avanzando. Castiga quedarse a distancia mirando.
##
## `sigue` es cuánto corrige la puntería mientras carga, y `hasta` en qué punto
## deja de corregir. Ahí está la mitad del asunto: si todos siguieran igual, la
## respuesta sería siempre la misma y daría igual cuál viniera.
const REPERTORIO := [
	{"id": "puno", "anim": "golpe", "aviso": 0.95, "activo": 0.22, "resto": 0.85,
		"cerca": 0.0, "lejos": 4.4, "peso": 3.0,
		"sigue": 1.0, "hasta": 0.7, "temblor": 0.5, "avanza": 4.2,
		"caja": Vector3(3.0, 2.2, 2.8), "alcance": 1.6, "centro_y": 1.3,
		"dano": "normal"},
	{"id": "barrido", "anim": "barrido", "aviso": 1.0, "activo": 0.3, "resto": 0.9,
		"cerca": 0.0, "lejos": 4.8, "peso": 2.5,
		"sigue": 0.45, "hasta": 0.55, "temblor": 0.6, "avanza": 3.4,
		"caja": Vector3(6.2, 1.0, 3.4), "alcance": 1.4, "centro_y": 0.45,
		"dano": "normal", "aviso_texto": "bajo"},
	{"id": "gancho", "anim": "gancho", "aviso": 1.15, "activo": 0.26, "resto": 1.0,
		"cerca": 0.0, "lejos": 4.2, "peso": 2.0,
		"sigue": 0.8, "hasta": 0.65, "temblor": 0.7, "avanza": 3.8,
		"caja": Vector3(3.6, 3.2, 3.0), "alcance": 1.5, "centro_y": 2.4,
		"dano": "normal", "aviso_texto": "alto"},
	{"id": "suelo", "anim": "golpe_suelo", "aviso": 1.55, "activo": 0.26, "resto": 1.15,
		"cerca": 0.0, "lejos": 7.5, "peso": 1.6,
		"sigue": 0.5, "hasta": 0.5, "temblor": 1.0,
		"area": true, "radio": 6.2, "alto": 3.0, "centro_y": 1.0,
		"dano": "suelo"},
	{"id": "embestida", "anim": "embestida", "aviso": 1.2, "activo": 0.75, "resto": 1.1,
		"cerca": 4.5, "lejos": 14.0, "peso": 3.0,
		"sigue": 1.3, "hasta": 0.8, "temblor": 0.8, "avanza": 9.5,
		"caja": Vector3(3.2, 2.6, 3.6), "alcance": 1.7, "centro_y": 1.2,
		"dano": "normal"},
]

## Cuántos golpes aguanta antes de acusar uno.
##
## SIN ESTO NO HAY PELEA. Cada golpe recibido lo mandaba a `Stagger`, así que
## pegando rápido se le encadenaba indefinidamente: no llegaba a atacar ni una
## vez. «Lo derroté golpeándolo rápido, ni se pudo defender» — literal, no era
## una forma de hablar.
##
## Ahora encaja tres seguidos sin inmutarse y acusa el cuarto. Se sigue viendo
## que le entran —parpadea y suena— pero no se le puede dejar clavado. Y en
## plena carga de un ataque no se aturde nunca: lo que ha empezado, lo termina.
const AGUANTE := [3, 4, 5]
var _encajados: int = 0

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


var _golpes_dados: int = 0

## SUS SONIDOS.
##
## Un jefe mudo de dos metros y medio no pesa: la mitad de que algo se lea como
## grande está en lo que suena al moverse, no en lo que mide. Los pasos son los
## que más trabajan aunque nadie los escuche a propósito.
const SFX_DESPERTAR := preload("res://assets/audio/sfx/jefe/despertar.ogg")
const SFX_PASO := [
	preload("res://assets/audio/sfx/jefe/paso_1.ogg"),
	preload("res://assets/audio/sfx/jefe/paso_2.ogg"),
]
const SFX_PUNO := preload("res://assets/audio/sfx/jefe/puno.ogg")
const SFX_TEMBLOR := preload("res://assets/audio/sfx/jefe/temblor.ogg")
const SFX_DERRUMBE := preload("res://assets/audio/sfx/jefe/derrumbe.ogg")
const SFX_ENCAJE := preload("res://assets/audio/sfx/jefe/paso_2.ogg")

## Cada cuánto pisa mientras anda. Sale de la animación: dos pasos por vuelta de
## `andar`, que dura dos segundos.
const PASO_CADA := 1.0
var _hasta_el_paso: float = 0.0

## El ataque de área usa sus propios números: pega más y empuja mucho más, que
## es lo que justifica salir corriendo en vez de aguantar.
@export var ataque_al_suelo: AttackData


func _ready() -> void:
	super()
	_animador = get_node_or_null("Animador") as AnimadorGuardian
	_ataque_normal = attack
	_velocidad_base = move_speed
	_giro_base = turn_speed
	add_to_group("jefes")
	_dormir()


## Elige el siguiente ataque y lo deja apuntado. Lo llaman `EWait` y `EApproach`.
##
## Filtra por distancia —de nada sirve barrer a alguien que está a diez metros—,
## descarta el último usado y sortea entre lo que queda. Lo de descartar el
## último es lo que más se nota: sin eso el azar repite, y dos barridos seguidos
## se leen como que el juego está roto, no como mala suerte.
func siguiente_ataque() -> String:
	var d := distance_to_target()
	var posibles: Array[Dictionary] = []
	var total := 0.0
	# Dos pasadas: la primera descarta el último usado, y solo si eso deja la
	# lista vacía se permite repetir.
	#
	# NO DEVOLVER NUNCA EL NOMBRE DE QUIEN PREGUNTA. La primera versión devolvía
	# «Approach» cuando no encajaba nada, y como es `EApproach` quien llama, se
	# transicionaba a sí mismo, volvía a preguntar y volvía a no encajar nada:
	# el juego se colgaba entero en un fotograma. Pasa solo a ciertas distancias
	# y con cierto ataque previo, que es lo que lo hacía difícil de ver venir.
	for pasada in 2:
		for ficha: Dictionary in REPERTORIO:
			if d < float(ficha["cerca"]) or d > float(ficha["lejos"]):
				continue
			if pasada == 0 and ficha["id"] == _ultimo_ataque:
				continue
			posibles.append(ficha)
			total += float(ficha["peso"]) * _apetito(ficha)
		if not posibles.is_empty():
			break

	if posibles.is_empty():
		# A esta distancia no le sirve ninguno. Se queda como está —el estado que
		# preguntó seguirá acercándose— y suelta la ficha para no bloquear turno.
		CombatDirector.release_token(self)
		return ""

	var dado := randf() * total
	_elegida = posibles[posibles.size() - 1]
	for ficha in posibles:
		dado -= float(ficha["peso"]) * _apetito(ficha)
		if dado <= 0.0:
			_elegida = ficha
			break
	_ultimo_ataque = str(_elegida["id"])
	_golpes_dados += 1
	return "Ataque"


## Cuánto le apetece cada ataque según la fase. Los gordos salen poco al
## principio y mucho al final: es lo que hace que la última fase se sienta
## distinta sin cambiar ningún número de daño.
func _apetito(ficha: Dictionary) -> float:
	var id: String = ficha["id"]
	if id == "suelo" or id == "gancho":
		return 0.6 + 0.5 * float(fase)
	if id == "embestida":
		return 0.8 + 0.35 * float(fase)
	return 1.0


var _elegida: Dictionary = {}
var _ultimo_ataque: String = ""


## HASTA DÓNDE SE PLANTEA ATACAR.
##
## Su `attack_range` son 3,9 m, y con eso el repertorio solo se consultaba a esa
## distancia: la embestida, que existe justamente para salir de lejos, **no se
## elegía nunca**. El guardián se quedaba plantado a cinco metros sin hacer nada
## mientras le pegaban desde fuera.
##
## Ahora el alcance sale del ataque de más largo que tenga. Si mañana se le añade
## uno que llegue a veinte metros, esto lo recoge solo.
func alcance_de_ataque() -> float:
	var mayor := attack_range
	for ficha: Dictionary in REPERTORIO:
		mayor = maxf(mayor, float(ficha["lejos"]))
	return mayor


func ficha_elegida() -> Dictionary:
	if _elegida.is_empty():
		return REPERTORIO[0]
	return _elegida


func datos_de(ficha: Dictionary) -> AttackData:
	if str(ficha.get("dano", "normal")) == "suelo" and ataque_al_suelo != null:
		return ataque_al_suelo
	return _ataque_normal


## Pone la animación y avisa por sonido de que viene algo.
func avisar_ataque(ficha: Dictionary) -> void:
	if _animador != null:
		_animador.poner(str(ficha["anim"]), true)


func sonar_impacto(ficha: Dictionary) -> void:
	if bool(ficha.get("area", false)) or str(ficha["id"]) == "embestida":
		AudioManager.play_sfx(SFX_TEMBLOR, 1.0, 0.0)
	else:
		AudioManager.play_sfx(SFX_PUNO, -2.0, 0.06)


var _ataque_normal: AttackData = null


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
	# Grave y sin variar el tono: es piedra de verdad, no un efecto de dibujos.
	AudioManager.play_sfx(SFX_DESPERTAR, -2.0, 0.0)
	await get_tree().create_timer(despertar_dura).timeout
	if defeated:
		return
	set_physics_process(true)
	hurtbox.set_deferred("monitorable", true)
	_aplicar_fase(0)


## Los pasos, contados a mano.
##
## Lo suyo sería dispararlos desde la animación con una pista de llamadas, pero
## las animaciones vienen de un `.glb` y ahí no hay dónde meterlas. Contando el
## tiempo mientras se mueve de verdad se consigue lo mismo, y si algún día se
## queda atascado contra un muro tampoco sonarán pasos: no se mueve, no pisa.
func _physics_process(delta: float) -> void:
	super(delta)
	if not despierto or defeated:
		return
	if velocity.length() < 0.6:
		_hasta_el_paso = 0.25
		if _animador != null:
			_animador.ritmo_normal()
		return
	if _animador != null:
		_animador.ritmo_de_paso(velocity.length(), _velocidad_base)
	_hasta_el_paso -= delta
	if _hasta_el_paso <= 0.0:
		_hasta_el_paso = PASO_CADA / maxf(BRIO[fase], 0.1)
		AudioManager.play_sfx(SFX_PASO[randi() % SFX_PASO.size()], -6.0, 0.06)


## AGUANTA LOS GOLPES EN VEZ DE ENCADENARSE.
##
## No se llama a `super()` a propósito: lo que hace el `Enemy` normal es mandarse
## a `Stagger` con cada golpe, y eso en un jefe con treinta y ocho de vida
## significa que quien pegue rápido gana sin que el otro llegue a moverse.
##
## Aquí el daño entra igual —y se ve igual, con su parpadeo y su chispa—, pero
## solo cada cuatro golpes lo acusa. Y **nunca mientras está atacando**: lo que
## empieza, lo termina. Ese es el trato: le puedes meter todo lo que quieras,
## pero el golpe que ya viene te llega.
func _on_hurtbox_hit(player_hitbox: Hitbox) -> void:
	if not despierto or defeated:
		return
	if _bloquea(player_hitbox):
		_al_bloquear()
		return

	var golpe := player_hitbox.attack
	var dano: int = golpe.damage if golpe != null else 1
	health -= dano

	CombatFeel.impact_from_attack(global_position + Vector3.UP * 1.4, golpe)
	CombatFeel.flash(mesh)
	AudioManager.play_sfx(SFX_ENCAJE, -5.0, 0.12)
	vida_cambiada.emit(health, max_health)

	if health <= 0:
		var hacia := player_hitbox.get_knockback_direction(global_position)
		state_machine.transition_to("Defeated",
			{"knockback": hacia * 3.0, "up": 1.0})
		return

	_encajados += 1
	var topa: int = AGUANTE[clampi(fase, 0, AGUANTE.size() - 1)]
	var atacando := state_machine.get_state_name() == "Ataque"
	if _encajados >= topa and not atacando:
		_encajados = 0
		CombatDirector.release_token(self)
		# Empujón corto: es de piedra y pesa. Salir volando como un peluche le
		# quitaría de golpe todo lo que cuesta que parezca pesado.
		var hacia := player_hitbox.get_knockback_direction(global_position)
		state_machine.transition_to("Stagger",
			{"knockback": hacia * 2.2, "up": 0.0})

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
	AudioManager.play_sfx(SFX_DERRUMBE, 0.0, 0.0)
	EventBus.show_message.emit("El guardián se inclina. La puerta está libre.", 4.0)
	derrotado.emit()
