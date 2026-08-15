extends Node
## (Sin `class_name`: es un autoload y ya tiene nombre global,
## `PartidasGuardadas`. Poner los dos hace que Godot registre dos identificadores
## para el mismo script y no resuelva ninguno.)
## Las tres partidas guardadas, y qué se sabe de cada una sin abrirla.
##
## ## Por qué tres y no una
##
## Una sola partida obliga a elegir entre seguir o empezar de cero, y a los ocho
## años «empezar de cero» se pulsa por curiosidad y se pierde todo. Con tres
## ranuras se puede trastear sin miedo: la que ya iba por la mitad sigue ahí.
##
## Tampoco muchas más. Tres caben en pantalla sin listas ni desplazamientos, y
## la pantalla de partidas tiene que entenderse sin leer nada.
##
## ## Lo que se enseña sin abrirla
##
## Cada ranura guarda un **resumen** —qué Sailor, cuánto se llevaba, cuánto se
## ha jugado— para poder pintarlo en el menú sin cargar la partida entera. Sin
## eso, la pantalla de selección tendría que abrir los tres archivos completos
## solo para escribir tres líneas.
##
## ## Sobre las vidas
##
## El resumen NO guarda la vida ni la posición: eso es de la sesión, no del
## progreso. Cuando llegue el sistema de vidas con puntos de guardado y corazones
## recogibles, lo que cambie será `datos_de_sesion()` —una función— y no el
## formato de las ranuras.

const CUANTAS := 3
const RUTA := "user://partida_%d.json"
const VERSION := 2

signal ranura_cambiada(cual: int)

## En cuál se está jugando. -1 = ninguna (estamos en los menús).
var actual: int = -1


## Lo que se sabe de una ranura sin cargarla: `{vacia, sailor, estrellas,
## objetivos, total_objetivos, nivel, minutos, cuando}`.
func resumen(cual: int) -> Dictionary:
	var ruta := RUTA % cual
	if not FileAccess.file_exists(ruta):
		return {"vacia": true}
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return {"vacia": true}
	var crudo: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(crudo) != TYPE_DICTIONARY:
		return {"vacia": true}
	var d: Dictionary = crudo
	var r: Dictionary = d.get("resumen", {})
	r["vacia"] = false
	return r


func hay_algo(cual: int) -> bool:
	return not bool(resumen(cual).get("vacia", true))


## Abre una ranura y deja el `GameManager` como estaba. Devuelve si había algo.
func cargar(cual: int) -> bool:
	actual = cual
	ranura_cambiada.emit(cual)
	var ruta := RUTA % cual
	if not FileAccess.file_exists(ruta):
		_empezar_de_cero()
		return false

	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		_empezar_de_cero()
		return false
	var crudo: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(crudo) != TYPE_DICTIONARY:
		_empezar_de_cero()
		return false

	var d: Dictionary = _migrar(crudo)
	GameManager.current_sailor_id = d.get("sailor", "moon")
	GameManager.unlocked_sailors = _lista(d.get("sailors", ["moon"]))
	GameManager.unlocked_outfits = _lista(d.get("trajes", ["default"]))
	GameManager.equipped_outfit = d.get("traje", "default")
	GameManager.level_progress = d.get("progreso", {})
	vista_apertura = bool(d.get("vista_apertura", false))
	_jugado = float(d.get("jugado", 0.0))
	_desde = Time.get_ticks_msec() / 1000.0
	return true


## Guarda la ranura en la que se esté jugando. Sin ranura no hace nada: así una
## partida de prueba lanzada desde el editor no pisa ningún guardado.
func guardar() -> void:
	if actual < 0:
		return
	var f := FileAccess.open(RUTA % actual, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo guardar la partida %d" % actual)
		return
	f.store_string(JSON.stringify({
		"version": VERSION,
		"sailor": GameManager.current_sailor_id,
		"sailors": GameManager.unlocked_sailors,
		"trajes": GameManager.unlocked_outfits,
		"traje": GameManager.equipped_outfit,
		"progreso": GameManager.level_progress,
		"jugado": tiempo_jugado(),
		"vista_apertura": vista_apertura,
		# El resumen va DUPLICADO a propósito: es lo único que lee el menú, y
		# leerlo suelto evita cargar el progreso entero de tres partidas solo
		# para pintar tres tarjetas.
		"resumen": _hacer_resumen(),
	}, "\t"))
	f.close()


func borrar(cual: int) -> void:
	var ruta := RUTA % cual
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	if actual == cual:
		actual = -1


func tiempo_jugado() -> float:
	if actual < 0:
		return _jugado
	return _jugado + (Time.get_ticks_msec() / 1000.0 - _desde)


var _jugado: float = 0.0
var _desde: float = 0.0


## Si ya se ha visto la cinemática de apertura en esta partida.
##
## Va en el guardado y no en los ajustes: cada partida es una historia que
## empieza, y quien abra la segunda ranura tiene derecho a verla otra vez. Pero
## solo una vez por partida — a la tercera muerte, minuto y medio de cuento es
## un peaje.
var vista_apertura: bool = false


func _empezar_de_cero() -> void:
	vista_apertura = false
	GameManager.current_sailor_id = "moon"
	GameManager.unlocked_sailors = ["moon"]
	GameManager.unlocked_outfits = ["default"]
	GameManager.equipped_outfit = "default"
	GameManager.level_progress = {}
	GameManager.reset_health()
	_jugado = 0.0
	_desde = Time.get_ticks_msec() / 1000.0


func _hacer_resumen() -> Dictionary:
	var estrellas := 0
	var niveles := 0
	for id: String in GameManager.level_progress:
		var p: Variant = GameManager.level_progress[id]
		if typeof(p) == TYPE_DICTIONARY:
			estrellas += int(p.get("stars", 0))
			if bool(p.get("completed", false)):
				niveles += 1
	return {
		"sailor": GameManager.current_sailor_id,
		"estrellas": estrellas,
		"niveles": niveles,
		"minutos": int(tiempo_jugado() / 60.0),
		"cuando": Time.get_datetime_string_from_system(false, true),
	}


func _migrar(d: Dictionary) -> Dictionary:
	# La v1 era el archivo único `save.json` con otros nombres de campo. Se
	# traduce en vez de descartarse: si tu prima ya tenía una partida, no la
	# pierde por haber cambiado el formato.
	if int(d.get("version", d.get("save_version", 1))) < 2:
		return {
			"version": VERSION,
			"sailor": d.get("current_sailor_id", "moon"),
			"sailors": d.get("unlocked_sailors", ["moon"]),
			"trajes": d.get("unlocked_outfits", ["default"]),
			"traje": d.get("equipped_outfit", "default"),
			"progreso": d.get("level_progress", {}),
			"jugado": 0.0,
		}
	return d


static func _lista(v: Variant) -> Array[String]:
	var salida: Array[String] = []
	if typeof(v) == TYPE_ARRAY:
		for x: Variant in v:
			salida.append(str(x))
	return salida
