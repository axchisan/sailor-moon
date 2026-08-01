extends GPUParticles3D
## Estallido de partículas de un solo uso que se autodestruye.
##
## Se instancia una por impacto y se libera sola. En un beat 'em up esto se
## dispara decenas de veces por segundo, así que el `queue_free` automático
## es obligatorio: sin él, la escena se llena de nodos muertos.

func _ready() -> void:
	one_shot = true
	emitting = false


## Lanza el estallido. Se llama justo después de instanciar.
func burst(color: Color, count: int = 18, scale_factor: float = 1.0) -> void:
	amount = maxi(1, count)

	# Se duplica el material para que cada estallido pueda tener su propio
	# color y tamaño sin pisar al de los demás.
	var settings := process_material as ParticleProcessMaterial
	if settings != null:
		settings = settings.duplicate() as ParticleProcessMaterial
		settings.color = color
		settings.scale_min = 0.10 * scale_factor
		settings.scale_max = 0.28 * scale_factor
		settings.initial_velocity_min = 2.0 * scale_factor
		settings.initial_velocity_max = 5.5 * scale_factor
		process_material = settings

	emitting = true
	# `lifetime` va en tiempo de juego; el temporizador ignora time_scale para
	# que el hit stop no deje partículas colgadas en escena.
	await get_tree().create_timer(lifetime + 0.3, true, false, true).timeout
	queue_free()
