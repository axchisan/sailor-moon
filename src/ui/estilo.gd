extends Node
class_name Estilo
## La pinta de todos los menús, en un sitio.
##
## ## Por qué existe
##
## Sin esto, cada pantalla elige sus colores y sus tamaños, y a la tercera ya no
## se parecen entre ellas. Cambiar «el rosa» pasa a ser buscarlo en ocho
## archivos, y siempre queda uno sin cambiar.
##
## ## Las decisiones de fondo
##
## **Nada de blanco puro ni negro puro.** El blanco a tope brilla en una pantalla
## de móvil y cansa a los cinco minutos; el negro puro hace que los bordes
## vibren. Todo tira a crema y a morado muy oscuro.
##
## **Poco contraste entre elementos, mucho en el texto.** Lo que hay que leer se
## lee de un vistazo; lo demás —marcos, fondos, separadores— se queda atrás y no
## compite. Es lo que hace que una pantalla se pueda mirar un rato largo.
##
## **Redondeado y con aire.** Bordes de 18-24 px y márgenes generosos. Los
## cantos vivos y las cosas apretadas se leen como formulario; esto es un juego
## para una niña de ocho años.

const ROSA := Color(1.0, 0.45, 0.72)
const ROSA_CLARO := Color(1.0, 0.72, 0.85)
const LILA := Color(0.60, 0.48, 0.92)
const CREMA := Color(1.0, 0.97, 0.99)
const ORO := Color(1.0, 0.84, 0.40)

## Los fondos, del más hondo al más cercano.
const FONDO_HONDO := Color(0.13, 0.07, 0.22)
const FONDO := Color(0.18, 0.10, 0.30)
const PANEL := Color(0.24, 0.14, 0.38, 0.94)
const PANEL_CLARO := Color(0.32, 0.20, 0.48, 0.94)

## Texto apagado: para lo que acompaña pero no se lee de primeras.
const TENUE := Color(0.78, 0.72, 0.88)

const FUENTE_TITULO := preload("res://assets/fonts/titulo.ttf")
const FUENTE_TEXTO := preload("res://assets/fonts/texto.ttf")


## Una etiqueta ya vestida. `peso` es el grosor de la tipografía: son fuentes
## variables, así que va de 400 (normal) a 800 (muy gorda) sin cambiar de archivo.
static func texto(cadena: String, tam: int = 24, color: Color = CREMA,
		titulo: bool = false, peso: int = 500) -> Label:
	var l := Label.new()
	l.text = cadena
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := FontVariation.new()
	f.base_font = FUENTE_TITULO if titulo else FUENTE_TEXTO
	f.variation_opentype = {"wght": peso}
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	return l


## Con sombra por detrás, para texto sobre imagen. Un contorno grueso lo
## ensucia; una sombra desplazada lo despega del fondo sin tocarlo.
static func texto_con_sombra(cadena: String, tam: int = 24,
		color: Color = CREMA, titulo: bool = true, peso: int = 700) -> Label:
	var l := texto(cadena, tam, color, titulo, peso)
	l.add_theme_color_override("font_shadow_color", Color(0.10, 0.03, 0.16, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(2, tam / 12))
	l.add_theme_constant_override("shadow_outline_size", maxi(3, tam / 10))
	return l


## Un botón grande, redondo y con su reacción al tocarlo.
##
## Los tamaños salen del dedo, no del ratón: **56 px de alto como mínimo** y
## texto de 24 para arriba. Un botón que en el escritorio se ve holgado, en un
## móvil se falla la mitad de las veces.
static func boton(cadena: String, ancho: float = 380.0,
		principal: bool = false) -> Button:
	var b := Button.new()
	b.text = cadena
	b.custom_minimum_size = Vector2(ancho, 68.0 if principal else 58.0)
	b.focus_mode = Control.FOCUS_ALL

	var f := FontVariation.new()
	f.base_font = FUENTE_TITULO
	f.variation_opentype = {"wght": 700 if principal else 600}
	b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", 30 if principal else 25)

	var relleno := ROSA if principal else PANEL_CLARO
	var letra := Color(0.20, 0.06, 0.16) if principal else CREMA
	b.add_theme_color_override("font_color", letra)
	b.add_theme_color_override("font_hover_color", letra)
	b.add_theme_color_override("font_pressed_color", letra)
	b.add_theme_color_override("font_focus_color", letra)
	b.add_theme_color_override("font_disabled_color", Color(letra, 0.4))

	b.add_theme_stylebox_override("normal", _caja(relleno))
	b.add_theme_stylebox_override("hover", _caja(relleno.lightened(0.12)))
	# Al pulsar se hunde: el desplazamiento hacia abajo es lo que hace que un
	# botón plano se sienta como algo que se aprieta.
	b.add_theme_stylebox_override("pressed", _caja(relleno.darkened(0.15), 3))
	b.add_theme_stylebox_override("focus", _caja(relleno, 0, true))
	b.add_theme_stylebox_override("disabled", _caja(Color(relleno, 0.35)))
	return b


static func _caja(relleno: Color, hundir: int = 0,
		marcado: bool = false) -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = relleno
	c.corner_radius_top_left = 22
	c.corner_radius_top_right = 22
	c.corner_radius_bottom_left = 22
	c.corner_radius_bottom_right = 22
	c.content_margin_left = 26
	c.content_margin_right = 26
	c.content_margin_top = 12 + hundir
	c.content_margin_bottom = 12 - hundir
	if marcado:
		c.border_width_left = 3
		c.border_width_right = 3
		c.border_width_top = 3
		c.border_width_bottom = 3
		c.border_color = ORO
	if hundir == 0:
		c.shadow_color = Color(0.06, 0.02, 0.12, 0.45)
		c.shadow_size = 10
		c.shadow_offset = Vector2(0, 5)
	return c


## Un panel de fondo para agrupar cosas.
static func panel(relleno: Color = PANEL, radio: int = 24) -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = relleno
	c.corner_radius_top_left = radio
	c.corner_radius_top_right = radio
	c.corner_radius_bottom_left = radio
	c.corner_radius_bottom_right = radio
	c.content_margin_left = 24
	c.content_margin_right = 24
	c.content_margin_top = 20
	c.content_margin_bottom = 20
	return c


## Una barra deslizante para los volúmenes, del tamaño de un dedo.
static func barra(valor: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = valor
	s.custom_minimum_size = Vector2(300, 46)

	var riel := StyleBoxFlat.new()
	riel.bg_color = Color(0.14, 0.07, 0.24)
	riel.corner_radius_top_left = 8
	riel.corner_radius_top_right = 8
	riel.corner_radius_bottom_left = 8
	riel.corner_radius_bottom_right = 8
	riel.content_margin_top = 8
	riel.content_margin_bottom = 8
	s.add_theme_stylebox_override("slider", riel)

	var lleno := StyleBoxFlat.new()
	lleno.bg_color = ROSA
	lleno.corner_radius_top_left = 8
	lleno.corner_radius_top_right = 8
	lleno.corner_radius_bottom_left = 8
	lleno.corner_radius_bottom_right = 8
	s.add_theme_stylebox_override("grabber_area", lleno)
	s.add_theme_stylebox_override("grabber_area_highlight", lleno)
	return s
