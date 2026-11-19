extends Control
## Écran de combat : un ennemi avec son intention, la machine à sous, les PV et l'armure
## du joueur, les mises et les reliques. Les PV, l'or, le sac et les reliques viennent de la
## partie en cours (GameState.partie).
##
## Un tour : on choisit une mise (facultatif), on tire le levier, les rouleaux s'affichent.
## Sans relance disponible, le tour se joue aussitôt. Avec le Dé pipé ou le Cinquième as, on peut
## relancer avant de « Valider ». En fin de combat, « Continuer » mène à l'écran que la partie demande
## (récompense, relique, portes ou fin).
## C'est aussi l'écran principal du projet (project.godot ne se modifie pas à la main) : si la partie
## n'attend pas un combat (au lancement : le choix des portes), il envoie vers le bon écran.
## L'interface est construite en code ; les vrais décors viendront en v0.8.

## La fenêtre fait 648 px de haut : toute la colonne de gauche (jusqu'au bouton Continuer)
## doit tenir dedans. tests/test_interface.gd vérifie la position des boutons.
const HAUTEUR_CASE := 100
const COULEUR_FOND := Color("1b1a24")
const COULEUR_CASE_VIDE := Color("2c2a38")
const COULEUR_CASE_BLOQUEE := Color("5a2430")
const COULEUR_COMBO := Color("ffd34d")
const COULEUR_CHOIX := Color("7fd7ff")
const COULEUR_VICTOIRE := Color("7ddc7d")
const COULEUR_DEFAITE := Color("ff6b6b")
const COULEUR_BOSS := Color("ff9a5c")

var machine: MachineASous
var partie: Partie
var combat: Combat

var cases: Array[PanelContainer] = []
var etiquettes: Array[Label] = []

var texte_etage: Label
var panneau_ennemi: PanelContainer
var etiquettes_ennemi: Array[Label] = []
var texte_nom_ennemi: Label
var barre_pv_ennemi: ProgressBar
var texte_pv_ennemi: Label
var texte_intention: Label
var texte_passif: Label
var barre_pv_joueur: ProgressBar
var texte_pv_joueur: Label
var texte_or: Label
var texte_fin: Label
var bouton_levier: Button
var bouton_continuer: Button
var texte_journal: RichTextLabel
var texte_graine: Label

# Mises : un bouton par mise possible, dans l'ordre de `mises`.
var mises: Array[Mise] = []
var boutons_mise: Array[Button] = []
var mise_choisie: int = 0

# Reliques possédées (une étiquette chacune, bulle d'aide = ce qu'elle fait).
var rangee_reliques: HFlowContainer

# Entre le tirage et « Valider » : relances (Dé pipé, Cinquième as).
var ligne_relance: HBoxContainer
var bouton_valider: Button
var bouton_de_pipe: Button
var bouton_cinquieme_as: Button
## Vrai quand on a cliqué sur « Cinquième as » et qu'on doit choisir le rouleau à garder.
var choix_du_rouleau: bool = false

# Boutons de test (visibles seulement quand on lance depuis l'éditeur).
var bouton_debug: Button
var bouton_debug_relique: Button
var bouton_debug_etage: Button


func _ready() -> void:
	partie = GameState.partie
	if partie.ecran != Partie.Ecran.COMBAT:
		GameState.rediriger()
		return
	machine = partie.creer_machine()
	combat = partie.creer_combat()
	_construire_interface()

	texte_graine.text = tr("Graine : %d") % partie.graine + "     " + Version.texte()
	texte_journal.text = tr("Tire le levier pour lancer la machine.")
	if not combat.journal_ouverture.is_empty():
		# Attaque surprise (Mimique) : elle a eu lieu avant le premier tirage.
		texte_journal.text = "[b][color=#ff6b6b]%s[/color][/b]

%s" % [
			"
