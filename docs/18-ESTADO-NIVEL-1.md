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
| 0 | `pradera` 20×26 | Placita de arranque, sin muros. Se aparece a 8,5 m |
| 1 | `pasillo` 20, muro derecho | Sendero de salida, abierto por un lado |
| 2 | `arena` r11 | Arena 1 — dos oleadas |
| 3 | `cruce` 30, sep. 16 | Dos ramas: directa y larga con plataformas |
| 4 | `arena` r11 | Arena 2 — cofrecitos |
| 5 | `pasillo` 15, sube 2,5 | Faroles, Mercury y la puerta del guardián |
| 6 | `arena` r13 | Guardián |
| 7-9 | paseo de vuelta | Sin peleas, baja al claro |
| 10 | `arena` r12 | Claro del portal |

Tipos disponibles: `pradera`, `pasillo` (con `muros`: ambos/izquierda/derecha/
ninguno, y `subida`), `cruce`, `arena`, `giro`.

> **La placita del arranque, pequeña y punto.** Se probó a 52×54 y a 34×46, y
> las dos veces una losa de ese tamaño se leyó como un bloque cuadrado puesto
> encima del mapa: borra el relieve que tenga debajo y desplaza el parque
> entero, y con él todo lo que se coloca por rumbo y distancia desde su centro
> (el estanque acabó tapado las dos veces).
>
> **Cada vez que cambien las medidas del `RECORRIDO` hay que mirar la vista
> aérea**, porque el centro del parque se mueve y con él el terreno, el
> estanque, los nueve rincones y el fondo lejano.

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
| Triángulos de pantalla | 97.500 | ~82.000 |
| Triángulos de sombra | 260.700 | ~62.000 |
| **Total por fotograma** | **358.200** | **~144.000** |
| Draw calls (en el móvil) | 156 | ~83 |

Medido con la pantalla del móvil (1600×720), que es mucho más ancha que un 16:9
y ve bastante más mundo de golpe. En 16:9 las cifras son menores.

1. **Descarte por frustum** — las multimallas se trocean en parcelas de 70 m
   (`LADO_PARCELA`). Antes cada una tenía una caja envolvente que cubría el
   mapa entero y no se descartaba nunca
2. **Descarte por oclusión** — cada muro del blockout lleva su
   `OccluderInstance3D`, así que lo que queda detrás de un seto no se dibuja.
   Mirando al muro: 32 draw calls; mirando al camino: 105
3. **Sombras** — de cuatro cascadas a una, de 55 m a 24, y sin sombra en el
   detalle menudo. Es lo que quitó 230.000 triángulos
4. **LOD por distancia** — `ALCANCE` apaga cada pieza cuando deja de aportar
   (una piedrecita a 36 m, una brizna a 44), con desvanecido para que no haya
   salto
5. **LOD de malla** — el cerezo tiene dos versiones: 596 triángulos de cerca y
   236 a partir de 44 m
6. **Menos polígonos en origen** — `divisiones` en `_esfera()`. El decorado bajó
   de 489.000 triángulos a 277.000

Y además: el hash de ruido de los shaders ya no usa `sin()` (trampa 52), MSAA
cambiado por FXAA, mapa de sombras a 2048 con filtro duro, y **distancia de
renderizado de 155 m** con la niebla cerrando entre los 78 y los 148 para que el
corte no se vea.

**Descartado:** bajar la resolución de render. Emborrona los contornos del cel
shading — trampa 63.

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

### Hecho en el bloque de pulido
| Qué | Cómo quedó |
|---|---|
| La pradera de arranque no existía | El `match` de `construir()` no tenía el caso; llevaba desde que se escribió sin ejecutarse |
| Bloques cuadrados sobre el mapa | Eran tres «manchas de tierra» rectangulares que se ponían en la pradera. Fuera |
| El parque hundido en las montañas | El terreno se centraba en un punto fijo del editor; ahora sigue al parque |
| Plaza de la fuente en una ladera | Los rincones exigen terreno llano (`_es_llano`, nueve puntos) |
| Bancos de espaldas al agua | `mirar: "centro"` calcula el giro en vez de escribirlo a ojo |
| Botas atravesando el camino | La franja de camino elevada no tenía colisión |
| Cámara mirando desde abajo | El pitch del `SpringArm3D` estaba invertido: el negativo es el que sube |

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

