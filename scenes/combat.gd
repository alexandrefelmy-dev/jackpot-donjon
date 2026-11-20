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
## n'attend pas un combat (par exemple le choix des salles bonus), il envoie vers le bon écran.
## L'interface est construite en code : l'ennemi en grand en arrière-plan, la machine à sous (MeubleMachine) devant.

## La fenêtre fait 648 px de haut : le meuble et la colonne de gauche doivent tenir dedans.
## tests/test_interface.gd vérifie la position des boutons.
## Largeur de la colonne de gauche (joueur et journal), et début de la scène de l'ennemi (à droite de cette colonne).
const MARGE_ECRAN := 24
const SEPARATION_CORPS := 16
const LARGEUR_COLONNE_GAUCHE := 290
const DECALAGE_SCENE_ENNEMI := MARGE_ECRAN + LARGEUR_COLONNE_GAUCHE + SEPARATION_CORPS
## Hauteur voulue (en pixels) du sprite de l'ennemi, et ligne de sol : le bas du sprite est posé à cette hauteur
## de la scène, juste derrière le haut du meuble (les pieds disparaissent derrière la machine).
const HAUTEUR_ENNEMI := 190
const SOL_ENNEMI := 330
const COULEUR_FOND := Color("1b1a24")
const COULEUR_CASE_VIDE := Color("2c2a38")
const COULEUR_CASE_BLOQUEE := Color("5a2430")
const COULEUR_COMBO := Habillage.COULEUR_OR
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
## La machine à sous (meuble, rouleaux, mises).
var meuble: MeubleMachine
## La bulle qui dit ce que l'ennemi va faire (cachée une fois le combat fini).
var bulle_intention: PanelContainer
## Sous les mises, quand aucun bouton d'action n'est affiché : un rappel (tirer le levier).
var texte_aide: Label
var texte_nom_ennemi: Label
var barre_pv_ennemi: ProgressBar
var texte_pv_ennemi: Label
var texte_intention: Label
var texte_passif: Label
var image_ennemi: ImageAnimee
var image_joueur: ImageAnimee
## L'icône de chaque rouleau (au-dessus du nom du symbole).
var icones: Array[TextureRect] = []
var barre_pv_joueur: ProgressBar
var texte_pv_joueur: Label
var texte_or: Label
var texte_fin: Label
var bouton_levier: LevierMachine
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
var ligne_relance: HFlowContainer
var bouton_valider: Button
var bouton_de_pipe: Button
var bouton_cinquieme_as: Button
## Vrai quand on a cliqué sur « Cinquième as » et qu'on doit choisir le rouleau à garder.
var choix_du_rouleau: bool = false

# Boutons de test (visibles seulement quand on lance depuis l'éditeur).
var bouton_debug: Button
var bouton_debug_relique: Button
var bouton_debug_etage: Button

## Les rouleaux s'arrêtent un par un (affichage seulement : la logique du tour est déjà calculée).
var animation_en_cours: bool = false
## Rouleaux qui défilent : par case, une fenêtre qui masque ce qui dépasse et une bande d'icônes qui glisse vers le bas.
var _fenetres: Array[Control] = []
var _decalages: Array[float] = []
var _en_rotation: Array[bool] = []
## Le rebond de chaque rouleau à son arrêt (un seul à la fois par rouleau).
var _rebonds: Dictionary = {}
## Instant d'arrêt de chaque rouleau (secondes après le levier, voir ChronologieRouleaux).
var _arrets: Array[float] = []
var _temps_animation: float = 0.0
var _textures_defilement: Array[Texture2D] = []
## Ce qui s'affiche une fois les rouleaux arrêtés : journal, chiffres, sons, secousse (voir _presenter_tour).
var _presentation: Callable
## Vitesse de défilement (pixels par seconde), espace entre deux icônes de la bande, et leur nombre.
const VITESSE_DEFILEMENT := 1100.0
const PAS_BANDE := 60.0
## Vitesse minimale (part de la vitesse normale) juste avant l'arrêt d'un rouleau.
const VITESSE_FIN_RALENTI := 0.12
## Vrai pour tester l'animation même en mode sans fenêtre (par défaut elle y est sautée).
var forcer_animation: bool = false


