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
