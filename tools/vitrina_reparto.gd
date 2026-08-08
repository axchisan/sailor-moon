extends Node3D
## Vitrina del reparto: comprueba de un vistazo que los once están montados.
##
## Va en `scenes/prototypes/test_reparto.tscn`. Al arrancar informa por consola
## de qué se montó y, sobre todo, de **cuántas cadenas de pelo quedaron vivas**:
## si una ficha nombra un hueso que el FBX no tiene, `HairPhysics` avisa pero el
## personaje se ve perfecto y en marcha, así que sin este recuento el fallo pasa
## desapercibido hasta que alguien note que el pelo va rígido.
##
## Con la tecla `sacudir` (o espacio) empuja a todo el reparto de lado para ver
## la física reaccionar sin tener que mover a nadie.

@export var fuerza_sacudida: float = 2.6

var _personajes: Array[PersonajeVisual] = []
var _contorno_visible: bool = true
var _toon_activo: bool = true
var _guardados: Dictionary = {}


func _ready() -> void:
	for hijo in $Reparto.get_children():
		if hijo is PersonajeVisual:
			_personajes.append(hijo)
	await get_tree().process_frame
	_informar()


func _informar() -> void:
	var con_fisica := 0
	var cadenas := 0
	print("\n--- Vitrina del reparto ---")
	for p in _personajes:
		var esqueleto := p.get_skeleton()
		var vivas := 0
		if esqueleto != null:
			for hijo in esqueleto.get_children():
				if hijo is SpringBoneChain:
					vivas += 1
		var esperadas: int = p.data.chain_roots.size()
		var marca := "✓" if vivas == esperadas else "✗"
		if esperadas > 0:
			con_fisica += 1
			cadenas += vivas
		print("%s %-16s %.2f m · huesos %3d · cadenas %d/%d" % [
			marca, p.data.display_name, p.data.height,
			esqueleto.get_bone_count() if esqueleto != null else 0,
			vivas, esperadas])
	print("%d personajes · %d con física · %d cadenas activas\n" % [
		_personajes.size(), con_fisica, cadenas])


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo:
		if evento.keycode == KEY_SPACE:
			sacudir()
		elif evento.keycode == KEY_C:
			alternar_contorno()


## Enciende y apaga el contorno del cel shading en todo el reparto.
##
## Sirve para distinguir de un vistazo dos fallos que se parecen mucho: manchas
## negras en el pelo pueden ser el contorno de inverted hull asomando entre
## mechones finos, o las caras interiores de una melena hueca. Si al apagarlo
## desaparecen, era el contorno.
func alternar_contorno() -> void:
	# `_OutlineWidth` SOLO existe en el material del `next_pass`; pedírselo al
	# material base devuelve `null` y asignarlo a un `float` tira el juego al
	# depurador, que además deja el MCP colgado.
	_contorno_visible = not _contorno_visible
	var ancho := 0.006 if _contorno_visible else 0.0
	var tocados := 0
	for p in _personajes:
		for malla in _mallas(p):
			for i in malla.mesh.get_surface_count():
				var mat := malla.get_active_material(i) as ShaderMaterial
				if mat == null or not (mat.next_pass is ShaderMaterial):
					continue
				mat.next_pass.set_shader_parameter("_OutlineWidth", ancho)
				tocados += 1
	print("[Vitrina] contorno %s (%d materiales)" % [
		"encendido" if _contorno_visible else "apagado", tocados])


## Quita y devuelve el cel shading, para distinguir un fallo del shader de uno
## del modelo. `ToonMaterial` trabaja con materiales de sustitución, así que
## ponerlos a `null` deja a la vista el material que trajo el FBX.
func alternar_cel_shading() -> void:
	_toon_activo = not _toon_activo
	for p in _personajes:
		for malla in _mallas(p):
			for i in malla.mesh.get_surface_count():
				if _toon_activo:
					if _guardados.has(malla) and i < _guardados[malla].size():
						malla.set_surface_override_material(i, _guardados[malla][i])
				else:
					if not _guardados.has(malla):
						var previos: Array[Material] = []
						for k in malla.mesh.get_surface_count():
							previos.append(malla.get_surface_override_material(k))
						_guardados[malla] = previos
					malla.set_surface_override_material(i, null)
	print("[Vitrina] cel shading %s" % ("puesto" if _toon_activo else "quitado"))


## Pone a todo el reparto un color de sombra neutro y claro.
##
## `ToonMaterial` calcula `_ShadeColor = albedo × shade_color`, así que un
## `shade_color` oscuro o saturado pinta toda la zona en sombra de ese tono. En
## una melena, donde las normales apuntan en todas direcciones, el escalón duro
## del MToon convierte esa sombra en un manchón que parece un fallo del modelo.
func probar_sombra_neutra(claro: bool = true) -> void:
	var tinte := Color(0.88, 0.86, 0.92) if claro else Color(0.62, 0.58, 0.75)
	for p in _personajes:
		for malla in _mallas(p):
			for i in malla.mesh.get_surface_count():
				var mat := malla.get_active_material(i) as ShaderMaterial
				if mat == null:
					continue
				var base: Color = mat.get_shader_parameter("_Color")
				mat.set_shader_parameter("_ShadeColor", base * tinte)
	print("[Vitrina] sombra %s" % ("neutra" if claro else "original"))


static func _mallas(nodo: Node, salida: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	if nodo is MeshInstance3D:
		salida.append(nodo)
	for hijo in nodo.get_children():
		_mallas(hijo, salida)
	return salida


## Empuja el reparto de lado un instante: la inercia hace el resto.
func sacudir() -> void:
	var lado := 1.0 if randf() < 0.5 else -1.0
	for p in _personajes:
		var t := create_tween()
		t.tween_property(p, "position:x", p.position.x + 0.35 * lado * fuerza_sacudida, 0.18)
		t.tween_property(p, "position:x", p.position.x, 0.45).set_trans(Tween.TRANS_ELASTIC)
