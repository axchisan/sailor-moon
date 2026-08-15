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
	{"id": "faroles", "texto": "Enciende los seis faroles", "meta": 6},
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
	# En grupo para que el portal pueda preguntarle qué falta sin cablear rutas.
	add_to_group("objetivos")
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
			"id": id,
			"texto": _texto_de(id),
			"hecho": esta_hecho(id),
			"cuantos": _progreso.get(id, 0),
			"meta": _meta_de(id),
		})
	return salida


func _al_limpiar_arena(id: String) -> void:
	# EL GUARDIÁN CUENTA EN LOS DOS SITIOS.
	#
	# Antes contaba solo como «Derrota al guardián», así que «Despeja los tres
	# caminos» únicamente podía recibir dos: las otras dos arenas. El objetivo
	# era **imposible de terminar** y con él el nivel entero, porque la puerta
	# espera a que estén los seis.
	#
	# Y las tres arenas son tres: dos de camino y la del guardián. Que limpiarla
	# marque dos casillas a la vez no es un fallo — es el final de la lista, y
	# que se cierren dos cosas de golpe ahí está bien.
	if id.ends_with("guardian"):
		anotar("guardian")
	anotar("arenas")


func _al_coger_estrella(total: int) -> void:
	fijar("estrellas", total)


func _anunciar(id: String) -> void:
	var texto := _texto_de(id)
	objetivo_cumplido.emit(id, cuantos_hechos(), LISTA.size())
	if avisar:
		# EL RECUENTO VA EN SU PROPIA LÍNEA Y DICE DE QUÉ ES.
		#
		# Antes era «✓ Enciende los seis faroles  (2 de 6)», y ese «2 de 6» son
		# objetivos del parque, no faroles. Pegado a un texto que habla de seis
		# faroles no hay forma de leerlo bien: parecía que al encender el sexto
		# el juego solo contaba dos, y el conteo estaba perfecto — lo que estaba
		# mal era la frase.
		#
		# Dos números distintos con el mismo «de 6» en el mismo renglón se van a
		# confundir siempre, por muy correctos que sean los dos.
		EventBus.show_message.emit("✓ %s\nLlevas %d de %d objetivos del parque" % [
			texto, cuantos_hechos(), LISTA.size()], 3.0)


func _comprobar_final() -> void:
	if _cerrado or cuantos_hechos() < LISTA.size():
		return
	_cerrado = true
	todos_cumplidos.emit()
	if avisar:
		EventBus.show_message.emit("¡El camino al siguiente lugar se ha abierto!", 3.5)


## Corrige cuántos hacen falta de algo, y su texto.
##
## LAS METAS ESCRITAS A MANO SE QUEDAN VIEJAS Y NADIE SE ENTERA.
##
## La lista pedía cuatro rincones y seis faroles porque eso era lo que había el
## día que se escribió. En cuanto se añade uno, o uno no cabe y se descarta al
## generar el nivel, el número deja de cuadrar — y un objetivo que pide más de
## lo que existe no se puede terminar, ni hay forma de notarlo jugando salvo
## dando vueltas por el parque buscando algo que no está.
##
## Ahora quien coloca las cosas dice cuántas colocó. La lista solo pone el texto.
func fijar_meta(id: String, cuantos: int, texto: String = "") -> void:
	if not _progreso.has(id) or cuantos <= 0:
		return
	_metas[id] = cuantos
	if not texto.is_empty():
		_textos[id] = texto
	_progreso[id] = mini(_progreso[id], cuantos)


var _metas: Dictionary = {}
var _textos: Dictionary = {}


func _texto_de(id: String) -> String:
	if _textos.has(id):
		return _textos[id]
	for ficha in LISTA:
		if ficha["id"] == id:
			return ficha["texto"]
	return id


func _meta_de(id: String) -> int:
	if _metas.has(id):
		return _metas[id]
	for ficha in LISTA:
		if ficha["id"] == id:
			return ficha["meta"]
	return 1