func _ready() -> void:
	partie = GameState.partie
	# Écran principal du projet : au lancement du jeu, aucune partie n'est en cours (la partie qui existe déjà
	# commence sur un combat, mais ce n'est pas encore une vraie partie) : on va au menu.
	if partie.ecran != Partie.Ecran.COMBAT or not GameState.en_partie:
		GameState.rediriger()
		return
	GameState.demarrer()
	Musique.jouer_pour(partie)
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

	image_ennemi.definir(Images.cadres_rognes(combat.ennemi.images, HAUTEUR_ENNEMI), 0.2)
	_poser_ennemi()
	image_joueur.definir(Images.cadres("knight_m_idle_anim", 72), 0.22)
	barre_pv_ennemi.max_value = combat.pv_max_ennemi
	barre_pv_joueur.max_value = combat.pv_max_joueur
	_rafraichir()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Entrees.LEVIER) and not event.is_echo():
		_tirer()


# --- Le tour : mise, levier, relances, validation -----------------------------

## Levier (bouton ou Espace). Pendant une relance possible, Espace valide le tirage affiché.
func _tirer() -> void:
	if combat == null:
		return
	if animation_en_cours:
		# Espace ou un clic pendant que les rouleaux s'arrêtent : on accélère, sans rien valider de plus.
		_terminer_animation()
		return
	if combat.est_fini():
		return
	if combat.tirage_en_attente:
		_valider()
		return

	var mise := mises[mise_choisie]
	if not combat.tirer(mise):
		return
	bouton_levier.animer()
	_lancer_rouleaux()
	if combat.peut_relancer():
		_attendre_validation()
	else:
		_valider(true)


## Applique le tirage affiché (et la mise) : l'ennemi agit ensuite. `pendant_le_tirage` : on vient de tirer
## et les rouleaux s'arrêtent encore ; le résultat est calculé tout de suite mais ne s'AFFICHE (journal, chiffres,
## sons, secousse) qu'une fois le dernier rouleau arrêté.
func _valider(pendant_le_tirage: bool = false) -> void:
	if not combat.tirage_en_attente:
		return
	if not pendant_le_tirage:
		_terminer_animation()
	choix_du_rouleau = false
	var numero_tour := combat.numero_tour
	var pv_avant := combat.pv_joueur
	var journal_combat := combat.valider()
	var presentation := _presenter_tour.bind(numero_tour, pv_avant, journal_combat)
	if animation_en_cours:
		_presentation = presentation
	else:
		presentation.call()


## Tout ce que le joueur voit et entend d'un tour : grille, journal, sons, chiffres qui s'envolent, secousse,
## flash de l'ennemi, pluie de pièces et bannière sur un jackpot.
func _presenter_tour(numero_tour: int, pv_avant: int, journal_combat: Array[String]) -> void:
	var resultat := combat.resultat_courant
	_dessiner_grille()
	_afficher_tour(numero_tour, resultat, journal_combat)
	for evenement in RetourTour.sons(resultat, pv_avant, combat.pv_joueur):
		Son.jouer(evenement)
	if combat.etat == Combat.Etat.VICTOIRE:
		Son.jouer(&"victoire")
	elif combat.etat == Combat.Etat.DEFAITE:
		Son.jouer(&"defaite")
	_lancer_les_effets(resultat, pv_avant)
	_choisir_mise(0)
	_rafraichir()


func _lancer_les_effets(resultat: ResultatTirage, pv_avant: int) -> void:
	var chiffres := Impacts.chiffres_du_tour(resultat, pv_avant, combat.pv_joueur)
	for i in chiffres.size():
		var lieu: Control = image_ennemi
		if chiffres[i]["lieu"] == "joueur":
			lieu = barre_pv_joueur
		elif chiffres[i]["lieu"] == "or":
			lieu = texte_or
		var centre := lieu.get_global_rect().get_center() - get_global_rect().position
		Impacts.chiffre(self, chiffres[i]["texte"], centre + Vector2(-20 + 70 * (i % 3), 0), chiffres[i]["couleur"])
	var force := Impacts.force_de_secousse(resultat, pv_avant, combat.pv_joueur)
	if force > 0.0:
		Impacts.secouer(self, force)
		if force >= 0.7:
			Impacts.arret_sur_image()
	if resultat.total("degats") > 0:
		Impacts.flash(image_ennemi)
	if resultat.a_un_jackpot():
		Impacts.banniere(self, tr("JACKPOT !"))
		Impacts.pluie_de_pieces(self)
		meuble.definir_ampoules(Ampoules.Mode.JACKPOT)
		get_tree().create_timer(2.5).timeout.connect(_ampoules_au_repos)


