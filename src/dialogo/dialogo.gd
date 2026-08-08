extends Resource
class_name Dialogo
## Una conversación completa: la lista de líneas y qué pasa al acabar.
##
## Los diálogos viven en `assets/data/dialogos/` como recursos, no en el
## código, para poder reescribir el guion sin tocar un solo script. Es lo que
## permite además exportar el texto entero para generar las voces.

@export var id: String = ""
@export var lineas: Array[LineaDialogo] = []

@export_group("Al terminar")
## Si se rellena, ese personaje se une al reparto (`EventBus.sailor_unlocked`).
@export var desbloquea: String = ""
@export var mensaje_final: String = ""


func tamano() -> int:
	return lineas.size()


## Vuelca el guion listo para pegar en fish.audio, una línea por intervención
## y agrupado por personaje, que es como se generan las voces (una sesión por
## voz). Se usa desde `tools/exportar_guion.gd`.
func exportar_para_voces() -> String:
	var por_hablante: Dictionary = {}
	for linea in lineas:
		if not por_hablante.has(linea.hablante):
			por_hablante[linea.hablante] = []
		por_hablante[linea.hablante].append(linea)

	var salida := "# Diálogo: %s\n" % id
	for hablante in por_hablante:
		salida += "\n## %s\n\n" % hablante
		var indice := 1
		for linea in por_hablante[hablante]:
			salida += "%d. %s\n" % [indice, linea.texto_para_voz()]
			indice += 1
	return salida
