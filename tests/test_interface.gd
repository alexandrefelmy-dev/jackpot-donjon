extends SceneTree
## Vérifie que les boutons importants des écrans tiennent dans la fenêtre du jeu
## (sinon on ne peut pas les cliquer : c'est arrivé avec « Continuer » en v0.3).
## À lancer en ligne de commande :
## godot --headless --path . -s res://tests/test_interface.gd

var echecs := 0
var hauteur_fenetre: float
var largeur_fenetre: float


func _initialize() -> void:
	# Les autoloads (GameState) ne sont prêts qu'après la première image.
	await process_frame
	# La fenêtre du mode test est minuscule : on lui donne la taille de la fenêtre du jeu,
	# sinon les écrans centrés seraient décalés.
	hauteur_fenetre = float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	largeur_fenetre = float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	root.size = Vector2i(int(largeur_fenetre), int(hauteur_fenetre))
	await process_frame
	print("hauteur de la fenêtre du jeu : %d" % hauteur_fenetre)
	var gs := root.get_node("GameState")
	var epee := load("res://data/symbols/epee.tres") as SymbolData
	var jackpot: Array[SymbolData] = [epee, epee, epee, epee, epee]

	# Combat gagné (bouton Continuer), contre un ennemi normal puis contre le boss.
	for boss in [false, true]:
		gs.nouvelle_partie()
		if boss:
			gs.partie.aller_au_boss()
		gs.aller_a(gs.SCENE_COMBAT)
		await _attendre()
		var combat_ecran: Control = current_scene
		var texte := "boss" if boss else "ennemi normal"

		# En cours de combat : le levier est visible.
		verifier_dans_la_fenetre(combat_ecran.bouton_levier, "bouton Tirer le levier (%s)" % texte)

		while not combat_ecran.combat.est_fini():
			combat_ecran.combat.jouer_tour(combat_ecran.machine.resoudre(jackpot))
		combat_ecran._rafraichir()
		await _attendre()
		verifier(combat_ecran.bouton_continuer.visible, "le bouton Continuer s'affiche après la victoire (%s)" % texte)
		verifier_dans_la_fenetre(combat_ecran.bouton_continuer, "bouton Continuer après victoire (%s)" % texte)
		verifier_dans_la_fenetre(combat_ecran.texte_fin, "texte de victoire (%s)" % texte)

	# Combat perdu.
	gs.nouvelle_partie()
	gs.aller_a(gs.SCENE_COMBAT)
	await _attendre()
	var perdu: Control = current_scene
	perdu.combat.pv_joueur = 0
	perdu.combat.etat = Combat.Etat.DEFAITE
	perdu._rafraichir()
	await _attendre()
	verifier_dans_la_fenetre(perdu.bouton_continuer, "bouton Continuer après défaite")

	# Écran de récompense.
	gs.nouvelle_partie()
	gs.aller_a(gs.SCENE_RECOMPENSE)
	await _attendre()
	var recompense: Control = current_scene
	verifier(recompense.boutons.size() == 3, "3 cartes de récompense")
	for carte in recompense.boutons:
		verifier_dans_la_fenetre(carte, "carte de récompense")
	verifier_dans_la_fenetre(recompense.bouton_passer, "bouton Passer")

	# Boutique : un sac varié avec des dorés, dans chaque mode (normal, retrait, amélioration).
	gs.nouvelle_partie()
	gs.partie.or_total = 100
	for index in [0, 6, 9, 11, 13]:
		gs.partie.sac.ameliorer(index)
	gs.partie.sac.ajouter(load("res://data/symbols/epee.tres") as SymbolData, 3)
	gs.aller_a(gs.SCENE_BOUTIQUE)
	await _attendre()
	var boutique_ecran: Control = current_scene
	verifier(boutique_ecran.cartes_offres.size() == 3, "3 offres dans la boutique")
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
		gs.nouvelle_partie()
		gs.partie.etat = Partie.Etat.VICTOIRE if victoire else Partie.Etat.DEFAITE
		gs.aller_a(gs.SCENE_FIN)
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