## Les rouleaux tournent tous (les symboles défilent), puis s'arrêtent de gauche à droite, chacun avec un
## ralentissement, un petit rebond et un clic un peu plus aigu. Le dernier se fait attendre (suspense, voir
## ChronologieRouleaux). Les rouleaux bloqués ne tournent pas. Pas d'animation en mode sans fenêtre (tests).
func _animer_rouleaux() -> void:
	if DisplayServer.get_name() == "headless" and not forcer_animation:
		return
	animation_en_cours = true
	_temps_animation = 0.0
	_arrets = ChronologieRouleaux.instants_d_arret(combat.grille_courante)
	_textures_defilement = _icones_pour_defiler()
	for i in cases.size():
		var bloque := i in combat.bloques_du_tirage
		_dessiner_case(i, null, false, bloque)
		_en_rotation[i] = not bloque and i < _arrets.size()
		_fenetres[i].visible = _en_rotation[i]
		if _en_rotation[i]:
			cases[i].add_theme_stylebox_override("panel", MeubleMachine.style_papier())
			etiquettes[i].text = ""
			_decalages[i] = randf() * PAS_BANDE
			for icone_bande: TextureRect in meuble.bandes[i]:
				icone_bande.texture = _icone_au_hasard()
			_placer_bande(i)
	meuble.definir_ampoules(Ampoules.Mode.COURSE)


## Les symboles qui défilent : ceux du sac du joueur (sinon ceux du tirage).
func _icones_pour_defiler() -> Array[Texture2D]:
	var symboles: Array[SymbolData] = []
	for groupe in partie.sac.groupes():
		symboles.append(groupe["symbole"])
	if symboles.is_empty():
		symboles.assign(combat.grille_courante.filter(func(s: SymbolData) -> bool: return s != null))
	var textures: Array[Texture2D] = []
	for symbole in symboles:
		var texture := Images.icone(symbole.icone, MeubleMachine.ICONE_ROULEAU)
		if texture != null:
			textures.append(texture)
	return textures


func _icone_au_hasard() -> Texture2D:
	if _textures_defilement.is_empty():
		return null
	return _textures_defilement[randi() % _textures_defilement.size()]


## Fait avancer les rouleaux qui tournent et arrête ceux dont l'heure est venue.
func _process(delta: float) -> void:
	if not animation_en_cours:
		return
	_temps_animation += delta
	var encore := false
	for i in cases.size():
		if not _en_rotation[i]:
			continue
		var reste := _arrets[i] - _temps_animation
		if reste <= 0.0:
			_en_rotation[i] = false
			_fenetres[i].visible = false
			_reveler_rouleau(i)
			continue
		encore = true
		var ralenti := ChronologieRouleaux.duree_ralenti(i, cases.size())
		var facteur := 1.0 if reste >= ralenti else lerpf(VITESSE_FIN_RALENTI, 1.0, reste / ralenti)
		_decalages[i] += VITESSE_DEFILEMENT * facteur * delta
		_placer_bande(i)
	if not encore:
		_terminer_animation(false)


## Place les icônes de la bande du rouleau `index` ; une icône qui ressort en haut change de symbole.
func _placer_bande(index: int) -> void:
	var bande := meuble.bandes[index]
	var longueur := PAS_BANDE * bande.size()
	for j in bande.size():
		var icone_bande: TextureRect = bande[j]
		var y := fposmod(_decalages[index] + PAS_BANDE * j, longueur) - PAS_BANDE
		if y < icone_bande.offset_top:
			icone_bande.texture = _icone_au_hasard()
		icone_bande.offset_top = y
		icone_bande.offset_bottom = y + PAS_BANDE


