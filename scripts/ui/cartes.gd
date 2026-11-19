class_name Cartes
extends RefCounted
## Petits outils d'affichage partagés par les écrans (récompense, boutique) :
## boutons colorés façon « carte » en attendant les vrais graphismes.

const COULEUR_SURVOL := Color("ffd34d")


static func couleur_texte(fond: Color) -> Color:
	return Color.BLACK if fond.get_luminance() > 0.5 else Color.WHITE


static func style(couleur: Color, en_valeur: bool) -> StyleBoxFlat:
	var boite := StyleBoxFlat.new()
	boite.set_corner_radius_all(12)
	boite.bg_color = couleur
	if en_valeur:
		boite.set_border_width_all(5)
		boite.border_color = COULEUR_SURVOL
	return boite


## Applique à un bouton les couleurs d'un symbole : fond coloré, bordure dorée au survol,
## fond assombri quand il est désactivé.
static func habiller_bouton(bouton: Button, couleur: Color) -> void:
	var texte := couleur_texte(couleur)
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		bouton.add_theme_color_override(etat, texte)
	bouton.add_theme_stylebox_override("normal", style(couleur, false))
	bouton.add_theme_stylebox_override("hover", style(couleur.lightened(0.15), true))
	bouton.add_theme_stylebox_override("pressed", style(couleur.darkened(0.15), true))
	bouton.add_theme_stylebox_override("disabled", style(couleur.darkened(0.45), false))
	bouton.add_theme_stylebox_override("focus", style(couleur, false))
