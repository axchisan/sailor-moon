extends Resource
class_name LineaDialogo
## Una intervención de un diálogo.
##
## El campo `emocion` no lo usa el juego para nada: es la **etiqueta de
## fish.audio** con la que se genera la voz de esa línea. Vive aquí, junto al
## texto, porque tenerlos separados garantiza que tarde o temprano se
## desincronizan — se cambia una frase y el audio sigue diciendo la anterior.
##
## `audio` puede quedar vacío: el diálogo funciona igual, solo que sin voz. Así
## se escribe y se prueba todo el guion antes de grabar nada.

## Id del personaje (`serena`, `mercury`, `luna`…). Se usa para el nombre que
## se muestra y, más adelante, para el retrato.
@export var hablante: String = ""
@export_multiline var texto: String = ""

@export_group("Voz")
## Etiqueta de fish.audio para generar esta línea: `[excited]`, `[soft]`,
## `[embarrassed]`… Vacío = tono neutro.
@export var emocion: String = ""
@export var audio: AudioStream

@export_group("Ritmo")
## Segundos que espera al terminar de escribirse antes de dejar avanzar.
## Un respiro corto evita que se salten las frases sin leerlas.
@export_range(0.0, 2.0) var pausa_final: float = 0.25
## Velocidad de escritura, en caracteres por segundo.
@export_range(10.0, 120.0) var velocidad: float = 42.0


## El texto tal cual se le pega a fish.audio, con su etiqueta delante.
func texto_para_voz() -> String:
	if emocion.is_empty():
		return texto
	return "%s %s" % [emocion, texto]