func _reveler_rouleau(index: int) -> void:
	var grille := combat.grille_courante
	if index >= grille.size():
		return
	_dessiner_case(index, grille[index], index in combat.resultat_courant.cases_en_combo, index in combat.bloques_du_tirage)
	Son.jouer(&"arret_rouleau", 1.0 + 0.07 * index)
	var case_grille := cases[index]
	case_grille.offset_transform_enabled = true
	case_grille.offset_transform_position = Vector2(0, -12)
	if _rebonds.has(index):
		(_rebonds[index] as Tween).kill()
	var rebond := case_grille.create_tween()
	_rebonds[index] = rebond
	rebond.tween_property(case_grille, "offset_transform_position", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _ampoules_au_repos() -> void:
	if is_instance_valid(meuble) and not animation_en_cours:
		meuble.definir_ampoules(Ampoules.Mode.REPOS)


## Finit l'animation tout de suite (tous les rouleaux arrêtés) puis affiche ce qui attendait. Quand on la coupe
## avant la fin (Espace), les rebonds en cours sont coupés aussi ; à la fin naturelle le dernier finit de rebondir.
func _terminer_animation(couper_les_rebonds: bool = true) -> void:
	if not animation_en_cours:
		return
	animation_en_cours = false
	if couper_les_rebonds:
		for rebond: Tween in _rebonds.values():
			rebond.kill()
		_rebonds.clear()
	_ampoules_au_repos()
	for i in cases.size():
		_en_rotation[i] = false
		_fenetres[i].visible = false
		cases[i].offset_transform_position = Vector2.ZERO
	_dessiner_grille()
	if _presentation.is_valid():
		var presentation := _presentation
		_presentation = Callable()
		presentation.call()


## Un tirage (ou une relance) commence : le bruit des rouleaux, la grille, puis les rouleaux qui défilent.
func _lancer_rouleaux() -> void:
	Son.jouer(&"rouleaux")
	_dessiner_grille()
	_animer_rouleaux()


## Les rouleaux sont affichés mais pas encore appliqués : on peut relancer ou valider. Pendant qu'ils s'arrêtent,
## rien n'est annoncé (ni combo, ni boutons) : c'est fait une fois le dernier rouleau arrêté.
func _attendre_validation() -> void:
	if animation_en_cours:
		_presentation = _attendre_validation
		return
	_afficher_apercu()
	_rafraichir()


## Dé pipé : relance tous les rouleaux.
func _relancer_tout() -> void:
	_terminer_animation()
	if combat.relancer_tout():
		choix_du_rouleau = false
		_lancer_rouleaux()
		_attendre_validation()


## Cinquième as, étape 1 : on active le choix du rouleau à garder (un second clic annule).
func _commencer_cinquieme_as() -> void:
	_terminer_animation()  # les rouleaux s'arrêtent d'abord : on choisit parmi des symboles visibles
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
	_terminer_animation()
	if combat.relancer_en_gardant(index):
		choix_du_rouleau = false
		_lancer_rouleaux()
		_attendre_validation()


func _choisir_mise(index: int) -> void:
	if animation_en_cours:
		# Le tour est déjà calculé : la mise ne se change pas pendant que les rouleaux s'arrêtent.
		if boutons_mise.size() > mise_choisie:
			boutons_mise[mise_choisie].button_pressed = true
		return
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

## Met à jour tout ce qui dépend de l'état du combat.
func _rafraichir() -> void:
	if partie.est_combat_de_boss():
		texte_etage.text = tr("Étage %d — BOSS") % partie.etage
		texte_etage.add_theme_color_override("font_color", COULEUR_BOSS)
	else:
		texte_etage.text = tr("Étage %d — Combat %d / %d") % [partie.etage, partie.pas, Donjon.NB_PAS] if not partie.en_salle_bonus \
				else tr("Étage %d — Salle bonus") % partie.etage

	texte_nom_ennemi.text = tr(combat.ennemi.nom)
	barre_pv_ennemi.value = combat.pv_ennemi
	texte_pv_ennemi.text = tr("PV %d / %d   Armure %d") % [
		combat.pv_ennemi, combat.pv_max_ennemi, combat.armure_ennemi]

	if combat.est_fini():
		texte_intention.text = ""
	else:
		texte_intention.text = Intentions.decrire(combat.intention_affichee())
	texte_passif.text = _texte_passif()
	texte_passif.visible = not texte_passif.text.is_empty()
	bulle_intention.visible = not combat.est_fini()

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
	bouton_de_pipe.visible = partie.a_relique(Reliques.DE_PIPE) or partie.relances_de_partie > 0
	bouton_de_pipe.disabled = combat.relances_toutes_les_cases() <= 0
	bouton_cinquieme_as.visible = partie.a_relique(Reliques.CINQUIEME_AS)
	bouton_cinquieme_as.disabled = combat.relances_cinquieme_as <= 0
	bouton_cinquieme_as.text = tr("Annuler : garder quel rouleau ?") if choix_du_rouleau \
			else tr("Cinquième as : garder un rouleau")
	texte_aide.visible = not ligne_relance.visible and not bouton_continuer.visible
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
	style.set_corner_radius_all(6)
	var etiquette := etiquettes[index]

	icones[index].texture = Images.icone(symbole.icone, MeubleMachine.ICONE_ROULEAU) if symbole != null and not bloquee else null
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
		etiquette.add_theme_color_override("font_color", Cartes.couleur_texte(symbole.couleur))
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
	texte.append_array(_lignes_combos(resultat))
	texte.append(_texte_des_totaux(resultat))
	texte.append("")
	if choix_du_rouleau:
		texte.append("[b]%s[/b]" % tr("Clique sur le rouleau à garder : les autres seront relancés."))
	else:
		texte.append(tr("Valide ce tirage (Espace) ou relance avec tes reliques."))
	texte_journal.text = "\n".join(texte)


## Les lignes « COMBO ! » / « JACKPOT !!! » d'un tirage, en or : une par combo.
func _lignes_combos(resultat: ResultatTirage) -> PackedStringArray:
	var lignes := PackedStringArray()
	for combo in resultat.combos:
		var titre := tr("JACKPOT !!!") if combo.est_jackpot() else tr("COMBO !")
		lignes.append("[color=#%s][b]%s[/b] %s[/color]" % [COULEUR_COMBO.to_html(false), titre,
				tr("%d × %s, effet ×%d") % [combo.longueur, tr(combo.symbole.nom), combo.multiplicateur]])
	return lignes


## Les effets du tirage, ligne par ligne, ou « aucun effet ».
func _texte_des_totaux(resultat: ResultatTirage) -> String:
	return tr("aucun effet") if resultat.totaux.is_empty() else Effets.decrire(resultat.totaux, "\n")


## Écrit ce qui s'est passé pendant le tour : combos, effets du tirage, puis le combat.
func _afficher_tour(numero_tour: int, resultat: ResultatTirage, journal_combat: Array[String]) -> void:
	var texte := PackedStringArray()
	texte.append("[b]%s[/b]" % (tr("Tour %d") % numero_tour))

	texte.append_array(_lignes_combos(resultat))

	texte.append("")
	texte.append("[b]%s[/b]" % tr("Tirage"))
	texte.append(_texte_des_totaux(resultat))

	texte.append("")
	texte.append("[b]%s[/b]" % tr("Combat"))
	for ligne in journal_combat:
		texte.append(ligne)

	texte_journal.text = "\n".join(texte)


# --- Construction de l'interface (en code) ---------------------------------
#
# De l'arrière vers l'avant : le décor, l'ennemi en grand (nom, vie et intention flottent autour de lui), puis
# l'interface : à gauche le joueur et le journal, au centre en bas le meuble de la machine, à droite son levier.

func _construire_interface() -> void:
	Cartes.ajouter_fond(self, COULEUR_FOND)
	_construire_scene_ennemi()

	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marge.add_theme_constant_override("margin_left", MARGE_ECRAN)
	marge.add_theme_constant_override("margin_right", MARGE_ECRAN)
	marge.add_theme_constant_override("margin_top", 14)
	marge.add_theme_constant_override("margin_bottom", 18)
	add_child(marge)

	var pile := VBoxContainer.new()
	pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pile.add_theme_constant_override("separation", 6)
	marge.add_child(pile)
	_construire_bandeau(pile)

	var corps := HBoxContainer.new()
	corps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corps.add_theme_constant_override("separation", SEPARATION_CORPS)
	pile.add_child(corps)
	_construire_colonne_gauche(corps)
	_construire_colonne_machine(corps)


## L'ennemi, en grand derrière la machine : un halo de lumière, son nom et sa vie au-dessus, son intention dans une
## bulle à côté, le texte de fin de combat par-dessus.
func _construire_scene_ennemi() -> void:
	var scene_ennemi := Control.new()
	scene_ennemi.name = "SceneEnnemi"
	scene_ennemi.set_anchors_preset(Control.PRESET_FULL_RECT)
	scene_ennemi.offset_left = DECALAGE_SCENE_ENNEMI
	scene_ennemi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scene_ennemi)

	var halo := Decor.halo(Color(combat.ennemi.couleur.lightened(0.25), 0.55))
	halo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	halo.offset_left = -320
	halo.offset_right = 320
	halo.offset_top = 20
	halo.offset_bottom = 430
	scene_ennemi.add_child(halo)

	var panneau_ennemi := VBoxContainer.new()
	panneau_ennemi.name = "Ennemi"
	panneau_ennemi.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panneau_ennemi.offset_left = -170
	panneau_ennemi.offset_right = 170
	panneau_ennemi.offset_top = 48
	panneau_ennemi.add_theme_constant_override("separation", 2)
	panneau_ennemi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_ennemi.add_child(panneau_ennemi)
	texte_nom_ennemi = _etiquette_ennemi(panneau_ennemi, 28)
	barre_pv_ennemi = _creer_barre_ennemi()
	panneau_ennemi.add_child(barre_pv_ennemi)
	texte_pv_ennemi = _etiquette_ennemi(panneau_ennemi, 17)
	image_ennemi = ImageAnimee.new()
	scene_ennemi.add_child(image_ennemi)

	# La bulle d'intention, à droite de l'ennemi.
	bulle_intention = PanelContainer.new()
	bulle_intention.name = "BulleIntention"
	bulle_intention.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bulle_intention.offset_left = 110
	bulle_intention.offset_right = 350
	bulle_intention.offset_top = 140
	bulle_intention.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bulle_intention.add_theme_stylebox_override("panel", _style_bulle())
	scene_ennemi.add_child(bulle_intention)
	var texte_bulle := VBoxContainer.new()
	texte_bulle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texte_bulle.add_theme_constant_override("separation", 2)
	bulle_intention.add_child(texte_bulle)
	var titre_intention := _etiquette_ennemi(texte_bulle, 14, false)
	titre_intention.text = tr("Intention")
	titre_intention.add_theme_color_override("font_color", Habillage.COULEUR_OR)
	texte_intention = _etiquette_ennemi(texte_bulle, 22, false)
	texte_intention.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte_passif = _etiquette_ennemi(texte_bulle, 15, false)
	texte_passif.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte_passif.add_theme_color_override("font_color", COULEUR_COMBO)

	texte_fin = Label.new()
	texte_fin.name = "TexteFin"
	texte_fin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	texte_fin.offset_top = 190
	texte_fin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texte_fin.add_theme_font_size_override("font_size", 38)
	Habillage.contour(texte_fin, Color(0, 0, 0, 0.9), 8)
	texte_fin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_ennemi.add_child(texte_fin)


