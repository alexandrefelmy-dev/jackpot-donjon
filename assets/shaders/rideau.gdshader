shader_type canvas_item;
// Rideau de velours rouge : des plis verticaux qui alternent clair et sombre, plus sombre en haut, qui s'estompe
// vers l'intérieur de l'écran. `cote_gauche` : le rideau est collé au bord gauche (sinon au bord droit).

uniform float plis = 5.0;
uniform vec4 couleur : source_color = vec4(0.62, 0.05, 0.13, 1.0);
uniform bool cote_gauche = true;

void fragment() {
	float onde = 0.5 + 0.5 * sin(UV.x * plis * 6.2831853);
	float ombre = 0.42 + 0.58 * onde;
	float haut = mix(0.5, 1.0, smoothstep(0.0, 0.4, UV.y));
	// 0 contre le bord de l'écran, 1 du côté intérieur : le rideau disparaît progressivement.
	float interieur = cote_gauche ? UV.x : 1.0 - UV.x;
	float alpha = 1.0 - smoothstep(0.72, 1.0, interieur);
	COLOR = vec4(couleur.rgb * ombre * haut, alpha);
}
