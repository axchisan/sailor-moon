extends Node
class_name Apertura
## El texto de la cinemática de apertura, tal cual está en el guion.
##
## Vive aparte de la cinemática porque son cosas distintas: una es **cómo** se
## cuenta —los tiempos, el movimiento, el fundido— y esto es **qué** se cuenta.
## Corregir una frase no debería obligar a abrir el reproductor.
##
## El texto sale literal de [`16-GUION.md`](../../docs/16-GUION.md), sin las
## etiquetas de fish.audio: esas son para generar la voz, no para leerse.

## Las cinco viñetas. `camara` es `[zoom desde, zoom hasta, desliz]`: el
## movimiento lento que convierte una lámina en una escena.
const VIÑETAS: Array[Dictionary] = [
	{
		"dibujo": "espejo_entero",
		# Se acerca despacio: empieza lejos, como quien recuerda algo.
		"camara": [1.0, 1.18, 0.0],
		"lineas": [
			"Hace mucho, mucho tiempo, sobre la ciudad de Tokio flotaba un espejo.",
			"Nadie lo veía. Pero todas las noches, mientras la gente dormía, el espejo guardaba sus sueños.",
		],
	},
	{
		"dibujo": "espejo_roto",
		# El mismo encuadre que la viñeta anterior, ya roto. La imagen repetida
		# es lo que cuenta el antes y el después.
		"camara": [1.18, 1.05, 0.0],
		"lineas": [
			"Una noche, nadie sabe por qué, el espejo se rompió.",
			"Y todos los sueños salieron volando.",
		],
	},
	{
		"dibujo": "lluvia",
		# Un desplazamiento lateral: la mirada recorre la ciudad.
		"camara": [1.12, 1.0, -0.06],
		"lineas": [
			"Se convirtieron en Estrellas de Sueño, y cayeron por toda la ciudad.",
			"En los parques. En los templos. En los tejados.",
		],
	},
	{
		"dibujo": "dama",
		# Se acerca a ella muy poco a poco, que es lo que la hace inquietante
		# sin que dé miedo.
		"camara": [1.0, 1.22, 0.03],
		"lineas": [
			"Pero alguien más las estaba buscando.",
			"La Dama del Espejo Roto vivía dentro del espejo. Sola. Desde hacía tanto tiempo que ya no se acordaba de cuánto.",
			"Y los sueños de los demás eran lo único que la acompañaba.",
		],
	},
	{
		"dibujo": "serena",
		"camara": [1.15, 1.0, 0.0],
		"lineas": [
			"Sin sus sueños, la gente se iba quedando apagada. Y gris.",
			"Por eso, esa mañana, una gata negra fue a buscar a una niña que soñaba más que nadie.",
			# El chiste que baja el tono justo antes de jugar. Después de cuatro
			# viñetas melancólicas hace falta, y de paso presenta a Serena como
			# es: buena persona y un desastre.
			"Aunque casi siempre soñara despierta. Y en clase.",
		],
	},
]


## Lánzala. Devuelve cuando ha terminado o se ha saltado.
static func reproducir(padre: Node) -> void:
	var c := Cinematica.new()
	padre.add_child(c)
	# Su propia música, en la capa de momento: al acabar se suelta sola y vuelve
	# lo que hubiera debajo.
	Musica.pedir(Musica.Capa.MOMENTO, "encuentro")
	await c.reproducir(VIÑETAS)
	Musica.soltar(Musica.Capa.MOMENTO)
