extends State
## Todos los ataques del guardián, en un solo estado.
##
## ## Por qué uno solo
##
## Cada ataque son las mismas tres partes —avisa, golpea, se recupera— y solo
## cambian los números: qué animación, cuánto avisa, dónde hace daño y si sigue a
## la jugadora mientras carga. Un estado por ataque serían cinco archivos casi
## idénticos, y añadir el sexto sería copiar y pegar el quinto.
##
## Así, un ataque nuevo es una fila en `GuardianPortal.REPERTORIO`.
##
## ## Lo que arregla
##
## Antes tenía un puñetazo y el golpe al suelo, y con eso la pelea se resolvía
## de una sola manera: alejarse un paso, acercarse a pegar, repetir. Un jefe con
## un ataque no tiene ritmo, tiene un bucle — y en cuanto se le pilla el bucle
## deja de haber pelea.
##
## Ahora hay cinco, y **cada uno pide una respuesta distinta**: el barrido va a
## ras de suelo y se salta; el gancho va alto y saltar es lo peor que se puede
## hacer, hay que salir; el golpe al suelo cubre un círculo y hay que alejarse;
## la embestida castiga quedarse lejos mirando. No se puede ganar con una sola
## costumbre.

var _ficha: Dictionary = {}
var _fase: int = 0
var _tiempo: float = 0.0
var _marca: MeshInstance3D = null
var _material: StandardMaterial3D = null
var _forma_previa: Shape3D = null
var _sitio_previo: Vector3 = Vector3.ZERO
var _rumbo: Vector3 = Vector3.FORWARD


func enter(_msg: Dictionary = {}) -> void:
	var jefe := actor as GuardianPortal
	_ficha = jefe.ficha_elegida()
	_fase = 0
	_tiempo = 0.0
	jefe.attack = jefe.datos_de(_ficha)
	jefe.hitbox.attack = jefe.attack
	jefe.avisar_ataque(_ficha)
	if _ficha.get("area", false):
		_pintar_el_aviso()


func exit() -> void:
	var e := actor as Enemy
	e.hitbox.disable()
	_devolver_la_caja()
	if _marca != null and is_instance_valid(_marca):
		_marca.queue_free()
	_marca = null


func physics_update(delta: float) -> String:
	var jefe := actor as GuardianPortal
	_tiempo += delta

	var aviso: float = _ficha.get("aviso", 1.0)
	var activo: float = _ficha.get("activo", 0.22)
	var resto: float = _ficha.get("resto", 1.0)

	match _fase:
		0:
			# EL SEGUIMIENTO ES DISTINTO EN CADA ATAQUE, Y AHÍ ESTÁ LA GRACIA.
			#
			# Si todos siguen igual, la respuesta es siempre la misma. El barrido
			# apenas corrige, así que esquivarlo de lado funciona; la embestida
			# corrige mucho al principio y nada al final, así que hay que esperar
			# a que se comprometa antes de apartarse. Eso es lo que hace que haya
			# que mirar QUÉ ataque viene, en vez de reaccionar siempre igual.
			var t := clampf(_tiempo / maxf(aviso, 0.01), 0.0, 1.0)
			var sigue: float = _ficha.get("sigue", 1.0)
			# Deja de corregir en el último tramo: un ataque que te persigue
			# hasta el instante del impacto no se puede esquivar, solo aguantar.
			var ventana: float = _ficha.get("hasta", 0.75)
			if t < ventana and sigue > 0.01:
				jefe.face_target(delta * sigue)
			jefe.brake(delta, 12.0)
			jefe.set_telegraph_pulse(t)
			if _marca != null:
				_crecer_el_aviso(t)
			if _tiempo >= aviso:
				_fase = 1
				_tiempo = 0.0
				_rumbo = jefe.get_forward()
				_montar_la_caja()
				jefe.hitbox.enable(jefe.attack)
				jefe.sonar_impacto(_ficha)
				CombatFeel.shake(_ficha.get("temblor", 0.5), 0.45)
				if _material != null:
					_material.albedo_color = Color(1.0, 0.95, 0.75, 0.75)
		1:
			# La embestida avanza mientras el golpe está activo; los demás se
			# quedan clavados donde estaban.
			var empuje: float = _ficha.get("avanza", 0.0)
			if empuje > 0.0:
				jefe.velocity.x = _rumbo.x * empuje
				jefe.velocity.z = _rumbo.z * empuje
			else:
				jefe.brake(delta, 16.0)
			if _tiempo >= activo:
				_fase = 2
				_tiempo = 0.0
				jefe.hitbox.disable()
				_devolver_la_caja()
				jefe.reset_color()
				if _marca != null and _material != null:
					var t2 := create_tween()
					t2.tween_property(_marca, "scale", Vector3(1.25, 1.0, 1.25), 0.25)
					t2.parallel().tween_property(_material, "albedo_color:a", 0.0, 0.25)
		2:
			jefe.brake(delta, 10.0)
			if _tiempo >= resto:
				CombatDirector.release_token(jefe)
				return "Wait"
	return ""


