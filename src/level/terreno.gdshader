shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back, ambient_light_disabled;

// POR QUÉ `ambient_light_disabled`, Y POR QUÉ ES EL CAMBIO MÁS IMPORTANTE DE ESTE
// ARCHIVO
//
// Medido en el móvil (Adreno 619), con la vista congelada y la referencia
// intercalada entre pruebas para descontar la deriva térmica:
//
//     media resolución     +112 %   (topa con el vsync, o sea ≥)
//     SIN TERRENO          +112 %   (topa)
//     terreno sin luz      +112 %   (topa)
//     sin nada en 3D       +113 %   (topa)
//     terreno sin triplanar  +4 %
//
// Léase la segunda fila otra vez: **quitar el terreno rinde lo mismo que quitar
// el mundo entero.** El terreno ES el fotograma. Y la tercera dice que no es su
// geometría ni sus píxeles: dejándolo donde está, con los mismos triángulos y
// tapando los mismos píxeles, pero SIN ILUMINAR, el juego se planta en el techo
// de los 60. Lo caro es iluminarlo.
//
// Ahora bien, apagar cosas de la iluminación una a una daba poco: el reflejo del
// cielo un 14 %, el ambiente un 8 %, las sombras un 9 %, el sol un 17 %. Nada de
// eso suma 112. Lo que pasa es que en una GPU de móvil el número de muestras de
// textura y de registros que gasta un shader decide cuántas ondas caben a la vez
// en la unidad; por debajo de cierto umbral entran el doble y la latencia se
// esconde sola. No es una suma, es un escalón.
//
// El ambiente y el reflejo tomados del cielo son **dos muestras de cubemap por
// píxel**, y son las más caras de la lista. `ambient_light_disabled` las quita
// las dos, y lo que aportaban se devuelve gratis: la luz ambiente es
// exactamente el color por la energía, sumado sin depender de nada, así que se
// calcula aquí abajo con una multiplicación.
//
// Y lo que NO se pierde: el sol sigue iluminando y el terreno sigue RECIBIENDO
// SOMBRAS. La sombra de Serena sobre el camino y las de los cerezos sobre la
// hierba siguen ahí, que es justo lo que se habría perdido dejando el terreno
// sin iluminar del todo.

// Superficies del escenario con aspecto dibujado: hierba, tierra, piedra,
// madera, agua. Un solo shader para todas.
//
// POR QUÉ UNO SOLO
//
// Hacer una textura por objeto no escala. Vienen plazas de piedra, interiores y
// un templo, y no puede haber un `.png` por cada superficie del juego. Aquí el
// material se define con **dos colores y tres números**, así que una losa gris
// de ciudad y una de arena de templo son el mismo material con otros
// parámetros. Un escenario nuevo no pide texturas nuevas: pide otra
// combinación.
//
// POR QUÉ SE VE DIBUJADO
//
// No es cuestión de detalle, es de **cuántos tonos hay**. Una foto tiene
// millones; un fondo de anime tiene tres o cuatro por superficie, con saltos
// claros entre ellos. Eso es lo que hace `tonos`: parte el ruido en escalones
// en vez de dejarlo continuo. Con manchas grandes y bordes marcados, el ojo lo
// lee como pintado a mano aunque la geometría sea de cajas.
//
// PROYECCIÓN SIN UV
//
// Las coordenadas salen de la POSICIÓN EN EL MUNDO, no de las UV. El blockout
// son cajas escaladas y multimallas sin desplegar, y desplegarlas a mano sería
// trabajo por cada pieza. Además así la escala es la misma en todo el mapa: un
// metro de hierba mide igual en el suelo del pasillo que en el disco de hierba,
// aunque las mallas tengan tamaños completamente distintos.
//
// EL PATRÓN VA HORNEADO EN UNA TEXTURA, Y ESA ES LA DIFERENCIA
//
// Antes se calculaba aquí mismo: dos octavas de ruido por muestra, tres
// muestras por la proyección triplanar, más el grano y las vetas. Veintiocho
// evaluaciones de hash por píxel, unas trescientas operaciones, en la
// superficie que ocupa media pantalla. Ese era el motivo real de que el juego
// no pasara de 40 fps, y no aparecía por ningún lado en el contador: no es
// geometría, es lo que cuesta pintar cada píxel.
//
// Lo importante es que **el patrón siempre es el mismo**. Entre la hierba y la
// madera cambian los colores y la escala, no el ruido. Así que se calcula una
// sola vez fuera del juego (`tools/generar_textura_ruido.gd`) y aquí se leen
// tres texels, que es justo para lo que una GPU tiene unidades dedicadas.
//
// De propina, los mapas MIP de la textura quitan el hormigueo que el ruido
// procedural hacía en la distancia: se ve mejor, no peor.

