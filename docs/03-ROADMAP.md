# Roadmap de desarrollo

> Filosofía: **vertical slice primero**. Un nivel completo y pulido antes que seis a medias.
> Es la única estrategia que evita el proyecto abandonado al 40%.
>
> Corolario para un beat 'em up: **el combate se pule antes de que exista un solo nivel.** Un beat 'em up con combate flojo no se arregla añadiendo contenido.

## Fase 0 — Cimientos (sin arte, todo gris)

**Objetivo:** motor y pipeline validados antes de invertir un minuto en assets.

- [ ] `git init` + Git LFS para binarios (`*.glb`, `*.png`, `*.ogg`, `*.wav`)
- [x] Renderizador decidido: **Mobile** (dispositivo objetivo Android 2019+)
- [ ] Aplicar `renderer/rendering_method="mobile"` en `project.godot`
- [ ] Crear la estructura de carpetas de `01-ARQUITECTURA.md`
- [ ] Autoloads funcionales: `EventBus`, `GameManager`, `SaveManager`, `AudioManager`, `SceneLoader`, `Settings`, `CombatFeel`
- [ ] `InputMap` con acciones abstractas (`move_*`, `jump`, `attack`, `special`, `transform`, `pause`) en teclado + gamepad
- [ ] Escena de prueba: suelo plano, cápsula, cámara orbital con `SpringArm3D`
- [ ] Controlador con máquina de estados (idle/walk/run/jump/fall)
- [ ] **Prueba de humo en Android:** exportar APK con la cápsula e instalarlo en el dispositivo real. **Ahora, no al final.** Los problemas de export de Android siempre aparecen y siempre tardan más de lo previsto
- [ ] Validar el addon VRM: importar un modelo de VRoid y confirmar que MToon funciona en 4.7.1

**Criterio de salida:** una cápsula que corre y salta en un móvil Android real.

## Fase 1 — El combate (la fase que decide el proyecto)

**Objetivo:** que machacar el botón contra cápsulas grises se sienta genuinamente bien. Sin escenario, sin arte, sin narrativa. Solo una sala vacía y enemigos.

- [ ] Hitbox / Hurtbox con capas de colisión, activadas por *call method tracks* de la animación
- [ ] Combo de 3 golpes con ventana de encadenado de 0,8 s
- [ ] **Auto-orientación** hacia el enemigo más cercano en cono frontal
- [ ] `CombatFeel`: hit stop, screen shake, partículas, flash blanco, sonido con pitch aleatorio
- [ ] Retroceso y reacción de impacto en el enemigo
- [ ] IA de enemigo básica (Peluchín): approach → telegraph → attack → recover → stagger
- [ ] **Sistema de fichas de ataque** (máximo 3 atacando a la vez)
- [ ] Barra de energía y ataque especial con zoom, pausa y texto en pantalla
- [ ] Salud, invulnerabilidad tras golpe, estado *dizzy* y reaparición sin castigo
- [ ] Purificación: el enemigo se convierte en criatura amistosa
- [ ] Gestor de arena: barrera mágica, oleadas, apertura al limpiar
- [ ] Los otros dos arquetipos: Globito (a distancia) y Cofrecito (escudo)
- [ ] Controles táctiles: joystick virtual (nodo nativo de Godot 4.7) + botones grandes
- [ ] **Prueba en dispositivo real, con dedos, no con ratón**

**Criterio de salida:** tú machacas el botón durante cinco minutos contra cápsulas grises y te apetece seguir. Si no, aquí se itera — no se avanza.

Este es el punto de no retorno del proyecto. Todo lo demás es contenido; esto es el juego.

## Fase 2 — Vertical slice: Nivel 1 completo

- [ ] Modelo real de Serena en VRoid (civil + Sailor) con las 15 animaciones de Mixamo
- [ ] Toon shader + outline (MToon en personajes, shader propio en escenario)
- [ ] **Secuencia de transformación completa** — el hito emocional
- [ ] Nivel 1 · Parque Juuban: 3 arenas + tramos de exploración + guardián
- [ ] Coleccionables: chispas y Estrellas de Sueño con feedback
- [ ] HUD: corazones, barra de especial, contadores, botón de guía
- [ ] Checkpoints y guardado/carga funcionando
- [ ] Música y SFX del nivel
- [ ] VFX del especial de Sailor Moon (Tiara Lunar)

