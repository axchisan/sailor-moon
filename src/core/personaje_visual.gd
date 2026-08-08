extends Node3D
class_name PersonajeVisual
## Monta un personaje del reparto a partir de su ficha, en tiempo de ejecución.
##
## Construye la misma jerarquía que `player.tscn` tiene escrita a mano:
##
##     PersonajeVisual
##     └── ToonRoot        cel shading (girado 180°: los modelos miran a +Z)
##         └── HairPhysics spring bones del pelo o la capa
##             └── modelo  el FBX rigueado en Mixamo
##
## Existe para no tener once escenas casi idénticas que hay que tocar una a una
## cada vez que cambia algo. Se le da un `CharacterData` y se monta solo.
##
## OJO CON EL ORDEN: el modelo se cuelga de `HairPhysics` ANTES de meter la
## física en el árbol. `HairPhysics._ready()` busca el `Skeleton3D` entre sus
## hijos, y si entra al árbol vacío no encuentra nada y no monta ninguna cadena,
## sin avisar de nada.

## Ficha del personaje. Si se deja vacía, este nodo no hace nada.
@export var data: CharacterData
## Reproduce la animación que el FBX trae de Mixamo. Para vitrinas y pruebas;
## en combate manda `CharacterAnimator`.
@export var reproducir_idle: bool = false

var _pelo: HairPhysics = null
var _toon: Node3D = null
var _modelo: Node3D = null


func _ready() -> void:
	if data == null or data.model == null:
		push_warning("PersonajeVisual '%s': sin ficha o sin modelo" % name)
		return
	montar()


func montar() -> void:
	_toon = Node3D.new()
	_toon.name = "ToonRoot"
	_toon.set_script(load("res://src/core/toon_root.gd"))
	_toon.shade_color = data.shade_color
	# Los modelos de Mixamo y de hi3d.ai miran a +Z; Godot usa −Z como frente.
	_toon.rotation.y = PI

	_pelo = HairPhysics.new()
	_pelo.name = "Fisica"
	_pelo.chain_roots = data.chain_roots
	_pelo.chain_length = data.chain_length
	_pelo.stiffness = data.stiffness
	_pelo.drag = data.drag
	_pelo.gravity_power = data.gravity_power
	_pelo.max_angle = data.max_angle

	_modelo = data.model.instantiate()
	_modelo.name = "Modelo"

	# de dentro afuera, para que cada _ready() vea ya a sus hijos
	_pelo.add_child(_modelo)
	_toon.add_child(_pelo)
	add_child(_toon)

	if reproducir_idle:
		var reproductor := _buscar_animplayer(_modelo)
		if reproductor != null and reproductor.get_animation_list().size() > 0:
			reproductor.play(reproductor.get_animation_list()[0])


func get_skeleton() -> Skeleton3D:
	return _pelo.get_skeleton() if _pelo != null else null


## Devuelve la melena a su sitio. Al teletransportar o reaparecer, si no el
## pelo sale disparado con la inercia que traía.
func reset_pelo() -> void:
	if _pelo != null:
		_pelo.reset()


static func _buscar_animplayer(nodo: Node) -> AnimationPlayer:
	if nodo is AnimationPlayer:
		return nodo
	for hijo in nodo.get_children():
		var encontrado := _buscar_animplayer(hijo)
		if encontrado != null:
			return encontrado
	return null