".join(combat.journal_ouverture), texte_journal.text]
	for i in machine.nb_cases():
		_dessiner_case(i, null, false)

	var fond := StyleBoxFlat.new()
	fond.set_corner_radius_all(10)
	fond.bg_color = combat.ennemi.couleur
	panneau_ennemi.add_theme_stylebox_override("panel", fond)
	var couleur_texte := _couleur_texte(combat.ennemi.couleur)
	for etiquette in etiquettes_ennemi:
		etiquette.add_theme_color_override("font_color", couleur_texte)

	barre_pv_ennemi.max_value = combat.ennemi.pv_max
	barre_pv_joueur.max_value = combat.pv_max_joueur
	_rafraichir()


func _unhandled_input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed or touche.echo:
		return
	if touche.keycode == KEY_SPACE:
		_tirer()


# --- Le tour : mise, levier, relances, validation -----------------------------

## Levier (bouton ou Espace). Pendant une relance possible, Espace valide le tirage affiché.
func _tirer() -> void:
	if combat == null or combat.est_fini():
		return
	if combat.tirage_en_attente:
		_valider()
		return

	var mise := mises[mise_choisie]
	if not combat.tirer(mise):
		return
	_dessiner_grille()
	if combat.peut_relancer():
		_attendre_validation()
	else:
		_valider()


## Applique le tirage affiché (et la mise) : l'ennemi agit ensuite.
func _valider() -> void:
	if not combat.tirage_en_attente:
		return
	choix_du_rouleau = false
	var numero_tour := combat.numero_tour
	var journal_combat := combat.valider()
	_dessiner_grille()
	_afficher_tour(numero_tour, combat.resultat_courant, journal_combat)
	_choisir_mise(0)
	_rafraichir()


## Les rouleaux sont affichés mais pas encore appliqués : on peut relancer ou valider.
func _attendre_validation() -> void:
	_afficher_apercu()
	_rafraichir()


## Dé pipé : relance tous les rouleaux.
func _relancer_tout() -> void:
	if combat.relancer_tout():
		choix_du_rouleau = false
		_dessiner_grille()
		_afficher_apercu()
		_rafraichir()


## Cinquième as, étape 1 : on active le choix du rouleau à garder (un second clic annule).
func _commencer_cinquieme_as() -> void:
	choix_du_rouleau = not choix_du_rouleau
	_dessiner_grille()
	_afficher_apercu()
	_rafraichir()


## Cinquième as, étape 2 : clic sur un rouleau = on le garde et on relance les autres.
func _sur_case(evenement: InputEvent, index: int) -> void:
	var clic := evenement as InputEventMouseButton
	if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT:
		_garder_rouleau(index)


func _garder_rouleau(index: int) -> void:
	if not choix_du_rouleau:
		return
	if combat.relancer_en_gardant(index):
		choix_du_rouleau = false
		_dessiner_grille()
		_afficher_apercu()
		_rafraichir()


func _choisir_mise(index: int) -> void:
	mise_choisie = index
	if boutons_mise.size() > index:
		boutons_mise[index].button_pressed = true


func _continuer() -> void:
	bouton_continuer.disabled = true
	partie.terminer_combat(combat)
	GameState.aller_a_suivant()


## Pour passer à l'étage suivant sans combattre le boss (bouton de test).
func _sauter_etage() -> void:
	bouton_debug_etage.disabled = true
	partie.sauter_etage()
	GameState.aller_a_suivant()


## Pour tester le boss sans traverser l'étage (bouton visible seulement en test, pas dans le jeu exporté).
## Ce n'est pas une touche : l'éditeur Godot garde F8 (arrêter) et d'autres touches de fonction.
func _aller_au_boss() -> void:
	bouton_debug.disabled = true
	partie.aller_au_boss()
	GameState.aller_a(GameState.SCENE_COMBAT)


## Pour essayer les reliques sans les acheter : en ajoute une au hasard (bouton visible seulement
## en test). Le combat recommence pour que la relique serve tout de suite.
func _donner_relique_debug() -> void:
	var propositions := partie.proposer_reliques(1)
	if propositions.is_empty():
		return
	bouton_debug_relique.disabled = true
	partie.ajouter_relique(propositions[0])
	GameState.aller_a(GameState.SCENE_COMBAT)


# --- Affichage -------------------------------------------------------------

