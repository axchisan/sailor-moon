extends Node3D
class_name TerrenoNivel
## El terreno que rodea al escenario: llano donde se juega, colinas al alejarse.
##
## ## Por qué se rehizo
##
## El primer intento fue un disco plano con un anillo de placas inclinadas al
## borde. No funcionaba, y no era cuestión de ajustar números:
##
## - **El llano era una mesa.** Salías del parque y todo era plano hasta el
##   horizonte, sin nada que mirar ni razón para andar.
## - **Las placas se leían como paredes.** Una superficie plana inclinada 60°
##   es una rampa, y el ojo la lee como construcción, no como monte.
## - **Tenían juntas.** Entre placa y placa quedaban rendijas por las que
##   colarse, y cada una había que taparla a mano.
##
## Lo tres se arreglan con la misma decisión: **una sola malla de terreno con
## altura**, generada por ruido. No hay juntas porque es continua, no parece
## construida porque no tiene aristas rectas, y el llano deja de ser una mesa
## porque puede ondular suavemente.
##
## ## Cómo se decide la altura
##
## En función de la distancia al centro, en tres franjas:
##
##     |<-- llano -->|<-- faldas -->|<-- colinas -->
##     0            r_llano       r_colinas       borde
##
## - **Llano:** altura 0 exacta. Es donde se apoya el blockout, y una sola
##   ondulación aquí dejaría el suelo del parque flotando o enterrado.
## - **Faldas:** empieza a ondular, cada vez más. La transición usa una curva
##   suave, que es lo que evita el escalón feo entre lo plano y lo accidentado.
## - **Colinas:** el relieve manda y sube hasta cerrar el paso.
##
## ## La colisión
##
## `HeightMapShape3D`, que es exactamente una rejilla de alturas — la misma que
## se usa para dibujar. Una forma cóncava de miles de triángulos costaría mucho
## más y daría lo mismo.

## Metros por celda. Más pequeño = colinas más detalladas y mucha más malla.
## 2,5 m es el punto donde una colina se ve redonda y la rejilla sigue siendo
## de menos de 20.000 vértices.
@export var paso: float = 2.5
## Medio lado del terreno cuadrado, en metros.
@export var alcance: float = 130.0

@export_group("Relieve")
## Hasta aquí el terreno es plano y liso: es donde se apoya el escenario.
@export var radio_llano: float = 46.0
## Desde aquí mandan las colinas que cierran el mapa.
@export var radio_colinas: float = 86.0
## Cuánto ondula el campo abierto entre el parque y las colinas.
@export var altura_campo: float = 1.8
## Cuánto levantan las colinas del borde.
@export var altura_colinas: float = 22.0
## Desde aquí arranca la cordillera del fondo, que ya no se pisa nunca.
@export var radio_cordillera: float = 112.0
@export var altura_cordillera: float = 46.0
## Tamaño de las ondulaciones, en metros.
@export var escala_campo: float = 26.0
@export var escala_colinas: float = 62.0
@export var semilla: int = 7781

@export_group("Aspecto")
@export var superficie: String = "hierba_lejos"
## A qué color tira lo lejano. El morado azulado no es capricho: es el color del
## aire acumulado, y es lo que hace que una montaña se lea como lejana.
@export var color_lejania: Color = Color(0.63, 0.62, 0.80)

var _alturas: PackedFloat32Array = PackedFloat32Array()
var _lado: int = 0
var _ruido: FastNoiseLite = null
var _ruido_fino: FastNoiseLite = null


func construir() -> void:
	for hijo in get_children():
		hijo.queue_free()

	_preparar_ruido()
	_lado = int(alcance * 2.0 / paso) + 1
	_alturas.resize(_lado * _lado)

	for j in _lado:
		for i in _lado:
			var x := -alcance + float(i) * paso
			var z := -alcance + float(j) * paso
			_alturas[j * _lado + i] = altura_en(x, z)

	_montar_malla()
	_montar_colision()
	print("[Terreno] %dx%d celdas (%.0f m de lado), colinas desde %.0f m" % [
		_lado, _lado, alcance * 2.0, radio_colinas])


func _preparar_ruido() -> void:
	_ruido = FastNoiseLite.new()
	_ruido.seed = semilla
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido.frequency = 1.0 / maxf(escala_colinas, 1.0)
	# Dos octavas: una da colinas demasiado limpias, cuatro las vuelve ruidosas
	# y aparecen picos afilados que no pegan con el estilo.
	_ruido.fractal_octaves = 2

	_ruido_fino = FastNoiseLite.new()
	_ruido_fino.seed = semilla + 991
	_ruido_fino.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido_fino.frequency = 1.0 / maxf(escala_campo, 1.0)
	_ruido_fino.fractal_octaves = 2


