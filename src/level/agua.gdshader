shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_disabled,
	depth_draw_always;

// Agua de estanque, en el mismo estilo dibujado que el resto del escenario.
//
// POR QUÉ NO VALE UNA TEXTURA
//
// El primer intento fue una receta más de la paleta de terreno: colores de agua
// sobre el mismo patrón de manchas. Y parecía exactamente lo que era — una
// calcomanía azul pegada al suelo. Da igual lo bien elegido que esté el color:
// **lo que hace que algo se lea como agua es que se mueva**, no que sea azul.
//
// Aquí hay cuatro cosas moviéndose, y ninguna es cara:
//
//   1. Ondas grandes que desplazan el color, en dos direcciones cruzadas
//   2. Espuma en el borde, donde el agua toca el fondo
//   3. Brillos que aparecen y desaparecen
//   4. La propia malla sube y baja
//
// LA ESPUMA DEL BORDE
//
// Es lo que más hace por vender el charco: compara la profundidad de lo que hay
// detrás del agua con la del propio píxel, y donde la diferencia es pequeña
// —o sea, donde el fondo está a punto de asomar— pinta una línea clara. Así el
// borde sigue la forma real del terreno en vez de ser el canto del disco, que
// era justo lo que delataba la calcomanía.

uniform vec3 color_hondo : source_color = vec3(0.18, 0.44, 0.62);
uniform vec3 color_claro : source_color = vec3(0.42, 0.72, 0.85);
uniform vec3 color_espuma : source_color = vec3(0.92, 0.98, 1.00);
uniform float transparencia : hint_range(0.0, 1.0) = 0.72;
// Metros de profundidad en los que se dibuja la orilla.
uniform float orilla : hint_range(0.05, 4.0) = 0.85;
uniform float velocidad : hint_range(0.0, 2.0) = 0.35;
uniform float escala_onda : hint_range(0.5, 20.0) = 5.5;
// Cuántos escalones de color. Pocos, igual que en el resto del escenario: es lo
// que lo mantiene dibujado en vez de fotográfico.
uniform int tonos : hint_range(2, 6) = 3;
uniform float altura_ola : hint_range(0.0, 0.5) = 0.06;

uniform sampler2D fondo_profundidad : hint_depth_texture, filter_linear_mipmap;

varying vec3 mundo;

// Mismo hash sin `sin()` que el terreno, y por el mismo motivo: el agua pide
// cuatro muestras de ruido por píxel y en móvil los senos se pagan caros.
float picotazo(vec2 p) {
	vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
	p3 += dot(p3, vec3(p3.y, p3.z, p3.x) + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float ruido(vec2 p) {
	vec2 celda = floor(p);
	vec2 dentro = fract(p);
	vec2 t = dentro * dentro * (3.0 - 2.0 * dentro);
	float a = picotazo(celda);
	float b = picotazo(celda + vec2(1.0, 0.0));
	float c = picotazo(celda + vec2(0.0, 1.0));
	float d = picotazo(celda + vec2(1.0, 1.0));
	return mix(mix(a, b, t.x), mix(c, d, t.x), t.y);
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// La superficie ondula de verdad. Es sutil, pero al mover la cámara el
	// reflejo del borde cambia y eso solo pasa si la malla no es plana.
	float ola = sin(mundo.x * 0.7 + TIME * 1.1) * cos(mundo.z * 0.6 - TIME * 0.9);
	VERTEX.y += ola * altura_ola;
}

void fragment() {
	vec2 uv = mundo.xz / escala_onda;
	float t = TIME * velocidad;

	// Dos capas de ondas en direcciones distintas. Con una sola se ve el patrón
	// desplazándose en bloque, como una cinta transportadora.
	float onda = ruido(uv + vec2(t, t * 0.6)) * 0.6
		+ ruido(uv * 1.9 - vec2(t * 0.8, t * 1.3)) * 0.4;

	float pasos = float(tonos);
	float escalonado = floor(onda * pasos) / max(pasos - 1.0, 1.0);
	vec3 color = mix(color_hondo, color_claro, clamp(escalonado, 0.0, 1.0));

	// Profundidad de lo que hay DETRÁS del agua, para saber dónde está la
	// orilla. Se convierte de la profundidad no lineal del buffer a metros.
	float cruda = texture(fondo_profundidad, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, cruda);
	vec4 vista = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vista.xyz /= vista.w;
	float hondura = length(vista.xyz) + VERTEX.z;

	// Espuma donde el fondo está cerca, con una onda encima para que la línea
	// no sea un contorno limpio de vector.
	float borde = 1.0 - smoothstep(0.0, orilla, hondura);
	float rizo = ruido(uv * 3.2 + vec2(t * 1.4, -t)) * 0.35;
	float espuma = smoothstep(0.45, 0.85, borde + rizo);
	color = mix(color, color_espuma, espuma);

	// Destellos sueltos: puntos muy claros que van y vienen.
	float brillo = ruido(uv * 2.6 - vec2(t * 0.5, t * 0.7));
	color += vec3(smoothstep(0.86, 0.99, brillo)) * 0.28;

	ALBEDO = color;
	// Más opaca en la orilla: si no, la espuma se transparenta y se pierde.
	ALPHA = mix(transparencia, 1.0, espuma);
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
