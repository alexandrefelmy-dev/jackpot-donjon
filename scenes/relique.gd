extends Control
## Écran « Choisis 1 relique parmi 2 » : après l'ouverture d'un coffre, d'une Mimique vaincue ou d'un
## boss. On ne peut pas passer : une relique est offerte. Ensuite la partie dit où aller (portes ou étage suivant).

const COULEUR_FOND := Color("1b1a24")
const TAILLE_CARTE := Vector2(300, 250)

var partie: Partie
var propositions: Array[RelicData] = []
var boutons: Array[Button] = []


func _ready() -> void:
	partie = GameState.partie
	if partie.ecran != Partie.Ecran.RELIQUE:
		GameState.rediriger()
		return
	GameState.demarrer()
	Musique.jouer_pour(partie)
	propositions = partie.proposer_reliques(Partie.NB_RELIQUES_OFFERTES)
	_construire_interface()


## Le joueur prend la relique : elle s'ajoute à sa partie, puis la partie dit où aller.
func _choisir(relique: RelicData) -> void:
	for bouton in boutons:
		bouton.disabled = true
	partie.choisir_relique(relique)
	Son.jouer(&"relique")
	GameState.aller_a_suivant()


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
	titre.text = tr("Une relique t'est offerte !")
	titre.add_theme_font_size_override("font_size", 32)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(titre)

	var consigne := Label.new()
	consigne.text = tr("Choisis-en une : elle te suivra jusqu'à la fin de la partie.")
	consigne.add_theme_font_size_override("font_size", 20)
	consigne.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(consigne)

	var cartes := HBoxContainer.new()
	cartes.add_theme_constant_override("separation", 24)
	cartes.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_child(cartes)
	for relique in propositions:
		var carte := _creer_carte(relique)
		cartes.add_child(carte)
		boutons.append(carte)


## Une carte = un gros bouton coloré avec le nom de la relique et ce qu'elle fait.
func _creer_carte(relique: RelicData) -> Button:
	var carte := Button.new()
	carte.custom_minimum_size = TAILLE_CARTE
	carte.focus_mode = Control.FOCUS_NONE
	carte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	carte.text = "%s\n\n%s" % [tr(relique.nom), tr(relique.description)]
	carte.add_theme_font_size_override("font_size", 20)
	carte.tooltip_text = tr("Prendre : %s") % tr(relique.nom)
	Cartes.habiller_bouton(carte, relique.couleur)
	carte.pressed.connect(_choisir.bind(relique))
	return carte