## Altura del terreno en un punto. Es la única fuente de verdad: la usan la
## malla, la colisión y cualquiera que necesite posar algo encima.
func altura_en(x: float, z: float) -> float:
	var distancia := sqrt(x * x + z * z)
	if distancia <= radio_llano:
		return 0.0

	# Cuánto se ha salido del llano, de 0 a 1, con curva suave. `smoothstep` es
	# lo que evita el pliegue: con una rampa lineal se ve la línea exacta donde
	# el terreno empieza a subir, y canta muchísimo.
	var t_campo := smoothstep(radio_llano, radio_colinas, distancia)
	var ondulado := _ruido_fino.get_noise_2d(x, z) * altura_campo * t_campo

	if distancia <= radio_colinas:
		return ondulado

	# Las colinas crecen con la distancia, pero **moduladas por ruido**: si
	# subieran parejo se vería el mismo anillo de cráter de antes, solo que
	# redondeado. Con el ruido hay collados más bajos y cerros más altos.
	var t_colina := smoothstep(radio_colinas, radio_cordillera, distancia)
	var relieve := (_ruido.get_noise_2d(x, z) + 1.0) * 0.5
	# Nunca baja del 45 %: un collado por el que se pudiera pasar andando
	# dejaría un agujero en el límite del mundo.
	relieve = 0.45 + relieve * 0.55
	var altura := ondulado + pow(t_colina, 1.35) * altura_colinas * relieve

	# Y más allá, la cordillera. Sustituye a los conos morados que hacían de
	# montañas: en vez de objetos lejanos con silueta de cono —que es justo lo
	# que los delataba— es el mismo terreno subiendo mucho más, con el mismo
	# ruido, y desteñido por la perspectiva aérea del shader.
	if distancia > radio_cordillera:
		var t_sierra := smoothstep(radio_cordillera, alcance * 0.95, distancia)
		var cresta := (_ruido.get_noise_2d(x * 0.6, z * 0.6) + 1.0) * 0.5
		altura += pow(t_sierra, 1.6) * altura_cordillera * (0.35 + cresta * 0.65)
	return altura


func _montar_malla() -> void:
	var malla := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.resize(_lado * _lado)
	normales.resize(_lado * _lado)

	for j in _lado:
		for i in _lado:
			var x := -alcance + float(i) * paso
			var z := -alcance + float(j) * paso
			var k := j * _lado + i
			vertices[k] = Vector3(x, _alturas[k], z)
			normales[k] = _normal_en(i, j)

	# El ORDEN de cada triángulo decide hacia dónde mira su cara. Con el
	# contrario a este, el terreno entero se dibuja del revés: desde arriba se
	# ve su parte de abajo, el descarte de caras traseras la oculta, y queda un
	# nivel donde los árboles flotan sobre el color del cielo. La malla está
	# ahí, la colisión funciona y no hay ningún error en consola — solo no se
	# ve nada.
	for j in _lado - 1:
		for i in _lado - 1:
			var a := j * _lado + i
			var b := a + 1
			var c := a + _lado
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])

	var datos := []
	datos.resize(Mesh.ARRAY_MAX)
	datos[Mesh.ARRAY_VERTEX] = vertices
	datos[Mesh.ARRAY_NORMAL] = normales
	datos[Mesh.ARRAY_INDEX] = indices
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, datos)

	var visual := MeshInstance3D.new()
	visual.name = "Superficie"
	visual.mesh = malla
	# Material propio, no el compartido de la paleta: este necesita la
	# perspectiva aérea encendida y el resto de superficies del parque no.
	var material := PaletaTerreno.obtener(superficie).duplicate() as ShaderMaterial
	material.set_shader_parameter("lejania", 0.92)
	material.set_shader_parameter("centro_mundo", global_position)
	material.set_shader_parameter("desde", radio_colinas * 0.75)
	material.set_shader_parameter("hasta", alcance * 0.85)
	material.set_shader_parameter("color_lejania", color_lejania)
	visual.material_override = material
	# No proyecta sombra: es una superficie enorme y su sombra propia no aporta
	# nada, pero se come el mapa de sombras entero.
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)


## Normal por diferencias con los vecinos. Sin esto la malla sale con normales
## planas y las colinas se ven facetadas como un diamante.
func _normal_en(i: int, j: int) -> Vector3:
	var izq := _alturas[j * _lado + maxi(i - 1, 0)]
	var der := _alturas[j * _lado + mini(i + 1, _lado - 1)]
	var arr := _alturas[maxi(j - 1, 0) * _lado + i]
	var aba := _alturas[mini(j + 1, _lado - 1) * _lado + i]
	return Vector3(izq - der, 2.0 * paso, arr - aba).normalized()


func _montar_colision() -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "CuerpoTerreno"
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0

	var forma := CollisionShape3D.new()
	var mapa := HeightMapShape3D.new()
	mapa.map_width = _lado
	mapa.map_depth = _lado
	mapa.map_data = _alturas
	forma.shape = mapa
	# `HeightMapShape3D` se coloca centrado en el origen y con **una unidad por
	# celda**, no en metros. Hay que escalarlo al paso de la rejilla o la
	# colisión queda del tamaño equivocado y no coincide con lo que se ve.
	forma.scale = Vector3(paso, 1.0, paso)
	cuerpo.add_child(forma)
	add_child(cuerpo)
