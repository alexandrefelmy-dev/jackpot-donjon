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


## Un style pour les petits boutons de mise : fond sombre, cadre doré quand elle est choisie.
## Les marges sont fixes pour que le texte ne soit jamais coupé quand le cadre apparaît.
static func style_mise(choisie: bool, survol: bool = false) -> StyleBoxFlat:
	var boite := StyleBoxFlat.new()
	boite.set_corner_radius_all(8)
	boite.bg_color = Color("4a3f1c") if choisie else (Color("3a3846") if survol else Color("2a2833"))
	boite.set_border_width_all(3 if choisie else 0)
	boite.border_color = COULEUR_SURVOL
	boite.content_margin_left = 12
	boite.content_margin_right = 12
	boite.content_margin_top = 4
	boite.content_margin_bottom = 4
	return boite


static func habiller_bouton_mise(bouton: Button) -> void:
	bouton.add_theme_stylebox_override("normal", style_mise(false))
	bouton.add_theme_stylebox_override("hover", style_mise(false, true))
	bouton.add_theme_stylebox_override("pressed", style_mise(true))
	bouton.add_theme_stylebox_override("hover_pressed", style_mise(true))
	bouton.add_theme_stylebox_override("disabled", style_mise(false))
	bouton.add_theme_stylebox_override("focus", style_mise(false))
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		bouton.add_theme_color_override(etat, Color.WHITE)
	bouton.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))


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
