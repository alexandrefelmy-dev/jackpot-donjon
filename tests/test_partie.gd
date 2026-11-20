extends SceneTree
## Tests de la partie (PV, or, sac, enchaînement des combats, récompenses, fin), à lancer en ligne de commande :
## godot --headless --path . -s res://tests/test_partie.gd
## Le parcours du donjon (portes, étages, coffres, repos) est dans test_donjon.gd.

var echecs := 0
var machine := MachineASous.new(5, 1)


func _init() -> void:
	test_partie_neuve()
	test_enchainement()
	test_combats_obligatoires()
	test_or_et_vol()
	test_defaite()
	test_victoire_du_boss()
	test_recompenses()
	test_combat_compte_une_fois()
	test_aller_au_boss()
	test_parties_automatiques()

	print("TERMINÉ : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


# --- Outils -----------------------------------------------------------------

## Va jusqu'au prochain combat : si on est au choix des salles bonus, on prend la première porte (le combat,
## lui, est déjà en cours dès le début d'un pas).
func vers_un_combat(partie: Partie) -> void:
	if partie.ecran == Partie.Ecran.PORTES:
		partie.choisir_porte(0)


## Fait gagner le combat en cours d'un coup (jackpot d'épées).
func gagner(partie: Partie) -> Combat:
	vers_un_combat(partie)
	var combat := partie.creer_combat()
	var epee := load("res://data/symbols/epee.tres") as SymbolData
	var grille: Array[SymbolData] = [epee, epee, epee, epee, epee]
	# Un jackpot fait 60 dégâts : on recommence jusqu'à la fin du combat (si les PV d'un ennemi changent).
	var tours := 0
	while not combat.est_fini() and tours < 50:
		combat.jouer_tour(machine.resoudre(grille))
		tours += 1
	return combat


## Joue un combat entier en tirant sans réfléchir.
func jouer_combat_auto(combat: Combat) -> void:
	var tours := 0
	while not combat.est_fini() and tours < 300:
		combat.tirer()
		combat.valider()
		tours += 1


# --- Tests ------------------------------------------------------------------

func test_partie_neuve() -> void:
	var partie := Partie.creer(1)
	verifier(partie.pv == 40 and partie.pv_max == 40, "une partie commence à 40 PV")
	verifier(partie.or_total == 0, "une partie commence à 0 or")
	verifier(partie.sac.taille() == 15, "le sac de départ a 15 symboles")
	verifier(partie.etage == 1 and partie.pas == 1, "on commence à l'étage 1, au pas 1")
	verifier(partie.ecran == Partie.Ecran.COMBAT and partie.ennemi_courant != null and not partie.en_salle_bonus,
			"on commence par le premier combat : il est obligatoire, sans porte")
	verifier(partie.portes().is_empty() and not partie.choisir_porte(0), "pendant un combat, aucune porte à choisir")
	verifier(partie.ennemi_courant == partie.donjon.combat(1, 1).ennemi, "l'ennemi est celui que le donjon a prévu pour ce pas")
	verifier(partie.etat == Partie.Etat.EN_COURS, "la partie est en cours")
	verifier(partie.graine == 1, "la graine est gardée : %d" % partie.graine)
	verifier(not partie.est_combat_de_boss(), "pas de boss au départ")
	verifier(partie.donjon != null and partie.donjon.etages.size() == 3, "la partie a son donjon de 3 étages")
	verifier(Partie.creer().graine >= 0, "sans graine donnée, une graine est choisie")
	verifier(Partie.creer(77).donjon.empreinte() == Partie.creer(77).donjon.empreinte(), "même graine, même donjon")


func test_enchainement() -> void:
	var partie := Partie.creer(3)
	vers_un_combat(partie)
	var premier := partie.ennemi_courant

	# Combat 1 : on perd un peu de PV, on gagne de l'or.
	var combat := partie.creer_combat()
	verifier(combat.ennemi == premier and combat.pv_joueur == 40, "le combat oppose le joueur à l'ennemi de la porte")
	combat.pv_joueur = 25
	combat.pv_ennemi = 0
	combat.etat = Combat.Etat.VICTOIRE
	combat.or_gagne = 7
	partie.terminer_combat(combat)
	verifier(partie.pv == 25, "les PV restent d'un combat à l'autre : %d" % partie.pv)
	verifier(partie.or_total == 7, "l'or est conservé : %d" % partie.or_total)
	verifier(partie.combats_gagnes == 1, "un combat gagné")
	verifier(partie.ecran == Partie.Ecran.RECOMPENSE, "après un combat gagné : la récompense")
	verifier(partie.etat == Partie.Etat.EN_COURS, "la partie continue")
	partie.terminer_recompense()
	verifier(partie.ecran == Partie.Ecran.COMBAT and partie.pas == 2 and partie.ennemi_courant == partie.donjon.combat(1, 2).ennemi,
			"puis le combat du pas 2, tout de suite (pas de porte après le pas 1)")

	# Combat suivant : démarre avec les PV restants.
	vers_un_combat(partie)
	var combat2 := partie.creer_combat()
	verifier(combat2.pv_joueur == 25, "le combat suivant démarre avec 25 PV : %d" % combat2.pv_joueur)
	verifier(combat2.armure_joueur == 0, "l'armure ne se garde pas entre les combats")
	verifier(combat2.pv_max_joueur == 40, "PV max conservés : %d" % combat2.pv_max_joueur)


## Les combats sont obligatoires : après chaque victoire, le combat suivant (ou le boss) vient tout seul, et on ne
## choisit entre 2 salles bonus qu'après les pas 2 et 4.
func test_combats_obligatoires() -> void:
	var partie := Partie.creer(21)
	var ordre := ""
	var combats := 0
	while partie.etage == 1 and partie.etat == Partie.Etat.EN_COURS and combats < 30:
		match partie.ecran:
			Partie.Ecran.COMBAT:
				var est_boss := partie.est_combat_de_boss()
				ordre += "B" if est_boss else ("m" if partie.en_salle_bonus else "C")
				var combat := partie.creer_combat()
				combat.pv_ennemi = 0
				combat.etat = Combat.Etat.VICTOIRE
				partie.terminer_combat(combat)
				combats += 1
			Partie.Ecran.RECOMPENSE:
				partie.terminer_recompense()
			Partie.Ecran.PORTES:
				ordre += "|"
				verifier(partie.portes().size() == 2 and partie.pas in Donjon.BONUS_APRES_PAS, "deux salles bonus après le pas %d" % partie.pas)
				# Boutique ou repos : on les quitte aussitôt.
				partie.choisir_porte(0)
				if partie.ecran == Partie.Ecran.BOUTIQUE:
					partie.quitter_boutique()
				elif partie.ecran == Partie.Ecran.REPOS:
					partie.repos_soigner()
					partie.quitter_repos()
				elif partie.ecran == Partie.Ecran.RELIQUE:
					partie.choisir_relique(partie.proposer_reliques(2)[0])
			Partie.Ecran.RELIQUE:
				partie.choisir_relique(partie.proposer_reliques(2)[0])
			_:
				break
	verifier(ordre == "CC|CC|CB", "étage 1 : 2 combats, 2 salles bonus au choix, 2 combats, le boss de l'étage : %s" % ordre)
	verifier(partie.etage == 2 and partie.pas == 1 and partie.ecran == Partie.Ecran.COMBAT, "le boss vaincu ouvre le premier combat de l'étage 2")

	# Une salle bonus finie mène au combat suivant, pas aux portes.
	var bonus := Partie.creer(22)
	bonus.pas = 2
	bonus.ecran = Partie.Ecran.PORTES
	var boutique_ou_repos := 0
	bonus.choisir_porte(0)
	if bonus.ecran == Partie.Ecran.BOUTIQUE:
		bonus.quitter_boutique()
		boutique_ou_repos += 1
	elif bonus.ecran == Partie.Ecran.REPOS:
		bonus.repos_dorer(0)
		boutique_ou_repos += 1
	if boutique_ou_repos > 0:
		verifier(bonus.ecran == Partie.Ecran.COMBAT and bonus.pas == 3 and not bonus.en_salle_bonus, "après la salle bonus, le combat du pas 3")


func test_or_et_vol() -> void:
	# L'or d'un combat (pièces + victoire) s'ajoute, ce qui a été volé s'en retranche.
	var partie := Partie.creer(12)
	partie.or_total = 10
	vers_un_combat(partie)
	var combat := partie.creer_combat()
	verifier(combat.or_du_joueur() == 10, "le combat voit l'or de la partie : %d" % combat.or_du_joueur())
	combat.or_gagne = 8
	combat.or_vole = 3
	combat.etat = Combat.Etat.VICTOIRE
	partie.terminer_combat(combat)
	verifier(partie.or_total == 15, "10 + 8 gagnés - 3 volés = 15 or : %d" % partie.or_total)

	# On peut perdre de l'or sur une défaite aussi, sans passer sous zéro.
	var partie2 := Partie.creer(13)
	partie2.or_total = 3
	vers_un_combat(partie2)
	var combat2 := partie2.creer_combat()
	combat2.or_vole = 3
	combat2.pv_joueur = 0
	combat2.etat = Combat.Etat.DEFAITE
	partie2.terminer_combat(combat2)
	verifier(partie2.or_total == 0, "l'or volé est retranché même en cas de défaite : %d" % partie2.or_total)


func test_defaite() -> void:
	var partie := Partie.creer(5)
	vers_un_combat(partie)
	var combat := partie.creer_combat()
	combat.pv_joueur = 0
	combat.etat = Combat.Etat.DEFAITE
	combat.or_gagne = 3
	partie.terminer_combat(combat)
	verifier(partie.etat == Partie.Etat.DEFAITE, "à 0 PV : défaite de la partie")
	verifier(partie.ecran == Partie.Ecran.FIN, "la défaite mène à l'écran de fin")
	verifier(partie.pv == 0 and partie.or_total == 3, "PV et or de la défaite reportés")
	verifier(partie.combats_gagnes == 0, "aucun combat gagné")

	# Une partie finie ne bouge plus.
	partie.terminer_combat(combat)
	verifier(partie.or_total == 3, "une partie finie ne bouge plus")
	verifier(partie.portes().is_empty() and not partie.choisir_porte(0), "plus de portes dans une partie finie")


func test_victoire_du_boss() -> void:
	# Le boss de l'étage 3 vaincu : victoire de la partie.
	var partie := Partie.creer(6)
	partie.etage = 3
	partie.pv = 500
	partie.pv_max = 500
	partie.aller_au_boss()
	var combat := gagner(partie)
	verifier(combat.etat == Combat.Etat.VICTOIRE, "des jackpots d'épées vainquent le boss")
	partie.terminer_combat(combat)
	verifier(partie.etat == Partie.Etat.VICTOIRE and partie.ecran == Partie.Ecran.FIN, "boss de l'étage 3 vaincu : victoire de la partie")
	verifier(partie.combats_gagnes == 1 and partie.boss_vaincus == 1 and partie.or_total == combat.ennemi.or_victoire,
			"or du boss compté : %d" % partie.or_total)

	# Un boss d'un autre étage ne finit pas la partie.
	var partie2 := Partie.creer(7)
	partie2.aller_au_boss()
	partie2.terminer_combat(gagner(partie2))
	verifier(partie2.etat == Partie.Etat.EN_COURS and partie2.ecran == Partie.Ecran.RELIQUE, "boss de l'étage 1 vaincu : une relique, la partie continue")


func test_recompenses() -> void:
	var partie := Partie.creer(7)
	var toutes_ok := true
	var vus := {}
	for essai in 200:
		var propositions := partie.proposer_recompenses()
		if propositions.size() != 3:
			toutes_ok = false
		var ids := {}
		for symbole in propositions:
			ids[symbole.id] = true
			vus[symbole.id] = true
			if symbole.id == &"crane":
				toutes_ok = false
		if ids.size() != 3:
			toutes_ok = false
	verifier(toutes_ok, "toujours 3 récompenses différentes, jamais de crâne (200 essais)")
	verifier(vus.size() == 4, "les 4 symboles de base sont proposés tour à tour : %d" % vus.size())

	# Choisir ajoute au sac ; passer ne change rien.
	var avant := partie.sac.taille()
	partie.choisir_recompense(partie.proposer_recompenses()[0])
	verifier(partie.sac.taille() == avant + 1, "choisir une récompense : sac à %d" % partie.sac.taille())
	verifier(partie.sac.taille() == 16, "le sac passe de 15 à 16 symboles")
	var apres := partie.sac.taille()
	partie.proposer_recompenses()
	verifier(partie.sac.taille() == apres, "regarder les récompenses (ou passer) ne change pas le sac")

	# Même graine = mêmes propositions.
	var a := Partie.creer(8).proposer_recompenses()
	var b := Partie.creer(8).proposer_recompenses()
	verifier(a[0].id == b[0].id and a[1].id == b[1].id and a[2].id == b[2].id,
			"même graine, mêmes récompenses")


func test_combat_compte_une_fois() -> void:
	var partie := Partie.creer(9)
	var combat := gagner(partie)
	partie.terminer_combat(combat)
	var or_apres := partie.or_total
	partie.terminer_combat(combat)
	verifier(partie.or_total == or_apres and partie.combats_gagnes == 1, "un combat n'est compté qu'une fois")

	# Un combat pas fini est ignoré.
	var partie2 := Partie.creer(10)
	vers_un_combat(partie2)
	var combat2 := partie2.creer_combat()
	partie2.terminer_combat(combat2)
	verifier(partie2.combats_gagnes == 0 and partie2.combat_courant == combat2, "un combat en cours n'est pas terminé")


func test_aller_au_boss() -> void:
	var partie := Partie.creer(11)
	partie.aller_au_boss()
	verifier(partie.est_combat_de_boss() and partie.ecran == Partie.Ecran.COMBAT, "aller_au_boss mène au combat du boss")
	var combat := partie.creer_combat()
	verifier(combat.ennemi.id == &"rat_croupier" and combat.pv_ennemi == combat.ennemi.pv_max,
			"le combat du boss de l'étage 1 : Rat-Croupier à pleins PV")


## 200 parties jouées sans réfléchir à travers tout le donjon (portes au hasard) : toutes doivent
## se terminer. Le taux de victoire est affiché pour guider l'équilibrage (pas un critère de réussite).
func test_parties_automatiques() -> void:
	var finies := 0
	var victoires := 0
	var coherent := true
	var combats_total := 0
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 5
	for graine in 200:
		var partie := Partie.creer(graine)
		var garde_fou := 0
		while partie.etat == Partie.Etat.EN_COURS and garde_fou < 600:
			match partie.ecran:
				Partie.Ecran.PORTES:
					partie.choisir_porte(hasard.randi_range(0, 1))
				Partie.Ecran.COMBAT:
					var combat := partie.creer_combat()
					jouer_combat_auto(combat)
					partie.terminer_combat(combat)
					combats_total += 1
				Partie.Ecran.RECOMPENSE:
					partie.choisir_recompense(partie.proposer_recompenses()[0])
					partie.terminer_recompense()
				Partie.Ecran.RELIQUE:
					partie.choisir_relique(partie.proposer_reliques(2)[0])
				Partie.Ecran.BOUTIQUE:
					partie.quitter_boutique()
				Partie.Ecran.REPOS:
					_repos_du_robot(partie)
				_:
					coherent = false
					break
			if partie.pv < 0 or partie.pv > partie.pv_max:
				coherent = false
			garde_fou += 1
		if partie.etat != Partie.Etat.EN_COURS:
			finies += 1
		if partie.etat == Partie.Etat.VICTOIRE:
			victoires += 1
	verifier(finies == 200, "les 200 parties automatiques se terminent : %d" % finies)
	verifier(coherent, "PV toujours cohérents sur 200 parties")
	print("  info  parties automatiques : %d victoires sur 200 (%d %%), %d combats joués" % [
		victoires, victoires / 2, combats_total])


func verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		echecs += 1
		print("  ÉCHEC ", message)


## Le repos du robot : se soigne s'il est blessé, sinon dore un symbole, sinon repart sans rien faire.
func _repos_du_robot(partie: Partie) -> void:
	if partie.soin_du_repos() > 0:
		partie.repos_soigner()
		return
	for i in partie.sac.taille():
		if partie.repos_dorer(i):
			return
	partie.quitter_repos()
