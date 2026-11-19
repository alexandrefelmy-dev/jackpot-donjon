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
	if partie.ecran != Partie.Ecran.RECOMPENSE:
		GameState.rediriger()
		return
	GameState.demarrer()
	Musique.jouer_pour(partie)
	propositions = partie.proposer_recompenses()
	_construire_interface()


## Le joueur prend un symbole (ou passe si `symbole` est null), puis la partie dit où aller
## (les portes du pas suivant).
func _choisir(symbole: SymbolData) -> void:
	for bouton in boutons:
		bouton.disabled = true
	bouton_passer.disabled = true
	Son.jouer(&"achat" if symbole != null else &"clic")
	if symbole != null:
		partie.choisir_recompense(symbole)
	partie.terminer_recompense()
	GameState.aller_a_suivant()


func _compter_dans_le_sac(symbole: SymbolData) -> int:
	var nombre := 0
	for dans_le_sac in partie.sac.symboles:
		if dans_le_sac.id == symbole.id:
			nombre += 1
	return nombre


func _construire_interface() -> void:
	Cartes.ajouter_fond(self, COULEUR_FOND)

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
	infos.text = tr("Combats gagnés : %d   Or : %d   PV : %d / %d") % [
		partie.combats_gagnes, partie.or_total, partie.pv, partie.pv_max]
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
		symbole.decrire_base(),
		tr("Combo de 3 : %s") % symbole.decrire_combo(),
		tr("Déjà %d dans ton sac") % _compter_dans_le_sac(symbole),
	]
	carte.add_theme_font_size_override("font_size", 18)
	carte.tooltip_text = tr("Ajouter %s à ton sac") % tr(symbole.nom)

	Cartes.habiller_bouton(carte, symbole.couleur)
	carte.icon = Images.icone(symbole.icone, 48)
	carte.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	carte.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	carte.pressed.connect(_choisir.bind(symbole))
	return carte
