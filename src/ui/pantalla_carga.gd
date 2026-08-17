extends CanvasLayer
class_name PantallaCarga
## Lo que se ve mientras el nivel se monta.
##
## ## Por qué hacía falta
##
## El cargador ya traía la escena en un hilo aparte, pero **nadie enseñaba
## nada**: se tocaba JUGAR y el juego se quedaba clavado unos segundos con la
## última imagen congelada. Eso no se lee como «está cargando», se lee como que
## se ha roto — y la reacción normal es volver a tocar, que empeora las cosas.
##
## ## El tirón no es cargar el archivo: es montar el nivel
##
## Traer el `.tscn` es rápido. Lo que cuesta es el `_ready()` del nivel, que
## genera el terreno, siembra mil ochocientos props, trocea las multimallas y
## construye el blockout — todo de golpe y sin poder repartirlo entre fotogramas.
##
## Por eso esta pantalla **no se quita cuando la escena carga**, sino cuando el
## nivel avisa de que ha terminado de montarse. Si se quitara antes, volvería el
## mismo tirón con la pantalla ya fuera.
##
## ## La barra no miente
##
## Sube con el progreso real hasta el 70%, y el resto lo cubre el montaje —que no
## se puede medir, así que avanza despacio y a ojo. Una barra que se planta en el
## 100% y luego espera es peor que no tener barra: dice que ha terminado cuando
## no ha terminado.

const PARTE_CARGA := 0.7

var _fondo: FondoMenu = null
var _barra: ColorRect = null
var _pista: Label = null
var _ancho: float = 520.0
var _valor: float = 0.0
var _montando: bool = false


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	EventBus.scene_load_progress.connect(_al_avanzar)
	set_process(true)


func _montar() -> void:
	var negro := ColorRect.new()
	negro.color = Color(0.09, 0.05, 0.17)
	negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(negro)

	# El mismo fondo del menú: el cielo, la luna y los pétalos. Cargar deja de
	# ser una pantalla muerta y pasa a ser el mismo sitio, más quieto.
	_fondo = FondoMenu.new()
	add_child(_fondo)

	var centro := Control.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	var titulo := Estilo.texto_con_sombra("Preparando el parque…", 34,
		Estilo.CREMA, true, 700)
	titulo.set_anchors_preset(Control.PRESET_CENTER)
	titulo.anchor_top = 0.44
	titulo.anchor_bottom = 0.44
	titulo.offset_left = -400.0
	titulo.offset_right = 400.0
	titulo.offset_top = -30.0
	titulo.offset_bottom = 30.0
	titulo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centro.add_child(titulo)

	var marco := ColorRect.new()
	marco.color = Color(0.14, 0.07, 0.24, 0.85)
	marco.set_anchors_preset(Control.PRESET_CENTER)
	marco.anchor_top = 0.56
	marco.anchor_bottom = 0.56
	marco.offset_left = -_ancho * 0.5
	marco.offset_right = _ancho * 0.5
	marco.offset_top = -9.0
	marco.offset_bottom = 9.0
	marco.grow_horizontal = Control.GROW_DIRECTION_BOTH
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(marco)

	_barra = ColorRect.new()
	_barra.color = Estilo.ROSA
	_barra.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_barra.offset_left = 3.0
	_barra.offset_right = 3.0
	_barra.offset_top = 3.0
	_barra.offset_bottom = -3.0
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.add_child(_barra)

	# Una frase del juego mientras se espera. No es relleno: da algo que leer,
	# y leer hace que veinte segundos se sientan como diez.
	_pista = Estilo.texto(PISTAS[randi() % PISTAS.size()], 19, Estilo.TENUE)
	_pista.set_anchors_preset(Control.PRESET_CENTER)
	_pista.anchor_top = 0.66
	_pista.anchor_bottom = 0.66
	_pista.offset_left = -420.0
	_pista.offset_right = 420.0
	_pista.offset_top = -40.0
	_pista.offset_bottom = 40.0
	_pista.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pista.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	centro.add_child(_pista)


const PISTAS := [
	"Las Estrellas de Sueño están repartidas por todo el parque. Algunas, en sitios altos.",
	"En la pausa puedes tocar un objetivo y te señalará hacia dónde ir.",
	"Los enemigos sueltan corazones cuando te queda poca vida.",
	"Los cristales de piedra guardan la partida y te curan del todo.",
	"Al guardián se le gana rodeándolo, no aguantando delante.",
	"Si algo brilla en lo alto de una roca, se puede trepar hasta ahí.",
]


func _al_avanzar(cuanto: float) -> void:
	_valor = maxf(_valor, cuanto * PARTE_CARGA)
	if cuanto >= 1.0:
		_montando = true


func _process(delta: float) -> void:
	# Durante el montaje del nivel no llega ningún progreso —el hilo principal
	# está ocupado— así que la barra avanza sola muy despacio. Es una mentira
	# piadosa: dice «sigo vivo», que es lo único que hay que decir ahí.
	if _montando and _valor < 0.97:
		_valor += delta * 0.12
	if _barra != null:
		# Anclada al borde izquierdo (`PRESET_LEFT_WIDE`), así que `offset_right`
		# ES el ancho de lo lleno. Estaba puesto como si midiera lo que falta y
		# la barra se quedaba en un puntito pasara lo que pasara.
		_barra.offset_right = 3.0 + (_ancho - 6.0) * clampf(_valor, 0.0, 1.0)


## La quita el nivel cuando ha terminado de montarse.
func listo() -> void:
	_valor = 1.0
	set_process(false)
	var t := create_tween()
	t.tween_interval(0.15)
	t.tween_property(self, "offset", Vector2(0, 0), 0.01)
	await t.finished
	var f := create_tween()
	# Un fundido a la escena, no un corte: el corte después de una espera larga
	# se lee como otro tirón más.
	for hijo in get_children():
		var c := hijo as CanvasItem
		if c != null:
			f.parallel().tween_property(c, "modulate:a", 0.0, 0.45)
	await f.finished
	queue_free()
