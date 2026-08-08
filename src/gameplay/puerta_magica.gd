extends Node3D
class_name PuertaMagica
## Cortina de energía que corta el paso hasta que se cumple algo.
##
## En el Nivel 1 tapa la entrada del guardián hasta que los tres faroles están
## encendidos. Es lo que convierte «hay tres faroles por ahí» en un objetivo:
## sin algo que se abra al terminar, encenderlos no significa nada.
##
## Se ve **a través** a propósito. Una pared opaca parece el final del nivel;
## una cortina translúcida deja ver que hay algo más allá y que falta abrirla.

signal abierta

@export var ancho: float = 9.0
@export var alto: float = 3.6
@export var color: Color = Color(0.72, 0.55, 1.0, 0.35)
## Cuántos segmentos verticales. Más = más suave y más draw calls.
@export var segmentos: int = 5

var esta_abierta: bool = false

var _cuerpo: StaticBody3D = null
var _material: StandardMaterial3D = null
var _tiempo: float = 0.0


func _ready() -> void:
	_construir()


func _process(delta: float) -> void:
	if esta_abierta or _material == null:
		return
	# Latido lento: una barrera quieta se lee como pared del escenario, y así
	# se entiende que es algo que se puede quitar.
	_tiempo += delta
	var pulso := 0.75 + 0.25 * sin(_tiempo * 2.2)
	_material.emission_energy_multiplier = 0.5 * pulso


func _construir() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = color
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.emission_enabled = true
	_material.emission = color
	_material.emission_energy_multiplier = 0.5

	_cuerpo = StaticBody3D.new()
	_cuerpo.name = "Cuerpo"
	_cuerpo.collision_layer = 1
	_cuerpo.collision_mask = 0
	add_child(_cuerpo)

	var ancho_seg := ancho / float(segmentos)
	var malla := BoxMesh.new()
	malla.size = Vector3(ancho_seg * 0.94, alto, 0.18)
	for i in segmentos:
		var visual := MeshInstance3D.new()
		visual.mesh = malla
		visual.material_override = _material
		visual.position = Vector3(
			-ancho * 0.5 + ancho_seg * (float(i) + 0.5), alto * 0.5, 0.0)
		_cuerpo.add_child(visual)

	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(ancho, alto, 0.4)
	forma.shape = caja
	forma.position.y = alto * 0.5
	_cuerpo.add_child(forma)
	set_process(true)


func abrir() -> void:
	if esta_abierta:
		return
	esta_abierta = true
	set_process(false)

	# Se retira hacia arriba desvaneciéndose. Desaparecer de golpe deja la duda
	# de si se ha abierto o si ha fallado algo.
	var t := create_tween().set_parallel(true)
	t.tween_property(_cuerpo, "position:y", alto * 1.2, 0.55) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(_material, "albedo_color:a", 0.0, 0.55)
	t.chain().tween_callback(func() -> void:
		_cuerpo.visible = false
		for hijo in _cuerpo.get_children():
			if hijo is CollisionShape3D:
				(hijo as CollisionShape3D).set_deferred("disabled", true)
		abierta.emit()
	)
