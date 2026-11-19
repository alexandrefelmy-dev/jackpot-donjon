extends Control
## Écran de boutique : acheter un symbole, retirer un symbole du sac, le rendre doré, se soigner.
## Toutes les règles (prix, conditions) sont dans Boutique : cet écran affiche et appelle.
## Il doit tenir dans la fenêtre 1152 × 648 : tests/test_interface.gd le vérifie.

const COULEUR_FOND := Color("1b1a24")
const COULEUR_MESSAGE := Color("ffd34d")

## Ce que fait un clic sur un symbole du sac.
enum Mode { NORMAL, RETRAIT, AMELIORATION }

var partie: Partie
var boutique: Boutique
var mode: Mode = Mode.NORMAL

var texte_infos: Label
var texte_message: Label
var cartes_offres: Array[Button] = []
var cartes_reliques: Array[Button] = []
var bouton_soin: Button
var bouton_retrait: Button
var bouton_amelioration: Button
var bouton_quitter: Button
var bouton_debug: Button
var zone_sac: ScrollContainer
var liste_sac: VBoxContainer


func _ready() -> void:
	partie = GameState.partie
	if partie.ecran != Partie.Ecran.BOUTIQUE:
		GameState.rediriger()
		return
	GameState.demarrer()
	Musique.jouer_pour(partie)
	boutique = Boutique.creer(partie)
	_construire_interface()
	_message(tr("Bienvenue ! Dépense ton or avec sagesse."))
	_rafraichir()


# --- Actions -----------------------------------------------------------------

func _acheter(index: int) -> void:
	var symbole := boutique.offres[index]
	if boutique.acheter(index):
		Son.jouer(&"achat")
		_message(tr("%s ajouté à ton sac.") % symbole.nom_affiche())
	else:
		_message(tr("Achat impossible."))
	_rafraichir()


func _acheter_relique(index: int) -> void:
	var relique := boutique.offres_reliques[index]
	if boutique.acheter_relique(index):
		Son.jouer(&"relique")
		_message(tr("%s : relique achetée !") % tr(relique.nom))
	else:
		_message(tr("Achat impossible."))
	_rafraichir()


func _soigner() -> void:
	if boutique.soigner():
		Son.jouer(&"soin")
		_message(tr("Tu récupères des PV."))
	else:
		_message(tr("Soin impossible."))
	_rafraichir()


## Un clic sur « Retirer » ou « Améliorer » : on choisit ensuite le symbole dans le sac (ou on annule).
func _changer_mode(nouveau: Mode) -> void:
	mode = Mode.NORMAL if mode == nouveau else nouveau
	match mode:
		Mode.RETRAIT:
			_message(tr("Choisis dans ton sac le symbole à retirer (%d or).") % boutique.prix_retrait())
		Mode.AMELIORATION:
			_message(tr("Choisis dans ton sac le symbole à rendre doré (%d or).") % boutique.prix_amelioration())
		_:
			_message(tr("Action annulée."))
	_rafraichir()


func _clic_sac(index_sac: int) -> void:
	match mode:
		Mode.RETRAIT:
			var nom := partie.sac.symboles[index_sac].nom_affiche()
			if boutique.retirer(index_sac):
				_message(tr("%s retiré de ton sac.") % nom)
			else:
				_message(tr("Retrait impossible."))
		Mode.AMELIORATION:
			var nom := partie.sac.symboles[index_sac].nom
			if boutique.ameliorer(index_sac):
				_message(tr("%s est maintenant doré !") % tr(nom))
			else:
				_message(tr("Amélioration impossible."))
		_:
			return
	mode = Mode.NORMAL
	_rafraichir()


## Pour tester la boutique sans attendre d'avoir de l'or (bouton visible seulement en test).
## Ce n'est pas une touche : l'éditeur Godot garde F8 (arrêter) et d'autres touches de fonction.
func _donner_or_debug() -> void:
	partie.or_total += 30
	_message(tr("Test : +30 or"))
	_rafraichir()


func _quitter() -> void:
	bouton_quitter.disabled = true
	partie.quitter_boutique()
	GameState.aller_a_suivant()


# --- Affichage ---------------------------------------------------------------

func _message(texte: String) -> void:
	texte_message.text = texte


