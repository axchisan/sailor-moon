extends Node
## Bus de eventos global. Solo declara señales, NUNCA lógica.
##
## Analogía backend: esto es el broker de mensajes. Los sistemas publican y se
## suscriben aquí en vez de llamarse entre ellos. El HUD no conoce al jugador:
## escucha `health_changed`. Sin esto, en dos semanas el proyecto es un nudo.

# Un bus de eventos declara señales que emiten OTRAS clases, así que Godot las
# ve como "no usadas aquí". Sin esto, la consola se llena de ~24 avisos y los
# errores de verdad se pierden entre ellos.
@warning_ignore_start("unused_signal")

# --- Progresión ---
signal star_collected(total: int)
signal sparkle_collected(total: int)
signal checkpoint_reached(position: Vector3)
signal level_completed(level_id: String)

# --- Estado del jugador ---
signal health_changed(current: int, maximum: int)
signal player_died()                                   # "mareada", no muerte
signal player_respawned(position: Vector3)

# --- Combate ---
signal combo_hit(index: int)                           # 1, 2 o 3
signal special_charge_changed(ratio: float)            # 0.0 - 1.0
signal special_ready()                                 # el botón brilla y suena
signal special_used(sailor_id: String, attack_name: String)
signal enemy_defeated(enemy_name: String, total_defeated: int)

# --- Arenas ---
signal arena_started(arena_id: String, wave_count: int)
signal wave_cleared(wave_index: int)
signal arena_cleared(arena_id: String)

# --- Transformación ---
signal transformation_started(sailor_id: String)
signal transformation_finished(sailor_id: String)
signal sailor_unlocked(sailor_id: String)
signal sailor_changed(sailor_id: String)

# --- Flujo de escenas ---
signal request_scene_change(scene_path: String)
signal scene_load_progress(ratio: float)
signal scene_ready(scene_path: String)

# --- UI ---
signal game_paused(is_paused: bool)
signal show_message(text: String, duration: float)

@warning_ignore_restore("unused_signal")
