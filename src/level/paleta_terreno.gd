extends Object
class_name PaletaTerreno
## Biblioteca de superficies del escenario: hierba, camino, piedra, madera…
##
## Todas salen del **mismo shader** ([`terreno.gdshader`](terreno.gdshader))
## cambiando dos o tres colores y un par de números. Esa es la idea entera: que
## montar un escenario nuevo no pida texturas nuevas, sino **otra combinación**
## de las que ya hay.
##
## Cuando toque la plaza de una ciudad, la losa de piedra ya está: se copia la
## receta, se cambian los colores a grises y sale un suelo urbano. Y como los
## materiales se cachean por nombre, da igual cuántas piezas lo usen — todas
## comparten el mismo recurso y una sola llamada de dibujado por malla.
##
## ## Cómo se lee una receta
##
## - `base` es el color que domina, `mancha` el oscuro y `luz` el claro que
##   asoma solo en las zonas altas del patrón
## - `escala` son **metros por repetición**: 3.0 significa que el patrón se
##   repite cada 3 m, y como la proyección va en coordenadas de mundo, eso mide
##   lo mismo en todas las piezas del mapa
## - `tonos` es cuántos escalones de color hay. Es el número que más manda en el
##   aspecto: 2 parece un cartel, 5 ya es un degradado y se pierde el estilo
## - `vetas` estira el patrón en una dirección, para madera y tierra pisada

const SHADER := preload("res://src/level/terreno.gdshader")

## Las recetas. Añadir una superficie nueva es añadir una entrada aquí.
const RECETAS := {
	# --- Naturales -----------------------------------------------------------
	"hierba": {
		"base": Color(0.43, 0.58, 0.36), "mancha": Color(0.33, 0.47, 0.30),
		"luz": Color(0.56, 0.70, 0.42), "escala": 3.4, "tonos": 3,
		"fuerza": 0.62, "grano": 0.20,
	},
	# La de fuera del camino, algo más apagada: separa lo jugable de lo que solo
	# se mira, sin necesidad de una valla.
	"hierba_lejos": {
		"base": Color(0.38, 0.52, 0.34), "mancha": Color(0.31, 0.44, 0.29),
		"luz": Color(0.47, 0.60, 0.38), "escala": 5.5, "tonos": 3,
		"fuerza": 0.5, "grano": 0.12,
	},
	"tierra_camino": {
		"base": Color(0.76, 0.70, 0.54), "mancha": Color(0.66, 0.59, 0.44),
		"luz": Color(0.84, 0.79, 0.63), "escala": 2.2, "tonos": 3,
		"fuerza": 0.45, "grano": 0.26, "vetas": 0.22,
	},
	"tierra_arena": {
		"base": Color(0.64, 0.55, 0.46), "mancha": Color(0.55, 0.46, 0.38),
		"luz": Color(0.72, 0.64, 0.53), "escala": 2.8, "tonos": 3,
		"fuerza": 0.5, "grano": 0.24,
	},
	# --- Construidas ---------------------------------------------------------
	"muro_seto": {
		"base": Color(0.34, 0.45, 0.32), "mancha": Color(0.25, 0.35, 0.25),
		"luz": Color(0.44, 0.56, 0.38), "escala": 1.5, "tonos": 4,
		"fuerza": 0.72, "grano": 0.30,
	},
	"piedra": {
		"base": Color(0.62, 0.62, 0.60), "mancha": Color(0.50, 0.50, 0.50),
		"luz": Color(0.74, 0.74, 0.71), "escala": 1.8, "tonos": 4,
		"fuerza": 0.55, "grano": 0.18,
	},
	"madera": {
		"base": Color(0.60, 0.44, 0.30), "mancha": Color(0.48, 0.34, 0.23),
		"luz": Color(0.70, 0.53, 0.37), "escala": 1.2, "tonos": 4,
		"fuerza": 0.5, "grano": 0.14, "vetas": 0.72,
	},
	"plataforma": {
		"base": Color(0.68, 0.58, 0.45), "mancha": Color(0.56, 0.47, 0.36),
		"luz": Color(0.78, 0.68, 0.54), "escala": 1.6, "tonos": 4,
		"fuerza": 0.5, "grano": 0.18, "vetas": 0.3,
	},
}

## Los materiales ya creados, por nombre. Sin esto habría un `ShaderMaterial`
## por pieza y se perdería el agrupado de llamadas de dibujado.
static var _cache: Dictionary = {}


## Devuelve el material de una superficie. Siempre el mismo objeto.
static func obtener(nombre: String) -> ShaderMaterial:
	if _cache.has(nombre):
		return _cache[nombre]
	if not RECETAS.has(nombre):
		push_warning("PaletaTerreno: no existe la superficie '%s'" % nombre)
		nombre = "hierba"
		if _cache.has(nombre):
			return _cache[nombre]

	var receta: Dictionary = RECETAS[nombre]
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("color_base", receta["base"])
	material.set_shader_parameter("color_mancha", receta["mancha"])
	material.set_shader_parameter("color_luz", receta["luz"])
	material.set_shader_parameter("escala", receta.get("escala", 3.0))
	material.set_shader_parameter("tonos", receta.get("tonos", 3))
	material.set_shader_parameter("fuerza", receta.get("fuerza", 0.55))
	material.set_shader_parameter("grano", receta.get("grano", 0.18))
	material.set_shader_parameter("vetas", receta.get("vetas", 0.0))
	material.set_shader_parameter("aspereza", receta.get("aspereza", 0.95))
	_cache[nombre] = material
	return material


## Una variante teñida de una superficie que ya existe, sin tocar la original.
##
## Es lo que hace que esto escale de verdad: la plaza de piedra gris de una
## ciudad y el suelo de arena de un templo son `piedra` con otro tinte, no dos
## superficies distintas que haya que inventar y mantener.
static func tenida(nombre: String, base: Color, mancha: Color,
		luz: Color, sufijo: String = "") -> ShaderMaterial:
	var clave := "%s_%s" % [nombre, sufijo if sufijo != "" else base.to_html(false)]
	if _cache.has(clave):
		return _cache[clave]
	var receta: Dictionary = RECETAS.get(nombre, RECETAS["hierba"])
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("color_base", base)
	material.set_shader_parameter("color_mancha", mancha)
	material.set_shader_parameter("color_luz", luz)
	material.set_shader_parameter("escala", receta.get("escala", 3.0))
	material.set_shader_parameter("tonos", receta.get("tonos", 3))
	material.set_shader_parameter("fuerza", receta.get("fuerza", 0.55))
	material.set_shader_parameter("grano", receta.get("grano", 0.18))
	material.set_shader_parameter("vetas", receta.get("vetas", 0.0))
	material.set_shader_parameter("aspereza", receta.get("aspereza", 0.95))
	_cache[clave] = material
	return material
