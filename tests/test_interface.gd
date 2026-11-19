extends SceneTree
## Vérifie que les boutons importants des écrans tiennent dans la fenêtre du jeu
## (sinon on ne peut pas les cliquer : c'est arrivé avec « Continuer » en v0.3).
## À lancer en ligne de commande :
## godot --headless --path . -s res://tests/test_interface.gd

var echecs := 0
var hauteur_fenetre: float
var largeur_fenetre: float


func _initialize() -> void:
	# Une image d'attente : la fenêtre de test doit être prête avant de mesurer.
	await process_frame
	# La fenêtre du mode test est minuscule : on lui donne la taille de la fenêtre du jeu,
	# sinon les écrans centrés seraient décalés.
	hauteur_fenetre = float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	largeur_fenetre = float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	root.size = Vector2i(int(largeur_fenetre), int(hauteur_fenetre))
	await process_frame
	print("hauteur de la fenêtre du jeu : %d" % hauteur_fenetre)
	pass
	var epee := load("res://data/symbols/epee.tres") as SymbolData
	var jackpot: Array[SymbolData] = [epee, epee, epee, epee, epee]

	# Combat gagné (bouton Continuer), contre un ennemi normal puis contre le boss.
	for boss in [false, true]:
		GameState.nouvelle_partie()
		if boss:
			GameState.partie.aller_au_boss()
		GameState.aller_a(GameState.SCENE_COMBAT)
		await _attendre()
		var combat_ecran: Control = current_scene
		var texte := "boss" if boss else "ennemi normal"

		# En cours de combat : le levier est visible.
		verifier_dans_la_fenetre(combat_ecran.bouton_levier, "bouton Tirer le levier (%s)" % texte)
		verifier_dans_la_fenetre(combat_ecran.bouton_debug, "bouton de test du combat (%s)" % texte)

		while not combat_ecran.combat.est_fini():
			combat_ecran.combat.jouer_tour(combat_ecran.machine.resoudre(jackpot))
		combat_ecran._rafraichir()
		await _attendre()
		verifier(combat_ecran.bouton_continuer.visible, "le bouton Continuer s'affiche après la victoire (%s)" % texte)
		verifier_dans_la_fenetre(combat_ecran.bouton_continuer, "bouton Continuer après victoire (%s)" % texte)
		verifier_dans_la_fenetre(combat_ecran.texte_fin, "texte de victoire (%s)" % texte)

	# Bouton de test « Aller au boss » : un clic mène au combat du boss (et on peut le jouer).
	GameState.nouvelle_partie()
	GameState.aller_a(GameState.SCENE_COMBAT)
	await _attendre()
	var avant_boss: Control = current_scene
	verifier(not avant_boss.partie.est_combat_de_boss() and not avant_boss.bouton_debug.disabled,
			"avant le clic, le bouton de test est actif et ce n'est pas le boss")
	avant_boss.bouton_debug.pressed.emit()
	await _attendre()
	var au_boss: Control = current_scene
	verifier(au_boss.partie.est_combat_de_boss() and au_boss.combat.ennemi.id == &"rat_croupier",
			"le clic sur le bouton de test mène au combat du boss")
	verifier(au_boss.bouton_debug.disabled, "au boss, le bouton de test est désactivé")
	verifier(au_boss.texte_etage.text.contains("BOSS"), "l'en-tête annonce le boss : %s" % au_boss.texte_etage.text)

	# Mises et reliques sur l'écran de combat : sans relique d'abord.
	GameState.nouvelle_partie()
	GameState.partie.or_total = 50
	GameState.aller_a(GameState.SCENE_COMBAT)
	await _attendre()
	var sans_relique: Control = current_scene
	verifier(sans_relique.boutons_mise.size() == 5, "5 boutons de mise : pas de mise, 5, 10, 20 or, quitte ou double")
	for bouton in sans_relique.boutons_mise:
		verifier_dans_la_fenetre(bouton, "bouton de mise « %s »" % bouton.text)
	verifier_dans_la_fenetre(sans_relique.rangee_reliques, "rangée de reliques (vide)")
	verifier(not sans_relique.ligne_relance.visible, "sans relance possible, pas de bouton Valider")
	verifier_dans_la_fenetre(sans_relique.bouton_debug_relique, "bouton de test des reliques")

	# Clic sur une mise puis sur le levier : sans relance, le tour se joue aussitôt.
	sans_relique.boutons_mise[2].pressed.emit()
	verifier(sans_relique.mise_choisie == 2, "clic sur « 10 or » : mise choisie")
	sans_relique._tirer()
	verifier(not sans_relique.combat.tirage_en_attente and sans_relique.combat.numero_tour == 2 or sans_relique.combat.est_fini(),
			"sans relance, le levier joue tout le tour")
	verifier(sans_relique.texte_journal.text.contains("Mise de 10 or"), "le journal parle de la mise de 10 or")
	verifier(sans_relique.mise_choisie == 0, "après le tour, la mise revient à « pas de mise »")

	# Quitte ou double impossible à 5 PV ou moins ; mise d'or impossible sans assez d'or.
	GameState.partie.pv = 5
	GameState.partie.or_total = 4
	GameState.aller_a(GameState.SCENE_COMBAT)
	await _attendre()
	var fragile: Control = current_scene
	verifier(fragile.boutons_mise[4].disabled, "quitte ou double grisé à 5 PV")
	verifier(fragile.boutons_mise[1].disabled, "mise de 5 or grisée avec 4 or")
	verifier(not fragile.boutons_mise[0].disabled, "« pas de mise » reste possible")

	# Toutes les reliques : 6 rouleaux, relances, reliques affichées.
	GameState.nouvelle_partie()
	GameState.partie.or_total = 50
	for relique in Reliques.toutes():
		GameState.partie.ajouter_relique(relique)
	GameState.aller_a(GameState.SCENE_COMBAT)
	await _attendre()
	var pleine: Control = current_scene
	verifier(pleine.cases.size() == 6, "6 rouleaux avec le Sixième rouleau")
	for case_rouleau in pleine.cases:
		verifier_dans_la_fenetre(case_rouleau, "rouleau (6 rouleaux)")
	verifier(pleine.rangee_reliques.get_child_count() == 9, "9 reliques affichées : %d" % pleine.rangee_reliques.get_child_count())
	verifier_dans_la_fenetre(pleine.rangee_reliques, "rangée de 9 reliques")
	verifier_dans_la_fenetre(pleine.bouton_levier, "bouton Tirer le levier (6 rouleaux)")
	for bouton in pleine.boutons_mise:
		verifier_dans_la_fenetre(bouton, "bouton de mise (9 reliques)")

	# Tirage en attente : Valider, Dé pipé et Cinquième as sont visibles et tiennent dans la fenêtre.
	pleine.boutons_mise[1].pressed.emit()
	pleine._tirer()
	await _attendre()
	verifier(pleine.combat.tirage_en_attente and pleine.ligne_relance.visible, "avec des relances, le tirage attend la validation")
	verifier(pleine.bouton_levier.disabled and not pleine.bouton_continuer.visible, "levier grisé, « Continuer » caché pendant l'attente")
	for bouton in [pleine.bouton_valider, pleine.bouton_de_pipe, pleine.bouton_cinquieme_as]:
		verifier_dans_la_fenetre(bouton, "bouton « %s »" % bouton.text)
	verifier(not pleine.boutons_mise[1].disabled and pleine.boutons_mise[2].disabled and pleine.boutons_mise[0].disabled,
			"pendant l'attente, seule la mise choisie reste affichée en clair")
	var relances_avant: int = pleine.combat.relances_gratuites

	# Clic sur « Dé pipé ».
	pleine.bouton_de_pipe.pressed.emit()
	verifier(pleine.combat.relances_gratuites == relances_avant - 1 and pleine.bouton_de_pipe.disabled,
			"clic sur Dé pipé : relance consommée, bouton grisé")
	verifier(pleine.combat.tirage_en_attente, "après la relance, on attend toujours la validation")

	# Clic sur « Cinquième as » puis sur un vrai clic de souris sur le rouleau 3.
	pleine.bouton_cinquieme_as.pressed.emit()
	verifier(pleine.choix_du_rouleau, "clic sur Cinquième as : on choisit le rouleau à garder")
	verifier(pleine.texte_journal.text.contains("Clique sur le rouleau"), "le journal explique quoi faire")
	var gardee: SymbolData = pleine.combat.grille_courante[2]
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	pleine.cases[2].gui_input.emit(clic)
	verifier(not pleine.choix_du_rouleau and pleine.combat.relances_cinquieme_as == 0,
			"clic sur le rouleau 3 : relance du Cinquième as consommée")
	verifier(pleine.combat.grille_courante[2] == gardee, "le rouleau 3 est resté identique")
	verifier(pleine.bouton_cinquieme_as.disabled, "Cinquième as grisé après usage")

	# Valider : le tour est joué, la mise est réglée.
	var or_avant_validation: int = pleine.combat.or_du_joueur()
	pleine.bouton_valider.pressed.emit()
	verifier(not pleine.combat.tirage_en_attente and not pleine.ligne_relance.visible, "Valider joue le tour")
	verifier(pleine.texte_journal.text.contains("Mise de 5 or"), "le journal parle de la mise de 5 or")
	verifier(pleine.combat.or_du_joueur() != or_avant_validation or pleine.combat.est_fini(),
			"la mise a été réglée (l'or a bougé)")

	# Espace valide un tirage en attente (au lieu de tirer encore).
	var pour_espace := Partie.creer(5)
	pour_espace.ajouter_relique(Reliques.charger(&"de_pipe"))
	GameState.partie = pour_espace
	GameState.aller_a(GameState.SCENE_COMBAT)
	await _attendre()
	var avec_espace: Control = current_scene
	avec_espace._tirer()
	verifier(avec_espace.combat.tirage_en_attente, "premier appel du levier : tirage en attente")
	avec_espace._tirer()
	verifier(not avec_espace.combat.tirage_en_attente, "second appel (Espace) : le tirage est validé")

	# Bouton de test « relique au hasard » : en ajoute une et relance le combat.
	GameState.nouvelle_partie()
	GameState.aller_a(GameState.SCENE_COMBAT)
	await _attendre()
	var avec_test: Control = current_scene
	avec_test.bouton_debug_relique.pressed.emit()
	await _attendre()
	verifier(GameState.partie.reliques.size() == 1, "le bouton de test a donné une relique")
	var apres_test: Control = current_scene
	verifier(apres_test.rangee_reliques.get_child_count() == 1 and apres_test.partie.reliques.size() == 1,
			"la relique reçue s'affiche sur le nouvel écran de combat")

	# Combat perdu.
	GameState.nouvelle_partie()
	GameState.aller_a(GameState.SCENE_COMBAT)
	await _attendre()
	var perdu: Control = current_scene
	perdu.combat.pv_joueur = 0
	perdu.combat.etat = Combat.Etat.DEFAITE
	perdu._rafraichir()
	await _attendre()
	verifier_dans_la_fenetre(perdu.bouton_continuer, "bouton Continuer après défaite")

	# Écran de récompense.
	GameState.nouvelle_partie()
	GameState.aller_a(GameState.SCENE_RECOMPENSE)
	await _attendre()
	var recompense: Control = current_scene
	verifier(recompense.boutons.size() == 3, "3 cartes de récompense")
	for carte in recompense.boutons:
		verifier_dans_la_fenetre(carte, "carte de récompense")
	verifier_dans_la_fenetre(recompense.bouton_passer, "bouton Passer")

	# Boutique : un sac varié avec des dorés, dans chaque mode (normal, retrait, amélioration).
	GameState.nouvelle_partie()
	GameState.partie.or_total = 100
	for index in [0, 6, 9, 11, 13]:
		GameState.partie.sac.ameliorer(index)
	GameState.partie.sac.ajouter(load("res://data/symbols/epee.tres") as SymbolData, 3)
	GameState.aller_a(GameState.SCENE_BOUTIQUE)
	await _attendre()
	var boutique_ecran: Control = current_scene
	verifier(boutique_ecran.cartes_offres.size() == 3, "3 offres dans la boutique")
	verifier_dans_la_fenetre(boutique_ecran.bouton_debug, "bouton de test de la boutique")
	var or_avant: int = GameState.partie.or_total
	boutique_ecran.bouton_debug.pressed.emit()
	verifier(GameState.partie.or_total == or_avant + 30, "le bouton de test donne 30 or : %d" % GameState.partie.or_total)
	GameState.partie.or_total = or_avant
	for nom_mode in ["normal", "retrait", "amélioration"]:
		if nom_mode == "retrait":
			boutique_ecran._changer_mode(boutique_ecran.Mode.RETRAIT)
		elif nom_mode == "amélioration":
			boutique_ecran._changer_mode(boutique_ecran.Mode.RETRAIT)  # annule le retrait
			boutique_ecran._changer_mode(boutique_ecran.Mode.AMELIORATION)
		await _attendre()
		var lignes_sac: int = boutique_ecran.liste_sac.get_child_count()
		verifier(lignes_sac >= 8, "le sac affiche ses groupes en mode %s : %d lignes" % [nom_mode, lignes_sac])
		for carte in boutique_ecran.cartes_offres:
			verifier_dans_la_fenetre(carte, "offre de la boutique (%s)" % nom_mode)
		verifier_dans_la_fenetre(boutique_ecran.bouton_soin, "bouton Se soigner (%s)" % nom_mode)
		verifier_dans_la_fenetre(boutique_ecran.bouton_retrait, "bouton Retirer (%s)" % nom_mode)
		verifier_dans_la_fenetre(boutique_ecran.bouton_amelioration, "bouton Améliorer (%s)" % nom_mode)
		verifier_dans_la_fenetre(boutique_ecran.zone_sac, "zone du sac (%s)" % nom_mode)
		verifier_dans_la_fenetre(boutique_ecran.texte_message, "message (%s)" % nom_mode)
		verifier_dans_la_fenetre(boutique_ecran.texte_infos, "ressources (%s)" % nom_mode)
		verifier_dans_la_fenetre(boutique_ecran.bouton_quitter, "bouton Quitter la boutique (%s)" % nom_mode)
	# Les lignes du sac se défilent : la dernière doit au moins être atteignable (la zone clique-défile).
	verifier(boutique_ecran.zone_sac.get_v_scroll_bar() != null, "le sac a une barre de défilement")

	# Boutique : reliques à vendre (dans la fenêtre, achat par un clic).
	GameState.nouvelle_partie()
	GameState.partie.or_total = 100
	GameState.aller_a(GameState.SCENE_BOUTIQUE)
	await _attendre()
	var boutique_reliques: Control = current_scene
	verifier(boutique_reliques.cartes_reliques.size() == 2, "2 reliques à vendre dans la boutique")
	for carte in boutique_reliques.cartes_reliques:
		verifier_dans_la_fenetre(carte, "carte de relique à vendre")
	verifier_dans_la_fenetre(boutique_reliques.zone_sac, "zone du sac (avec les reliques à vendre)")
	verifier_dans_la_fenetre(boutique_reliques.texte_infos, "ressources (avec les reliques)")
	var relique_visee: RelicData = boutique_reliques.boutique.offres_reliques[0]
	var or_avant_relique: int = GameState.partie.or_total
	boutique_reliques.cartes_reliques[0].pressed.emit()
	verifier(GameState.partie.a_relique(relique_visee.id), "clic sur une relique : elle est achetée")
	verifier(GameState.partie.or_total == or_avant_relique - relique_visee.prix, "le prix de la relique est débité")
	verifier(boutique_reliques.cartes_reliques[0].disabled and boutique_reliques.cartes_reliques[0].text.contains("ACHETÉE"),
			"la relique achetée est marquée et grisée")
	verifier(boutique_reliques.texte_infos.text.contains("Reliques : 1"), "l'en-tête compte la relique : %s" % boutique_reliques.texte_infos.text)
	# Boutique avec toutes les reliques possédées : plus aucune carte.
	GameState.nouvelle_partie()
	for relique in Reliques.toutes():
		GameState.partie.ajouter_relique(relique)
	GameState.aller_a(GameState.SCENE_BOUTIQUE)
	await _attendre()
	verifier(current_scene.cartes_reliques.is_empty(), "plus de relique à vendre quand on les a toutes")
	verifier_dans_la_fenetre(current_scene.bouton_quitter, "bouton Quitter (toutes les reliques possédées)")

	# Écran « relique offerte » après le combat 3 : on y arrive depuis la récompense.
	GameState.nouvelle_partie()
	GameState.partie.combats_gagnes = 3
	GameState.aller_a(GameState.SCENE_RECOMPENSE)
	await _attendre()
	current_scene._choisir(null)
	await _attendre()
	verifier(current_scene.name == "Relique", "après le combat 3, la récompense mène à la relique offerte : %s" % current_scene.name)
	var offerte: Control = current_scene
	verifier(offerte.boutons.size() == 2, "2 reliques proposées")
	for carte in offerte.boutons:
		verifier_dans_la_fenetre(carte, "carte de la relique offerte")
	var choisie: RelicData = offerte.propositions[1]
	offerte.boutons[1].pressed.emit()
	await _attendre()
	verifier(GameState.partie.a_relique(choisie.id), "la relique choisie est possédée")
	verifier(GameState.partie.relique_offerte and not GameState.partie.relique_a_offrir(), "l'offre est terminée")
	verifier(current_scene.name == "Boutique", "après la relique, on va à la boutique : %s" % current_scene.name)

	# Hors combat 3 : la récompense mène directement à la boutique.
	GameState.nouvelle_partie()
	GameState.partie.combats_gagnes = 2
	GameState.aller_a(GameState.SCENE_RECOMPENSE)
	await _attendre()
	current_scene._choisir(null)
	await _attendre()
	verifier(current_scene.name == "Boutique", "après le combat 2, la récompense mène à la boutique")

	# Écrans de fin.
	for victoire in [true, false]:
		GameState.nouvelle_partie()
		GameState.partie.etat = Partie.Etat.VICTOIRE if victoire else Partie.Etat.DEFAITE
		GameState.aller_a(GameState.SCENE_FIN)
		await _attendre()
		var fin: Control = current_scene
		var bouton := _trouver_bouton(fin)
		verifier(bouton != null, "l'écran de fin a un bouton Rejouer")
		if bouton != null:
			verifier_dans_la_fenetre(bouton, "bouton Rejouer (%s)" % ("victoire" if victoire else "défaite"))

	print("TERMINÉ : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


func _attendre() -> void:
	await process_frame
	await process_frame
	await process_frame


func _trouver_bouton(noeud: Node) -> Button:
	if noeud is Button:
		return noeud
	for enfant in noeud.get_children():
		var trouve := _trouver_bouton(enfant)
		if trouve != null:
			return trouve
	return null


## Le contrôle doit se trouver tout entier dans la fenêtre (hauteur et largeur du jeu).
func verifier_dans_la_fenetre(controle: Control, nom: String) -> void:
	var zone := controle.get_global_rect()
	verifier(zone.position.y >= 0 and zone.end.y <= hauteur_fenetre \
			and zone.position.x >= 0 and zone.end.x <= largeur_fenetre,
			"%s dans la fenêtre (haut %d à %d sur %d, gauche %d à %d sur %d)" % [
				nom, zone.position.y, zone.end.y, hauteur_fenetre,
				zone.position.x, zone.end.x, largeur_fenetre])


func verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		echecs += 1
		print("  ÉCHEC ", message)
