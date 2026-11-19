class_name Cartes
extends RefCounted
## Petits outils d'affichage partagés par les écrans (récompense, boutique) :
## boutons colorés façon « carte » en attendant les vrais graphismes.

const COULEUR_SURVOL := Color("ffd34d")
## Jetons d'âme et malédictions (Comptoir, écran de fin).
const COULEUR_JETONS := Color("b9a4ff")
const COULEUR_MALEDICTION := Color("ff8a8a")


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


## Une grosse carte cliquable : un titre en grand et un texte dessous, sur un fond coloré.
## (Un Button n'a qu'une taille de police : le titre et le texte sont deux étiquettes posées
## dessus, qui laissent passer la souris.) Le texte se change avec changer_carte().
static func creer_carte(couleur: Color, titre: String, detail: String, taille: Vector2,
		taille_titre: int = 40, taille_detail: int = 19) -> Button:
	var carte := Button.new()
	carte.custom_minimum_size = taille
	carte.focus_mode = Control.FOCUS_NONE
	habiller_bouton(carte, couleur)

	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for cote in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marge.add_theme_constant_override(cote, 18)
	carte.add_child(marge)
	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 16)
	boite.alignment = BoxContainer.ALIGNMENT_CENTER
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marge.add_child(boite)

	var texte := couleur_texte(couleur)
	var etiquette_titre := Label.new()
	etiquette_titre.add_theme_font_size_override("font_size", taille_titre)
	etiquette_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiquette_titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boite.add_child(etiquette_titre)
	var etiquette_detail := Label.new()
	etiquette_detail.add_theme_font_size_override("font_size", taille_detail)
	etiquette_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiquette_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boite.add_child(etiquette_detail)
	for etiquette in [etiquette_titre, etiquette_detail]:
		etiquette.add_theme_color_override("font_color", texte)
		etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carte.set_meta("titre", etiquette_titre)
	carte.set_meta("detail", etiquette_detail)
	changer_carte(carte, titre, detail)
	return carte


## Change le titre et le texte d'une carte faite par creer_carte().
static func changer_carte(carte: Button, titre: String, detail: String) -> void:
	(carte.get_meta("titre") as Label).text = titre
	(carte.get_meta("detail") as Label).text = detail


## Tout le texte d'une carte (titre, ligne vide, texte) : pour les tests.
static func texte_carte(carte: Button) -> String:
	return "%s\n\n%s" % [(carte.get_meta("titre") as Label).text, (carte.get_meta("detail") as Label).text]


## Donne à un contrôle (titre, étiquette) la lumière pulsante d'un néon. Le pulsement est coupé si le joueur
## a demandé de réduire les flashs. Le shader est chargé une fois ; chaque contrôle a son propre matériau.
const SHADER_NEON := "res://assets/shaders/neon.gdshader"
static var _shader_neon: Shader


static func neon(controle: CanvasItem, couleur_halo: Color = Color("ffd34d")) -> void:
	if _shader_neon == null:
		_shader_neon = load(SHADER_NEON) as Shader
	var materiau := ShaderMaterial.new()
	materiau.shader = _shader_neon
	materiau.set_shader_parameter("couleur_halo", couleur_halo)
	materiau.set_shader_parameter("amplitude", 0.0 if Impacts.flashs_reduits() else 0.35)
	controle.material = materiau