## Met à jour tout ce qui dépend de l'état : or, PV, offres, services, sac.
func _rafraichir() -> void:
	texte_infos.text = tr("Or : %d     PV : %d / %d     Sac : %d symboles     Reliques : %d") % [
		partie.or_total, partie.pv, partie.pv_max, partie.sac.taille(), partie.reliques.size()]

	for i in cartes_offres.size():
		_rafraichir_offre(i)
	for i in cartes_reliques.size():
		_rafraichir_relique(i)

	bouton_soin.text = tr("Se soigner de %d PV (%d or)") % [Boutique.SOIN_PV, boutique.prix_soin()]
	bouton_soin.disabled = not boutique.peut_soigner()

	if mode == Mode.RETRAIT:
		bouton_retrait.text = tr("Annuler le retrait")
	else:
		bouton_retrait.text = tr("Retirer un symbole du sac (%d or)") % boutique.prix_retrait()
	bouton_retrait.disabled = mode != Mode.RETRAIT and partie.or_total < boutique.prix_retrait() \
			or partie.sac.taille() <= 1

	if mode == Mode.AMELIORATION:
		bouton_amelioration.text = tr("Annuler l'amélioration")
	else:
		bouton_amelioration.text = tr("Rendre un symbole doré (%d or)") % boutique.prix_amelioration()
	bouton_amelioration.disabled = mode != Mode.AMELIORATION and partie.or_total < boutique.prix_amelioration()

	_rafraichir_sac()


func _rafraichir_relique(i: int) -> void:
	var relique := boutique.offres_reliques[i]
	var carte := cartes_reliques[i]
	if boutique.reliques_vendues[i]:
		carte.text = "%s\n%s" % [tr(relique.nom), tr("ACHETÉE")]
	else:
		carte.text = "%s\n%s\n%s" % [
			tr(relique.nom), tr(relique.description), tr("Prix : %d or") % boutique.prix_relique(i)]
	carte.disabled = not boutique.peut_acheter_relique(i)


func _rafraichir_offre(i: int) -> void:
	var symbole := boutique.offres[i]
	var carte := cartes_offres[i]
	if boutique.vendues[i]:
		carte.text = "%s\n\n%s" % [tr(symbole.nom), tr("VENDU")]
	else:
		carte.text = "%s\n%s\n%s\n\n%s" % [
			tr(symbole.nom),
			symbole.decrire_base(),
			tr("Combo de 3 : %s") % symbole.decrire_combo(),
			tr("Prix : %d or") % boutique.prix_offre(i),
		]
	carte.disabled = not boutique.peut_acheter(i)


## Le sac, un symbole par ligne (les symboles identiques sont regroupés).
func _rafraichir_sac() -> void:
	for ancien in liste_sac.get_children():
		liste_sac.remove_child(ancien)
		ancien.queue_free()

	for groupe in partie.sac.groupes():
		var symbole: SymbolData = groupe["symbole"]
		var index: int = groupe["index"]
		var ligne := Button.new()
		ligne.text = "%s ×%d  —  %s" % [symbole.nom_affiche(), groupe["quantite"], symbole.decrire_base()]
		ligne.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ligne.custom_minimum_size = Vector2(0, 36)
		ligne.focus_mode = Control.FOCUS_NONE
		ligne.add_theme_font_size_override("font_size", 17)
		ligne.tooltip_text = "%s\n%s\n%s" % [
			symbole.nom_affiche(),
			symbole.decrire_base(),
			tr("Combo de 3 : %s") % symbole.decrire_combo(),
		]
		Cartes.habiller_bouton(ligne, symbole.couleur)
		match mode:
			Mode.RETRAIT:
				ligne.disabled = not boutique.peut_retirer(index)
			Mode.AMELIORATION:
				ligne.disabled = not boutique.peut_ameliorer(index)
		ligne.pressed.connect(_clic_sac.bind(index))
		liste_sac.add_child(ligne)


# --- Construction de l'interface (en code) -----------------------------------