## Pose le sprite de l'ennemi au centre de la scène, son bas sur la ligne de sol.
func _poser_ennemi() -> void:
	var taille := image_ennemi.custom_minimum_size
	image_ennemi.set_anchors_preset(Control.PRESET_CENTER_TOP)
	image_ennemi.offset_left = -taille.x / 2.0
	image_ennemi.offset_right = taille.x / 2.0
	image_ennemi.offset_top = SOL_ENNEMI - taille.y
	image_ennemi.offset_bottom = SOL_ENNEMI


## En haut : l'étage et la salle (de la place est laissée à droite au bouton plein écran).
func _construire_bandeau(parent: Control) -> void:
	var bandeau := HBoxContainer.new()
	bandeau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bandeau.add_theme_constant_override("separation", 12)
	parent.add_child(bandeau)

	texte_etage = Label.new()
	texte_etage.add_theme_font_size_override("font_size", 26)
	Habillage.contour(texte_etage, Color(0, 0, 0, 0.8), 5)
	bandeau.add_child(texte_etage)

	var place_plein_ecran := Control.new()
	place_plein_ecran.custom_minimum_size = Vector2(PleinEcran.TAILLE_BOUTON + PleinEcran.MARGE - 24, 0)
	place_plein_ecran.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bandeau.add_child(place_plein_ecran)


