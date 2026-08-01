extends Resource
class_name AttackData
## Datos de un golpe. Editable desde el inspector sin tocar código.
##
## Analogía backend: es un DTO de configuración. Ajustar el combate consiste en
## tocar estos números, no en reescribir la lógica.
##
## Los tres tiempos son el vocabulario clásico de los juegos de acción:
##   windup   → anticipación: se ve venir el golpe
##   active   → la hitbox está encendida, es cuando conecta
##   recovery → recuperación: estás vendido si fallas
##
## Cuando lleguen las animaciones reales (Fase 2), `windup` y `active` los
## marcará el AnimationPlayer con call method tracks y estos campos pasarán a
## ser solo el respaldo. El resto de valores seguirá viviendo aquí.

@export var display_name: String = "Golpe"

@export_group("Tiempos")
@export_range(0.0, 1.0, 0.01) var windup: float = 0.10
@export_range(0.0, 1.0, 0.01) var active: float = 0.10
@export_range(0.0, 1.0, 0.01) var recovery: float = 0.16

@export_group("Daño e impacto")
@export var damage: int = 1
@export var knockback: float = 4.0
@export var knockback_up: float = 0.0
## Cuánto se lanza el personaje hacia delante al golpear. Da sensación de peso.
@export var lunge: float = 2.0

@export_group("Sensación")
@export_range(0.0, 0.5, 0.01) var hit_stop: float = 0.06
@export_range(0.0, 2.0, 0.05) var shake: float = 0.25

## Duración total del golpe.
func total_time() -> float:
	return windup + active + recovery
