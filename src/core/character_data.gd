extends Resource
class_name CharacterData
## Ficha de un personaje del reparto.
##
## Es el DTO que describe todo lo que distingue a una Sailor de otra: su modelo,
## su estatura, qué se le mueve al andar y con cuánta gracia. La lógica de
## combate y de montaje lee esto; no hay una escena por personaje.
##
## Las fichas están en `assets/data/personajes/`. El reparto completo y el
## procedimiento para prepararlos están en `docs/12-REPARTO.md`.

@export var id: String = ""
@export var display_name: String = ""
## El FBX rigueado en Mixamo, no el `.glb` de partida.
@export var model: PackedScene
## Estatura real en metros. Va a escala: de 1,10 m (Chibi Moon) a 1,80 m
## (Tuxedo Mask), y en combate esa diferencia informa de un vistazo.
@export var height: float = 1.6

@export_group("Física del pelo")
## Primer hueso de cada cadena. Vacío = no se le mueve nada (pelo corto).
@export var chain_roots: Array[String] = []
@export_range(1, 12) var chain_length: int = 5
@export_range(0.0, 4.0) var stiffness: float = 1.4
@export_range(0.0, 1.0) var drag: float = 0.45
@export_range(0.0, 4.0) var gravity_power: float = 0.9
## Tope de separación. Bajo en las capas: si no, se levantan como un ala.
@export_range(0.0, 180.0) var max_angle: float = 75.0

@export_group("Aspecto")
## Color de la sombra del cel shading. Cada una tira hacia su color de planeta.
@export var shade_color: Color = Color(0.62, 0.58, 0.75)
## Color de las partículas y destellos de sus golpes.
@export var vfx_color: Color = Color(1.0, 0.85, 0.4)


func tiene_fisica() -> bool:
	return not chain_roots.is_empty()