func _couleur_texte(fond: Color) -> Color:
	return Color.BLACK if fond.get_luminance() > 0.5 else Color.WHITE


## Met à jour tout ce qui dépend de l'état du combat.
func _rafraichir() -> void:
	if partie.est_combat_de_boss():
		texte_etage.text = tr("Étage %d — BOSS") % partie.etage
		texte_etage.add_theme_color_override("font_color", COULEUR_BOSS)
	else:
		texte_etage.text = tr("Étage %d — Salle %d / %d") % [partie.etage, partie.pas, Donjon.NB_PAS]

	texte_nom_ennemi.text = tr(combat.ennemi.nom)
	barre_pv_ennemi.value = combat.pv_ennemi
	texte_pv_ennemi.text = tr("PV %d / %d   Armure %d") % [
		combat.pv_ennemi, combat.ennemi.pv_max, combat.armure_ennemi]

	if combat.est_fini():
		texte_intention.text = ""
	else:
		texte_intention.text = tr("Intention : %s") % Intentions.decrire(combat.intention_affichee())
	texte_passif.text = _texte_passif()
	texte_passif.visible = not texte_passif.text.is_empty()

	barre_pv_joueur.value = combat.pv_joueur
	texte_pv_joueur.text = tr("Toi : PV %d / %d   Armure %d") % [
		combat.pv_joueur, combat.pv_max_joueur, combat.armure_joueur]
	texte_or.text = tr("Or : %d   Sac : %d symboles") % [
		combat.or_du_joueur(), partie.sac.taille()]

	# Les rouleaux que l'ennemi vient de bloquer sont déjà marqués pour le prochain tirage.
	if not combat.tirage_en_attente:
		for index in combat.rouleaux_bloques:
			_dessiner_case(index, null, false, true)

	match combat.etat:
		Combat.Etat.VICTOIRE:
			texte_fin.text = tr("VICTOIRE ! +%d or") % combat.ennemi.or_victoire
			texte_fin.add_theme_color_override("font_color", COULEUR_VICTOIRE)
		Combat.Etat.DEFAITE:
			texte_fin.text = tr("DÉFAITE... tu n'as plus de PV.")
			texte_fin.add_theme_color_override("font_color", COULEUR_DEFAITE)
		Combat.Etat.FUITE:
			texte_fin.text = tr("%s s'est enfui !") % tr(combat.ennemi.nom)
			texte_fin.add_theme_color_override("font_color", COULEUR_BOSS)
		_:
			texte_fin.text = ""
	bouton_levier.disabled = combat.est_fini() or combat.tirage_en_attente
	bouton_continuer.visible = combat.est_fini()

	_rafraichir_mises()
	_rafraichir_relances()


## Ce que l'ennemi fait en plus de son intention, en une ligne (ou rien) : la règle du tour du
## Grand Croupier, ou le passif (crânes temporaires déjà glissés dans la machine, renfort...).
func _texte_passif() -> String:
	if combat.est_fini():
		return ""
	if not combat.regle_active.is_empty():
		return tr("Règle du tour : %s") % ReglesMachine.decrire(combat.regle_active)
	var texte := Intentions.decrire_passif(combat.ennemi.passif)
	if combat.cranes_temporaires > 0:
		texte += " " + tr("(%d / %d)") % [combat.cranes_temporaires, Combat.MAX_CRANES_TEMPORAIRES]
	return texte


## Les boutons de mise : grisés si la mise est impossible (pas assez d'or, trop peu de PV).
## Pendant qu'un tirage attend sa validation, on ne peut plus changer de mise : seule la mise
## choisie reste affichée en clair, pour qu'on voie ce qu'on a misé.
func _rafraichir_mises() -> void:
	for i in boutons_mise.size():
		if combat.est_fini():
			boutons_mise[i].disabled = true
		elif combat.tirage_en_attente:
			boutons_mise[i].disabled = i != mise_choisie
		else:
			boutons_mise[i].disabled = not combat.peut_miser(mises[i])
	# Une mise devenue impossible (or volé, PV perdus) est abandonnée.
	if not combat.peut_miser(mises[mise_choisie]) and not combat.tirage_en_attente:
		_choisir_mise(0)


