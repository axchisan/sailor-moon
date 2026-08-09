extends Node
class_name ObjetivosNivel
## La lista de cosas que hay que hacer para cerrar un nivel.
##
## ## Por qué existe
##
## El Nivel 1 se acababa matando lo que había y hablando con Mercury. Eso no da
## para un acto, y sobre todo **no da razones para recorrer el sitio**: con el
## parque ampliado y campo abierto alrededor, sin objetivos repartidos todo eso
## es decorado caro.
##
## ## Las reglas
##
## - **Nada se puede fallar para siempre.** Todo se puede volver a intentar, y
##   lo recogido no se pierde al morir. A los ocho años, perder una hora de
##   juego por un fallo no enseña nada, solo hace llorar.
## - **Todo se anuncia al cumplirse.** Un objetivo que se completa en silencio
##   es un objetivo que no existe.
## - **El último abre la salida.** No hay que ir a buscar a nadie a preguntar.
##
## ## Cómo se declara
##
## Cada objetivo es una entrada de `LISTA` con su `id`, el texto que se le
## enseña a la jugadora y de qué señal del `EventBus` se entera. Añadir uno
## nuevo es añadir una fila, no tocar código.

signal objetivo_cumplido(id: String, hechos: int, total: int)
signal todos_cumplidos

## Los objetivos del Acto 1. El orden es el que se muestra.
const LISTA: Array[Dictionary] = [
	{"id": "arenas", "texto": "Despeja los tres caminos", "meta": 3},
	{"id": "faroles", "texto": "Enciende los tres faroles", "meta": 3},
	{"id": "mercury", "texto": "Encuentra a Amy", "meta": 1},
	{"id": "estrellas", "texto": "Reúne las 7 Estrellas de Sueño", "meta": 7},
	{"id": "rincones", "texto": "Recorre los cuatro rincones del parque", "meta": 4},
	{"id": "guardian", "texto": "Derrota al guardián", "meta": 1},
]

@export var level_id: String = "nivel_1"
## Anuncia cada objetivo al cumplirse.
@export var avisar: bool = true

var _progreso: Dictionary = {}
var _cerrado: bool = false


func _ready() -> void:
	for ficha in LISTA:
		_progreso[ficha["id"]] = 0

	EventBus.arena_cleared.connect(_al_limpiar_arena)
	EventBus.star_collected.connect(_al_coger_estrella)


## Suma uno a un objetivo. Lo llaman los faroles, los encuentros y los rincones,
## que no tienen una señal propia en el `EventBus`.
func anotar(id: String, cantidad: int = 1) -> void:
	if _cerrado or not _progreso.has(id):
		return
	var meta := _meta_de(id)
	var antes: int = _progreso[id]
	if antes >= meta:
		return
	_progreso[id] = mini(antes + cantidad, meta)
	if _progreso[id] >= meta:
		_anunciar(id)
	_comprobar_final()


## Fija el valor de un contador, en vez de sumarle. Para lo que ya lleva su
## propia cuenta —las Estrellas las cuenta `GameManager`—, sumar aquí daría un
## total distinto en cuanto se recargue el nivel.
func fijar(id: String, valor: int) -> void:
	if _cerrado or not _progreso.has(id):
		return
	var meta := _meta_de(id)
	var antes: int = _progreso[id]
	_progreso[id] = clampi(valor, 0, meta)
	if antes < meta and _progreso[id] >= meta:
		_anunciar(id)
	_comprobar_final()


func esta_hecho(id: String) -> bool:
	return _progreso.get(id, 0) >= _meta_de(id)


func cuantos_hechos() -> int:
	var total := 0
	for ficha in LISTA:
		if esta_hecho(ficha["id"]):
			total += 1
	return total


## Para el HUD y el panel de pausa: lista de `{texto, hecho, cuantos, meta}`.
func resumen() -> Array[Dictionary]:
	var salida: Array[Dictionary] = []
	for ficha in LISTA:
		var id: String = ficha["id"]
		salida.append({
			"texto": ficha["texto"],
			"hecho": esta_hecho(id),
			"cuantos": _progreso.get(id, 0),
			"meta": _meta_de(id),
		})
	return salida


func _al_limpiar_arena(id: String) -> void:
	# El guardián cuenta aparte: es el cierre, no una arena más.
	if id.ends_with("guardian"):
		anotar("guardian")
	else:
		anotar("arenas")


func _al_coger_estrella(total: int) -> void:
	fijar("estrellas", total)


func _anunciar(id: String) -> void:
	var texto := ""
	for ficha in LISTA:
		if ficha["id"] == id:
			texto = ficha["texto"]
			break
	objetivo_cumplido.emit(id, cuantos_hechos(), LISTA.size())
	if avisar:
		EventBus.show_message.emit("✓ %s  (%d de %d)" % [
			texto, cuantos_hechos(), LISTA.size()], 2.4)


func _comprobar_final() -> void:
	if _cerrado or cuantos_hechos() < LISTA.size():
		return
	_cerrado = true
	todos_cumplidos.emit()
	if avisar:
		EventBus.show_message.emit("¡El camino al siguiente lugar se ha abierto!", 3.5)


func _meta_de(id: String) -> int:
	for ficha in LISTA:
		if ficha["id"] == id:
			return ficha["meta"]
	return 1
