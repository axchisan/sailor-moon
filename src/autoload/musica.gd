extends Node
## Decide qué canción suena en cada momento y la cambia sin que se note.
##
## ## Por qué hace falta un director
##
## Poner la música desde cada sitio —el nivel arranca la del parque, la arena la
## del combate, el jefe la suya— parece más simple y se rompe enseguida: al
## salir de una arena hay que acordarse de volver a la anterior, y si dos cosas
## piden música a la vez gana la última que hable, no la que importa.
##
## Aquí hay **una pila de capas**. Cada sitio *pide* su música y la *suelta*
## cuando termina; suena siempre la de más prioridad que esté pedida, y al
## soltarla se vuelve sola a la de debajo. Nadie tiene que acordarse de nada.
##
## ## Las reglas
##
## - **Una canción por sitio, y se queda.** Cambiar de tema cada dos minutos
##   marea. El cruce dura un segundo largo, que es lo justo para que no se note
##   el corte sin que se solapen dos melodías.
## - **Al hablar baja, no se corta.** Cortarla deja un silencio que suena a
##   error; bajarla a un tercio deja oír la voz sin que se note el cambio.
## - **El silencio también se usa.** Antes de que el guardián despierte no suena
##   nada: dos segundos de nada hacen más por ese momento que cualquier redoble.

const MENU := preload("res://assets/audio/musica/menu.mp3")
const PARQUE := preload("res://assets/audio/musica/parque.mp3")
const COMBATE := preload("res://assets/audio/musica/combate.mp3")
const JEFE := preload("res://assets/audio/musica/jefe.mp3")
const PORTAL := preload("res://assets/audio/musica/portal.mp3")
const ENCUENTRO := preload("res://assets/audio/musica/encuentro.mp3")

## De menos a más importante. La que esté pedida y más abajo en esta lista es la
## que suena.
enum Capa {
	FONDO,      ## el sitio donde se está: menú, parque, claro
	MOMENTO,    ## una conversación, un rato especial
	COMBATE,    ## una arena en marcha
	JEFE,       ## el guardián
	NADA,       ## silencio a propósito, y manda sobre todo lo demás
}

const POR_CAPA := {
	"menu": MENU,
	"parque": PARQUE,
	"combate": COMBATE,
	"jefe": JEFE,
	"portal": PORTAL,
	"encuentro": ENCUENTRO,
}

## Cuánto dura el cruce entre canciones.
const CRUCE := 1.4
## A cuánto baja mientras alguien habla.
const AGACHADA := 0.32

var _pedidas: Dictionary = {}
var _sonando: String = ""
var _agachada: bool = false


func _ready() -> void:
	EventBus.arena_started.connect(_al_empezar_arena)
	EventBus.arena_cleared.connect(_al_limpiar_arena)


## Pide una canción en una capa. Mientras nadie pida algo más importante, suena.
func pedir(capa: Capa, cual: String) -> void:
	_pedidas[capa] = cual
	_revisar()


## Suelta la capa. Vuelve sola la de debajo, sin que nadie tenga que recordarla.
func soltar(capa: Capa) -> void:
	_pedidas.erase(capa)
	_revisar()


## Silencio a propósito, por encima de todo. Para los momentos en que la música
## estorbaría — la aparición del guardián, sobre todo.
func callar() -> void:
	pedir(Capa.NADA, "")


func destapar() -> void:
	soltar(Capa.NADA)


## Baja el volumen sin cambiar de canción. Para los diálogos.
func agachar(si: bool) -> void:
	if _agachada == si:
		return
	_agachada = si
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		return
	var destino := Settings.music_volume * (AGACHADA if si else 1.0)
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001))),
		db_to_linear(AudioServer.get_bus_volume_db(idx)), destino, 0.4)


func _revisar() -> void:
	var mejor := -1
	for capa: int in _pedidas:
		if capa > mejor:
			mejor = capa
	if mejor < 0:
		if not _sonando.is_empty():
			_sonando = ""
			AudioManager.stop_music(true)
		return

	var quiere: String = _pedidas[mejor]
	if quiere == _sonando:
		return
	_sonando = quiere
	if quiere.is_empty():
		AudioManager.stop_music(true)
		return
	var pieza: AudioStream = POR_CAPA.get(quiere, null)
	if pieza == null:
		return
	# Los mp3 no traen el bucle marcado y una canción de fondo que se acaba a los
	# dos minutos deja el resto de la partida en silencio, sin ningún error.
	if pieza is AudioStreamMP3:
		(pieza as AudioStreamMP3).loop = true
	AudioManager.play_music(pieza, true)


func _al_empezar_arena(_id: String, _oleadas: int) -> void:
	pedir(Capa.COMBATE, "combate")


func _al_limpiar_arena(_id: String) -> void:
	soltar(Capa.COMBATE)