## « Valider » et les boutons de relance remplacent « Continuer » pendant un tirage en attente.
func _rafraichir_relances() -> void:
	ligne_relance.visible = combat.tirage_en_attente and not combat.est_fini()
	bouton_de_pipe.visible = partie.a_relique(Reliques.DE_PIPE)
	bouton_de_pipe.disabled = combat.relances_gratuites <= 0
	bouton_cinquieme_as.visible = partie.a_relique(Reliques.CINQUIEME_AS)
	bouton_cinquieme_as.disabled = combat.relances_cinquieme_as <= 0
	bouton_cinquieme_as.text = tr("Annuler : garder quel rouleau ?") if choix_du_rouleau \
			else tr("Cinquième as : garder un rouleau")
	var curseur := Control.CURSOR_POINTING_HAND if choix_du_rouleau else Control.CURSOR_ARROW
	for case_rouleau in cases:
		case_rouleau.mouse_default_cursor_shape = curseur


## Dessine les rouleaux du tirage en cours (ou du dernier tour joué).
func _dessiner_grille() -> void:
	var grille := combat.grille_courante
	var resultat := combat.resultat_courant
	for i in grille.size():
		_dessiner_case(i, grille[i], i in resultat.cases_en_combo, i in combat.bloques_du_tirage)


func _dessiner_case(index: int, symbole: SymbolData, en_combo: bool, bloquee: bool = false) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	var etiquette := etiquettes[index]

	if bloquee:
		style.bg_color = COULEUR_CASE_BLOQUEE
		etiquette.text = tr("BLOQUÉ")
		etiquette.add_theme_color_override("font_color", Color.WHITE)
		cases[index].tooltip_text = tr("Ce rouleau est bloqué : il restera vide au prochain tirage.")
	elif symbole == null:
		style.bg_color = COULEUR_CASE_VIDE
		etiquette.text = tr("vide")
		etiquette.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
		cases[index].tooltip_text = ""
	else:
		style.bg_color = symbole.couleur
		etiquette.text = symbole.nom_affiche()
		etiquette.add_theme_color_override("font_color", _couleur_texte(symbole.couleur))
		cases[index].tooltip_text = "%s\n%s\n%s" % [
			symbole.nom_affiche(),
			symbole.decrire_base(),
			tr("Combo de 3 : %s") % symbole.decrire_combo(),
		]

	if en_combo:
		style.set_border_width_all(6)
		style.border_color = COULEUR_COMBO
	elif choix_du_rouleau and symbole != null and not bloquee:
		# Cinquième as : les rouleaux qu'on peut garder sont entourés.
		style.set_border_width_all(4)
		style.border_color = COULEUR_CHOIX

	cases[index].add_theme_stylebox_override("panel", style)


## Pendant un tirage en attente : ce que donnerait le tour, et ce qu'on peut faire.
func _afficher_apercu() -> void:
	var resultat := combat.resultat_courant
	var texte := PackedStringArray()
	texte.append("[b]%s[/b]" % tr("Tirage affiché, pas encore appliqué"))
	for combo in resultat.combos:
		var titre := tr("JACKPOT !!!") if combo.est_jackpot() else tr("COMBO !")
		texte.append("[color=#ffd34d][b]%s[/b] %s[/color]" % [
			titre, tr("%d × %s, effet ×%d") % [
				combo.longueur, tr(combo.symbole.nom), combo.multiplicateur]])
	if resultat.totaux.is_empty():
		texte.append(tr("aucun effet"))
	else:
		texte.append(Effets.decrire(resultat.totaux, "\n"))
	texte.append("")
	if choix_du_rouleau:
		texte.append("[b]%s[/b]" % tr("Clique sur le rouleau à garder : les autres seront relancés."))
	else:
		texte.append(tr("Valide ce tirage (Espace) ou relance avec tes reliques."))
	texte_journal.text = "\n".join(texte)