func _construire_interface() -> void:
	var fond := ColorRect.new()
	fond.color = COULEUR_FOND
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)

	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for cote in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marge.add_theme_constant_override(cote, 20)
	add_child(marge)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	marge.add_child(page)

	# En-tête : titre et ressources.
	var entete := HBoxContainer.new()
	page.add_child(entete)
	var titre := Label.new()
	titre.text = tr("Boutique")
	titre.add_theme_font_size_override("font_size", 28)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entete.add_child(titre)
	texte_infos = Label.new()
	texte_infos.add_theme_font_size_override("font_size", 20)
	entete.add_child(texte_infos)

	# Corps : à gauche les offres et les services, à droite le sac.
	var corps := HBoxContainer.new()
	corps.add_theme_constant_override("separation", 28)
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(corps)
	_construire_colonne_achats(corps)
	_construire_colonne_sac(corps)

	# Message et sortie.
	texte_message = Label.new()
	texte_message.add_theme_font_size_override("font_size", 18)
	texte_message.add_theme_color_override("font_color", COULEUR_MESSAGE)
	page.add_child(texte_message)

	bouton_quitter = Button.new()
	bouton_quitter.text = tr("Quitter la boutique")
	bouton_quitter.custom_minimum_size = Vector2(0, 46)
	bouton_quitter.focus_mode = Control.FOCUS_NONE
	bouton_quitter.pressed.connect(_quitter)
	page.add_child(bouton_quitter)

	if OS.is_debug_build():
		bouton_debug = Button.new()
		bouton_debug.text = tr("[test] +30 or")
		bouton_debug.focus_mode = Control.FOCUS_NONE
		bouton_debug.pressed.connect(_donner_or_debug)
		page.add_child(bouton_debug)


func _construire_colonne_achats(parent: Control) -> void:
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	colonne.custom_minimum_size = Vector2(560, 0)
	parent.add_child(colonne)

	var titre_offres := Label.new()
	titre_offres.text = tr("À vendre")
	titre_offres.add_theme_font_size_override("font_size", 22)
	colonne.add_child(titre_offres)

	var ligne_offres := HBoxContainer.new()
	ligne_offres.add_theme_constant_override("separation", 12)
	colonne.add_child(ligne_offres)
	for i in boutique.offres.size():
		var carte := Button.new()
		carte.custom_minimum_size = Vector2(176, 150)
		carte.focus_mode = Control.FOCUS_NONE
		carte.add_theme_font_size_override("font_size", 16)
		Cartes.habiller_bouton(carte, boutique.offres[i].couleur)
		carte.pressed.connect(_acheter.bind(i))
		ligne_offres.add_child(carte)
		cartes_offres.append(carte)

	var titre_services := Label.new()
	titre_services.text = tr("Services")
	titre_services.add_theme_font_size_override("font_size", 22)
	colonne.add_child(titre_services)

	bouton_soin = _creer_bouton_service(colonne, _soigner)
	bouton_retrait = _creer_bouton_service(colonne, _changer_mode.bind(Mode.RETRAIT))
	bouton_amelioration = _creer_bouton_service(colonne, _changer_mode.bind(Mode.AMELIORATION))


func _creer_bouton_service(parent: Control, action: Callable) -> Button:
	var bouton := Button.new()
	bouton.custom_minimum_size = Vector2(0, 44)
	bouton.focus_mode = Control.FOCUS_NONE
	bouton.add_theme_font_size_override("font_size", 18)
	bouton.pressed.connect(action)
	parent.add_child(bouton)
	return bouton


func _construire_colonne_sac(parent: Control) -> void:
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(colonne)

	# Les reliques à vendre (2), au-dessus du sac.
	var titre_reliques := Label.new()
	titre_reliques.text = tr("Reliques à vendre")
	titre_reliques.add_theme_font_size_override("font_size", 22)
	colonne.add_child(titre_reliques)

	var ligne_reliques := HBoxContainer.new()
	ligne_reliques.add_theme_constant_override("separation", 10)
	colonne.add_child(ligne_reliques)
	for i in boutique.offres_reliques.size():
		var carte := Button.new()
		carte.custom_minimum_size = Vector2(0, 112)
		carte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		carte.focus_mode = Control.FOCUS_NONE
		carte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		carte.add_theme_font_size_override("font_size", 15)
		Cartes.habiller_bouton(carte, boutique.offres_reliques[i].couleur)
		carte.tooltip_text = "%s\n%s" % [tr(boutique.offres_reliques[i].nom), tr(boutique.offres_reliques[i].description)]
		carte.pressed.connect(_acheter_relique.bind(i))
		ligne_reliques.add_child(carte)
		cartes_reliques.append(carte)

	var titre := Label.new()
	titre.text = tr("Ton sac")
	titre.add_theme_font_size_override("font_size", 22)
	colonne.add_child(titre)

	zone_sac = ScrollContainer.new()
	zone_sac.size_flags_vertical = Control.SIZE_EXPAND_FILL
	zone_sac.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	colonne.add_child(zone_sac)

	liste_sac = VBoxContainer.new()
	liste_sac.add_theme_constant_override("separation", 6)
	liste_sac.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone_sac.add_child(liste_sac)