**Criterio de salida (el único que importa): tu prima juega el Nivel 1 en el móvil, sola, y quiere seguir.**

## Fase 3 — Producción de contenido

Con el molde validado, cada nivel sale más rápido que el anterior.

- [ ] Nivel 2 · Templo Hikawa + Sailor Mars (fuego, área)
- [ ] Nivel 3 · Escuela y biblioteca + Sailor Mercury (agua, ralentiza)
- [ ] Nivel 4 · Arcade Crown + Sailor Jupiter (rayo, rompe escudos)
- [ ] Nivel 5 · Pasarela y teatro + Sailor Venus (cadena, alcance largo)
- [ ] Variantes cosméticas de enemigos por nivel (mismo esqueleto, distinto color)
- [ ] Peligros ambientales del nivel 5
- [ ] Selección de Sailor al inicio de nivel
- [ ] Menú principal, selección de nivel, armario de vestuario
- [ ] Sistema de diálogos con retratos

## Fase 4 — Clímax y cierre

- [ ] Nivel 6 · Torre del Espejo Roto: gauntlet + cambio de Sailor en tiempo real (menú radial)
- [ ] Boss final en tres fases, cada una vulnerable a una Sailor distinta
- [ ] Cinemáticas de intro y final
- [ ] Post-créditos con el personaje sorpresa
- [ ] Créditos con las atribuciones de `CREDITOS.md`

## Fase 5 — Pulido y entrega

- [ ] Perfilado en el dispositivo real: draw calls, partículas, texturas comprimidas (ETC2/ASTC)
- [ ] Ajuste de dificultad — casi con seguridad hay que bajarla
- [ ] Modo asistido para activar en silencio si hace falta
- [ ] Audio mixing coherente
- [ ] Icono, splash, nombre de la app
- [ ] Build firmado y sideload en su dispositivo
- [ ] **Playtest con ella y una libreta.** No expliques nada; anota dónde se atasca. Vale más que todo este documento

---

## Riesgos identificados y cómo se mitigan

| Riesgo | Probabilidad | Mitigación |
|---|---|---|
| El combate se siente flojo y el juego no engancha | **Alta** | Fase 1 entera dedicada a esto, con cápsulas grises. No se avanza hasta que se sienta bien |
| El alcance crece y el proyecto se abandona | **Alta** | Vertical slice. Con 3 niveles ya es un juego completo |
| El pipeline de assets 3D consume todo el tiempo | Alta | Greybox → placeholder CC0 → final. Jugable en todo momento |
| 15 animaciones × 5 Sailors resulta inasumible | Media | **Esqueleto y animaciones compartidos.** Se preparan una vez. Diferenciación por VFX |
| Apuntar en 3D frustra a una niña de 8 años | **Media-Alta** | Auto-orientación al enemigo más cercano. Es innegociable |
| Problemas de export en Android al final | Media | APK de prueba en Fase 0 |
| 8 enemigos + partículas tumban el rendimiento | Media | Presupuestos definidos; enemigos de 3–5k tris; perfilar en hardware real |
| El addon VRM falla en Godot 4.7.1 | Baja-Media | Se valida en Fase 0. Plan B: GLB + toon shader propio |

## Lo que se recorta si hay que recortar

En orden, de lo primero a lo último:

1. Sistema de vestuario y chispas
2. Niveles 4 y 5 (el juego funciona con Moon, Mars y Mercury)
3. Peligros ambientales
4. Menú radial de cambio de Sailor (se fija una por sección del nivel final)
5. Cinemáticas (se sustituyen por paneles ilustrados con texto)
6. Tercer arquetipo de enemigo (Cofrecito)

Lo que **nunca** se recorta, porque es el juego: el *feel* del combate, la transformación, el ataque especial, y que ella pueda jugarlo sola.
