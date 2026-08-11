extends CanvasLayer
class_name PanelDialogo
## Muestra un diálogo línea a línea, con el texto escribiéndose.
##
## ## Por qué se escribe letra a letra
##
## No es decoración: a los 8 años se lee despacio, y un bloque de texto que
## aparece de golpe se salta sin leer. Escribiéndose, el ritmo lo marca el
## juego. Y quien ya sabe lo que pone puede tocar para completarlo de golpe.
##
## ## El toque para avanzar tiene dos fases
##
## El primer toque **completa la línea**; el segundo pasa a la siguiente. Sin
## esa distinción, un toque impaciente se come una frase entera sin que se
## llegue a ver.
##
## El audio de cada línea (generado con fish.audio) se reproduce si existe; si
## no, el diálogo funciona igual, en silencio.

signal terminado(dialogo_id: String)
signal linea_mostrada(indice: int)

@export var velocidad_por_defecto: float = 42.0
## Cuánto sube el panel al aparecer, en píxeles.
@export var altura_entrada: float = 60.0

@onready var _marco: Control = $Marco
@onready var _nombre: Label = $Marco/Nombre
## El recuadro del retrato en vivo. Se crea la primera vez que hace falta.
var _retrato: TextureRect = null
@onready var _texto: RichTextLabel = $Marco/Texto
@onready var _flecha: Label = $Marco/Flecha
@onready var _voz: AudioStreamPlayer = $Voz

var _boton_cerrar: Button = null

var _dialogo: Dialogo = null
var _indice: int = -1
var _escritos: float = 0.0
var _escribiendo: bool = false
var _esperando: bool = false
var _pausa: float = 0.0
var _velocidad_actual: float = 42.0


func _ready() -> void:
	# Los encuentros lo buscan por grupo: así puede haber uno solo por escena
	# sin que nadie tenga que saber dónde está colgado en el árbol.
	add_to_group("panel_dialogo")
	visible = false
	set_process(false)
	_flecha.visible = false
	_dejar_pasar_el_toque(_marco)
	_montar_cerrar()


## Hace que el cuadro no se coma los toques.
##
## Un `Control` con el filtro por defecto (`STOP`) consume el clic antes de que
## llegue a `_unhandled_input`. Como el cuadro ocupa media pantalla, el diálogo
## solo avanzaba tocando FUERA de él — que es justo donde nadie toca, porque lo
## que se está mirando es el texto.
##
## Se aplica a todo el árbol del marco: basta que un hijo lo pare (la etiqueta
## del nombre, el texto) para que el agujero siga ahí.
func _dejar_pasar_el_toque(nodo: Node) -> void:
	if nodo is Control:
		(nodo as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for hijo in nodo.get_children():
		_dejar_pasar_el_toque(hijo)


## Botón de cerrar, arriba a la derecha del cuadro.
##
## Este SÍ para el toque: es la única parte del cuadro que hace algo distinto
## de avanzar, y hay que poder salir de una conversación ya vista sin tener que
## pasar todas las frases.
func _montar_cerrar() -> void:
	_boton_cerrar = Button.new()
	_boton_cerrar.name = "Cerrar"
	_boton_cerrar.text = "✕"
	_boton_cerrar.focus_mode = Control.FOCUS_NONE
	_boton_cerrar.mouse_filter = Control.MOUSE_FILTER_STOP
	_boton_cerrar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Área generosa: en un móvil, una equis de veinte píxeles no se acierta.
	_boton_cerrar.custom_minimum_size = Vector2(56, 56)
	_boton_cerrar.position = Vector2(-64, 8)
	_boton_cerrar.add_theme_font_size_override("font_size", 26)
	_boton_cerrar.pressed.connect(_al_pulsar_cerrar)
	_marco.add_child(_boton_cerrar)


## Arranca una conversación. Devuelve false si no hay nada que decir.
func mostrar(dialogo: Dialogo) -> bool:
	if dialogo == null or dialogo.tamano() == 0:
		return false
	_dialogo = dialogo
	_indice = -1
	visible = true
	set_process(true)

	# Sube desde abajo: aparecer de golpe en mitad de la pantalla asusta.
	_marco.position.y += altura_entrada
	_marco.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_marco, "position:y", _marco.position.y - altura_entrada, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_marco, "modulate:a", 1.0, 0.18)

	_siguiente_linea()
	return true


func _process(delta: float) -> void:
	# Las acciones se consultan por estado y no por evento. Un `InputEvent` solo
	# llega si alguien lo emite de verdad; `Input.action_press()` —que es lo que
	# usan los botones táctiles y las herramientas de prueba— cambia el estado
	# sin generar evento, y por `_unhandled_input` el diálogo no avanzaba nunca.
	if Input.is_action_just_pressed("ui_cancel"):
		_al_pulsar_cerrar()
		return
	if Input.is_action_just_pressed("attack") \
			or Input.is_action_just_pressed("jump") \
			or Input.is_action_just_pressed("ui_accept"):
		avanzar()

	if _esperando:
		_pausa -= delta
		if _pausa <= 0.0:
			_esperando = false
			_flecha.visible = true
		return

	if not _escribiendo:
		return

	var linea := _linea_actual()
	if linea == null:
		return
	_escritos += _velocidad_actual * delta
	var total := _texto.get_total_character_count()
	_texto.visible_characters = int(_escritos)
	if _escritos >= float(total):
		_terminar_linea()


