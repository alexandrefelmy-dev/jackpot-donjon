shader_type canvas_item;
// Moquette de casino : un fond violet très sombre, un treillis de losanges dorés et un petit point au centre de
// chaque losange. Dessinée par le code (aucune image). `repetitions` = nombre de motifs en largeur et en hauteur
// (le décor le règle d'après la taille de l'écran pour que les losanges restent carrés).

uniform vec2 repetitions = vec2(18.0, 10.0);
uniform vec4 couleur_fond : source_color = vec4(0.075, 0.045, 0.17, 1.0);
uniform vec4 couleur_motif : source_color = vec4(0.46, 0.33, 0.11, 1.0);

void fragment() {
	vec2 p = UV * repetitions;
	vec2 c = fract(p) - 0.5;
	// Le losange : les points à la même distance « de Manhattan » du centre ; on garde un trait fin.
	float d = abs(c.x) + abs(c.y);
	float trait = 1.0 - smoothstep(0.0, 0.04, abs(d - 0.44));
	// Un petit point au centre de chaque losange.
	float point = 1.0 - smoothstep(0.06, 0.1, length(c));
	// Une fleurette aux coins (là où quatre losanges se touchent).
	float coin = 1.0 - smoothstep(0.05, 0.09, length(fract(p + 0.5) - 0.5));
	float motif = max(max(trait * 0.5, point * 0.6), coin * 0.4);
	// Un léger velours : le fond varie très peu d'un motif à l'autre.
	float velours = 0.92 + 0.08 * sin(p.x * 3.1) * sin(p.y * 2.7);
	COLOR = vec4(mix(couleur_fond.rgb * velours, couleur_motif.rgb, motif), 1.0);
}
