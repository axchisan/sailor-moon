extends Node
class_name AmbienteNivel
## El fondo sonoro del parque: pájaros, agua y el crepitar de los faroles.
##
## No es música — va por debajo de ella y no se calla nunca. Es lo que hace que
## el parque suene a sitio en vez de a escenario: sin nada de fondo, el silencio
## entre pisada y pisada delata que ahí no hay nada.
##
## El general suena en la cabeza de la jugadora (2D, sin posición). Los de sitio
## —el agua, el fuego— van con `AudioStreamPlayer3D`, así que suben al acercarse
## y bajan al alejarse solos, sin una línea de código que lo gestione.

const BOSQUE := preload("res://assets/audio/ambiente/parque.mp3")
const AGUA := preload("res://assets/audio/ambiente/agua.mp3")
const FUEGO := preload("res://assets/audio/ambiente/fuego.mp3")
const PORTAL := preload("res://assets/audio/ambiente/portal.mp3")

## Muy bajo a propósito. Un ambiente que se oye es un ambiente mal puesto: tiene
## que notarse cuando se quita, no cuando está.
@export var volumen_fondo: float = -26.0
@export var volumen_agua: float = -14.0
@export var volumen_fuego: float = -18.0
@export var volumen_portal: float = -16.0


func _ready() -> void:
	_fondo()


func _fondo() -> void:
	var p := AudioStreamPlayer.new()
	p.stream = BOSQUE
	p.bus = "SFX"
	p.volume_db = volumen_fondo
	add_child(p)
	_en_bucle(p.stream)
	p.play()


## Pone un sonido de sitio en un punto del mapa. El alcance decide desde dónde
## empieza a oírse.
func en_un_sitio(cual: AudioStream, donde: Vector3, alcance: float,
		volumen: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = cual
	p.bus = "SFX"
	p.volume_db = volumen
	p.max_distance = alcance
	p.unit_size = alcance * 0.35
	# Sin esto se oiría igual de fuerte a un metro que a treinta, que es lo que
	# hace que un sonido "de sitio" no se lea como que viene de ningún sitio.
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(p)
	p.global_position = donde
	_en_bucle(p.stream)
	p.play()
	return p


func agua_en(donde: Vector3) -> void:
	en_un_sitio(AGUA, donde, 26.0, volumen_agua)


func fuego_en(donde: Vector3) -> void:
	en_un_sitio(FUEGO, donde, 9.0, volumen_fuego)


func portal_en(donde: Vector3) -> void:
	en_un_sitio(PORTAL, donde, 20.0, volumen_portal)


## El bucle se marca en el propio recurso y NO se rearranca desde `finished`.
##
## Reconectar `finished` a `play()` parece la red de seguridad obvia, y es una
## trampa: si el sonido no carga, termina en el mismo instante en que empieza,
## vuelve a arrancar, vuelve a terminar… y el juego se cuelga entero en un
## fotograma. Con siete de estos sonando a la vez, basta que falle uno.
static func _en_bucle(cual: AudioStream) -> void:
	if cual is AudioStreamMP3:
		(cual as AudioStreamMP3).loop = true
	elif cual is AudioStreamOggVorbis:
		(cual as AudioStreamOggVorbis).loop = true