## Écrit ce qui s'est passé pendant le tour : combos, effets du tirage, puis le combat.
func _afficher_tour(numero_tour: int, resultat: ResultatTirage, journal_combat: Array[String]) -> void:
	var texte := PackedStringArray()
	texte.append("[b]%s[/b]" % (tr("Tour %d") % numero_tour))

	for combo in resultat.combos:
		var titre := tr("JACKPOT !!!") if combo.est_jackpot() else tr("COMBO !")
		texte.append("[color=#ffd34d][b]%s[/b] %s[/color]" % [
			titre, tr("%d × %s, effet ×%d") % [
				combo.longueur, tr(combo.symbole.nom), combo.multiplicateur]])

	texte.append("")
	texte.append("[b]%s[/b]" % tr("Tirage"))
	if resultat.totaux.is_empty():
		texte.append(tr("aucun effet"))
	else:
		texte.append(Effets.decrire(resultat.totaux, "\n"))

	texte.append("")
	texte.append("[b]%s[/b]" % tr("Combat"))
	for ligne in journal_combat:
		texte.append(ligne)

	texte_journal.text = "\n".join(texte)


# --- Construction de l'interface (en code) ---------------------------------

func _construire_interface() -> void:
	var fond := ColorRect.new()
	fond.color = COULEUR_FOND
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)

	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for cote in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marge.add_theme_constant_override(cote, 24)
	add_child(marge)

	var ecran := HBoxContainer.new()
	ecran.add_theme_constant_override("separation", 40)
	marge.add_child(ecran)

	_construire_colonne_combat(ecran)
	_construire_colonne_journal(ecran)


func _construire_colonne_combat(parent: Control) -> void:
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 8)
	parent.add_child(colonne)

	# Titre : étage et numéro du combat.
	texte_etage = Label.new()
	texte_etage.add_theme_font_size_override("font_size", 26)
	colonne.add_child(texte_etage)

	# L'ennemi : nom, PV, armure, intention.
	panneau_ennemi = PanelContainer.new()
	colonne.add_child(panneau_ennemi)
	var marge_ennemi := MarginContainer.new()
	for cote in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marge_ennemi.add_theme_constant_override(cote, 12)
	panneau_ennemi.add_child(marge_ennemi)
	var boite_ennemi := VBoxContainer.new()
	boite_ennemi.add_theme_constant_override("separation", 6)
	marge_ennemi.add_child(boite_ennemi)

	texte_nom_ennemi = _etiquette_ennemi(boite_ennemi, 24)
	barre_pv_ennemi = _creer_barre()
	boite_ennemi.add_child(barre_pv_ennemi)
	texte_pv_ennemi = _etiquette_ennemi(boite_ennemi, 18)
	texte_intention = _etiquette_ennemi(boite_ennemi, 22)
	texte_passif = _etiquette_ennemi(boite_ennemi, 16)

	# Les rouleaux (5, ou 6 avec le Sixième rouleau, un peu plus étroits).
	var largeur_case := 120 if machine.colonnes <= 5 else 104
	var grille := GridContainer.new()
	grille.columns = machine.colonnes
	grille.add_theme_constant_override("h_separation", 10)
	grille.add_theme_constant_override("v_separation", 10)
	colonne.add_child(grille)
	for i in machine.nb_cases():
		var case_grille := PanelContainer.new()
		case_grille.custom_minimum_size = Vector2(largeur_case, HAUTEUR_CASE)
		case_grille.gui_input.connect(_sur_case.bind(i))
		var etiquette := Label.new()
		etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		etiquette.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		etiquette.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiquette.add_theme_font_size_override("font_size", 20 if machine.colonnes <= 5 else 17)
		case_grille.add_child(etiquette)
		grille.add_child(case_grille)
		cases.append(case_grille)
		etiquettes.append(etiquette)

	bouton_levier = Button.new()
	bouton_levier.text = tr("Tirer le levier (Espace)")
	bouton_levier.custom_minimum_size = Vector2(0, 52)
	bouton_levier.focus_mode = Control.FOCUS_NONE  # sinon Espace déclencherait 2 tirages
	bouton_levier.pressed.connect(_tirer)
	colonne.add_child(bouton_levier)

	# Le joueur : PV, armure, or, sac.
	barre_pv_joueur = _creer_barre()
	colonne.add_child(barre_pv_joueur)
	texte_pv_joueur = Label.new()
	texte_pv_joueur.add_theme_font_size_override("font_size", 20)
	colonne.add_child(texte_pv_joueur)
	texte_or = Label.new()
	texte_or.add_theme_font_size_override("font_size", 18)
	colonne.add_child(texte_or)

	# Fin du combat, ou (au même endroit) valider / relancer un tirage en attente.
	texte_fin = Label.new()
	texte_fin.add_theme_font_size_override("font_size", 26)
	colonne.add_child(texte_fin)
	bouton_continuer = Button.new()
	bouton_continuer.text = tr("Continuer")
	bouton_continuer.custom_minimum_size = Vector2(0, 44)
	bouton_continuer.focus_mode = Control.FOCUS_NONE
	bouton_continuer.pressed.connect(_continuer)
	colonne.add_child(bouton_continuer)

	ligne_relance = HBoxContainer.new()
	ligne_relance.add_theme_constant_override("separation", 8)
	colonne.add_child(ligne_relance)
	bouton_valider = _creer_bouton_relance(tr("Valider (Espace)"), _valider)
	bouton_de_pipe = _creer_bouton_relance(tr("Dé pipé : tout relancer"), _relancer_tout)
	bouton_cinquieme_as = _creer_bouton_relance(tr("Cinquième as : garder un rouleau"), _commencer_cinquieme_as)
	ligne_relance.visible = false