## La caja de daño de este ataque. Cada uno tiene la suya, y ahí está la mitad
## del diseño: alta, baja, delante o alrededor.
func _montar_la_caja() -> void:
	var jefe := actor as GuardianPortal
	var forma := _caja()
	if forma == null:
		return
	_forma_previa = forma.shape
	_sitio_previo = jefe.hitbox.position

	if _ficha.get("area", false):
		var cil := CylinderShape3D.new()
		cil.radius = _ficha.get("radio", 6.0)
		cil.height = _ficha.get("alto", 3.0)
		forma.shape = cil
		jefe.hitbox.position = Vector3(0.0, _ficha.get("centro_y", 1.0), 0.0)
		return

	var caja := BoxShape3D.new()
	caja.size = _ficha.get("caja", Vector3(3.4, 2.4, 2.6))
	forma.shape = caja
	jefe.hitbox.position = Vector3(0.0, _ficha.get("centro_y", 1.2),
		-_ficha.get("alcance", 1.5))


func _devolver_la_caja() -> void:
	if _forma_previa == null:
		return
	var jefe := actor as GuardianPortal
	var forma := _caja()
	if forma != null:
		forma.shape = _forma_previa
	if jefe.hitbox != null:
		jefe.hitbox.position = _sitio_previo
	_forma_previa = null


func _caja() -> CollisionShape3D:
	var e := actor as Enemy
	if e.hitbox == null:
		return null
	for hijo in e.hitbox.get_children():
		if hijo is CollisionShape3D:
			return hijo as CollisionShape3D
	return null


## El círculo del suelo, solo para los ataques de área. Un disco relleno: se ve
## de un vistazo dónde NO hay que estar, que es lo único que hace falta saber.
func _pintar_el_aviso() -> void:
	var e := actor as Enemy
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(1.0, 0.42, 0.52, 0.30)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

	var malla := CylinderMesh.new()
	var r: float = _ficha.get("radio", 6.0)
	malla.top_radius = r
	malla.bottom_radius = r
	malla.height = 0.06
	malla.radial_segments = 28

	_marca = MeshInstance3D.new()
	_marca.mesh = malla
	_marca.material_override = _material
	_marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.get_parent().add_child(_marca)
	_marca.global_position = e.global_position + Vector3.UP * 0.06
	_marca.scale = Vector3(0.05, 1.0, 0.05)


func _crecer_el_aviso(t: float) -> void:
	if _marca == null or not is_instance_valid(_marca):
		return
	var e := actor as Enemy
	_marca.global_position = e.global_position + Vector3.UP * 0.06
	var crecido := 1.0 - pow(1.0 - t, 2.4)
	_marca.scale = Vector3(maxf(crecido, 0.05), 1.0, maxf(crecido, 0.05))
	if _material != null:
		_material.albedo_color.a = 0.22 + 0.30 * t