uniform vec3 color_base : source_color = vec3(0.42, 0.55, 0.38);
uniform vec3 color_mancha : source_color = vec3(0.34, 0.47, 0.31);
uniform vec3 color_luz : source_color = vec3(0.52, 0.64, 0.44);
// Metros que ocupa una repetición del patrón. Más grande = manchas más grandes.
uniform float escala : hint_range(0.2, 20.0) = 3.0;
// Cuántos escalones de color. 2 es cartel, 5 ya parece degradado.
uniform int tonos : hint_range(2, 6) = 3;
// Cuánto pesa el patrón sobre el color base.
uniform float fuerza : hint_range(0.0, 1.0) = 0.55;
// Segundo patrón, mucho más fino: rompe las manchas grandes para que no se lea
// la repetición. Sin él, a partir de cierta distancia se ve el mosaico.
uniform float grano : hint_range(0.0, 1.0) = 0.18;
// Rayado en una dirección, para vetas de madera o surcos de tierra.
uniform float vetas : hint_range(0.0, 1.0) = 0.0;
uniform float aspereza : hint_range(0.0, 1.0) = 0.95;

// La luz ambiente, a mano. Sustituye a la que el motor sacaba del cielo (ver la
// cabecera). Tienen que valer lo mismo que el `Environment` de la escena, o el
// suelo se ve de otro tono que los personajes: lo sincroniza `nivel.gd`.
uniform vec3 ambiente_color : source_color = vec3(0.62, 0.70, 0.86);
uniform float ambiente_energia : hint_range(0.0, 2.0) = 0.35;

// Perspectiva aérea: lo lejano se destiñe hacia el color del aire y tira a azul.
//
// Es la razón por la que las montañas de verdad se ven moradas, y hace más por
// la sensación de distancia que cualquier cantidad de geometría. Aquí sustituye
// a los conos morados que hacían de montañas al fondo: en vez de poner objetos
// lejanos, se tiñe el propio terreno según lo lejos que esté.
//
// Con `lejania` a 0 no hace nada, así que las superficies del parque —que están
// todas cerca— pueden usar el mismo shader sin enterarse.
uniform vec3 centro_mundo = vec3(0.0, 0.0, 0.0);
uniform vec3 color_lejania : source_color = vec3(0.62, 0.60, 0.78);
uniform float lejania : hint_range(0.0, 1.0) = 0.0;
uniform float desde : hint_range(10.0, 400.0) = 70.0;
uniform float hasta : hint_range(20.0, 600.0) = 190.0;