func _creer_bouton_relance(texte: String, action: Callable) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.custom_minimum_size = Vector2(0, 44)
	bouton.focus_mode = Control.FOCUS_NONE
	bouton.pressed.connect(action)
	ligne_relance.add_child(bouton)
	return bouton


func _construire_colonne_journal(parent: Control) -> void:
	var colonne := VBoxContainer.new()
	colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.add_theme_constant_override("separation", 8)
	parent.add_child(colonne)

	_construire_panneau_mise(colonne)
	_construire_rangee_reliques(colonne)

	var titre := Label.new()
	titre.text = tr("Dernier tour")
	titre.add_theme_font_size_override("font_size", 22)
	colonne.add_child(titre)

	texte_journal = RichTextLabel.new()
	texte_journal.bbcode_enabled = true
	texte_journal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texte_journal.add_theme_font_size_override("normal_font_size", 18)
	texte_journal.add_theme_font_size_override("bold_font_size", 18)
	colonne.add_child(texte_journal)

	texte_graine = Label.new()
	texte_graine.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	colonne.add_child(texte_graine)

	if OS.is_debug_build():
		# Les trois boutons de test tiennent sur une ligne (le journal garde sa place).
		var rangee_test := HFlowContainer.new()
		rangee_test.add_theme_constant_override("h_separation", 6)
		rangee_test.add_theme_constant_override("v_separation", 4)
		colonne.add_child(rangee_test)

		bouton_debug = Button.new()
		bouton_debug.text = tr("[test] Boss")
		bouton_debug.tooltip_text = tr("Aller directement au boss de l'étage")
		bouton_debug.disabled = partie.est_combat_de_boss()
		bouton_debug.focus_mode = Control.FOCUS_NONE
		bouton_debug.pressed.connect(_aller_au_boss)
		rangee_test.add_child(bouton_debug)

		bouton_debug_relique = Button.new()
		bouton_debug_relique.text = tr("[test] +1 relique")
		bouton_debug_relique.tooltip_text = tr("Recevoir une relique au hasard")
		bouton_debug_relique.disabled = not partie.peut_recevoir_relique()
		bouton_debug_relique.focus_mode = Control.FOCUS_NONE
		bouton_debug_relique.pressed.connect(_donner_relique_debug)
		rangee_test.add_child(bouton_debug_relique)

		bouton_debug_etage = Button.new()
		bouton_debug_etage.text = tr("[test] Étage suivant")
		bouton_debug_etage.tooltip_text = tr("Passer à l'étage suivant sans combattre le boss")
		bouton_debug_etage.disabled = partie.etage >= Donjon.NB_ETAGES
		bouton_debug_etage.focus_mode = Control.FOCUS_NONE
		bouton_debug_etage.pressed.connect(_sauter_etage)
		rangee_test.add_child(bouton_debug_etage)