## À gauche : le joueur (vie, armure, or), puis le journal du dernier tour.
func _construire_colonne_gauche(parent: Control) -> void:
	var colonne := VBoxContainer.new()
	colonne.custom_minimum_size = Vector2(LARGEUR_COLONNE_GAUCHE, 0)
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_theme_constant_override("separation", 8)
	parent.add_child(colonne)

	var panneau_joueur := PanelContainer.new()
	panneau_joueur.add_theme_stylebox_override("panel", _style_panneau())
	colonne.add_child(panneau_joueur)
	var ligne_joueur := HBoxContainer.new()
	ligne_joueur.add_theme_constant_override("separation", 10)
	panneau_joueur.add_child(ligne_joueur)
	image_joueur = ImageAnimee.new()
	image_joueur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne_joueur.add_child(image_joueur)
	var bloc_joueur := VBoxContainer.new()
	bloc_joueur.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bloc_joueur.add_theme_constant_override("separation", 3)
	ligne_joueur.add_child(bloc_joueur)
	texte_pv_joueur = Label.new()
	texte_pv_joueur.add_theme_font_size_override("font_size", 16)
	texte_pv_joueur.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bloc_joueur.add_child(texte_pv_joueur)
	barre_pv_joueur = _creer_barre()
	bloc_joueur.add_child(barre_pv_joueur)
	texte_or = Label.new()
	texte_or.add_theme_font_size_override("font_size", 16)
	texte_or.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bloc_joueur.add_child(texte_or)

	_construire_rangee_reliques(colonne)

	var panneau_journal := PanelContainer.new()
	panneau_journal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panneau_journal.add_theme_stylebox_override("panel", _style_panneau())
	colonne.add_child(panneau_journal)
	var boite_journal := VBoxContainer.new()
	boite_journal.add_theme_constant_override("separation", 4)
	panneau_journal.add_child(boite_journal)
	var titre := Label.new()
	titre.text = tr("Dernier tour")
	titre.add_theme_font_size_override("font_size", 18)
	titre.add_theme_color_override("font_color", COULEUR_COMBO)
	boite_journal.add_child(titre)
	texte_journal = RichTextLabel.new()
	texte_journal.bbcode_enabled = true
	texte_journal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texte_journal.add_theme_font_size_override("normal_font_size", 15)
	texte_journal.add_theme_font_size_override("bold_font_size", 15)
	boite_journal.add_child(texte_journal)
	texte_graine = Label.new()
	texte_graine.add_theme_font_size_override("font_size", 12)
	texte_graine.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	texte_graine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boite_journal.add_child(texte_graine)
	_construire_boutons_de_test(boite_journal)