// EL CAMINO SE PINTA AQUÍ, NO SE CONSTRUYE
//
// Antes el camino era una caja de 16 cm puesta encima de la losa del suelo, que
// a su vez era otra caja de un metro apoyada sobre el terreno. Dos escalones,
// dos cantos verticales a la vista y una pelea de z-fighting en cada junta: era
// el motivo de que el parque se leyera como bloques cuadrados encima del mapa.
//
// Ahora el terreno es una superficie continua y el camino es un COLOR sobre
// ella. La máscara dice cuánto hay de cada superficie en cada punto, y como es
// una textura, su resolución no depende de lo gruesa que sea la malla del
// terreno: el borde del camino sale nítido aunque una celda mida tres metros.
//
// Con `mezcla_activa` a 0 el shader se comporta exactamente como antes, así que
// las piezas sueltas —muros, plataformas, props— siguen usándolo sin enterarse.
uniform sampler2D mascara : hint_default_black, filter_linear, repeat_disable;
uniform float mezcla_activa : hint_range(0.0, 1.0) = 0.0;
// Esquina y tamaño del trozo de mundo que cubre la máscara, en metros.
uniform vec2 mascara_origen = vec2(0.0, 0.0);
uniform vec2 mascara_tam = vec2(1.0, 1.0);
// La segunda superficie: los mismos tres colores, para el camino.
uniform vec3 color_base_2 : source_color = vec3(0.76, 0.70, 0.54);
uniform vec3 color_mancha_2 : source_color = vec3(0.66, 0.59, 0.44);
uniform vec3 color_luz_2 : source_color = vec3(0.84, 0.79, 0.63);

// El patrón, horneado. Tres canales que antes eran tres cálculos distintos:
//
//   R  manchas   dos octavas, las masas grandes de color
//   G  grano     ruido fino, rompe la repetición de las manchas
//   B  vetas     ruido estirado en un eje, para madera y tierra pisada
//
// Se genera con `tools/generar_textura_ruido.gd`. Si se regenera, hay que
// forzar la reimportación (trampa 41 de ESTADO.md).
uniform sampler2D ruido_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

// TRIPLANAR SÍ, PERO NO EN EL SUELO
//
// La proyección triplanar lee el patrón TRES veces —una por cada plano— y las
// mezcla por la normal. Eso hace falta en un muro, en una roca o en un tronco,
// que tienen caras mirando a cualquier lado.
//
// La superficie del terreno no. Es un mapa de alturas: su normal apunta hacia
// arriba casi en todas partes, así que `peso.y` vale casi 1 y las otras dos
// lecturas se pagan enteras para no aportar nada. Y es justamente la superficie
// que ocupa media pantalla — medido en el móvil, el terreno solo se lleva el
// 61 % del coste de pintar el fotograma.
//
// Con esto a `true` se lee UNA vez, proyectando sobre el plano XZ. Lo que se
// pierde es que en las cuestas muy empinadas el patrón sale estirado; como son
// las laderas del fondo y el patrón es una mancha posterizada, no se distingue.
uniform bool solo_plano = false;

// Cuántas celdas del patrón lleva dentro una repetición de la textura. Tiene
// que coincidir con `DOMINIO` del generador, o las manchas cambian de tamaño.
const float DOMINIO = 4.0;


// Proyección triplanar con MEZCLA, no eligiendo un eje con un `if`.
//
// Elegir el eje dominante es más barato, pero produce parpadeos: en cuanto dos
// componentes de la normal se parecen —una superficie a 45°, o simplemente el
// error de precisión al girar la cámara— la condición salta de rama y el patrón
// cambia de golpe. Se veía como un centelleo en los muros al mover la vista.
//
// Mezclando los tres planos con pesos, la transición es continua y el problema
// desaparece. Una sola lectura por plano trae los tres patrones a la vez: el
// grano y las vetas salían antes del plano dominante para ahorrar, y al venir
// todos de la misma mezcla desaparece además la costura que tenían.
//
// OJO: la normal se recibe COMO ARGUMENTO, no se calcula aquí dentro. Los
// nombres del motor —`INV_VIEW_MATRIX`, `NORMAL`, `VERTEX`— solo existen dentro
// de `vertex()`, `fragment()` y `light()`; en una función propia no están
// declarados. El compilador lo dice («Unknown identifier in expression»), pero
// el mensaje se pierde entre los avisos del arranque y lo que se ve es el
// terreno GRIS LISO: Godot cae al material por defecto cuando un shader no
// compila, y eso parece un problema de iluminación, no de código. Es la trampa
// 38 de ESTADO.md, en versión nueva.
vec3 triplanar(vec3 normal_mundo, vec3 mundo, float inv) {
	vec3 n = abs(normal_mundo);
	vec3 peso = n * n;
	peso *= peso;
	peso /= max(peso.x + peso.y + peso.z, 0.0001);
	return texture(ruido_tex, mundo.xz * inv).rgb * peso.y
		+ texture(ruido_tex, mundo.zy * inv).rgb * peso.x
		+ texture(ruido_tex, mundo.xy * inv).rgb * peso.z;
}