## Les mises : pas de mise, 5 / 10 / 20 or, quitte ou double. Une seule choisie à la fois.
func _construire_panneau_mise(parent: Control) -> void:
	var titre := Label.new()
	titre.text = tr("Mise (facultative)")
	titre.add_theme_font_size_override("font_size", 20)
	parent.add_child(titre)

	var boutons := HFlowContainer.new()
	boutons.add_theme_constant_override("h_separation", 6)
	boutons.add_theme_constant_override("v_separation", 6)
	parent.add_child(boutons)

	mises.append(Mise.aucune())
	for montant in Mise.MONTANTS_OR:
		mises.append(Mise.en_or(montant))
	mises.append(Mise.quitte_ou_double())

	var groupe := ButtonGroup.new()
	for i in mises.size():
		var bouton := Button.new()
		bouton.text = mises[i].libelle()
		bouton.toggle_mode = true
		bouton.button_group = groupe
		bouton.focus_mode = Control.FOCUS_NONE
		bouton.custom_minimum_size = Vector2(0, 34)
		Cartes.habiller_bouton_mise(bouton)
		bouton.pressed.connect(_choisir_mise.bind(i))
		match mises[i].type:
			Mise.Type.OR:
				bouton.tooltip_text = tr("Si le tirage a un combo (hors crânes), tu reçois %d fois ta mise. Sinon elle est perdue.") % Mise.MULTIPLICATEUR_GAIN_OR
			Mise.Type.QUITTE_OU_DOUBLE:
				bouton.tooltip_text = tr("Aucun crâne visible : effets positifs doublés. Un crâne visible : tu perds %d PV.") % Mise.PV_QUITTE_OU_DOUBLE
			_:
				bouton.tooltip_text = tr("Pas de risque, pas de gain en plus.")
		boutons.add_child(bouton)
		boutons_mise.append(bouton)
	boutons_mise[0].button_pressed = true


## Les reliques possédées, avec une bulle d'aide qui dit ce que chacune fait.
func _construire_rangee_reliques(parent: Control) -> void:
	var titre := Label.new()
	titre.text = tr("Reliques")
	titre.add_theme_font_size_override("font_size", 20)
	parent.add_child(titre)

	rangee_reliques = HFlowContainer.new()
	rangee_reliques.add_theme_constant_override("h_separation", 6)
	rangee_reliques.add_theme_constant_override("v_separation", 6)
	parent.add_child(rangee_reliques)

	if partie.reliques.is_empty():
		var aucune := Label.new()
		aucune.text = tr("aucune pour l'instant")
		aucune.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
		rangee_reliques.add_child(aucune)
		return
	for relique in partie.reliques:
		var puce := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(8)
		style.bg_color = relique.couleur
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		puce.add_theme_stylebox_override("panel", style)
		puce.tooltip_text = "%s\n%s" % [tr(relique.nom), tr(relique.description)]
		var nom := Label.new()
		nom.text = tr(relique.nom)
		nom.add_theme_font_size_override("font_size", 16)
		nom.add_theme_color_override("font_color", _couleur_texte(relique.couleur))
		puce.add_child(nom)
		rangee_reliques.add_child(puce)


func _creer_barre() -> ProgressBar:
	var barre := ProgressBar.new()
	barre.show_percentage = false
	barre.custom_minimum_size = Vector2(0, 20)
	return barre


## Crée une étiquette du panneau de l'ennemi (sa couleur de texte suit celle de l'ennemi).
func _etiquette_ennemi(parent: Control, taille: int) -> Label:
	var etiquette := Label.new()
	etiquette.add_theme_font_size_override("font_size", taille)
	parent.add_child(etiquette)
	etiquettes_ennemi.append(etiquette)
	return etiquette
