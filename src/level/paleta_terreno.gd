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

## El patrón de todas las superficies, horneado a una textura.
##
## Es UNA sola para el juego entero: lo que distingue la hierba de la madera son
## los colores y la escala, no el ruido. Antes se calculaba en el shader y
## costaba veintiocho evaluaciones de hash por píxel — ver la cabecera de
## `terreno.gdshader`. Se regenera con `tools/generar_textura_ruido.gd`.
const RUIDO := preload("res://assets/textures/ruido_superficie.png")

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
	"agua": {
		"base": Color(0.38, 0.66, 0.80), "mancha": Color(0.28, 0.54, 0.72),
		"luz": Color(0.62, 0.84, 0.92), "escala": 4.5, "tonos": 3,
		"fuerza": 0.62, "grano": 0.10, "aspereza": 0.18,
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

## El contraste y la saturación del `Environment`, para poder hornearlos.
##
## Tienen que ser LOS MISMOS que los del `WorldEnvironment` de la escena, o el
## móvil y el PC dejan de verse igual.
const CONTRASTE := 1.08
const SATURACION := 1.25


## Aplica el ajuste de color al color de origen, en vez de a cada píxel.
##
## POR QUÉ EXISTE
##
## El ajuste del `Environment` es lo que hace que el parque se vea vivo y con
## tono de anime en vez de pálido — quitarlo no era una opción. Pero es de lo
## más caro que había en el móvil, y no por la cuenta: contraste y saturación
## son cuatro operaciones. Lo caro es **cuándo** se hace. Al aplicarse sobre el
## fotograma ya terminado, hay que releer la pantalla entera; y una GPU de móvil
## trabaja por tiles, así que eso la obliga a volcar el búfer de color a memoria
## y traérselo de vuelta. El ancho de banda es justo su recurso escaso.
##
## La cuenta, en cambio, se puede hacer UNA VEZ al cargar el nivel sobre los
## colores de las recetas, que es de donde sale casi todo lo que se ve. El
## resultado es el mismo y no cuesta nada por fotograma.
##
## Es la misma fórmula que aplica Godot en su paso de tonemap, en el mismo
## orden: primero el contraste alrededor del gris medio, después la saturación
## hacia la luminancia. Los pesos de luminancia son los suyos.
##
## Solo se hornea en el móvil: en el PC el `Environment` sigue haciéndolo como
## siempre, y hornearlo además lo aplicaría dos veces.
static func vivo(color: Color) -> Color:
	if not OS.has_feature("mobile"):
		return color
	var c := Vector3(color.r, color.g, color.b)
	c = Vector3(0.5, 0.5, 0.5).lerp(c, CONTRASTE)
	var luz := c.dot(Vector3(0.2125, 0.7154, 0.0721))
	c = Vector3(luz, luz, luz).lerp(c, SATURACION)
	return Color(maxf(c.x, 0.0), maxf(c.y, 0.0), maxf(c.z, 0.0), color.a)


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
	var material := _crear(receta, receta["base"], receta["mancha"], receta["luz"])
	_cache[nombre] = material
	return material


## Monta el material a partir de una receta y tres colores. Lo comparten
## `obtener()` y `tenida()`, que solo se diferencian en de dónde salen los
## colores: teniéndolo en un sitio, añadir un parámetro al shader es tocar una
## línea y no dos que se desincronizan.
static func _crear(receta: Dictionary, base: Color, mancha: Color,
		luz: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("ruido_tex", RUIDO)
	material.set_shader_parameter("color_base", vivo(base))
	material.set_shader_parameter("color_mancha", vivo(mancha))
	material.set_shader_parameter("color_luz", vivo(luz))
	material.set_shader_parameter("escala", receta.get("escala", 3.0))
	material.set_shader_parameter("tonos", receta.get("tonos", 3))
	material.set_shader_parameter("fuerza", receta.get("fuerza", 0.55))
	material.set_shader_parameter("grano", receta.get("grano", 0.18))
	material.set_shader_parameter("vetas", receta.get("vetas", 0.0))
	material.set_shader_parameter("aspereza", receta.get("aspereza", 0.95))
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
	var material := _crear(receta, base, mancha, luz)
	_cache[clave] = material
	return material
