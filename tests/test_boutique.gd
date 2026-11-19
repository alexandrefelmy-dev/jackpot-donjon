extends SceneTree
## Tests de la boutique et des symboles dorés, à lancer en ligne de commande :
## godot --headless --path . -s res://tests/test_boutique.gd

var echecs := 0

var epee: SymbolData
var bouclier: SymbolData
var potion: SymbolData
var piece: SymbolData
var crane: SymbolData


func _init() -> void:
	epee = load("res://data/symbols/epee.tres")
	bouclier = load("res://data/symbols/bouclier.tres")
	potion = load("res://data/symbols/potion.tres")
	piece = load("res://data/symbols/piece.tres")
	crane = load("res://data/symbols/crane.tres")

	test_prix_des_symboles()
	test_symbole_dore()
	test_sac()
	test_offres()
	test_achat()
	test_retrait()
	test_amelioration()
	test_soin()
	test_parties_avec_boutique()

	print("TERMINÉ : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


# --- Outils -----------------------------------------------------------------

## Une partie neuve avec de l'or.
func partie_avec(or_depart: int, graine: int = 1) -> Partie:
	var partie := Partie.creer(graine)
	partie.or_total = or_depart
	return partie


# --- Tests ------------------------------------------------------------------

func test_prix_des_symboles() -> void:
	verifier(epee.prix > 0 and bouclier.prix > 0 and potion.prix > 0 and piece.prix > 0,
			"les 4 symboles de base ont un prix")
	verifier(crane.prix == 0, "le crâne n'a pas de prix (jamais vendu)")
	var dans_la_fourchette := true
	for symbole in [epee, bouclier, potion, piece]:
		if symbole.prix < 8 or symbole.prix > 15:
			dans_la_fourchette = false
	verifier(dans_la_fourchette, "les prix d'achat sont entre 8 et 15 or")


func test_symbole_dore() -> void:
	var doree := epee.creer_doree()
	verifier(doree.doree and not epee.doree, "la copie est dorée, l'original non")
	verifier(doree.id == epee.id, "le symbole doré garde l'identité de l'original")
	verifier(doree.effet_base["degats"] == 6, "épée dorée : 6 dégâts de base")
	verifier(epee.effet_base["degats"] == 3, "l'épée d'origine garde 3 dégâts (le .tres n'est pas modifié)")
	verifier(doree.effet_combo["degats"] == 15, "l'effet de combo de la copie n'est pas doublé (le combo le fait)")
	verifier(doree.nom_affiche() == "★ " + epee.nom_affiche(), "le nom du doré porte une étoile : %s" % doree.nom_affiche())
	verifier(not epee.nom_affiche().begins_with("★"), "le nom de l'original n'a pas d'étoile")

	# La copie est vraiment indépendante (copie profonde).
	doree.effet_combo["degats"] = 999
	verifier(epee.effet_combo["degats"] == 15, "modifier la copie ne touche pas l'original")
	var crane_dore := crane.creer_doree()
	verifier(crane_dore.effet_base["malus_ennemi"] == 2, "un crâne doré double aussi son malus")

	# Les prix et la couleur sont gardés.
	verifier(doree.prix == epee.prix and doree.couleur == epee.couleur, "la copie garde le prix et la couleur")


func test_sac() -> void:
	var sac := Sac.creer_sac_de_depart()
	verifier(sac.retirer(0) and sac.taille() == 14, "retirer un symbole : 14 restants")
	verifier(not sac.retirer(99) and not sac.retirer(-1) and sac.taille() == 14, "un index invalide ne retire rien")

	var sac2 := Sac.creer_sac_de_depart()
	var avant := sac2.symboles[0]
	verifier(sac2.ameliorer(0), "améliorer un symbole")
	verifier(sac2.symboles[0].doree and not avant.doree, "le symbole du sac est remplacé par sa version dorée")
	verifier(sac2.symboles[0].id == avant.id and sac2.taille() == 15, "même identité, même taille de sac")
	verifier(not sac2.ameliorer(0), "un symbole déjà doré ne s'améliore pas deux fois")
	verifier(not sac2.ameliorer(40), "améliorer un index invalide échoue")
	verifier(epee.effet_base["degats"] == 3, "le .tres d'origine n'est pas modifié par l'amélioration du sac")

	# Groupes : 6 épées, 3 boucliers, 2 potions, 2 pièces, 2 crânes = 5 groupes.
	var sac3 := Sac.creer_sac_de_depart()
	var groupes := sac3.groupes()
	verifier(groupes.size() == 5, "le sac de départ a 5 groupes : %d" % groupes.size())
	verifier(groupes[0]["symbole"].id == &"epee" and groupes[0]["quantite"] == 6 and groupes[0]["index"] == 0,
			"1er groupe : 6 épées à partir de l'index 0")
	var total := 0
	for groupe in groupes:
		total += int(groupe["quantite"])
	verifier(total == 15, "la somme des groupes = 15 symboles")

	# Un doré forme son propre groupe.
	sac3.ameliorer(0)
	var groupes2 := sac3.groupes()
	verifier(groupes2.size() == 6, "un symbole doré forme un groupe à part : %d groupes" % groupes2.size())
	var epees_normales := 0
	var epees_dorees := 0
	for groupe in groupes2:
		if groupe["symbole"].id == &"epee":
			if groupe["symbole"].doree:
				epees_dorees += int(groupe["quantite"])
			else:
				epees_normales += int(groupe["quantite"])
	verifier(epees_dorees == 1 and epees_normales == 5, "1 épée dorée et 5 épées normales")


func test_offres() -> void:
	var tout_bon := true
	var vus := {}
	for graine in 100:
		var boutique := Boutique.creer(partie_avec(0, graine))
		if boutique.offres.size() != 3:
			tout_bon = false
		var ids := {}
		for symbole in boutique.offres:
			ids[symbole.id] = true
			vus[symbole.id] = true
			if symbole.id == &"crane" or symbole.prix <= 0:
				tout_bon = false
		if ids.size() != 3:
			tout_bon = false
	verifier(tout_bon, "toujours 3 offres différentes, jamais de crâne (100 boutiques)")
	verifier(vus.size() == 4, "les 4 symboles de base apparaissent dans les offres : %d" % vus.size())

	var a := Boutique.creer(partie_avec(0, 5))
	var b := Boutique.creer(partie_avec(0, 5))
	verifier(a.offres[0].id == b.offres[0].id and a.offres[1].id == b.offres[1].id and a.offres[2].id == b.offres[2].id,
			"même graine, mêmes offres")
	verifier(a.vendues == [false, false, false], "au début, rien n'est vendu")


func test_achat() -> void:
	var partie := partie_avec(100)
	var boutique := Boutique.creer(partie)
	var offre := boutique.offres[0]
	var prix := boutique.prix_offre(0)
	verifier(prix == offre.prix, "le prix de l'offre est celui du symbole")
	verifier(boutique.acheter(0), "acheter avec assez d'or")
	verifier(partie.or_total == 100 - prix, "l'or est débité : %d" % partie.or_total)
	verifier(partie.sac.taille() == 16 and partie.sac.symboles[15].id == offre.id, "le symbole acheté est dans le sac")
	verifier(boutique.vendues[0] and not boutique.peut_acheter(0), "l'offre achetée disparaît de l'étal")
	verifier(not boutique.acheter(0) and partie.or_total == 100 - prix, "on ne peut pas acheter 2 fois la même offre")

	# Pas assez d'or : rien ne change.
	var pauvre := partie_avec(prix_minimum() - 1)
	var boutique2 := Boutique.creer(pauvre)
	var refuse := true
	for i in 3:
		if boutique2.acheter(i):
			refuse = false
	verifier(refuse and pauvre.or_total == prix_minimum() - 1 and pauvre.sac.taille() == 15,
			"pas assez d'or : aucun achat, rien ne change")

	# Juste assez d'or.
	var juste := partie_avec(0)
	var boutique3 := Boutique.creer(juste)
	juste.or_total = boutique3.prix_offre(1)
	verifier(boutique3.acheter(1) and juste.or_total == 0, "avec exactement le prix, l'achat passe")

	verifier(not boutique.acheter(7) and not boutique.acheter(-1), "une offre qui n'existe pas ne s'achète pas")


## Le prix du symbole le moins cher à la vente.
func prix_minimum() -> int:
	var minimum := 999
	for symbole in [epee, bouclier, potion, piece]:
		minimum = mini(minimum, symbole.prix)
	return minimum


func test_retrait() -> void:
	var partie := partie_avec(100)
	var boutique := Boutique.creer(partie)
	verifier(boutique.prix_retrait() == 10, "1er retrait : 10 or")
	verifier(boutique.retirer(12), "retirer un symbole")
	verifier(partie.or_total == 90 and partie.sac.taille() == 14, "10 or débités, sac à 14 : %d or" % partie.or_total)
	verifier(boutique.prix_retrait() == 15, "2e retrait : 15 or")
	boutique.retirer(0)
	verifier(partie.or_total == 75, "15 or débités : %d" % partie.or_total)
	verifier(boutique.prix_retrait() == 20, "3e retrait : 20 or")
	boutique.retirer(0)
	verifier(partie.or_total == 55 and partie.nb_retraits == 3, "20 or débités, 3 retraits : %d" % partie.or_total)

	# Le prix suit la partie, pas la boutique : une nouvelle visite garde le prix.
	var boutique2 := Boutique.creer(partie)
	verifier(boutique2.prix_retrait() == 25, "une nouvelle boutique garde le prix du 4e retrait : 25 or")

	# Pas assez d'or : rien ne change.
	var pauvre := partie_avec(9)
	var boutique3 := Boutique.creer(pauvre)
	verifier(not boutique3.retirer(0) and pauvre.sac.taille() == 15 and pauvre.or_total == 9 and pauvre.nb_retraits == 0,
			"9 or ne suffisent pas pour un retrait")
	verifier(not boutique3.peut_retirer(99) and not boutique3.peut_retirer(-1), "un index invalide ne se retire pas")

	# On garde au moins un symbole.
	var seul := partie_avec(500)
	seul.sac = Sac.new()
	seul.sac.ajouter(epee, 1)
	var boutique4 := Boutique.creer(seul)
	verifier(not boutique4.retirer(0) and seul.sac.taille() == 1, "on ne retire jamais le dernier symbole du sac")

	# Retirer un crâne.
	var partie5 := partie_avec(50)
	var boutique5 := Boutique.creer(partie5)
	var index_crane := -1
	for i in partie5.sac.taille():
		if partie5.sac.symboles[i].id == &"crane":
			index_crane = i
	boutique5.retirer(index_crane)
	var cranes := 0
	for symbole in partie5.sac.symboles:
		if symbole.id == &"crane":
			cranes += 1
	verifier(cranes == 1, "retirer un crâne : il en reste 1")


func test_amelioration() -> void:
	var partie := partie_avec(50)
	var boutique := Boutique.creer(partie)
	verifier(boutique.prix_amelioration() == 20, "améliorer coûte 20 or")
	verifier(boutique.ameliorer(0), "dorer un symbole")
	verifier(partie.or_total == 30 and partie.sac.symboles[0].doree, "20 or débités, symbole doré : %d or" % partie.or_total)
	verifier(not boutique.peut_ameliorer(0) and not boutique.ameliorer(0) and partie.or_total == 30,
			"un symbole déjà doré ne se redore pas, et rien n'est débité")
	verifier(boutique.ameliorer(1) and partie.or_total == 10, "on peut dorer un autre symbole")

	var pauvre := partie_avec(19)
	var boutique2 := Boutique.creer(pauvre)
	verifier(not boutique2.ameliorer(0) and pauvre.or_total == 19 and not pauvre.sac.symboles[0].doree,
			"19 or ne suffisent pas pour dorer")
	verifier(not boutique2.peut_ameliorer(99), "un index invalide ne s'améliore pas")

	# Le .tres partagé reste intact.
	verifier(not epee.doree and epee.effet_base["degats"] == 3, "le symbole partagé reste intact")


func test_soin() -> void:
	var partie := partie_avec(50)
	partie.pv = 20
	var boutique := Boutique.creer(partie)
	verifier(boutique.peut_soigner(), "on peut se soigner à 20/40 PV")
	verifier(boutique.soigner() and partie.pv == 30 and partie.or_total == 40, "+10 PV pour 10 or : %d PV, %d or" % [partie.pv, partie.or_total])
	boutique.soigner()
	boutique.soigner()
	# De 20 à 40 PV : 2 soins seulement (le 3e est refusé), donc 3 soins demandés = 20 or dépensés au total.
	verifier(partie.pv == 40 and partie.or_total == 30, "le soin s'arrête aux PV max : %d PV, %d or" % [partie.pv, partie.or_total])
	verifier(not boutique.peut_soigner() and not boutique.soigner() and partie.or_total == 30,
			"à PV max, on ne peut plus se soigner et rien n'est débité")

	# Un soin partiel ne dépasse pas les PV max.
	var partie2 := partie_avec(50)
	partie2.pv = 35
	Boutique.creer(partie2).soigner()
	verifier(partie2.pv == 40, "35 + 10 PV plafonné à 40 : %d" % partie2.pv)

	# Sans or.
	var partie3 := partie_avec(9)
	partie3.pv = 10
	var boutique3 := Boutique.creer(partie3)
	verifier(not boutique3.soigner() and partie3.pv == 10 and partie3.or_total == 9, "9 or ne suffisent pas pour se soigner")


## Des parties jouées par un robot qui passe par la boutique après chaque combat : toutes finissent,
## l'or ne devient jamais négatif, les PV restent cohérents. Le taux de victoire est affiché
## pour guider l'équilibrage (ce n'est pas un critère de réussite).
func test_parties_avec_boutique() -> void:
	var machine := MachineASous.new(5, 1)
	var finies := 0
	var victoires := 0
	var coherent := true
	var dores_total := 0
	var retraits_total := 0
	for graine in 200:
		var partie := Partie.creer(graine)
		var garde_fou := 0
		while partie.etat == Partie.Etat.EN_COURS and garde_fou < 20:
			var combat := partie.creer_combat()
			var tours := 0
			while not combat.est_fini() and tours < 300:
				var grille := machine.tirer(partie.sac, partie.rng, combat.rouleaux_bloques)
				combat.jouer_tour(machine.resoudre(grille))
				tours += 1
			partie.terminer_combat(combat)
			if partie.etat == Partie.Etat.EN_COURS:
				partie.choisir_recompense(partie.proposer_recompenses()[0])
				jouer_boutique_robot(partie)
				if partie.or_total < 0 or partie.pv < 0 or partie.pv > partie.pv_max or partie.sac.taille() < 1:
					coherent = false
			garde_fou += 1
		if partie.etat != Partie.Etat.EN_COURS:
			finies += 1
		if partie.etat == Partie.Etat.VICTOIRE:
			victoires += 1
		retraits_total += partie.nb_retraits
		for symbole in partie.sac.symboles:
			if symbole.doree:
				dores_total += 1
	verifier(finies == 200, "les 200 parties avec boutique se terminent : %d" % finies)
	verifier(coherent, "or, PV et sac toujours cohérents dans la boutique")
	print("  info  parties avec boutique : %d victoires sur 200 (%d %%) ; en moyenne %.1f retraits et %.1f dorés par partie" % [
		victoires, victoires / 2, retraits_total / 200.0, dores_total / 200.0])


## Le robot : se soigne s'il manque 10 PV ou plus, retire les crânes, dore une épée,
## puis achète ce qu'il peut.
func jouer_boutique_robot(partie: Partie) -> void:
	var boutique := Boutique.creer(partie)
	while boutique.peut_soigner() and partie.pv <= partie.pv_max - Boutique.SOIN_PV:
		boutique.soigner()
	for i in partie.sac.taille():
		if partie.sac.symboles[i].id == &"crane":
			if boutique.retirer(i):
				break
	for i in partie.sac.taille():
		if partie.sac.symboles[i].id == &"epee" and boutique.ameliorer(i):
			break
	for i in boutique.offres.size():
		boutique.acheter(i)


func verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		echecs += 1
		print("  ÉCHEC ", message)