### Hecho en el bloque de píxeles y geometría
| Qué | Cómo quedó |
|---|---|
| El parque se veía cuadrado | El suelo del blockout ya no se dibuja: el terreno sube hasta su cara de arriba y lo tapa. Sigue estando como cuerpo, que no cuesta dibujado |
| El camino era un escalón de 16 cm | Dejó de ser geometría. Se pinta con una máscara de 1024 px sobre el terreno, con el borde difuminado medio metro |
| El terreno subía en festón | Las zonas de apoyo eran círculos y un pasillo es un rectángulo: por las esquinas asomaba el canto de la losa |
| Bordes aserrados en las faldas | La transición cabía dentro de una celda. Se promedia con los vecinos, y el llano del terreno se puso a la altura del suelo pisable para que en lo llano no haya nada que levantar |
| Sombras recortadas en zigzag | No era el terreno: era el filtro de sombra DURO. Se identificó apagando las sombras con F8 |
| 32 `sin()` por píxel de cielo | La trampa 52 seguía viva en `cielo_anime.gdshader`. Hash sin senos, 3 octavas y una sola pasada de nube |
| 28 evaluaciones de ruido por píxel de terreno | Patrón horneado a una textura de 3 canales (`tools/generar_textura_ruido.gd`) |
| No había forma de saber qué costaba | Banco de pruebas: **F8**, o un toque en la esquina superior **derecha** en el móvil |

### Hecho en los bloques de cierre

| Qué | Cómo quedó |
|---|---|
| El jefe guardián | Modelo, esqueleto de 19 huesos, once animaciones, cinco ataques, tres fases y aguante. Sale del portal al **volver al claro** con todo hecho |
| Sonido | Efectos de grabación real, voz propia por bicho y ambiente con posición en el mundo |
| Música | Banda sonora completa con director de capas por prioridad |
| Menús y guardado | Menú, tres partidas, ajustes, créditos, pausa y pantalla de carga |
| Vidas | Corazones que sueltan los enemigos y puntos de guardado antes de cada arena |
| Trepar | Ocho repechos con premio arriba, **solo donde de verdad hay hueco** |
| Objetivos | Seleccionables: tocar uno pone una flecha que lo señala |
| La apertura | Cinco viñetas dibujadas por código, saltables, una vez por partida |
| Los cuatro fallos de móvil | Pausa detrás del panel, reaparecer en la arena equivocada, cargar sin pantalla y el jefe saliendo donde no tocaba |
| Golpear a través de la barrera | `Hitbox` tira un rayo contra el escenario: al jefe ya no se le remata desde fuera del anillo |

### Lo que queda

| Qué | Por qué |
|---|---|
| **Rendimiento, tercera pasada** | Encargado a otro agente. Todo en [`26-OPTIMIZACION.md`](26-OPTIMIZACION.md) |
| **Mapa de escenarios** | El portal abre, pero no lleva a ninguna parte todavía |
| **Rematar los cantos de los setos** | Los muros siguen siendo cajas con las esquinas y los extremos a la vista |
| Pasos de tierra y agarrarse a una cornisa | Los dos sonidos que faltan |

### Del plan maestro
| Fase | Estado |
|---|---|
| A — Mundo sólido | ✅ |
| B — Texturas reciclables | ✅ |
| C — Mundo abierto | ✅ |
| C bis — Objetivos y portal | ✅ (falta el mapa de escenarios) |
| C ter — Que el nivel explique lo que pide | ✅ |
| D — Rendimiento | 🟡 dos pasadas; falta la tercera |
| E — Salto, doble salto, trepar, Cofrecito | ✅ |
| F — Conversación viva | ✅ salvo la voz de Mercury |
| G — Menú, guardado, vidas | ✅ |
| H — Historia y cinemática | 🟡 apertura montada; faltan las escenas entre niveles y el final |

**El Nivel 1 está terminado y jugable de cabo a rabo.**
