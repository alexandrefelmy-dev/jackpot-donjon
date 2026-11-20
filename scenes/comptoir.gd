extends Control
## Le Comptoir du Croupier : entre deux parties (et au lancement du jeu, en attendant le menu de la v0.8),
## on y dépense ses jetons d'âme en avantages permanents, on voit ses malédictions, puis on joue.

const COULEUR_FOND := Color("1b1a24")
const TAILLE_CARTE := Vector2(330, 126)
## Couleur de chaque achat (en attendant les vrais graphismes).
const COULEURS: Dictionary = {
	Comptoir.Achat.SYMBOLE: Color("4f7f6a"),
	Comptoir.Achat.RELIQUE: Color("7a5aa8"),
	Comptoir.Achat.PV_MAX: Color("a84f58"),
	Comptoir.Achat.OR_DE_DEPART: Color("a8893a"),
	Comptoir.Achat.RELANCE: Color("3f78a8"),
	Comptoir.Achat.TREFLE: Color("4f9a4f"),
}

var comptoir: Comptoir
var boutons_achats: Array[Button] = []
var texte_jetons: Label
## Les records du joueur (voir Profil), sous les jetons.
var texte_records: Label
var texte_message: Label
var texte_maledictions: Label
var texte_debloques: Label
var bouton_menu: Button
var bouton_jouer: Button
var bouton_debug_jetons: Button
var bouton_debug_reset: Button


func _ready() -> void:
	GameState.demarrer()
	Musique.jouer_menu()
	GameState.charger_profil()
	GameState.en_partie = false
	comptoir = Comptoir.creer(GameState.profil)
	_construire_interface()
	texte_message.text = GameState.message_profil if not GameState.message_profil.is_empty() \
			else tr("Dépense tes jetons d'âme, puis lance une partie.")
	_rafraichir()


# --- Actions -----------------------------------------------------------------

func _unhandled_input(evenement: InputEvent) -> void:
	if evenement.is_action_pressed(Entrees.RETOUR):
		_menu()


func _menu() -> void:
	Son.jouer(&"clic")
	GameState.vers_le_menu()


func _acheter(achat: Comptoir.Achat) -> void:
	var titre := comptoir.titre(achat)
	if comptoir.acheter(achat):
		Son.jouer(&"achat")
		if not GameState.sauver_profil():
			texte_message.text = GameState.message_profil
			_rafraichir()
			return
		if comptoir.dernier_deblocage != &"":
			texte_message.text = tr("%s : %s est débloqué !") % [titre, _nom_deblocage(comptoir.dernier_deblocage)]
		else:
			texte_message.text = tr("%s : acheté !") % titre
	else:
		texte_message.text = tr("Achat impossible.")
	_rafraichir()


func _jouer() -> void:
	bouton_jouer.disabled = true
	Son.jouer(&"clic")
	GameState.nouvelle_partie()
	GameState.aller_a_suivant()


## Pour tester sans enchaîner les parties (bouton visible seulement en test).
func _donner_jetons_debug() -> void:
	GameState.profil.jetons += 50
	GameState.sauver_profil()
	texte_message.text = tr("Test : +50 jetons")
	_rafraichir()


func _reinitialiser_debug() -> void:
	GameState.reinitialiser_profil()
	comptoir = Comptoir.creer(GameState.profil)
	texte_message.text = tr("Test : profil remis à zéro")
	_rafraichir()


# --- Affichage ---------------------------------------------------------------

func _nom_deblocage(id: StringName) -> String:
	if id in Profil.SYMBOLES_A_DEBLOQUER:
		return tr((load("res://data/symbols/%s.tres" % id) as SymbolData).nom)
	var relique := Reliques.charger(id)
	return tr(relique.nom) if relique != null else String(id)


func _rafraichir() -> void:
	var profil := GameState.profil
	texte_jetons.text = tr("Jetons d'âme : %d     Parties : %d     Victoires : %d") % [
		profil.jetons, profil.parties_jouees, profil.victoires]
	texte_records.text = profil.texte_records()
	for i in boutons_achats.size():
		var achat: Comptoir.Achat = Comptoir.ORDRE[i]
		var epuise := comptoir.est_epuise(achat)
		var detail := comptoir.detail(achat) if epuise else "%s\n%s" % [comptoir.detail(achat), tr("%d jetons") % comptoir.prix(achat)]
		Cartes.changer_carte(boutons_achats[i], comptoir.titre(achat), detail)
		boutons_achats[i].disabled = not comptoir.peut_acheter(achat)

	if profil.maledictions.is_empty():
		texte_maledictions.text = tr("Aucune : la prochaine partie est sans malédiction.")
	else:
		var lignes := PackedStringArray()
		for id in profil.maledictions:
			lignes.append(Maledictions.texte(id))
		texte_maledictions.text = "\n".join(lignes)

	var symboles := PackedStringArray()
	for id in profil.symboles_debloques:
		if id in Profil.SYMBOLES_A_DEBLOQUER:
			symboles.append(_nom_deblocage(id))
	var reliques := PackedStringArray()
	for id in profil.reliques_debloquees:
		reliques.append(_nom_deblocage(id))
	texte_debloques.text = tr("Symboles gagnés : %s\nReliques possibles : %s") % [
		", ".join(symboles) if not symboles.is_empty() else tr("aucun"), ", ".join(reliques)]


