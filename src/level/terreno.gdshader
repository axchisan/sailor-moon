shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

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

// Cuántas celdas del patrón lleva dentro una repetición de la textura. Tiene
// que coincidir con `DOMINIO` del generador, o las manchas cambian de tamaño.
const float DOMINIO = 4.0;

void fragment() {
	// En `fragment()`, VERTEX y NORMAL vienen en espacio de VISTA, no de mundo.
	// Hay que pasarlos con `INV_VIEW_MATRIX`: la posición como punto (w = 1) y
	// la normal como dirección (w = 0), para que no le afecte la traslación.
	//
	// No existe ningún `NORMAL_WORLD` en Godot 4 — usarlo compila en silencio
	// hasta que se ejecuta, y entonces el material se queda en blanco liso sin
	// más pista que una línea en la consola.
	vec3 mundo = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = abs(normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz));

	// Proyección triplanar con MEZCLA, no eligiendo un eje con un `if`.
	//
	// Elegir el eje dominante es más barato, pero produce parpadeos: en cuanto
	// dos componentes de la normal se parecen —una superficie a 45°, o
	// simplemente el error de precisión al girar la cámara— la condición salta
	// de rama y el patrón cambia de golpe. Se veía como un centelleo en los
	// muros al mover la vista.
	//
	// Mezclando los tres planos con pesos, la transición es continua y el
	// problema desaparece. Antes eso costaba triplicar el ruido, que es de
	// donde salía el problema de rendimiento; ahora son tres lecturas de
	// textura y el argumento del ahorro ya no aplica.
	vec3 peso = pow(n, vec3(4.0));
	peso /= max(peso.x + peso.y + peso.z, 0.0001);

	// El DOMINIO compensa que cada repetición de la textura lleve varias celdas
	// del patrón dentro: así una mancha sigue midiendo `escala` metros.
	float inv = 1.0 / max(escala * DOMINIO, 0.01);
	vec2 uv_y = mundo.xz * inv;
	vec2 uv_x = mundo.zy * inv;
	vec2 uv_z = mundo.xy * inv;

	// Una sola lectura por plano trae los tres patrones a la vez. El grano y
	// las vetas salían antes del plano dominante para ahorrar; ahora vienen de
	// la misma mezcla, así que además desaparece la costura que tenían.
	vec3 ruidos = texture(ruido_tex, uv_y).rgb * peso.y
		+ texture(ruido_tex, uv_x).rgb * peso.x
		+ texture(ruido_tex, uv_z).rgb * peso.z;

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
	ROUGHNESS = aspereza;
	METALLIC = 0.0;
}
