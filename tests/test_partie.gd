extends SceneTree
## Tests de la partie, à lancer en ligne de commande :
## godot --headless --path . -s res://tests/test_partie.gd

var echecs := 0
var machine := MachineASous.new(5, 1)


func _init() -> void:
	test_partie_neuve()
	test_rencontres()
	test_enchainement()
	test_defaite()
	test_victoire_du_boss()
	test_recompenses()
	test_combat_compte_une_fois()
	test_aller_au_boss()
	test_parties_automatiques()

	print("TERMINÉ : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


# --- Outils -----------------------------------------------------------------

## Fait gagner le combat en cours d'un coup (jackpot d'épées).
func gagner(partie: Partie) -> Combat:
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
func jouer_combat_auto(partie: Partie, combat: Combat) -> void:
	var tours := 0
	while not combat.est_fini() and tours < 300:
		var grille := machine.tirer(partie.sac, partie.rng, combat.rouleaux_bloques)
		combat.jouer_tour(machine.resoudre(grille))
		tours += 1


# --- Tests ------------------------------------------------------------------

func test_partie_neuve() -> void:
	var partie := Partie.creer(1)
	verifier(partie.pv == 40 and partie.pv_max == 40, "une partie commence à 40 PV")
	verifier(partie.or_total == 0, "une partie commence à 0 or")
	verifier(partie.sac.taille() == 15, "le sac de départ a 15 symboles")
	verifier(partie.numero_combat == 1, "on commence au combat 1")
	verifier(partie.etat == Partie.Etat.EN_COURS, "la partie est en cours")
	verifier(partie.graine == 1, "la graine est gardée : %d" % partie.graine)
	verifier(not partie.est_combat_de_boss(), "le combat 1 n'est pas le boss")


func test_rencontres() -> void:
	var partie := Partie.creer(2)
	verifier(partie.rencontres.size() == 6, "5 combats normaux + le boss = 6 rencontres")
	var tous_etage_1 := true
	for rencontre in partie.rencontres:
		if rencontre.etage != 1:
			tous_etage_1 = false
	verifier(tous_etage_1, "toutes les rencontres sont de l'étage 1")
	verifier(partie.rencontres[5].est_boss and partie.rencontres[5].id == &"rat_croupier",
			"la dernière rencontre est le Rat-Croupier")
	verifier(partie.rencontres.slice(0, 5).all(func(e: EnemyData) -> bool: return not e.est_boss),
			"les 5 premières rencontres ne sont pas des boss")

	# Jamais le même ennemi deux fois de suite, sur beaucoup de parties.
	var jamais_deux_fois := true
	var ennemis_vus := {}
	for graine in 100:
		var p := Partie.creer(graine)
		for i in 4:
			if p.rencontres[i].id == p.rencontres[i + 1].id:
				jamais_deux_fois = false
		for i in 5:
			ennemis_vus[p.rencontres[i].id] = true
	verifier(jamais_deux_fois, "jamais deux fois le même ennemi de suite (100 parties)")
	verifier(ennemis_vus.size() == 3, "les 3 ennemis de l'étage 1 apparaissent : %d" % ennemis_vus.size())

	# Même graine = mêmes rencontres.
	var a := Partie.creer(77)
	var b := Partie.creer(77)
	var identiques := true
	for i in 6:
		if a.rencontres[i].id != b.rencontres[i].id:
			identiques = false
	verifier(identiques, "même graine, mêmes rencontres")
	verifier(Partie.creer().graine >= 0, "sans graine donnée, une graine est choisie")


func test_enchainement() -> void:
	var partie := Partie.creer(3)
	var premier := partie.ennemi_actuel()

	# Combat 1 : on perd un peu de PV, on gagne de l'or.
	var combat := partie.creer_combat()
	verifier(combat.ennemi == premier and combat.pv_joueur == 40, "le combat 1 oppose le joueur au 1er ennemi")
	combat.pv_joueur = 25
	combat.pv_ennemi = 0
	combat.etat = Combat.Etat.VICTOIRE
	combat.or_gagne = 7
	partie.terminer_combat(combat)
	verifier(partie.pv == 25, "les PV restent d'un combat à l'autre : %d" % partie.pv)
	verifier(partie.or_total == 7, "l'or est conservé : %d" % partie.or_total)
	verifier(partie.numero_combat == 2 and partie.combats_gagnes == 1, "on passe au combat 2")
	verifier(partie.etat == Partie.Etat.EN_COURS, "la partie continue")

	# Combat 2 : démarre avec les PV restants.
	var combat2 := partie.creer_combat()
	verifier(combat2.pv_joueur == 25, "le combat 2 démarre avec 25 PV : %d" % combat2.pv_joueur)
	verifier(combat2.ennemi == partie.rencontres[1], "le combat 2 oppose le joueur à la 2e rencontre")
	verifier(combat2.armure_joueur == 0, "l'armure ne se garde pas entre les combats")

	# Les PV max sont respectés par les soins du combat suivant.
	verifier(combat2.pv_max_joueur == 40, "PV max conservés : %d" % combat2.pv_max_joueur)

	# Les 5 combats puis le boss.
	var partie2 := Partie.creer(4)
	for numero in range(1, 6):
		verifier(partie2.numero_combat == numero and not partie2.est_combat_de_boss(), "combat normal %d" % numero)
		gagner(partie2)
		partie2.terminer_combat(partie2.combat_courant)
	verifier(partie2.numero_combat == 6 and partie2.est_combat_de_boss(), "après 5 victoires, c'est le boss")
	verifier(partie2.combats_gagnes == 5, "5 combats gagnés : %d" % partie2.combats_gagnes)


func test_defaite() -> void:
	var partie := Partie.creer(5)
	var combat := partie.creer_combat()
	combat.pv_joueur = 0
	combat.etat = Combat.Etat.DEFAITE
	combat.or_gagne = 3
	partie.terminer_combat(combat)
	verifier(partie.etat == Partie.Etat.DEFAITE, "à 0 PV : défaite de la partie")
	verifier(partie.pv == 0 and partie.or_total == 3, "PV et or de la défaite reportés")
	verifier(partie.combats_gagnes == 0, "aucun combat gagné")

	# Une partie finie ne bouge plus.
	partie.terminer_combat(combat)
	verifier(partie.or_total == 3, "une partie finie ne bouge plus")


func test_victoire_du_boss() -> void:
	var partie := Partie.creer(6)
	partie.aller_au_boss()
	var combat := gagner(partie)
	verifier(combat.etat == Combat.Etat.VICTOIRE, "des jackpots d'épées vainquent le boss")
	partie.terminer_combat(combat)
	verifier(partie.etat == Partie.Etat.VICTOIRE, "boss vaincu : victoire de la partie")
	verifier(partie.numero_combat == 6, "le compteur ne dépasse pas le boss")
	verifier(partie.combats_gagnes == 1 and partie.or_total == combat.ennemi.or_victoire,
			"or du boss compté : %d" % partie.or_total)


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
	verifier(partie.or_total == or_apres and partie.numero_combat == 2, "un combat n'est compté qu'une fois")

	# Un combat pas fini est ignoré.
	var partie2 := Partie.creer(10)
	var combat2 := partie2.creer_combat()
	partie2.terminer_combat(combat2)
	verifier(partie2.numero_combat == 1 and partie2.combat_courant == combat2, "un combat en cours n'est pas terminé")


func test_aller_au_boss() -> void:
	var partie := Partie.creer(11)
	partie.aller_au_boss()
	verifier(partie.est_combat_de_boss() and partie.numero_combat == 6, "aller_au_boss mène au combat 6")
	var combat := partie.creer_combat()
	verifier(combat.ennemi.id == &"rat_croupier" and combat.pv_ennemi == combat.ennemi.pv_max,
			"le combat du boss : Rat-Croupier à pleins PV")


## 200 parties jouées sans réfléchir : toutes doivent se terminer. Le taux de victoire
## est affiché pour guider l'équilibrage (ce n'est pas un critère de réussite).
func test_parties_automatiques() -> void:
	var finies := 0
	var victoires := 0
	var coherent := true
	var combats_total := 0
	for graine in 200:
		var partie := Partie.creer(graine)
		var garde_fou := 0
		while partie.etat == Partie.Etat.EN_COURS and garde_fou < 20:
			var combat := partie.creer_combat()
			jouer_combat_auto(partie, combat)
			partie.terminer_combat(combat)
			combats_total += 1
			if partie.pv < 0 or partie.pv > partie.pv_max:
				coherent = false
			if partie.etat == Partie.Etat.EN_COURS:
				partie.choisir_recompense(partie.proposer_recompenses()[0])
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
