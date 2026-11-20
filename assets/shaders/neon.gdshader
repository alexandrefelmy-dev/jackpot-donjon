shader_type canvas_item;
// Néon : un texte ou un cadre dont la lumière pulse doucement, avec un reflet de la couleur du halo.
// La période par défaut (2 s) divise le temps de rebouclage de TIME (3600 s) : le pulsement ne saute jamais.
// `amplitude` = 0 coupe le pulsement (option « Réduire les flashs »).

uniform vec4 couleur_halo : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform float periode : hint_range(0.5, 6.0) = 2.0;
uniform float amplitude : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	float pouls = 0.5 + 0.5 * sin(TIME * 6.2831853 / periode);
	vec3 lumiere = mix(texel.rgb * COLOR.rgb, couleur_halo.rgb, 0.25 * amplitude * pouls);
	COLOR = vec4(lumiere * (1.0 + amplitude * pouls), texel.a * COLOR.a);
}
