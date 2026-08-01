extends RefCounted
class_name ToonMaterial
## Convierte materiales PBR normales en cel shading estilo anime.
##
## POR QUÉ EXISTE: los modelos de VRoid venían con MToon de fábrica. Los de
## Tripo (y los de cualquier generador de IA) vienen con `StandardMaterial3D`
## PBR, que se ve realista, no anime. Este helper reaprovecha el shader MToon
## que ya trajo el addon VRM y lo aplica a CUALQUIER malla.
##
## Así conservamos el look anime aunque el pipeline de personajes haya cambiado
## de VRoid a Tripo.
##
## Uso típico, en el _ready de un personaje importado:
##     ToonMaterial.apply(self)
##
## El contorno negro se hace con `next_pass`: Godot dibuja la malla otra vez con
## un segundo material en `cull_front`, es decir, solo las caras traseras
## ligeramente infladas. Es la técnica de "inverted hull" y cuesta un draw call
## extra por superficie.

const MTOON := preload("res://addons/Godot-MToon-Shader/mtoon.gdshader")
const MTOON_OUTLINE := preload("res://addons/Godot-MToon-Shader/mtoon_outline.gdshader")

## Modo de ancho del contorno: 1 = coordenadas de mundo (grosor constante en
## metros). 2 = pantalla. 0 = sin contorno.
const OUTLINE_MODE_WORLD := 1


## Aplica cel shading a todas las MeshInstance3D bajo `root`.
## Devuelve cuántas superficies convirtió.
static func apply(
		root: Node,
		shade_color: Color = Color(0.62, 0.58, 0.75),
		toony: float = 0.9,
		outline_width: float = 0.15,
		outline_color: Color = Color(0.18, 0.09, 0.15),
		rim_color: Color = Color(1.0, 0.95, 1.0)
	) -> int:

	var converted := 0
	for mesh_instance in _collect_meshes(root):
		var mesh := mesh_instance.mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface)
			# Si ya es MToon (modelo VRM), no se toca.
			if source is ShaderMaterial:
				continue
			var toon := _build(source as BaseMaterial3D, shade_color, toony,
				outline_width, outline_color, rim_color)
			mesh_instance.set_surface_override_material(surface, toon)
			converted += 1
	return converted


static func _build(source: BaseMaterial3D, shade_color: Color, toony: float,
		outline_width: float, outline_color: Color, rim_color: Color) -> ShaderMaterial:

	var albedo := Color.WHITE
	var texture: Texture2D = null
	var normal_map: Texture2D = null

	if source != null:
		albedo = source.albedo_color
		texture = source.albedo_texture
		normal_map = source.normal_texture

	var material := ShaderMaterial.new()
	material.shader = MTOON

	material.set_shader_parameter("_Color", albedo)
	# El color de sombra es lo que crea el escalón de luz característico del
	# anime: una sombra teñida, no un simple oscurecimiento.
	material.set_shader_parameter("_ShadeColor", albedo * shade_color)
	if texture != null:
		material.set_shader_parameter("_MainTex", texture)
		material.set_shader_parameter("_ShadeTexture", texture)
	if normal_map != null:
		material.set_shader_parameter("_BumpMap", normal_map)

	# `_ShadeToony` cerca de 1 = transición dura entre luz y sombra (dos bandas).
	# Bajarlo a ~0.5 da un degradado más suave, menos anime.
	material.set_shader_parameter("_ShadeToony", clampf(toony, 0.0, 1.0))
	material.set_shader_parameter("_ShadeShift", 0.0)
	material.set_shader_parameter("_ShadingGradeRate", 1.0)
	material.set_shader_parameter("_ReceiveShadowRate", 1.0)
	material.set_shader_parameter("_LightColorAttenuation", 0.0)
	material.set_shader_parameter("_IndirectLightIntensity", 0.5)

	# Luz de borde: el brillo suave del contorno, muy característico del anime.
	material.set_shader_parameter("_RimColor", rim_color)
	material.set_shader_parameter("_RimFresnelPower", 3.0)
	material.set_shader_parameter("_RimLift", 0.0)
	material.set_shader_parameter("_RimLightingMix", 0.3)

	material.set_shader_parameter("_EmissionColor", Color.BLACK)
	material.set_shader_parameter("_MainTex_ST", Vector4(1, 1, 0, 0))

	if outline_width > 0.0:
		material.next_pass = _build_outline(outline_width, outline_color, texture, albedo)

	return material


static func _build_outline(width: float, color: Color, texture: Texture2D,
		albedo: Color) -> ShaderMaterial:
	var outline := ShaderMaterial.new()
	outline.shader = MTOON_OUTLINE
	outline.set_shader_parameter("_OutlineWidthMode", float(OUTLINE_MODE_WORLD))
	outline.set_shader_parameter("_OutlineWidth", width)
	outline.set_shader_parameter("_OutlineColor", color)
	outline.set_shader_parameter("_OutlineColorMode", 0.0)
	outline.set_shader_parameter("_OutlineLightingMix", 0.0)
	outline.set_shader_parameter("_OutlineScaledMaxDistance", 1.0)
	outline.set_shader_parameter("_Color", albedo)
	if texture != null:
		outline.set_shader_parameter("_MainTex", texture)
	return outline


static func _collect_meshes(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			found.append(node)
		for child in node.get_children():
			stack.append(child)
	return found