## Au centre en bas : le meuble de la machine ; à droite, son levier.
func _construire_colonne_machine(parent: Control) -> void:
	var colonne := VBoxContainer.new()
	colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(colonne)
	var vide := Control.new()  # pousse la machine vers le bas : l'ennemi reste visible au-dessus
	vide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(vide)

	var ligne := HBoxContainer.new()
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_theme_constant_override("separation", 6)
	colonne.add_child(ligne)

	meuble = MeubleMachine.new()
	meuble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(meuble)
	meuble.construire(machine.colonnes, machine.nb_cases(), _sur_case)
	cases = meuble.cases
	etiquettes = meuble.etiquettes
	icones = meuble.icones
	_fenetres = meuble.fenetres
	_decalages.resize(machine.nb_cases())
	_en_rotation.resize(machine.nb_cases())

	var colonne_levier := VBoxContainer.new()
	colonne_levier.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	colonne_levier.add_theme_constant_override("separation", 0)
	ligne.add_child(colonne_levier)
	bouton_levier = LevierMachine.new()
	bouton_levier.tooltip_text = tr("Tirer le levier (Espace)")
	bouton_levier.pressed.connect(_tirer)
	colonne_levier.add_child(bouton_levier)
	var aide := Label.new()
	aide.text = tr("Espace")
	aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aide.add_theme_font_size_override("font_size", 14)
	aide.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	colonne_levier.add_child(aide)

	_construire_panneau_mise(meuble.zone_mises)
	_construire_actions(meuble.zone_actions)


## Sous les mises : « Continuer » en fin de combat, ou valider / relancer un tirage en attente.
func _construire_actions(parent: Control) -> void:
	parent.custom_minimum_size = Vector2(0, 40)  # la place est réservée : le meuble ne change pas de taille

	texte_aide = Label.new()
	texte_aide.text = tr("Tire le levier pour lancer la machine.")
	texte_aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texte_aide.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texte_aide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texte_aide.add_theme_font_size_override("font_size", 16)
	texte_aide.add_theme_color_override("font_color", Color(Habillage.COULEUR_OR, 0.75))
	parent.add_child(texte_aide)

	bouton_continuer = Button.new()
	bouton_continuer.text = tr("Continuer")
	bouton_continuer.custom_minimum_size = Vector2(0, 40)
	bouton_continuer.focus_mode = Control.FOCUS_NONE
	bouton_continuer.add_theme_font_size_override("font_size", 22)
	Cartes.habiller_bouton(bouton_continuer, Color("e0a82e"))
	bouton_continuer.pressed.connect(_continuer)
	parent.add_child(bouton_continuer)

	ligne_relance = HFlowContainer.new()
	ligne_relance.alignment = FlowContainer.ALIGNMENT_CENTER
	ligne_relance.add_theme_constant_override("h_separation", 6)
	ligne_relance.add_theme_constant_override("v_separation", 4)
	parent.add_child(ligne_relance)
	bouton_valider = _creer_bouton_relance(tr("Valider (Espace)"), _valider)
	bouton_de_pipe = _creer_bouton_relance(tr("Relance gratuite : tout relancer"), _relancer_tout)
	bouton_cinquieme_as = _creer_bouton_relance(tr("Cinquième as : garder un rouleau"), _commencer_cinquieme_as)
	ligne_relance.visible = false


func _creer_bouton_relance(texte: String, action: Callable) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.custom_minimum_size = Vector2(0, 40)
	bouton.focus_mode = Control.FOCUS_NONE
	bouton.add_theme_font_size_override("font_size", 15)
	Cartes.habiller_bouton_mise(bouton)
	bouton.pressed.connect(action)
	ligne_relance.add_child(bouton)
	return bouton


