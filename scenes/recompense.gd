extends Control
## Écran de récompense après un combat gagné : 1 symbole parmi 3 à ajouter au sac, ou passer.

const COULEUR_FOND := Color("1b1a24")
const TAILLE_CARTE := Vector2(230, 230)

var partie: Partie
var propositions: Array[SymbolData] = []
var boutons: Array[Button] = []
var bouton_passer: Button


func _ready() -> void:
	partie = GameState.partie
	propositions = partie.proposer_recompenses()
	_construire_interface()


## Le joueur prend un symbole (ou passe si `symbole` est null), puis il va à la relique
## offerte (après le combat 3) ou directement à la boutique.
func _choisir(symbole: SymbolData) -> void:
	for bouton in boutons:
		bouton.disabled = true
	bouton_passer.disabled = true
	if symbole != null:
		partie.choisir_recompense(symbole)
	if partie.relique_a_offrir():
		GameState.aller_a(GameState.SCENE_RELIQUE)
	else:
		GameState.aller_a(GameState.SCENE_BOUTIQUE)


func _compter_dans_le_sac(symbole: SymbolData) -> int:
	var nombre := 0
	for dans_le_sac in partie.sac.symboles:
		if dans_le_sac.id == symbole.id:
			nombre += 1
	return nombre


func _construire_interface() -> void:
	var fond := ColorRect.new()
	fond.color = COULEUR_FOND
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 18)
	centre.add_child(colonne)

	var titre := Label.new()
	titre.text = tr("Victoire ! Choisis une récompense")
	titre.add_theme_font_size_override("font_size", 32)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(titre)

	var infos := Label.new()
	infos.text = tr("Combats gagnés : %d / %d   Or : %d   PV : %d / %d") % [
		partie.combats_gagnes, Partie.NB_COMBATS_NORMAUX + 1, partie.or_total, partie.pv, partie.pv_max]
	infos.add_theme_font_size_override("font_size", 18)
	infos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(infos)

	var cartes := HBoxContainer.new()
	cartes.add_theme_constant_override("separation", 20)
	cartes.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_child(cartes)
	for symbole in propositions:
		var carte := _creer_carte(symbole)
		cartes.add_child(carte)
		boutons.append(carte)

	var sac := Label.new()
	sac.text = tr("Ton sac contient %d symboles. Le symbole choisi y sera ajouté.") % partie.sac.taille()
	sac.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	sac.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(sac)

	bouton_passer = Button.new()
	bouton_passer.text = tr("Passer")
	bouton_passer.custom_minimum_size = Vector2(0, 48)
	bouton_passer.focus_mode = Control.FOCUS_NONE
	bouton_passer.pressed.connect(_choisir.bind(null))
	colonne.add_child(bouton_passer)


## Une carte = un gros bouton coloré avec le nom du symbole et ses effets.
func _creer_carte(symbole: SymbolData) -> Button:
	var carte := Button.new()
	carte.custom_minimum_size = TAILLE_CARTE
	carte.focus_mode = Control.FOCUS_NONE
	carte.text = "%s\n\n%s\n\n%s\n\n%s" % [
		tr(symbole.nom),
		Effets.decrire(symbole.effet_base),
		tr("Combo de 3 : %s") % Effets.decrire(symbole.effet_combo),
		tr("Déjà %d dans ton sac") % _compter_dans_le_sac(symbole),
	]
	carte.add_theme_font_size_override("font_size", 18)
	carte.tooltip_text = tr("Ajouter %s à ton sac") % tr(symbole.nom)

	var couleur_texte := Color.BLACK if symbole.couleur.get_luminance() > 0.5 else Color.WHITE
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		carte.add_theme_color_override(etat, couleur_texte)
	carte.add_theme_stylebox_override("normal", _style_carte(symbole.couleur, false))
	carte.add_theme_stylebox_override("hover", _style_carte(symbole.couleur.lightened(0.15), true))
	carte.add_theme_stylebox_override("pressed", _style_carte(symbole.couleur.darkened(0.15), true))
	carte.add_theme_stylebox_override("disabled", _style_carte(symbole.couleur.darkened(0.4), false))
	carte.pressed.connect(_choisir.bind(symbole))
	return carte


func _style_carte(couleur: Color, en_valeur: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.bg_color = couleur
	if en_valeur:
		style.set_border_width_all(5)
		style.border_color = Color("ffd34d")
	return style
