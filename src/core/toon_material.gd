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


## La luz de borde va APAGADA por defecto, y esa es una decisión, no un olvido.
##
## En MToon el rim NO es un reflejo: mira `mtoon_common.gdshaderinc`, línea 277.
##
##     emission += rim * (1.0 - _RimLightingMix)
##
## O sea que con `_RimLightingMix` bajo, casi todo el rim se va a **EMISSION**,
## que es luz propia: no le afecta el sol, ni la sombra, ni la hora del día. Y
## `rim` vale `pow(1 - dot(N,V), potencia) * color`, que en la silueta —donde la
## normal es perpendicular a la vista— vale exactamente 1.
##
## Con los valores que había (`_RimColor` blanco y `_RimLightingMix` 0,12), cada
## personaje llevaba **un +0,88 de blanco puro sumado a todo su contorno**, sin
## nada que lo apagara. Eso es el «aura blanca» y el «delineado raro» que se
## veía alrededor de Serena, de Luna y de los enemigos: no era el contorno negro
## fallando, era un halo de luz propia por delante de él.
##
## Si algún día se quiere un rim de verdad, la forma correcta es dejar el color
## y subir `rim_mix` a 1.0: entonces el borde se ilumina **con la escena** en vez
## de brillar solo, y de noche o a contraluz se apaga como tiene que apagarse.
const RIM_APAGADO := Color(0.0, 0.0, 0.0)

## Cuánto se dobla la normal hacia arriba antes de iluminar (`mix_normal`, línea
## 280 del include). Es el mando que decide si el personaje tiene sombreado o es
## una calcomanía.
##
## Estaba en 0.5: media normal apuntando al cielo, así que la cara iluminada y la
## de sombra recibían casi la misma luz y el escalón del cel shading no llegaba a
## verse. El personaje salía plano y pálido pasara lo que pasara con el resto de
## la iluminación. 0.1 es el valor propio de MToon: suaviza lo justo para que la
## sombra no sea un corte a cuchillo, sin borrarla.
const LUZ_DE_ARRIBA := 0.1


## Aplica cel shading a todas las MeshInstance3D bajo `root`.
## Devuelve cuántas superficies convirtió.
## `outline_width` va en METROS. 0.02 es un contorno que se lee en un móvil sin
## engordar la silueta; 0.006 —lo que había— desaparece por completo en cuanto
## el personaje se aleja tres metros, y sin contorno el cel shading no se lee.
## Valores como 0.15 (15 cm) inflan la malla entera.
static func apply(
		root: Node,
		shade_color: Color = Color(0.62, 0.58, 0.75),
		toony: float = 0.9,
		outline_width: float = 0.02,
		outline_color: Color = Color(0.18, 0.09, 0.15),
		rim_color: Color = RIM_APAGADO,
		rim_mix: float = 1.0
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
				outline_width, outline_color, rim_color, rim_mix)
			mesh_instance.set_surface_override_material(surface, toon)
			converted += 1
	return converted


static func _build(source: BaseMaterial3D, shade_color: Color, toony: float,
		outline_width: float, outline_color: Color, rim_color: Color,
		rim_mix: float) -> ShaderMaterial:

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
	material.set_shader_parameter("_IndirectLightIntensity", LUZ_DE_ARRIBA)

	# Luz de borde. Apagada por defecto: ver `RIM_APAGADO` arriba.
	#
	# `_RimFresnelPower` sube de 3 a 5 para que, cuando se encienda, sea una
	# línea fina en el canto y no medio personaje bañado: con 3 el degradado
	# empieza a los 45° de la silueta y cubre casi toda la figura.
	material.set_shader_parameter("_RimColor", rim_color)
	material.set_shader_parameter("_RimFresnelPower", 5.0)
	material.set_shader_parameter("_RimLift", 0.0)
	material.set_shader_parameter("_RimLightingMix", rim_mix)

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
