extends Control
class_name MenuPrincipal
## Lo primero que se ve al abrir el juego.
##
## ## Qué tiene que conseguir
##
## Que al abrirlo apetezca jugar. Nada más. No es una pantalla de opciones con
## un botón de jugar arriba: es **el cartel del juego**, y todo lo demás va
## detrás y más pequeño.
##
## Por eso el orden de la pantalla es: fondo que se mueve → título grande →
## botón de jugar → el resto. Lo que más ocupa es lo que más importa.
##
## ## Cómo entra
##
## Escalonado, no de golpe: primero el fondo, luego el título bajando, luego los
## botones apareciendo uno detrás de otro. Es medio segundo largo y es lo que
## separa «se ha abierto una ventana» de «ha empezado algo».
##
## ## Nada de callejones
##
## Todos los botones llevan a algo que existe y funciona, y de todas las
## pantallas se vuelve. Un menú con opciones que no hacen nada enseña a no
## fiarse de los botones.

const RUTA_NIVEL := "res://scenes/levels/nivel_1_parque.tscn"

var _fondo: FondoMenu = null
var _columna: VBoxContainer = null
var _titulo: Control = null
var _capa: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# El menú corre con el juego pausado —se usa también desde la pausa— así que
	# tiene que seguir procesando.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fondo = FondoMenu.new()
	add_child(_fondo)
	_montar()
	_entrar()
	Musica.pedir(Musica.Capa.FONDO, "menu")
	SceneLoader.escena_lista.call_deferred()


func _montar() -> void:
	_capa = Control.new()
	_capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_capa)

	# TÍTULO ARRIBA, BOTONES ABAJO, Y AIRE EN MEDIO.
	#
	# En un móvil la mano tapa la mitad de abajo, así que lo que hay que mirar va
	# arriba y lo que hay que tocar, abajo — donde llega el pulgar sin recolocar
	# la mano.
	_titulo = _hacer_titulo()
	_capa.add_child(_titulo)

	_columna = VBoxContainer.new()
	_columna.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_columna.anchor_top = 0.46
	_columna.anchor_bottom = 1.0
	_columna.offset_left = -210.0
	_columna.offset_right = 210.0
	_columna.offset_bottom = -46.0
	_columna.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_columna.alignment = BoxContainer.ALIGNMENT_END
	_columna.add_theme_constant_override("separation", 14)
	_capa.add_child(_columna)

	var hay := _hay_alguna_partida()
	_boton("JUGAR" if not hay else "CONTINUAR", _al_jugar, true)
	if hay:
		_boton("Partidas", _al_partidas)
	_boton("Ajustes", _al_ajustes)
	_boton("Créditos", _al_creditos)

	var pie := Estilo.texto("Un regalo hecho a mano · 2026", 15,
		Color(Estilo.CREMA, 0.5))
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_columna.add_child(pie)


func _hacer_titulo() -> Control:
	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_CENTER_TOP)
	caja.anchor_top = 0.10
	caja.offset_left = -400.0
	caja.offset_right = 400.0
	caja.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_theme_constant_override("separation", -6)

	var uno := Estilo.texto_con_sombra("SAILOR MOON", 58, Estilo.CREMA, true, 800)
	uno.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(uno)

	# El subtítulo en rosa y más pequeño: el nombre de la saga se reconoce, y lo
	# que dice de qué va ESTE juego va debajo sin robarle sitio.
	var dos := Estilo.texto_con_sombra("El Cristal de los Sueños", 34,
		Estilo.ROSA_CLARO, true, 600)
	dos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(dos)
	return caja


func _boton(cadena: String, alpulsar: Callable, principal: bool = false) -> Button:
	var b := Estilo.boton(cadena, 420.0, principal)
	b.pressed.connect(alpulsar)
	_columna.add_child(b)
	return b


## Entrada escalonada. Cada cosa llega un poco después de la anterior.
func _entrar() -> void:
	_titulo.modulate.a = 0.0
	_titulo.position.y -= 40.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_titulo, "modulate:a", 1.0, 0.7).set_delay(0.15)
	t.tween_property(_titulo, "position:y", _titulo.position.y + 40.0, 0.9) \
		.set_delay(0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var i := 0
	for hijo in _columna.get_children():
		var c := hijo as Control
		if c == null:
			continue
		c.modulate.a = 0.0
		var paso := create_tween()
		paso.tween_interval(0.55 + 0.09 * float(i))
		paso.tween_property(c, "modulate:a", 1.0, 0.35)
		i += 1


func _hay_alguna_partida() -> bool:
	for i in PartidasGuardadas.CUANTAS:
		if PartidasGuardadas.hay_algo(i):
			return true
	return false


func _sonar() -> void:
	AudioManager.play_sfx(preload("res://assets/audio/sfx/ui/toque.wav"),
		-16.0, 0.06)


## JUGAR va directo a jugar. Si hay partidas, a la última tocada; si no hay
## ninguna, a la primera ranura y a correr.
##
## Meter una pantalla de selección por delante en la primera partida es poner un
## trámite entre el botón y el juego — y la primera vez que se abre algo es
## cuando menos paciencia hay.
func _al_jugar() -> void:
	var cual := 0
	for i in PartidasGuardadas.CUANTAS:
		if PartidasGuardadas.hay_algo(i):
			cual = i
			break
	PartidasGuardadas.cargar(cual)
	SceneLoader.change_scene(RUTA_NIVEL)


func _al_partidas() -> void:
	_abrir(PantallaPartidas.new())


func _al_ajustes() -> void:
	_abrir(PantallaAjustes.new())


func _al_creditos() -> void:
	_abrir(PantallaCreditos.new())


## Abre una subpantalla encima. El menú se queda debajo, escondido pero vivo:
## volver es quitar la de arriba, sin recargar nada.
func _abrir(pantalla: Control) -> void:
	_capa.visible = false
	add_child(pantalla)
	if pantalla.has_signal("cerrada"):
		pantalla.connect("cerrada", func() -> void:
			_capa.visible = true
			# Los botones se rehacen: si se ha borrado o creado una partida,
			# «JUGAR» y «CONTINUAR» ya no dicen lo mismo.
			for hijo in _columna.get_children():
				hijo.queue_free()
			await get_tree().process_frame
			var hay := _hay_alguna_partida()
			_boton("JUGAR" if not hay else "CONTINUAR", _al_jugar, true)
			if hay:
				_boton("Partidas", _al_partidas)
			_boton("Ajustes", _al_ajustes)
			_boton("Créditos", _al_creditos)
			var pie := Estilo.texto("Un regalo hecho a mano · 2026", 15,
				Color(Estilo.CREMA, 0.5))
			pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_columna.add_child(pie))