## Les boutons de test (seulement quand on lance depuis l'éditeur, pas dans le jeu exporté).
func _construire_boutons_de_test(parent: Control) -> void:
	if not OS.is_debug_build():
		return
	var rangee_test := HFlowContainer.new()
	rangee_test.add_theme_constant_override("h_separation", 6)
	rangee_test.add_theme_constant_override("v_separation", 4)
	parent.add_child(rangee_test)

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
	titre.text = tr("Mise")
	titre.add_theme_font_size_override("font_size", 17)
	titre.add_theme_color_override("font_color", Habillage.COULEUR_OR)
	parent.add_child(titre)

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
		bouton.custom_minimum_size = Vector2(0, 32)
		Cartes.habiller_bouton_mise(bouton)
		bouton.pressed.connect(_choisir_mise.bind(i))
		match mises[i].type:
			Mise.Type.OR:
				bouton.tooltip_text = tr("Si le tirage a un combo (hors crânes), tu reçois %d fois ta mise. Sinon elle est perdue.") % combat.gain_mise_or
			Mise.Type.QUITTE_OU_DOUBLE:
				bouton.tooltip_text = tr("Aucun crâne visible : effets positifs doublés. Un crâne visible : tu perds %d PV.") % Mise.PV_QUITTE_OU_DOUBLE
			_:
				bouton.tooltip_text = tr("Pas de risque, pas de gain en plus.")
		parent.add_child(bouton)
		boutons_mise.append(bouton)
	boutons_mise[0].button_pressed = true


## Les reliques possédées (des pastilles sous le joueur), avec une bulle d'aide qui dit ce que chacune fait.
func _construire_rangee_reliques(parent: Control) -> void:
	rangee_reliques = HFlowContainer.new()
	rangee_reliques.add_theme_constant_override("h_separation", 5)
	rangee_reliques.add_theme_constant_override("v_separation", 4)
	parent.add_child(rangee_reliques)

	for relique in partie.reliques:
		var puce := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(8)
		style.bg_color = relique.couleur
		style.content_margin_left = 7
		style.content_margin_right = 7
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		puce.add_theme_stylebox_override("panel", style)
		puce.tooltip_text = "%s\n%s" % [tr(relique.nom), tr(relique.description)]
		var nom := Label.new()
		nom.text = tr(relique.nom)
		nom.add_theme_font_size_override("font_size", 14)
		nom.add_theme_color_override("font_color", Cartes.couleur_texte(relique.couleur))
		puce.add_child(nom)
		rangee_reliques.add_child(puce)


func _creer_barre() -> ProgressBar:
	var barre := ProgressBar.new()
	barre.show_percentage = false
	barre.custom_minimum_size = Vector2(0, 16)
	return barre


## La jauge de vie de l'ennemi : fine, rouge sur fond sombre, sans texte (les PV sont écrits dessous).
func _creer_barre_ennemi() -> ProgressBar:
	var barre := ProgressBar.new()
	barre.show_percentage = false
	barre.custom_minimum_size = Vector2(260, 14)
	barre.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0, 0, 0, 0.6)
	fond.set_corner_radius_all(7)
	fond.border_color = Color(1, 1, 1, 0.5)
	fond.set_border_width_all(2)
	var remplissage := StyleBoxFlat.new()
	remplissage.bg_color = Color("d63a3a")
	remplissage.set_corner_radius_all(7)
	barre.add_theme_stylebox_override("background", fond)
	barre.add_theme_stylebox_override("fill", remplissage)
	return barre


## Une étiquette du nom, des PV ou de l'intention de l'ennemi : lisible sur n'importe quel fond (contour sombre).
func _etiquette_ennemi(parent: Control, taille: int, centree: bool = true) -> Label:
	var etiquette := Label.new()
	etiquette.add_theme_font_size_override("font_size", taille)
	Habillage.contour(etiquette, Color(0, 0, 0, 0.9), maxi(3, taille / 6))
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centree:
		etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(etiquette)
	return etiquette


## Un panneau sombre translucide (le joueur, le journal) : lisible par-dessus le décor.
func _style_panneau() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.08, 0.82)
	style.border_color = Habillage.COULEUR_OR_SOMBRE
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	return style


func _style_bulle() -> StyleBoxFlat:
	var style := _style_panneau()
	style.bg_color = Color(0.08, 0.05, 0.08, 0.88)
	style.border_color = Habillage.COULEUR_OR
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	return style
