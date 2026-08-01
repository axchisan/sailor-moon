# Roadmap de desarrollo

> Filosofía: **vertical slice primero**. Un nivel completo y pulido antes que seis a medias.
> Es la única estrategia que evita el proyecto abandonado al 40%.
>
> Corolario para un beat 'em up: **el combate se pule antes de que exista un solo nivel.** Un beat 'em up con combate flojo no se arregla añadiendo contenido.

## Fase 0 — Cimientos (sin arte, todo gris)

**Objetivo:** motor y pipeline validados antes de invertir un minuto en assets.

- [x] `git init` + Git LFS para binarios (`*.glb`, `*.png`, `*.ogg`, `*.wav`)
- [x] Renderizador decidido: **Mobile** (dispositivo objetivo Android 2019+)
- [x] Aplicar `renderer/rendering_method="mobile"` en `project.godot` — confirmado en ejecución: `Metal 4.0 - Forward Mobile`
- [x] Crear la estructura de carpetas de `01-ARQUITECTURA.md`
- [x] Autoloads funcionales: `EventBus`, `GameManager`, `SaveManager`, `AudioManager`, `SceneLoader`, `Settings`, `CombatFeel`
- [x] `InputMap` con 14 acciones abstractas en teclado + gamepad
- [x] Escena de prueba: suelo, plataformas, muro, cámara orbital con `SpringArm3D`
- [x] Controlador con máquina de estados (Idle/Move/Jump/Fall) + coyote time y jump buffer
- [x] Cadena de exportación Android montada y APK de depuración generado y firmado
- [x] **APK instalado y ejecutándose en un dispositivo Android real** ✅
- [x] Addon VRM validado en 4.7.1 — ver [`04-VALIDACION-VRM.md`](04-VALIDACION-VRM.md). Plan A confirmado: VRoid → VRM → MToon funciona

**Criterio de salida:** una cápsula que corre y salta en un móvil Android real. **CUMPLIDO ✅**

## Fase 0 — CERRADA (2026-08-01)

### Entorno de compilación Android (montado el 2026-08-01)

| Componente | Ruta / versión |
|---|---|
| JDK | Temurin 17 — `/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home` |
| Android SDK | `/opt/homebrew/share/android-commandlinetools` |
| Build-Tools | 35.0.0 · Platform 35 · Platform-Tools 37 |
| Keystore de depuración | `~/.android/debug.keystore` (alias `androiddebugkey`, pass `android`) |
| Plantillas de exportación | 4.7.1.stable |
| APK | `export/sailor_moon.apk` — `com.familia.sailormoon`, minSdk 24, arm64-v8a |

Comando de exportación:
```bash
godot --headless --path . --export-debug "Android" export/sailor_moon.apk
```

Instalación en el dispositivo (con depuración USB activada):
```bash
/opt/homebrew/share/android-commandlinetools/platform-tools/adb install -r export/sailor_moon.apk
```

## Fase 1 — El combate (la fase que decide el proyecto)

**Objetivo:** que machacar el botón contra cápsulas grises se sienta genuinamente bien. Sin escenario, sin arte, sin narrativa. Solo una sala vacía y enemigos.

- [x] Hitbox / Hurtbox con capas de colisión (las activa el estado de ataque; pasarán a *call method tracks* cuando haya animaciones en la Fase 2)
- [x] Combo de 3 golpes con ventana de encadenado de 0,8 s — verificado: daño 1 / 1 / 2
- [x] **Auto-orientación** hacia el enemigo más cercano (puntuación por distancia + ángulo, sin cono estricto)
- [x] `CombatFeel`: hit stop, screen shake, partículas, flash blanco, sonido con pitch aleatorio
- [x] Retroceso y reacción de impacto en el enemigo
- [x] IA de enemigo básica (Peluchín): approach → wait → telegraph → attack → stagger
- [x] **Sistema de fichas de ataque** — verificado: con 8 enemigos rodeando, máximo 3 atacando
- [x] Barra de energía y ataque especial con zoom, invulnerabilidad y texto en pantalla
- [x] Salud, invulnerabilidad tras golpe, estado *dizzy* y reaparición sin castigo
- [x] Purificación: el enemigo se convierte en criatura amistosa que se queda saltando
- [x] Gestor de arena: barrera mágica generada por código, oleadas configurables
- [x] Controles táctiles: joystick virtual flotante + botones grandes
- [x] Sonidos placeholder sintetizados (sin audio no se puede juzgar el *feel*)
- [ ] Los otros dos arquetipos: Globito (a distancia) y Cofrecito (escudo)
- [ ] **Prueba en dispositivo real, con dedos, no con ratón**
- [ ] **Ajuste del *feel*: machacar el botón cinco minutos y que apetezca seguir**

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
