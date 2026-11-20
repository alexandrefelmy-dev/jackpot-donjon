class_name Habillage
extends RefCounted
## Le style commun des écrans : boutons « casino » (vin sombre, cadre doré), jauges, bulles d'aide, et des titres
## en néon. Le thème est construit une seule fois ; Cartes.ajouter_fond() le pose sur la racine de chaque écran, donc
## tous les boutons et jauges qui n'ont pas leur propre style le reçoivent. Un style posé à la main sur un contrôle
## (les cartes colorées, les mises, la machine) l'emporte toujours sur celui-ci.

const COULEUR_OR := Color("ffd34d")
const COULEUR_OR_SOMBRE := Color("a8801f")
const COULEUR_VIN := Color("2a1220")
const COULEUR_TEXTE := Color("f3ead8")

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()

	var survol := _boite(Color("5a1c36"), COULEUR_OR, 3)
	survol.shadow_color = Color(COULEUR_OR, 0.45)  # un halo doré sous la souris
	survol.shadow_size = 9
	t.set_stylebox("normal", "Button", _boite(COULEUR_VIN, COULEUR_OR_SOMBRE, 3))
	t.set_stylebox("hover", "Button", survol)
	t.set_stylebox("pressed", "Button", _boite(Color("1c0a14"), COULEUR_OR, 4))
	t.set_stylebox("hover_pressed", "Button", _boite(Color("1c0a14"), COULEUR_OR, 4))
	t.set_stylebox("disabled", "Button", _boite(Color("1d1520"), Color(COULEUR_OR_SOMBRE, 0.3), 3))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", COULEUR_TEXTE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", COULEUR_OR)
	t.set_color("font_hover_pressed_color", "Button", COULEUR_OR)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))

	var fond_jauge := _boite(Color(0, 0, 0, 0.55), COULEUR_OR_SOMBRE, 2)
	fond_jauge.set_corner_radius_all(8)
	var remplissage := _boite(Color("3fae5c"), Color("3fae5c"), 0)
	remplissage.set_corner_radius_all(8)
	t.set_stylebox("background", "ProgressBar", fond_jauge)
	t.set_stylebox("fill", "ProgressBar", remplissage)

	var bulle := _boite(Color(0.06, 0.04, 0.08, 0.95), COULEUR_OR, 2)
	bulle.set_content_margin_all(8)
	t.set_stylebox("panel", "TooltipPanel", bulle)
	t.set_color("font_color", "TooltipLabel", COULEUR_TEXTE)

	_theme = t
	return t


## Un panneau sombre translucide à cadre doré (joueur et journal du combat, statistiques de fin) : lisible
## par-dessus le décor.
static func panneau() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.08, 0.82)
	style.border_color = COULEUR_OR_SOMBRE
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	return style


## Donne à un titre l'allure d'une enseigne : or, contour sombre et lumière de néon pulsante.
static func titre(etiquette: Label, couleur: Color = COULEUR_OR) -> void:
	etiquette.add_theme_color_override("font_color", couleur)
	contour(etiquette, couleur.darkened(0.7), 5)
	Cartes.neon(etiquette, couleur)


## Un contour (couleur et épaisseur) autour d'un texte : il reste lisible sur n'importe quel fond.
static func contour(etiquette: Label, couleur: Color = Color(0, 0, 0, 0.9), epaisseur: int = 5) -> void:
	etiquette.add_theme_color_override("font_outline_color", couleur)
	etiquette.add_theme_constant_override("outline_size", epaisseur)


static func _boite(fond: Color, bordure: Color, epaisseur: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.border_color = bordure
	style.set_border_width_all(epaisseur)
	style.set_corner_radius_all(22)  # des pastilles, pas des rectangles
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
