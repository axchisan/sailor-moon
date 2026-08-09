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
- **Zonas hundidas** (`hondonadas` en `terreno_nivel.gd`): el vaso del estanque
  se cava en el propio terreno con perfil de cuenco y borde ondulado. La hermana
  de `zonas_elevadas()`

### Superficies
Ocho recetas en `PaletaTerreno`, todas del mismo shader: `hierba`,
`hierba_lejos`, `tierra_camino`, `tierra_arena`, `muro_seto`, `piedra`,
`madera`, `agua`, `plataforma`. Proyección triplanar en coordenadas de mundo.

### Props
**Kit 1** (`blender_kit_parque.py`): cerezo, cerezo gigante, arbusto, roca,
valla, banco, papelera, farol de piedra, torii, pagoda, montaña.
**Kit 2** (`blender_kit_expansion.py`): portal antiguo, pasarela de 14 m,
peñasco, macizo de flores, tocón, farolillo, nenúfar.
**Detalle de suelo** (mismo archivo, `generar_detalle()`): mata de hierba,
piedrecitas, ramitas, hojarasca, mariposa, pajarillo.
**Kit 3 — vida de parque** (`blender_kit_vida.py`): puesto de dulces, matera,
maceta, mesa con sombrilla, fuente de piedra, cartel indicador, columpio,
tobogán, losa de sendero, guirnalda de farolillos, estatua de gato, seto bajo.

Todo en `MultiMesh` — ~1950 props en 32 draw calls. Colisión por forma
primitiva, solo en lo que pararía a una niña.

### Los rincones
Nueve conjuntos compuestos a mano (`RINCONES` en `decorador_nivel.gd`), no props
sueltos: kiosco de dulces con terraza, zona de juegos, plaza de la fuente,
merendero, altar del gato, vivero, y tres rincones pequeños de paso.

- Cada uno se sitúa por rumbo y distancia, **mira al centro del parque**, y si
  no cabe gira hasta encontrar sitio
- Llevan **suelo empedrado** de losas, que es lo que los convierte en plaza en
  vez de en muebles sobre la hierba
- Un **sendero de losas** los une con el camino principal, y el arranque se
  elige de forma que no cruce ningún muro

### Rendimiento
Seis técnicas, de más a menos impacto. Medido desde el punto de aparición:

| | Antes | Después |
|---|---|---|
| Triángulos de pantalla | 97.500 | 69.400 |
| Triángulos de sombra | 260.700 | 30.900 |
| **Total por fotograma** | **358.200** | **100.300** |
| Draw calls | 101 | 99 |

1. **Descarte por frustum** — las multimallas se trocean en parcelas de 52 m
   (`LADO_PARCELA`). Antes cada una tenía una caja envolvente que cubría el
   mapa entero y no se descartaba nunca
2. **Descarte por oclusión** — cada muro del blockout lleva su
   `OccluderInstance3D`, así que lo que queda detrás de un seto no se dibuja.
   Mirando al muro: 32 draw calls; mirando al camino: 105
3. **Sombras** — de cuatro cascadas a una, de 55 m a 30, y sin sombra en el
   detalle menudo. Es lo que quitó 230.000 triángulos
4. **LOD por distancia** — `ALCANCE` apaga cada pieza cuando deja de aportar
   (una piedrecita a 42 m, una brizna a 52), con desvanecido para que no haya
   salto
5. **LOD de malla** — el cerezo tiene dos versiones: 596 triángulos de cerca y
   236 a partir de 44 m
6. **Menos polígonos en origen** — `divisiones` en `_esfera()`. El decorado bajó
   de 489.000 triángulos a 277.000

Y en los shaders: el hash de ruido ya no usa `sin()` (ver trampa 52), MSAA
cambiado por FXAA, y el mapa de sombras a 2048 con filtro duro.

### El reparto del sitio
Nada se planta encima de otra cosa. Cada copia reserva un círculo (`HUECO`) en
una rejilla espacial y la siguiente que caiga ahí se descarta. Los muros y
plataformas del blockout vienen del constructor (`estorbos`) como rectángulos
orientados. La consola lo canta en cada carga:

```
[Nivel] descartados: 0 sin suelo, 552 encima de otro, 68 dentro de un muro
```

El orden de siembra es el orden de prioridad: estanque → rincones → senderos →
camino → arenas → campo → detalle → linde.

### El estanque
Es el único sitio del nivel donde el terreno y el decorado tienen que cuadrar al
centímetro, así que **una sola función manda sobre la forma**: `_radio_contorno()`
en `decorador_nivel.gd`. La usan la lámina de agua, el vaso que se cava en el
terreno y el cálculo de por dónde cruza el puente.

- **Agua** (`agua.gdshader`): dos capas de onda cruzadas, espuma de orilla por
  profundidad del buffer, destellos y desplazamiento de vértices. Posterizada a
  cuatro tonos, igual que el resto del escenario
- **Nivel de la lámina**: la altura media de cuatro puntos de la ORILLA menos el
  calado. Nunca `_posar()` — ver trampa 43
- **El puente cruza por donde el estanque es más estrecho** y se escala a ese
  través, con un metro de apoyo por punta
- Campo, detalle y piedras de orilla esquivan el agua (`_moja()`)

### Juego
- 7 Estrellas, 3 faroles, encuentro con Mercury, 3 arenas
- **6 objetivos** que abren el portal al completarse
- **4 rincones** con baliza que se apaga al visitarlos
- **Portal** modelado, en el claro del final
- **Plano aéreo** de apertura, saltable
- Luna acompaña, con animación y cola por física
- Modo desarrollador (F1–F7)

## Lo que falta

### Hecho en este bloque
| Qué | Cómo quedó |
|---|---|
| Zonas hundidas en el terreno | `hondonadas` + `_excavar()`, con perfil de cuenco |
| Agua que parezca agua | Shader propio con ondas, espuma de orilla y destellos |
| Estanque menos redondo | Contorno de dos senos, compartido por agua, vaso y puente |
| Colisión del puente | Caja de 14 m alineada con la tabla, no con la barandilla |
| Arranque al borde | Pradera de salida de 30×34 a 52×54, spawn movido a z = −18 |
| Detalle del suelo | 520 matas, 190 piedrecitas, 130 ramitas, 160 hojarascas |
| Animalitos | 22 mariposas y 9 pajarillos en `bichos.gd`, en multimalla |

### Hecho en el bloque de ambientación
| Qué | Cómo quedó |
|---|---|
| Props montados unos sobre otros | Registro de ocupación: 334 solapes eliminados |
| Props dentro de las paredes | `estorbos` del constructor: 219 → ~68 (los que quedan son copas, no pies) |
| Hierba atravesando el suelo | El rayo de `_posar()` iba de +4 a −8 m y no llegaba al terreno de las faldas |
| Baranda del puente sin colisión | `CUERPO` admite varias formas por pieza |
| Zonas planas desaprovechadas | Nueve rincones compuestos con empedrado y senderos |
| Parpadeos en el empedrado y en el camino | Z-fighting: la losa quedaba al ras del terreno y el disco de arena a la misma cota que el pasillo |
| Tirones en todo el mapa | 358.000 → 100.300 triángulos por fotograma (ver Rendimiento) |

### En curso
| Qué | Por qué |
|---|---|
| **Comprobar el rendimiento en el móvil** | En el Mac va a 60 fps siempre; las cifras hay que verlas allí. Panel: F1, o **tres toques en la esquina superior izquierda** |
| **Mapa de escenarios** | El portal ya abre, pero no lleva a ninguna parte todavía |

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
