# Nivel 1 — estado y pendientes

> Foto del Nivel 1 a día de hoy: qué está montado, cómo encaja cada pieza y qué
> falta. Se actualiza al cerrar cada bloque de trabajo.
>
> Plan general: [`15-PLAN-MAESTRO.md`](15-PLAN-MAESTRO.md).
> Trampas técnicas: [`ESTADO.md`](ESTADO.md) §6.

## Cómo se monta un nivel

Cuatro nodos y un orden que **importa**:

```
Nivel1Parque (nivel.gd)
├── Terreno    ← 1º. Colinas y campo. Necesita las zonas altas del blockout
├── Blockout   ← se construye en su _ready(), antes que el nivel
├── Decorado   ← 3º. Posa cada prop con un rayo, así que necesita suelo
└── Objetivos, CamaraApertura, PortalSalida, rincones…
```

1. **`ConstructorNivel`** levanta el recorrido desde `RECORRIDO`, una lista de
   pasos. Decide **por dónde se juega**.
2. **`TerrenoNivel`** genera colinas y campo, y se levanta bajo las partes altas
   del blockout preguntándole sus `zonas_elevadas()`.
3. **`DecoradorNivel`** siembra props. Decide **qué se ve**. Se puede borrar
   entero y el nivel se sigue jugando.
4. El resto son objetivos, cámara y portal.

## El recorrido, paso a paso

| # | Paso | Qué es |
|---|---|---|
| 0 | `pradera` 30×34 | Arranque abierto, sin muros |
| 1 | `pasillo` 20, muro derecho | Sendero de salida |
| 2 | `arena` r11 | Arena 1 — dos oleadas |
| 3 | `cruce` 30, sep. 16 | Dos ramas: directa y larga con plataformas |
| 4 | `arena` r11 | Arena 2 — cofrecitos |
| 5 | `pasillo` 15, sube 2,5 | Faroles, Mercury y la puerta del guardián |
| 6 | `arena` r13 | Guardián |
| 7-9 | paseo de vuelta | Sin peleas, baja al claro |
| 10 | `arena` r12 | Claro del portal |

Tipos disponibles: `pradera`, `pasillo` (con `muros`: ambos/izquierda/derecha/
ninguno, y `subida`), `cruce`, `arena`, `giro`.

## Qué hay montado

### Mundo
- **Terreno por ruido** con llano, faldas, colinas y cordillera. Contorno
  deformado para que no sea una diana. Colisión `HeightMapShape3D`
- **Perspectiva aérea** en el shader: lo lejano se destiñe a morado. Sustituye a
  las montañas de cono
- **Red de seguridad**: pasado el radio de colinas + margen, se devuelve al mapa
- **Cero agujeros**, verificado por barrido de rayos en cada carga

### Superficies
Ocho recetas en `PaletaTerreno`, todas del mismo shader: `hierba`,
`hierba_lejos`, `tierra_camino`, `tierra_arena`, `muro_seto`, `piedra`,
`madera`, `agua`, `plataforma`. Proyección triplanar en coordenadas de mundo.

### Props
**Kit 1** (`blender_kit_parque.py`): cerezo, cerezo gigante, arbusto, roca,
valla, banco, papelera, farol de piedra, torii, pagoda, montaña.
**Kit 2** (`blender_kit_expansion.py`): portal antiguo, puente, peñasco, macizo
de flores, tocón, farolillo, nenúfar.

Todo en `MultiMesh` — ~1000 props en 27 draw calls. Colisión por forma
primitiva, solo en lo que pararía a una niña.

### Juego
- 7 Estrellas, 3 faroles, encuentro con Mercury, 3 arenas
- **6 objetivos** que abren el portal al completarse
- **4 rincones** con baliza que se apaga al visitarlos
- **Portal** modelado, en el claro del final
- **Plano aéreo** de apertura, saltable
- Luna acompaña, con animación y cola por física
- Modo desarrollador (F1–F7)

## Lo que falta

### En curso
| Qué | Por qué |
|---|---|
| **Zonas hundidas en el terreno** | El estanque está apoyado, no encajado. Es la hermana de `zonas_elevadas()` |
| **Agua que parezca agua** | Ahora es una textura fija: sin movimiento no se lee como líquido |
| **Estanque menos redondo** | Un disco perfecto se ve como una moneda |
| **Colisión del puente** | Se atraviesa |
| **Arranque aún al borde** | La pradera ayudó pero se sigue viendo el final del camino |
| **Detalle del suelo** | Hierba alta, piedrecitas, palitos, hojas: el suelo es liso |
| **Animalitos** | Algo que se mueva. Un parque sin bichos está muerto |

### Del plan maestro
| Fase | Estado |
|---|---|
| A — Mundo sólido | ✅ |
| B — Texturas reciclables | ✅ |
| C — Mundo abierto | ✅ |
| C bis — Objetivos y portal | ✅ (falta el mapa de escenarios) |
| D — Rendimiento | ⬜ los tirones de partículas ya están |
| E — Salto, doble salto, trepar | ⬜ **esperando animaciones de Mixamo** |
| E — Cofrecito | ⬜ |
| F — Conversación viva | ⬜ |
| G — Menú, guardado, vidas | ⬜ |
| H — Historia y cinemática | ⬜ guion escrito, sin montar |

### Bloqueado por ti
- **Animaciones de Mixamo** ([`17-ANIMACIONES.md`](17-ANIMACIONES.md)): subir
  `Models/rigged_originales/serena_rigged.fbx`, sin riguear. Desbloquea la Fase E
- **Arte de la cinemática** ([`16-GUION.md`](16-GUION.md)): cinco viñetas

## Cómo probarlo

```bash
# Validar que todo compila
./tools/validar_scripts.sh

# Exportar (se hace al cerrar cada bloque)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --export-debug "Android" export/sailor_moon.apk

# Instalar
/opt/homebrew/share/android-commandlinetools/platform-tools/adb \
  install -r export/sailor_moon.apk
```

Al cargar, la consola dice si el terreno invade la zona jugable, cuántos props
se sembraron y en cuántas draw calls. Si algo de eso cambia de golpe, algo se ha
roto.