void fragment() {
	// En `fragment()`, VERTEX y NORMAL vienen en espacio de VISTA, no de mundo.
	// Hay que pasarlos con `INV_VIEW_MATRIX`: la posición como punto (w = 1) y
	// la normal como dirección (w = 0), para que no le afecte la traslación.
	//
	// No existe ningún `NORMAL_WORLD` en Godot 4 — usarlo compila en silencio
	// hasta que se ejecuta, y entonces el material se queda en blanco liso sin
	// más pista que una línea en la consola.
	vec3 mundo = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// El DOMINIO compensa que cada repetición de la textura lleve varias celdas
	// del patrón dentro: así una mancha sigue midiendo `escala` metros.
	float inv = 1.0 / max(escala * DOMINIO, 0.01);

	vec3 ruidos;
	if (solo_plano) {
		// Una sola lectura, sobre el plano del suelo. Ver `solo_plano` arriba.
		ruidos = texture(ruido_tex, mundo.xz * inv).rgb;
	} else {
		ruidos = triplanar(
			normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz), mundo, inv);
	}

	float patron = ruidos.r;
	if (vetas > 0.001) {
		// Las vetas van a lo largo de un eje y muy estiradas en el otro.
		patron = mix(patron, ruidos.b, vetas);
	}

	// El escalonado: aquí es donde deja de parecer una foto.
	float pasos = float(tonos);
	float escalonado = floor(patron * pasos) / max(pasos - 1.0, 1.0);
	escalonado = clamp(escalonado, 0.0, 1.0);

	// Tres colores en vez de dos: el tercero solo asoma en la banda más alta y
	// hace de luz, que es como se pinta la hierba en un fondo de anime.
	//
	// Los colores se eligen ANTES de aplicar el patrón, no se mezclan los dos
	// resultados al final. Así el camino conserva su propio escalonado en vez de
	// salir un promedio lavado de los dos, que es lo que hace que una mezcla de
	// terrenos se lea como barro.
	vec3 c_base = color_base;
	vec3 c_mancha = color_mancha;
	vec3 c_luz = color_luz;
	if (mezcla_activa > 0.001) {
		float m = texture(mascara, (mundo.xz - mascara_origen) / mascara_tam).r;
		m *= mezcla_activa;
		c_base = mix(c_base, color_base_2, m);
		c_mancha = mix(c_mancha, color_mancha_2, m);
		c_luz = mix(c_luz, color_luz_2, m);
	}

	vec3 color = mix(c_mancha, c_base, smoothstep(0.0, 0.6, escalonado));
	color = mix(color, c_luz, smoothstep(0.72, 1.0, escalonado));
	color = mix(c_base, color, fuerza);

	if (grano > 0.001) {
		color += (ruidos.g - 0.5) * grano * 0.14;
	}

	if (lejania > 0.001) {
		// La distancia se mide en el PLANO: lo que aleja una montaña es lo
		// lejos que está, no lo alta que sea.
		float d = length(mundo.xz - centro_mundo.xz);
		float mezcla = smoothstep(desde, hasta, d) * lejania;
		color = mix(color, color_lejania, mezcla);
	}

	ALBEDO = color;
	// El ambiente que el motor ya no aporta. Es la misma cuenta que hacía él
	// —color de la superficie por color del ambiente por su energía— solo que
	// sin ir a buscar el cubemap del cielo. Va por `EMISSION` porque tiene que
	// sumarse SIN depender de la luz: eso es lo que significa «ambiente», y es
	// lo que hace que la cara en sombra no se vaya a negro.
	EMISSION = color * ambiente_color * ambiente_energia;
	ROUGHNESS = aspereza;
	METALLIC = 0.0;
}
