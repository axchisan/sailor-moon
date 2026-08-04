extends Node3D
## Aplica cel shading a todos los modelos que cuelguen de este nodo.
##
## Se pone en el nodo padre de los modelos importados. Es la forma más cómoda
## de convertir un `.glb` recién importado sin tocar nada más.

## Tinte de la sombra. Es lo que crea el escalón de luz del anime.
@export var shade_color: Color = Color(0.62, 0.58, 0.75)
## Cerca de 1 = transición dura entre luz y sombra. Bajarlo la suaviza.
@export_range(0.0, 1.0) var toony: float = 0.9
## Grosor del contorno en metros. 0 lo desactiva.
@export var outline_width: float = 0.006
@export var outline_color: Color = Color(0.18, 0.09, 0.15)
@export var rim_color: Color = Color(1.0, 0.95, 1.0)
@export var rim_mix: float = 0.12


func _ready() -> void:
	var converted := ToonMaterial.apply(
		self, shade_color, toony, outline_width, outline_color, rim_color, rim_mix
	)
	print("[ToonRoot] %s: %d superficies convertidas a MToon" % [name, converted])