## Tocar o hacer clic en cualquier parte de la pantalla también avanza. Las
## teclas y los botones se miran en `_process`, por estado.
func _unhandled_input(evento: InputEvent) -> void:
	if not visible:
		return
	# El tipo va explícito: `InputEvent` no declara `pressed`, así que las
	# comprobaciones de toque devuelven Variant y GDScript no puede inferir el
	# tipo del conjunto. Sin esto, error de parseo al arrancar.
	var avanza: bool = false
	if evento is InputEventScreenTouch:
		avanza = (evento as InputEventScreenTouch).pressed
	elif evento is InputEventMouseButton:
		var clic := evento as InputEventMouseButton
		avanza = clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT
	if not avanza:
		return
	get_viewport().set_input_as_handled()
	avanzar()


## Salir de la conversación sin pasar todas las frases.
##
## Corta la voz: si no, el personaje sigue hablando con el cuadro ya cerrado.
## El diálogo se da por terminado igual que si se hubiera leído entero, para
## que lo que desbloquee se desbloquee — cerrar es una comodidad, no un castigo.
func _al_pulsar_cerrar() -> void:
	if not visible:
		return
	_voz.stop()
	_esperando = false
	_escribiendo = false
	_indice = _dialogo.tamano() if _dialogo != null else 0
	_cerrar()


## Un paso del diálogo: primero completa la línea, después pasa a la siguiente.
func avanzar() -> void:
	if not visible:
		return
	if _escribiendo:
		_escritos = float(_texto.get_total_character_count())
		_texto.visible_characters = -1
		_terminar_linea()
	elif not _esperando:
		_siguiente_linea()


func _terminar_linea() -> void:
	_escribiendo = false
	_texto.visible_characters = -1
	var linea := _linea_actual()
	_pausa = linea.pausa_final if linea != null else 0.0
	_esperando = _pausa > 0.0
	if not _esperando:
		_flecha.visible = true


## Cuelga el retrato en vivo del cuadro, o lo quita si se le pasa `null`.
##
## El recuadro se crea la primera vez y luego solo se enseña o se esconde: es
## una esquina del panel, no hace falta reconstruirlo en cada conversación.
##
## La textura viene de un `SubViewport` que enfoca al personaje de verdad, así
## que **se mueve**: si está diciendo su frase con la animación de hablar, aquí
## se le ve decirla. Ver [`retrato.gd`](retrato.gd).
func poner_retrato(textura: Texture2D) -> void:
	if _retrato == null:
		_retrato = TextureRect.new()
		_retrato.name = "Retrato"
		_retrato.custom_minimum_size = Vector2(132, 132)
		_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Sobre el marco y pegado al borde de arriba: es donde no tapa el texto
		# y donde se mira antes de empezar a leer.
		_retrato.set_anchors_preset(Control.PRESET_TOP_LEFT)
		# Encima del cuadro y por delante de la etiqueta del nombre, que se corre
		# a la derecha para dejarle sitio. Puesto más abajo le tapaba el nombre a
		# medias, que es peor que no tener retrato.
		_retrato.position = Vector2(6, -128)
		var marco := get_node_or_null("Marco")
		if marco != null:
			marco.add_child(_retrato)
		else:
			add_child(_retrato)

	_retrato.texture = textura
	_retrato.visible = textura != null
	# El nombre se aparta para no quedar debajo del retrato.
	if _nombre != null:
		_nombre.position.x = 128.0 if textura != null else 24.0


func _siguiente_linea() -> void:
	_indice += 1
	if _dialogo == null or _indice >= _dialogo.tamano():
		_cerrar()
		return

	var linea := _dialogo.lineas[_indice]
	_nombre.text = _nombre_visible(linea.hablante)
	_texto.text = linea.texto
	_texto.visible_characters = 0
	_escritos = 0.0
	_escribiendo = true
	_flecha.visible = false
	_velocidad_actual = linea.velocidad if linea.velocidad > 0.0 else velocidad_por_defecto

	if linea.audio != null:
		_voz.stream = linea.audio
		_voz.play()
		# La escritura se acompasa a la voz: se reparte el texto entre lo que
		# dura el audio. Con una velocidad fija, el texto acaba mucho antes que
		# la frase y parece que el personaje sigue hablando solo, o al revés.
		var duracion := linea.audio.get_length()
		var letras := float(_texto.get_total_character_count())
		if duracion > 0.15 and letras > 0.0:
			# Un pelín más rápido que la voz: es mejor terminar de leer justo
			# antes de que acabe la frase que ir por detrás.
			_velocidad_actual = (letras / duracion) * 1.08

	linea_mostrada.emit(_indice)


func _cerrar() -> void:
	set_process(false)
	var id := _dialogo.id if _dialogo != null else ""
	var desbloquea := _dialogo.desbloquea if _dialogo != null else ""
	var mensaje := _dialogo.mensaje_final if _dialogo != null else ""

	var t := create_tween()
	t.tween_property(_marco, "modulate:a", 0.0, 0.18)
	t.tween_callback(func() -> void:
		visible = false
		if not desbloquea.is_empty():
			EventBus.sailor_unlocked.emit(desbloquea)
		if not mensaje.is_empty():
			EventBus.show_message.emit(mensaje, 2.5)
		terminado.emit(id)
	)
	_dialogo = null


func _linea_actual() -> LineaDialogo:
	if _dialogo == null or _indice < 0 or _indice >= _dialogo.tamano():
		return null
	return _dialogo.lineas[_indice]


## Los ids son en minúscula y sin acentos para que valgan como nombre de
## archivo; lo que se enseña en pantalla es otra cosa.
static func _nombre_visible(id: String) -> String:
	match id:
		"serena": return "Serena"
		"luna": return "Luna"
		"mercury": return "Amy"
		"mars": return "Rei"
		"jupiter": return "Makoto"
		"venus": return "Minako"
		"chibi_moon": return "Chibi Moon"
		"tuxedo": return "Tuxedo Mask"
		_: return id.capitalize()
