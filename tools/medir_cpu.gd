extends Node
class_name MedirCPU
## Reparto del tiempo de CPU por fotograma, y caza de tirones.
##
## POR QUÉ HACE FALTA, APARTE DEL OTRO BANCO
##
## `medir_rendimiento.gd` apaga cosas que se DIBUJAN. Pero en el Mac apagarlo
## todo —terreno, decorado, personajes y cielo— deja los fps donde estaban: la
## GPU está de brazos cruzados y quien manda es la CPU. Y un móvil tiene una CPU
## entre cinco y diez veces más lenta que la del Mac, así que todo lo que aquí
## cuesta un milisegundo allí cuesta cinco.
##
## Este mide lo otro: cuánto tarda el fotograma por dentro, cuántos tirones hay
## y de quién son. La técnica es la misma —apagar una cosa y volver a medir—
## pero lo que se apaga es el `_process` de cada subsistema, no su malla.
##
## LO QUE MIRAR NO ES LA MEDIA, SON LOS PERCENTILES
##
## Un juego a 60 fps de media con un tirón de 40 ms cada segundo se JUEGA peor
## que uno a 45 fps clavados: el tirón se nota y la media no lo enseña. Por eso
## el informe da p50, p90, p99 y el peor, y cuenta cuántos fotogramas se pasaron
## de 16,6 ms (60 fps) y de 33,3 ms (30 fps).
##
## CÓMO SE USA
##
##     var m = load("res://tools/medir_cpu.gd").new()
##     get_tree().current_scene.add_child(m)

const FOTOGRAMAS_POR_PRUEBA := 400
const FOTOGRAMAS_DE_ASIENTO := 20

## Qué se apaga en cada prueba. La clave es el nombre que sale en el informe;
## el valor, los nodos a los que se les quita el `_process` y el
## `_physics_process`.
##
## Se apaga el proceso, NO se borra el nodo: así lo que se ve no cambia y la
## carga de la GPU es idéntica entre pruebas. Lo único que se mueve es la CPU.
const APAGABLES := {
	"servidor MCP": ["/root/McpInteractionServer"],
	"bichos": ["Bichos"],
	"jugadora": ["Player"],
	"Luna": ["Luna"],
	"interfaz": ["GameUI"],
	"objetivos y guía": ["Objetivos"],
}


func _ready() -> void:
	name = "MedirCPU"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_correr.call_deferred()


func _correr() -> void:
	print("\n[CPU] empieza")
	var resultados: Array[Dictionary] = []
	resultados.append(await _prueba("tal cual", []))
	for etiqueta in APAGABLES:
		resultados.append(await _prueba("sin " + etiqueta, APAGABLES[etiqueta]))
	# Y el suelo de todo: sin ningún script de juego corriendo. Lo que quede es
	# lo que cuestan el motor, la animación y la física, que no se tocan desde
	# GDScript.
	var todos: Array = []
	for etiqueta in APAGABLES:
		todos.append_array(APAGABLES[etiqueta])
	resultados.append(await _prueba("sin nada de eso", todos))
	_informe(resultados)
	queue_free()


func _prueba(etiqueta: String, rutas: Array) -> Dictionary:
	var apagados := _apagar(rutas, false)
	for i in FOTOGRAMAS_DE_ASIENTO:
		await get_tree().process_frame

	var tiempos: Array[float] = []
	for i in FOTOGRAMAS_POR_PRUEBA:
		var antes := Time.get_ticks_usec()
		await get_tree().process_frame
		tiempos.append((Time.get_ticks_usec() - antes) / 1000.0)

	_apagar(apagados, true)
	tiempos.sort()
	var lentos_60 := 0
	var lentos_30 := 0
	for t in tiempos:
		if t > 16.6:
			lentos_60 += 1
		if t > 33.3:
			lentos_30 += 1
	return {
		"prueba": etiqueta,
		"p50": tiempos[int(tiempos.size() * 0.50)],
		"p90": tiempos[int(tiempos.size() * 0.90)],
		"p99": tiempos[int(tiempos.size() * 0.99)],
		"max": tiempos[-1],
		"lentos_60": 100.0 * lentos_60 / tiempos.size(),
		"lentos_30": 100.0 * lentos_30 / tiempos.size(),
	}


## Apaga (o vuelve a encender) el proceso de una lista de nodos.
## Devuelve los que de verdad se tocaron, para poder deshacerlo exacto.
func _apagar(rutas: Array, encender: bool) -> Array:
	var tocados: Array = []
	for ruta in rutas:
		var nodo: Node = null
		if str(ruta).begins_with("/"):
			nodo = get_node_or_null(NodePath(ruta))
		else:
			nodo = get_tree().current_scene.get_node_or_null(NodePath(ruta))
		if nodo == null:
			continue
		_proceso_recursivo(nodo, encender)
		tocados.append(ruta)
	return tocados


func _proceso_recursivo(nodo: Node, encender: bool) -> void:
	nodo.set_process(encender)
	nodo.set_physics_process(encender)
	for hijo in nodo.get_children():
		_proceso_recursivo(hijo, encender)


func _informe(resultados: Array[Dictionary]) -> void:
	var lineas: Array[String] = []
	lineas.append("")
	lineas.append("[CPU] %s · %d fotogramas por prueba" % [OS.get_name(), FOTOGRAMAS_POR_PRUEBA])
	lineas.append("prueba                  p50     p90     p99     max   >16ms   >33ms")
	lineas.append("---------------------------------------------------------------------")
	for r in resultados:
		lineas.append("%-20s %6.2f  %6.2f  %6.2f  %6.1f  %5.1f%%  %5.1f%%" % [
			r["prueba"], r["p50"], r["p90"], r["p99"], r["max"],
			r["lentos_60"], r["lentos_30"]])
	lineas.append("---------------------------------------------------------------------")
	lineas.append("Milisegundos por fotograma. 16,6 = 60 fps · 33,3 = 30 fps.")
	lineas.append("Lo que baje el p99 quita TIRONES; lo que baje el p50 sube la media.")
	print("\n".join(lineas))
