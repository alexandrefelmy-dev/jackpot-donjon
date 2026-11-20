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
## Côté (en pixels) de l'icône d'un rouleau.
const ICONE_ROULEAU := 48
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
var image_ennemi: ImageAnimee
var image_joueur: ImageAnimee
## L'icône de chaque rouleau (au-dessus du nom du symbole).
var icones: Array[TextureRect] = []
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

## Les rouleaux s'arrêtent un par un (affichage seulement : la logique du tour est déjà calculée).
var animation_en_cours: bool = false
## Rouleaux qui défilent : par case, une fenêtre qui masque ce qui dépasse et une bande d'icônes qui glisse vers le bas.
var _fenetres: Array[Control] = []
var _bandes: Array[Array] = []
var _decalages: Array[float] = []
var _en_rotation: Array[bool] = []
## Instant d'arrêt de chaque rouleau (secondes après le levier, voir ChronologieRouleaux).
var _arrets: Array[float] = []
var _temps_animation: float = 0.0
var _textures_defilement: Array[Texture2D] = []
## Ce qui s'affiche une fois les rouleaux arrêtés : journal, chiffres, sons, secousse (voir _presenter_tour).
var _presentation: Callable
## Vitesse de défilement (pixels par seconde), espace entre deux icônes de la bande, et leur nombre.
const VITESSE_DEFILEMENT := 1100.0
const PAS_BANDE := 60.0
const NB_ICONES_BANDE := 4
## Vitesse minimale (part de la vitesse normale) juste avant l'arrêt d'un rouleau.
const VITESSE_FIN_RALENTI := 0.12
## Vrai pour tester l'animation même en mode sans fenêtre (par défaut elle y est sautée).
var forcer_animation: bool = false


func _ready() -> void:
	partie = GameState.partie
	if partie.ecran != Partie.Ecran.COMBAT:
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

	var fond := StyleBoxFlat.new()
	fond.set_corner_radius_all(10)
	fond.bg_color = combat.ennemi.couleur
	panneau_ennemi.add_theme_stylebox_override("panel", fond)
	var couleur_texte := _couleur_texte(combat.ennemi.couleur)
	for etiquette in etiquettes_ennemi:
		etiquette.add_theme_color_override("font_color", couleur_texte)

	image_ennemi.definir(Images.cadres(combat.ennemi.images, 96), 0.2)
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
	Son.jouer(&"rouleaux")
	_dessiner_grille()
	_animer_rouleaux()
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
		var lieu: Control = panneau_ennemi
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
		Impacts.flash(panneau_ennemi)
	if resultat.a_un_jackpot():
		Impacts.banniere(self, tr("JACKPOT !"))
		Impacts.pluie_de_pieces(self)


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
			etiquettes[i].text = ""
			_decalages[i] = randf() * PAS_BANDE
			for icone_bande: TextureRect in _bandes[i]:
				icone_bande.texture = _icone_au_hasard()
			_placer_bande(i)


## Les symboles qui défilent : ceux du sac du joueur (sinon ceux du tirage).
func _icones_pour_defiler() -> Array[Texture2D]:
	var symboles: Array[SymbolData] = []
	for groupe in partie.sac.groupes():
		symboles.append(groupe["symbole"])
	if symboles.is_empty():
		symboles.assign(combat.grille_courante.filter(func(s: SymbolData) -> bool: return s != null))
	var textures: Array[Texture2D] = []
	for symbole in symboles:
		var texture := Images.icone(symbole.icone, ICONE_ROULEAU)
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
		_terminer_animation()