# --- Construction de l'interface (en code) -----------------------------------

func _construire_interface() -> void:
	Cartes.ajouter_fond(self, COULEUR_FOND)

	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for cote in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marge.add_theme_constant_override(cote, 20)
	add_child(marge)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	marge.add_child(page)

	var titre := Label.new()
	titre.text = tr("Comptoir du Croupier")
	titre.add_theme_font_size_override("font_size", 32)
	Habillage.titre(titre, Cartes.COULEUR_JETONS)
	page.add_child(titre)

	texte_jetons = Label.new()
	texte_jetons.add_theme_font_size_override("font_size", 20)
	texte_jetons.add_theme_color_override("font_color", Cartes.COULEUR_JETONS)
	page.add_child(texte_jetons)
	texte_records = Label.new()
	texte_records.add_theme_font_size_override("font_size", 16)
	texte_records.add_theme_color_override("font_color", Habillage.COULEUR_DISCRETE)
	page.add_child(texte_records)

	var corps := HBoxContainer.new()
	corps.add_theme_constant_override("separation", 24)
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(corps)

	var grille := GridContainer.new()
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", 12)
	grille.add_theme_constant_override("v_separation", 10)
	corps.add_child(grille)
	for achat in Comptoir.ORDRE:
		var carte := Cartes.creer_carte(COULEURS[achat], "", "", TAILLE_CARTE, 20, 15)
		carte.pressed.connect(_acheter.bind(achat))
		grille.add_child(carte)
		boutons_achats.append(carte)

	var droite := VBoxContainer.new()
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	droite.add_theme_constant_override("separation", 6)
	corps.add_child(droite)
	var titre_maledictions := Label.new()
	titre_maledictions.text = tr("Malédictions de la prochaine partie")
	titre_maledictions.add_theme_font_size_override("font_size", 20)
	droite.add_child(titre_maledictions)
	texte_maledictions = Label.new()
	texte_maledictions.add_theme_font_size_override("font_size", 17)
	texte_maledictions.add_theme_color_override("font_color", Cartes.COULEUR_MALEDICTION)
	texte_maledictions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	droite.add_child(texte_maledictions)
	var titre_debloques := Label.new()
	titre_debloques.text = tr("Ce que tu as débloqué")
	titre_debloques.add_theme_font_size_override("font_size", 20)
	droite.add_child(titre_debloques)
	texte_debloques = Label.new()
	texte_debloques.add_theme_font_size_override("font_size", 16)
	texte_debloques.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	droite.add_child(texte_debloques)

	texte_message = Label.new()
	texte_message.add_theme_font_size_override("font_size", 18)
	texte_message.add_theme_color_override("font_color", Cartes.COULEUR_SURVOL)
	texte_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(texte_message)

	var bas := HBoxContainer.new()
	bas.add_theme_constant_override("separation", 12)
	page.add_child(bas)
	bouton_jouer = Button.new()
	bouton_jouer.text = tr("Jouer")
	bouton_jouer.custom_minimum_size = Vector2(320, 52)
	bouton_jouer.focus_mode = Control.FOCUS_NONE
	bouton_jouer.pressed.connect(_jouer)
	bas.add_child(bouton_jouer)
	bouton_menu = Button.new()
	bouton_menu.text = tr("Menu")
	bouton_menu.custom_minimum_size = Vector2(140, 52)
	bouton_menu.focus_mode = Control.FOCUS_NONE
	bouton_menu.pressed.connect(_menu)
	bas.add_child(bouton_menu)
	if OS.is_debug_build():
		bouton_debug_jetons = Button.new()
		bouton_debug_jetons.text = tr("[test] +50 jetons")
		bouton_debug_jetons.focus_mode = Control.FOCUS_NONE
		bouton_debug_jetons.pressed.connect(_donner_jetons_debug)
		bas.add_child(bouton_debug_jetons)
		bouton_debug_reset = Button.new()
		bouton_debug_reset.text = tr("[test] Réinitialiser le profil")
		bouton_debug_reset.focus_mode = Control.FOCUS_NONE
		bouton_debug_reset.pressed.connect(_reinitialiser_debug)
		bas.add_child(bouton_debug_reset)
