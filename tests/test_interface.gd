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
		aller_au_combat()
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

	# La version du jeu s'affiche sur l'écran de combat, à côté de la graine.
	var expression := RegEx.create_from_string("^\\d+\\.\\d+$")
	verifier(expression.search(Version.NUMERO) != null, "le numéro de version a la forme 0.6 : %s" % Version.NUMERO)
	GameState.nouvelle_partie()
	aller_au_combat()
	await _attendre()
	var avec_version: Control = current_scene
	verifier(avec_version.texte_graine.text.contains(Version.texte()), "l'écran de combat affiche la version : %s" % avec_version.texte_graine.text)
	verifier(avec_version.texte_graine.text.contains(str(GameState.partie.graine)), "…et la graine")
	verifier_dans_la_fenetre(avec_version.texte_graine, "graine et version")

	# Bouton de test « Aller au boss » : un clic mène au combat du boss (et on peut le jouer).
	GameState.nouvelle_partie()
	aller_au_combat()
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
	aller_au_combat()
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
	aller_au_combat()
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
	aller_au_combat()
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
	GameState.lancer(pour_espace)
	aller_au_combat()
	await _attendre()
	var avec_espace: Control = current_scene
	avec_espace._tirer()
	verifier(avec_espace.combat.tirage_en_attente, "premier appel du levier : tirage en attente")
	avec_espace._tirer()
	verifier(not avec_espace.combat.tirage_en_attente, "second appel (Espace) : le tirage est validé")

	# Bouton de test « relique au hasard » : en ajoute une et relance le combat.
	GameState.nouvelle_partie()
	aller_au_combat()
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
	aller_au_combat()
	await _attendre()
	var perdu: Control = current_scene
	perdu.combat.pv_joueur = 0
	perdu.combat.etat = Combat.Etat.DEFAITE
	perdu._rafraichir()
	await _attendre()
	verifier_dans_la_fenetre(perdu.bouton_continuer, "bouton Continuer après défaite")

	# Écran de récompense.
	GameState.nouvelle_partie()
	aller_a_ecran(Partie.Ecran.RECOMPENSE)
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
	aller_a_ecran(Partie.Ecran.BOUTIQUE)
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
	aller_a_ecran(Partie.Ecran.BOUTIQUE)
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
	aller_a_ecran(Partie.Ecran.BOUTIQUE)
	await _attendre()
	verifier(current_scene.cartes_reliques.is_empty(), "plus de relique à vendre quand on les a toutes")
	verifier_dans_la_fenetre(current_scene.bouton_quitter, "bouton Quitter (toutes les reliques possédées)")

	# La récompense mène aux portes du pas suivant.
	GameState.nouvelle_partie()
	aller_a_ecran(Partie.Ecran.RECOMPENSE)
	await _attendre()
	current_scene._choisir(null)
	await _attendre()
	verifier(current_scene.name == "Portes" and GameState.partie.pas == 2, "la récompense mène aux portes du pas 2 : %s" % current_scene.name)

	# Boss de l'étage 1 vaincu : l'écran des reliques (2 cartes), puis les portes de l'étage 2.
	GameState.nouvelle_partie()
	GameState.partie.aller_au_boss()
	var combat_boss := GameState.partie.creer_combat()
	while not combat_boss.est_fini():
		combat_boss.jouer_tour(MachineASous.new(5, 1).resoudre(jackpot))
	GameState.partie.terminer_combat(combat_boss)
	GameState.aller_a_suivant()
	await _attendre()
	verifier(current_scene.name == "Relique", "boss vaincu : l'écran de relique : %s" % current_scene.name)
	var offerte: Control = current_scene
	verifier(offerte.boutons.size() == 2, "2 reliques proposées")
	for carte in offerte.boutons:
		verifier_dans_la_fenetre(carte, "carte de la relique offerte")
	var choisie: RelicData = offerte.propositions[1]
	offerte.boutons[1].pressed.emit()
	await _attendre()
	verifier(GameState.partie.a_relique(choisie.id), "la relique choisie est possédée")
	verifier(current_scene.name == "Portes" and GameState.partie.etage == 2 and GameState.partie.pas == 1,
			"après la relique du boss : les portes de l'étage 2 : %s" % current_scene.name)

	# Écran des portes : à chaque pas des 3 étages, les 2 portes et les textes tiennent dans la fenêtre.
	for etage in range(1, 4):
		for pas in range(1, 6):
			GameState.nouvelle_partie()
			GameState.partie.etage = etage
			GameState.partie.pas = pas
			GameState.aller_a_suivant()
			await _attendre()
			var portes_ecran: Control = current_scene
			verifier(portes_ecran.boutons_portes.size() == 2, "2 portes (étage %d, pas %d)" % [etage, pas])
			for porte in portes_ecran.boutons_portes:
				verifier_dans_la_fenetre(porte, "porte (étage %d, pas %d)" % [etage, pas])

	# À l'étage 3, une porte de coffre prévient des mimiques.
	var avertit := false
	for graine in 100:
		var donjon_coffre := Donjon.creer(graine)
		if donjon_coffre.portes(3, 2)[0].type == Salle.Type.COFFRE or donjon_coffre.portes(3, 2)[1].type == Salle.Type.COFFRE:
			GameState.lancer(Partie.creer(graine))
			GameState.partie.etage = 3
			GameState.partie.pas = 2
			GameState.aller_a_suivant()
			await _attendre()
			for texte in current_scene.textes_portes:
				if texte.contains("COFFRE"):
					avertit = texte.contains("mimiques")
			break
	verifier(avertit, "à l'étage 3, les portes de coffre préviennent des mimiques")

	# Un clic sur une porte mène à l'écran de la salle (combat, boutique, coffre = relique, repos).
	var attendus := {Salle.Type.COMBAT: "Combat", Salle.Type.BOUTIQUE: "Boutique", Salle.Type.COFFRE: "Relique", Salle.Type.REPOS: "Repos"}
	var types_testes := {}
	for graine in 80:
		GameState.lancer(Partie.creer(graine))
		GameState.partie.pas = 2 + graine % 4
		var salle: Salle = GameState.partie.portes()[graine % 2]
		if int(types_testes.get(salle.type, 0)) >= 2:
			continue
		types_testes[salle.type] = int(types_testes.get(salle.type, 0)) + 1
		GameState.aller_a_suivant()
		await _attendre()
		current_scene.boutons_portes[graine % 2].pressed.emit()
		await _attendre()
		verifier(current_scene.name == attendus[salle.type], "porte %s : l'écran « %s » s'ouvre" % [salle.nom_type(), current_scene.name])
	verifier(types_testes.size() == 4, "les 4 types de salle ont été franchis par un clic")

	# Un coffre-mimique mène au combat de la Mimique, avec la surprise dans le journal.
	var graine_mimique := -1
	var index_mimique := -1
	var pas_mimique := -1
	for graine in 200:
		if graine_mimique >= 0:
			break
		var donjon_test := Donjon.creer(graine)
		for pas in range(1, 6):
			for i in 2:
				if donjon_test.portes(3, pas)[i].mimique and graine_mimique < 0:
					graine_mimique = graine
					index_mimique = i
					pas_mimique = pas
	verifier(graine_mimique >= 0, "une graine avec une mimique à l'étage 3 existe")
	GameState.lancer(Partie.creer(graine_mimique))
	GameState.partie.etage = 3
	GameState.partie.pas = pas_mimique
	GameState.aller_a_suivant()
	await _attendre()
	current_scene.boutons_portes[index_mimique].pressed.emit()
	await _attendre()
	var ecran_mimique: Control = current_scene
	verifier(ecran_mimique.name == "Combat" and ecran_mimique.combat.ennemi.id == &"mimique", "le coffre-mimique mène au combat contre la Mimique")
	verifier(ecran_mimique.texte_journal.text.contains("surprise"), "le journal annonce l'attaque surprise")
	verifier(ecran_mimique.combat.pv_joueur == 30, "la surprise a coûté 10 PV : %d" % ecran_mimique.combat.pv_joueur)

	# Repos : les deux choix tiennent dans la fenêtre ; se reposer soigne ; dorer passe par le sac.
	GameState.nouvelle_partie()
	GameState.partie.pv = 10
	aller_a_ecran(Partie.Ecran.REPOS)
	await _attendre()
	var repos: Control = current_scene
	verifier_dans_la_fenetre(repos.bouton_soin, "carte Se reposer")
	verifier_dans_la_fenetre(repos.bouton_dorer, "carte Rendre un symbole doré")
	verifier_dans_la_fenetre(repos.texte_infos, "ressources du repos")
	verifier_dans_la_fenetre(repos.texte_message, "message du repos")
	verifier(Cartes.texte_carte(repos.bouton_soin).contains("12"), "le bouton annonce +12 PV (30 % de 40)")
	repos._choisir_symbole()
	await _attendre()
	verifier(repos.zone_sac.visible and not repos.zone_choix.visible, "« Rendre un symbole doré » montre le sac")
	verifier_dans_la_fenetre(repos.zone_sac, "sac du repos")
	verifier_dans_la_fenetre(repos.bouton_annuler, "bouton Annuler du repos")
	verifier(repos.liste_sac.get_child_count() >= 4, "le sac du repos affiche ses symboles : %d lignes" % repos.liste_sac.get_child_count())
	repos._annuler()
	await _attendre()
	repos.bouton_soin.pressed.emit()
	await _attendre()
	verifier(GameState.partie.pv == 22 and current_scene.name == "Portes" and GameState.partie.pas == 2,
			"se reposer rend 12 PV et mène aux portes du pas 2 : PV %d, %s" % [GameState.partie.pv, current_scene.name])
	GameState.nouvelle_partie()
	aller_a_ecran(Partie.Ecran.REPOS)
	await _attendre()
	current_scene._choisir_symbole()
	current_scene._dorer(0)
	await _attendre()
	verifier(GameState.partie.sac.symboles[0].doree and current_scene.name == "Portes", "doré gratuitement, retour aux portes")
	GameState.nouvelle_partie()
	aller_a_ecran(Partie.Ecran.REPOS)
	await _attendre()
	verifier(current_scene.bouton_soin.disabled, "à PV pleins, « Se reposer » est grisé")

	# Combat contre chacun des ennemis (passifs, règles, surprise) : tout tient dans la fenêtre.
	var ennemis_a_voir: Array[String] = [
		"rat_egout", "squelette", "gobelin_tricheur", "rat_croupier", "fantome_joueur", "golem_jetons",
		"pickpocket", "dame_de_pique", "garde_du_coffre", "mimique", "usurier", "grand_croupier"]
	for id in ennemis_a_voir:
		GameState.nouvelle_partie()
		GameState.partie.ennemi_courant = load("res://data/enemies/%s.tres" % id) as EnemyData
		GameState.partie.ecran = Partie.Ecran.COMBAT
		GameState.aller_a_suivant()
		await _attendre()
		var contre: Control = current_scene
		# Quelques tours : les crânes s'accumulent, les règles changent.
		for tour in 4:
			if not contre.combat.est_fini():
				contre.combat.pv_joueur = 40
				contre._tirer()
		contre._rafraichir()
		await _attendre()
		var composants := {
			"levier": contre.bouton_levier, "titre": contre.texte_etage, "intention": contre.texte_intention,
			"passif": contre.texte_passif, "PV du joueur": contre.texte_pv_joueur, "or": contre.texte_or,
			"graine": contre.texte_graine, "test boss": contre.bouton_debug, "test relique": contre.bouton_debug_relique,
			"test étage": contre.bouton_debug_etage, "reliques": contre.rangee_reliques}
		for nom_composant: String in composants:
			verifier_dans_la_fenetre(composants[nom_composant], "%s : %s" % [id, nom_composant])
		if not contre.combat.est_fini():
			contre.combat.etat = Combat.Etat.FUITE if id == "pickpocket" else Combat.Etat.VICTOIRE
			contre._rafraichir()
			await _attendre()
		verifier_dans_la_fenetre(contre.bouton_continuer, "bouton Continuer (%s)" % id)
		verifier_dans_la_fenetre(contre.texte_fin, "texte de fin (%s)" % id)
	GameState.nouvelle_partie()
	GameState.partie.ennemi_courant = load("res://data/enemies/grand_croupier.tres") as EnemyData
	GameState.partie.ecran = Partie.Ecran.COMBAT
	GameState.aller_a_suivant()
	await _attendre()
	verifier(current_scene.texte_passif.visible and current_scene.texte_passif.text.contains("Règle du tour"),
			"le Grand Croupier annonce la règle du tour : %s" % current_scene.texte_passif.text)

	# Une partie qui n'attend pas un combat : l'écran de combat (écran principal) redirige vers les portes...
	GameState.nouvelle_partie()
	GameState.aller_a(GameState.SCENE_COMBAT)
	await _attendre()
	verifier(current_scene.name == "Portes", "en partie, l'écran principal redirige vers les portes : %s" % current_scene.name)
	# ... et au lancement du jeu (hors partie) vers le Comptoir.
	GameState.en_partie = false
	GameState.aller_a(GameState.SCENE_COMBAT)
	await _attendre()
	verifier(current_scene.name == "Menu", "au lancement, l'écran principal mène au menu principal : %s" % current_scene.name)

	# --- Menu principal ---
	GameState.options = Options.new()
	var menu: Control = current_scene
	for composant in [menu.bouton_jouer, menu.bouton_comptoir, menu.bouton_options, menu.bouton_quitter, menu.texte_titre, menu.texte_version]:
		verifier_dans_la_fenetre(composant, "menu : %s" % composant.name)
	verifier(menu.texte_version.text == Version.texte(), "le menu affiche la version : %s" % menu.texte_version.text)
	menu.bouton_options.pressed.emit()
	await _attendre()
	verifier(current_scene.name == "Options", "« Options » ouvre les options : %s" % current_scene.name)

	# --- Options ---
	var reglages: Control = current_scene
	for composant in [reglages.curseur_musique, reglages.curseur_effets, reglages.texte_musique, reglages.texte_effets,
			reglages.case_plein_ecran, reglages.case_tremblements, reglages.case_flashs, reglages.bouton_credits,
			reglages.bouton_retour, reglages.texte_message]:
		verifier_dans_la_fenetre(composant, "options : %s" % composant.name)
	verifier(reglages.curseur_musique.value == 60 and reglages.curseur_effets.value == 80, "les curseurs montrent 60 % et 80 %")
	reglages.curseur_musique.value = 30
	verifier(is_equal_approx(GameState.options.volume_musique, 0.3), "un curseur change l'option")
	verifier(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(Son.BUS_MUSIQUE)), 0.09), "…et le gain du bus Musique (0,3 au carré = 0,09)")
	verifier(reglages.texte_musique.text.contains("30"), "…et son texte : %s" % reglages.texte_musique.text)
	reglages.curseur_effets.value = 0
	verifier(AudioServer.is_bus_mute(AudioServer.get_bus_index(Son.BUS_EFFETS)), "effets à 0 : le bus Effets est coupé")
	reglages.case_tremblements.button_pressed = true
	reglages.case_flashs.button_pressed = true
	verifier(GameState.options.reduire_tremblements and GameState.options.reduire_flashs, "les cases d'accessibilité changent les options")
	reglages.bouton_credits.pressed.emit()
	verifier(reglages.texte_credits.visible, "« Crédits » affiche les crédits")
	verifier_dans_la_fenetre(reglages.texte_credits, "texte des crédits")
	# --- Plein écran : bouton en haut à droite et Alt+Entrée, sur tous les écrans ---
	var plein := PleinEcran.instance
	verifier(is_instance_valid(plein) and plein.is_inside_tree() and plein.bouton != null, "le bouton plein écran est installé à la racine du jeu")
	verifier_dans_la_fenetre(plein.bouton, "bouton plein écran")
	verifier(plein.bouton.focus_mode == Control.FOCUS_NONE, "…sans focus (Espace et Entrée ne le déclenchent pas)")
	var etat_avant := GameState.options.plein_ecran
	plein.bouton.pressed.emit()
	verifier(GameState.options.plein_ecran != etat_avant, "le bouton bascule l'option plein écran")
	verifier(reglages.case_plein_ecran.button_pressed == GameState.options.plein_ecran, "…et la case des Options suit")
	var entree_seule := InputEventKey.new()
	entree_seule.keycode = KEY_ENTER
	entree_seule.pressed = true
	plein._input(entree_seule)
	verifier(GameState.options.plein_ecran != etat_avant, "Entrée seule ne bascule pas le plein écran")
	var alt_entree := InputEventKey.new()
	alt_entree.keycode = KEY_ENTER
	alt_entree.alt_pressed = true
	alt_entree.pressed = true
	plein._input(alt_entree)
	verifier(GameState.options.plein_ecran == etat_avant, "Alt+Entrée bascule le plein écran")
	GameState.options = Options.new()
	GameState.appliquer_options()
	var echap := InputEventKey.new()
	echap.physical_keycode = KEY_ESCAPE
	echap.pressed = true
	reglages._unhandled_input(echap)
	await _attendre()
	verifier(current_scene.name == "Menu", "Échap revient au menu : %s" % current_scene.name)
	current_scene.bouton_comptoir.pressed.emit()
	await _attendre()
	verifier(current_scene.name == "Comptoir", "« Comptoir du Croupier » ouvre le Comptoir : %s" % current_scene.name)
	verifier_dans_la_fenetre(current_scene.bouton_menu, "bouton Menu du Comptoir")
	current_scene._unhandled_input(echap)
	await _attendre()
	verifier(current_scene.name == "Menu", "Échap au Comptoir : retour au menu")
	current_scene.bouton_jouer.pressed.emit()
	await _attendre()
	verifier(current_scene.name == "Portes" and GameState.en_partie, "« Jouer » lance une partie : %s" % current_scene.name)
	# Espace (action « levier ») tire le levier.
	GameState.partie.choisir_porte(0)
	GameState.aller_a_suivant()
	await _attendre()
	var espace := InputEventKey.new()
	espace.physical_keycode = KEY_SPACE
	espace.pressed = true
	var avant_tour: int = current_scene.combat.numero_tour
	current_scene._unhandled_input(espace)
	verifier(current_scene.combat.numero_tour == avant_tour + 1 or current_scene.combat.tirage_en_attente or current_scene.combat.est_fini(), "la barre d'espace tire le levier")
	# --- Les rouleaux s'arrêtent un par un ---
	var anime: Control = current_scene
	anime.forcer_animation = true
	var tour_avant_anim: int = anime.combat.numero_tour
	anime._tirer()
	verifier(anime.animation_en_cours and anime.combat.numero_tour == tour_avant_anim + 1, "le tour est calculé tout de suite, les rouleaux s'arrêtent ensuite")
	verifier(anime._en_rotation[0] and anime._en_rotation[4] and anime._fenetres[0].visible and anime._fenetres[4].visible, "au début, tous les rouleaux tournent (les symboles défilent)")
	await create_timer(0.7).timeout
	verifier(not anime._en_rotation[0] and not anime._fenetres[0].visible and anime.etiquettes[0].text != "", "au bout d'un instant, le premier rouleau est arrêté et affiche son symbole")
	verifier(anime._en_rotation[4] and anime._fenetres[4].visible, "…pendant que le dernier tourne encore")
	await create_timer(1.5).timeout
	verifier(anime._en_rotation[4], "le dernier rouleau se fait attendre (suspense) : il tourne encore après 2,2 s")
	await create_timer(1.3).timeout
	verifier(not anime.animation_en_cours and not anime._en_rotation[4] and anime.etiquettes[4].text != "", "au bout de ~3,5 s au plus, tous les rouleaux sont arrêtés")
	verifier(anime.texte_journal.text.contains("Tour"), "…et le journal du tour est alors affiché : %s" % anime.texte_journal.text.left(30).replace("
", " "))
	var tour_apres: int = anime.combat.numero_tour
	anime._tirer()
	verifier(anime.animation_en_cours, "un nouveau tirage relance l'animation")
	anime._tirer()
	verifier(not anime.animation_en_cours and not anime._fenetres[4].visible and anime.etiquettes[4].text != "", "Espace pendant l'animation l'accélère : tous les rouleaux sont arrêtés d'un coup")
	verifier(anime.combat.numero_tour == tour_apres + 1 or anime.combat.est_fini(), "…sans jouer un tour de plus (un seul tour par tirage)")
	anime.forcer_animation = false

	# Le menu et les options ne touchent pas à ce que le profil de test contient.
	GameState.en_partie = false

	# --- Comptoir du Croupier ---
	var profil := Profil.nouveau()
	profil.jetons = 100
	profil.maledictions.assign([&"sac_leste", &"croupier_rancunier", &"mauvais_oeil"] as Array[StringName])
	GameState.profil = profil
	GameState.en_partie = false
	GameState.aller_a(GameState.SCENE_COMPTOIR)
	await _attendre()
	var comptoir_ecran: Control = current_scene
	verifier(comptoir_ecran.boutons_achats.size() == 6, "6 achats au Comptoir")
	for carte in comptoir_ecran.boutons_achats:
		verifier_dans_la_fenetre(carte, "carte d'achat du Comptoir")
	for composant in [comptoir_ecran.texte_jetons, comptoir_ecran.texte_message, comptoir_ecran.texte_maledictions,
			comptoir_ecran.texte_debloques, comptoir_ecran.bouton_jouer, comptoir_ecran.bouton_debug_jetons, comptoir_ecran.bouton_debug_reset]:
		verifier_dans_la_fenetre(composant, "Comptoir : %s" % composant.name)
	verifier(comptoir_ecran.texte_maledictions.text.contains("Sac lesté") and comptoir_ecran.texte_maledictions.text.contains("Mauvais œil"),
			"les 3 malédictions sont affichées : %s" % comptoir_ecran.texte_maledictions.text.replace("\n", " | "))
	verifier(comptoir_ecran.texte_jetons.text.contains("100"), "les jetons s'affichent : %s" % comptoir_ecran.texte_jetons.text)
	# Un clic sur « Débloquer un symbole » : 10 jetons dépensés, un symbole débloqué.
	comptoir_ecran.boutons_achats[0].pressed.emit()
	verifier(profil.jetons == 90 and profil.symboles_debloques.size() == 5, "clic sur « Débloquer un symbole » : 90 jetons, un symbole de plus")
	verifier(comptoir_ecran.texte_message.text.contains("débloqué"), "le message annonce le déblocage : %s" % comptoir_ecran.texte_message.text)
	verifier_dans_la_fenetre(comptoir_ecran.texte_message, "message du Comptoir après un achat")
	# Un achat impossible est grisé.
	profil.jetons = 5
	comptoir_ecran._rafraichir()
	verifier(comptoir_ecran.boutons_achats[0].disabled and comptoir_ecran.boutons_achats[5].disabled, "sans assez de jetons, les cartes sont grisées")
	# Tout acheté : les cartes sont épuisées et le Comptoir tient toujours dans la fenêtre.
	profil.jetons = 1000
	for achat in Comptoir.ORDRE:
		for i in 6:
			comptoir_ecran.comptoir.acheter(achat)
	comptoir_ecran._rafraichir()
	await _attendre()
	for carte in comptoir_ecran.boutons_achats:
		verifier(carte.disabled, "tout acheté : la carte est grisée")
		verifier_dans_la_fenetre(carte, "carte épuisée du Comptoir")
	verifier_dans_la_fenetre(comptoir_ecran.texte_debloques, "liste des éléments débloqués (tout débloqué)")
	# « Jouer » : la partie démarre avec les avantages et les malédictions du profil.
	comptoir_ecran.bouton_jouer.pressed.emit()
	await _attendre()
	verifier(current_scene.name == "Portes" and GameState.en_partie, "« Jouer » mène aux portes d'une nouvelle partie : %s" % current_scene.name)
	verifier(GameState.partie.profil == profil and GameState.partie.pv_max == 40 + 15 and GameState.partie.maledictions.size() == 3,
			"la partie a les avantages (+15 PV) et les 3 malédictions du profil")
	# Test du bouton de test et de la remise à zéro.
	GameState.vers_le_comptoir()
	await _attendre()
	var avant_test := profil.jetons
	current_scene.bouton_debug_jetons.pressed.emit()
	verifier(profil.jetons == avant_test + 50, "« [test] +50 jetons » : +50 jetons")
	current_scene.bouton_debug_reset.pressed.emit()
	verifier(GameState.profil.jetons == 0 and GameState.profil.symboles_debloques.size() == 4, "« [test] Réinitialiser le profil » : profil neuf")

	# --- Écran de fin avec le bilan du profil ---
	var profil_fin := Profil.nouveau()
	profil_fin.maledictions.assign([&"fatigue"] as Array[StringName])
	GameState.profil = profil_fin
	var perdue := Partie.creer(1, profil_fin)
	perdue.salles_franchies = 9
	perdue.boss_vaincus = 1
	perdue.etat = Partie.Etat.DEFAITE
	perdue.ecran = Partie.Ecran.FIN
	GameState.lancer(perdue)
	GameState.aller_a_suivant()
	await _attendre()
	var fin_bilan: Control = current_scene
	verifier(fin_bilan.texte_jetons != null and profil_fin.jetons == 14, "défaite après 9 salles et 1 boss : 14 jetons enregistrés (%d)" % profil_fin.jetons)
	verifier(fin_bilan.texte_malediction != null and fin_bilan.texte_malediction.text.contains("effacée"), "l'écran dit qu'une malédiction est effacée (le boss)")
	verifier(fin_bilan.texte_malediction.text.contains("reçue"), "…et qu'une nouvelle est reçue")
	for composant in [fin_bilan.texte_jetons, fin_bilan.texte_malediction, fin_bilan.bouton_rejouer, fin_bilan.bouton_comptoir, fin_bilan.bouton_menu]:
		verifier_dans_la_fenetre(composant, "fin de partie : %s" % composant.name)
	var jetons_apres := profil_fin.jetons
	GameState.aller_a_suivant()
	await _attendre()
	verifier(profil_fin.jetons == jetons_apres and profil_fin.parties_jouees == 1, "recharger l'écran de fin ne crédite pas une 2e fois")
	current_scene.bouton_comptoir.pressed.emit()
	await _attendre()
	verifier(current_scene.name == "Comptoir" and not GameState.en_partie, "« Comptoir du Croupier » mène au Comptoir")
	GameState.profil = null

	# Écrans de fin.
	for victoire in [true, false]:
		GameState.nouvelle_partie()
		GameState.partie.ecran = Partie.Ecran.FIN
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


## Le combat du premier pas (les deux portes du pas 1 sont des combats), sauf si la partie y est déjà.
func aller_au_combat() -> void:
	if GameState.partie.ecran == Partie.Ecran.PORTES:
		GameState.partie.choisir_porte(0)
	GameState.aller_a(GameState.SCENE_COMBAT)


## Force l'écran demandé par la partie (pour regarder un écran sans jouer tout ce qui y mène).
func aller_a_ecran(ecran: Partie.Ecran) -> void:
	GameState.partie.ecran = ecran
	GameState.aller_a_suivant()


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