## Place les icônes de la bande du rouleau `index` ; une icône qui ressort en haut change de symbole.
func _placer_bande(index: int) -> void:
	var bande := _bandes[index]
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
	var rebond := case_grille.create_tween()
	rebond.tween_property(case_grille, "offset_transform_position", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Finit l'animation tout de suite (tous les rouleaux arrêtés) puis affiche ce qui attendait.
func _terminer_animation() -> void:
	if not animation_en_cours:
		return
	animation_en_cours = false
	for i in cases.size():
		_en_rotation[i] = false
		_fenetres[i].visible = false
		cases[i].offset_transform_position = Vector2.ZERO
	_dessiner_grille()
	if _presentation.is_valid():
		var presentation := _presentation
		_presentation = Callable()
		presentation.call()


## Les rouleaux sont affichés mais pas encore appliqués : on peut relancer ou valider.
func _attendre_validation() -> void:
	_afficher_apercu()
	_rafraichir()


## Dé pipé : relance tous les rouleaux.
func _relancer_tout() -> void:
	_terminer_animation()
	if combat.relancer_tout():
		choix_du_rouleau = false
		Son.jouer(&"rouleaux")
		_dessiner_grille()
		_animer_rouleaux()
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
	_terminer_animation()
	if combat.relancer_en_gardant(index):
		choix_du_rouleau = false
		Son.jouer(&"rouleaux")
		_dessiner_grille()
		_animer_rouleaux()
		_afficher_apercu()
		_rafraichir()


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
		combat.pv_ennemi, combat.pv_max_ennemi, combat.armure_ennemi]

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
	bouton_de_pipe.visible = partie.a_relique(Reliques.DE_PIPE) or partie.relances_de_partie > 0
	bouton_de_pipe.disabled = combat.relances_toutes_les_cases() <= 0
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

	icones[index].texture = Images.icone(symbole.icone, ICONE_ROULEAU) if symbole != null and not bloquee else null
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
	Cartes.ajouter_fond(self, COULEUR_FOND)

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
	boite_ennemi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ligne_ennemi := HBoxContainer.new()
	ligne_ennemi.add_theme_constant_override("separation", 12)
	marge_ennemi.add_child(ligne_ennemi)
	ligne_ennemi.add_child(boite_ennemi)
	image_ennemi = ImageAnimee.new()
	ligne_ennemi.add_child(image_ennemi)

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
		var contenu := VBoxContainer.new()
		contenu.alignment = BoxContainer.ALIGNMENT_CENTER
		contenu.add_theme_constant_override("separation", 0)
		contenu.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icone := TextureRect.new()
		icone.custom_minimum_size = Vector2(ICONE_ROULEAU, ICONE_ROULEAU)
		icone.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenu.add_child(icone)
		etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenu.add_child(etiquette)
		case_grille.add_child(contenu)
		# Le rouleau qui tourne : une fenêtre qui masque ce qui dépasse, et des icônes qui glissent dedans.
		var fenetre := Control.new()
		fenetre.clip_contents = true
		fenetre.visible = false
		fenetre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bande: Array = []
		for j in NB_ICONES_BANDE:
			var icone_bande := TextureRect.new()
			icone_bande.set_anchors_preset(Control.PRESET_TOP_WIDE)
			icone_bande.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			icone_bande.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icone_bande.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icone_bande.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icone_bande.modulate = Color(1, 1, 1, 0.8)
			fenetre.add_child(icone_bande)
			bande.append(icone_bande)
		case_grille.add_child(fenetre)
		_fenetres.append(fenetre)
		_bandes.append(bande)
		_decalages.append(0.0)
		_en_rotation.append(false)
		grille.add_child(case_grille)
		cases.append(case_grille)
		etiquettes.append(etiquette)
		icones.append(icone)

	bouton_levier = Button.new()
	bouton_levier.text = tr("Tirer le levier (Espace)")
	bouton_levier.custom_minimum_size = Vector2(0, 52)
	bouton_levier.focus_mode = Control.FOCUS_NONE  # sinon Espace déclencherait 2 tirages
	bouton_levier.pressed.connect(_tirer)
	colonne.add_child(bouton_levier)

	# Le joueur : PV, armure, or, sac.
	var ligne_joueur := HBoxContainer.new()
	ligne_joueur.add_theme_constant_override("separation", 12)
	colonne.add_child(ligne_joueur)
	var bloc_joueur := VBoxContainer.new()
	bloc_joueur.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bloc_joueur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne_joueur.add_child(bloc_joueur)
	barre_pv_joueur = _creer_barre()
	bloc_joueur.add_child(barre_pv_joueur)
	texte_pv_joueur = Label.new()
	texte_pv_joueur.add_theme_font_size_override("font_size", 20)
	bloc_joueur.add_child(texte_pv_joueur)
	texte_or = Label.new()
	texte_or.add_theme_font_size_override("font_size", 18)
	bloc_joueur.add_child(texte_or)
	image_joueur = ImageAnimee.new()
	ligne_joueur.add_child(image_joueur)

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
	bouton_de_pipe = _creer_bouton_relance(tr("Relance gratuite : tout relancer"), _relancer_tout)
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
				bouton.tooltip_text = tr("Si le tirage a un combo (hors crânes), tu reçois %d fois ta mise. Sinon elle est perdue.") % combat.gain_mise_or
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
