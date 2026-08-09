extends SceneTree
## Hornea el patrón de las superficies del escenario a una textura.
##
## Uso:
##   godot --headless --path . --script tools/generar_textura_ruido.gd
##
## POR QUÉ EXISTE
##
## `terreno.gdshader` calculaba su patrón a base de ruido procedural: 2 octavas
## por muestra, 3 muestras por la proyección triplanar, más el grano y las
## vetas. Son **28 evaluaciones de hash por píxel** —unas trescientas
## operaciones— en la superficie que ocupa media pantalla. Ese era el coste que
## mantenía el juego clavado en 25-40 fps, y no se veía en el contador de
## triángulos porque no es geometría: es lo que cuesta pintar cada píxel.
##
## El patrón, además, **es siempre el mismo**. Lo que cambia entre la hierba y
## la madera son los colores y la escala, no el ruido. Así que se calcula una
## vez aquí, se guarda en una imagen, y en el móvil el shader hace tres lecturas
## de textura — que es justo para lo que una GPU tiene unidades dedicadas.
##
## QUÉ LLEVA CADA CANAL
##
## Los tres patrones que el shader necesitaba caben en una sola lectura:
##
##   R  manchas   dos octavas, las masas grandes de color
##   G  grano     ruido fino, rompe la repetición de las manchas
##   B  vetas     ruido estirado en un eje, para madera y tierra pisada
##
## POR QUÉ LAS FRECUENCIAS SON ENTERAS
##
## Una textura que se repite tiene que **cerrar por los bordes**, o se ve la
## costura en rejilla por todo el mapa. Eso obliga a que el ruido sea periódico,
## y para eso su frecuencia tiene que ser un número entero de celdas. Las del
## shader original (2,7 y 0,6) se han redondeado a las enteras más cercanas: el
## patrón sale del mismo tipo y a la escala a la que se ve no se distingue.

const LADO := 512
const DESTINO := "res://assets/textures/ruido_superficie.png"

## Cuántas celdas del patrón caben en una repetición de la textura.
##
## El shader divide la posición del mundo por `escala * DOMINIO`, así que una
## mancha sigue midiendo los mismos metros que antes: esto no cambia el aspecto,
## solo cuántas manchas hay dentro de cada copia de la imagen.
const DOMINIO := 4

## Frecuencias de cada patrón, en celdas por repetición de la textura.
const F_MANCHA_1 := DOMINIO          # la octava grande
const F_MANCHA_2 := DOMINIO * 3      # la octava fina (era 2,7)
const F_GRANO := DOMINIO * 13
const F_VETA_X := DOMINIO * 9
const F_VETA_Y := DOMINIO * 1        # muy estirada (era 0,6)


func _init() -> void:
	var img := Image.create(LADO, LADO, false, Image.FORMAT_RGB8)
	var inv := 1.0 / float(LADO)

	for j in LADO:
		var v := float(j) * inv
		for i in LADO:
			var u := float(i) * inv
			# Las mismas dos octavas que hacía el shader, con los mismos pesos.
			var manchas := _ruido(u * F_MANCHA_1, v * F_MANCHA_1, F_MANCHA_1) * 0.65 \
				+ _ruido(u * F_MANCHA_2, v * F_MANCHA_2, F_MANCHA_2) * 0.35
			var grano := _ruido(u * F_GRANO, v * F_GRANO, F_GRANO)
			var vetas := _ruido_rect(u * F_VETA_X, v * F_VETA_Y, F_VETA_X, F_VETA_Y)
			img.set_pixel(i, j, Color(manchas, grano, vetas))

	var err := img.save_png(ProjectSettings.globalize_path(DESTINO))
	if err != OK:
		push_error("No se pudo guardar %s (error %d)" % [DESTINO, err])
	else:
		print("Guardada %s — %dx%d, dominio de %d celdas" % [DESTINO, LADO, LADO, DOMINIO])
	quit()


# --- El mismo ruido que usaba el shader, pero periódico -----------------------

func _fract(x: float) -> float:
	return x - floor(x)


## Hash sin `sin()`, idéntico al de `terreno.gdshader`. Se envuelve el número de
## celda antes de entrar, y eso es lo que hace que la textura cierre.
func _picotazo(cx: int, cy: int, periodo_x: int, periodo_y: int) -> float:
	var px := float(wrapi(cx, 0, periodo_x))
	var py := float(wrapi(cy, 0, periodo_y))
	var a := _fract(px * 0.1031)
	var b := _fract(py * 0.1031)
	var c := _fract(px * 0.1031)
	var d := a * (b + 33.33) + b * (c + 33.33) + c * (a + 33.33)
	a += d
	b += d
	c += d
	return _fract((a + b) * c)


func _ruido(x: float, y: float, periodo: int) -> float:
	return _ruido_rect(x, y, periodo, periodo)


## Ruido de valor con suavizado cúbico, con período distinto por eje para poder
## estirar las vetas sin romper el cierre de la textura.
func _ruido_rect(x: float, y: float, per_x: int, per_y: int) -> float:
	var cx := floori(x)
	var cy := floori(y)
	var fx := x - float(cx)
	var fy := y - float(cy)
	# Suavizado cúbico: con interpolación lineal se ven los rombos de la rejilla.
	var tx := fx * fx * (3.0 - 2.0 * fx)
	var ty := fy * fy * (3.0 - 2.0 * fy)
	var a := _picotazo(cx, cy, per_x, per_y)
	var b := _picotazo(cx + 1, cy, per_x, per_y)
	var c := _picotazo(cx, cy + 1, per_x, per_y)
	var d := _picotazo(cx + 1, cy + 1, per_x, per_y)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)
