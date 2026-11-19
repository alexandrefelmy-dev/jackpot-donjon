extends SceneTree
## Tests des mises (et plus tard des relances), à lancer en ligne de commande :
## godot --headless --path . -s res://tests/test_mises.gd

var echecs := 0
var machine := MachineASous.new(5, 1)

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

	test_mise_objet()
	test_peut_miser()
	test_mise_or_gagnee()
	test_mise_or_perdue()
	test_combo_de_cranes_ne_compte_pas()
	test_quitte_ou_double_gagne()
	test_quitte_ou_double_perdu()
	test_mise_et_mort_de_l_ennemi()
	test_mise_invalide()
	test_jeton_porte_bonheur()
	test_deux_temps_equivaut_a_l_ancien_tour()
	test_deux_temps_etats()
	test_de_pipe()
	test_cinquieme_as()
	test_relances_et_trefle()
	test_relances_et_mises()
	test_combats_aleatoires_avec_mises()
	test_combats_deux_temps_avec_toutes_les_reliques()

	print("TERMINÉ : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


# --- Outils -----------------------------------------------------------------

## Un ennemi de test à valeurs fixes : 100 PV, ne fait jamais rien (il se contente de patienter).
func ennemi_passif(pv: int = 100) -> EnemyData:
	var e := EnemyData.new()
	e.nom = "Mannequin"
	e.pv_max = pv
	e.or_victoire = 5
	e.intentions = [{"type": "protection", "valeur": 0}]
	return e


func grille_de(symboles: Array) -> Array[SymbolData]:
	var grille: Array[SymbolData] = []
	for i in 5:
		grille.append(symboles[i] if i < symboles.size() else null)
	return grille


func tour(combat: Combat, symboles: Array, mise: Mise) -> Array[String]:
	return combat.jouer_tour(machine.resoudre(grille_de(symboles)), mise)


func combat_avec(or_depart: int, pv: int = 40) -> Combat:
	return Combat.new(ennemi_passif(), pv, 40, null, 5, or_depart)


# --- Tests ------------------------------------------------------------------

func test_mise_objet() -> void:
	verifier(Mise.aucune().type == Mise.Type.AUCUNE, "pas de mise")
	var or_mise := Mise.en_or(10)
	verifier(or_mise.type == Mise.Type.OR and or_mise.montant == 10, "mise d'or de 10")
	verifier(Mise.quitte_ou_double().type == Mise.Type.QUITTE_OU_DOUBLE, "quitte ou double")
	verifier(Mise.MONTANTS_OR == [5, 10, 20], "les montants autorisés sont 5, 10 et 20")
	verifier("10" in or_mise.libelle() and "5" in Mise.quitte_ou_double().libelle(), "les libellés annoncent le montant")
	verifier(Mise.aucune().libelle() == "Pas de mise", "libellé de l'absence de mise")


func test_peut_miser() -> void:
	var combat := combat_avec(10, 40)
	verifier(combat.peut_miser(null) and combat.peut_miser(Mise.aucune()), "on peut toujours ne pas miser")
	verifier(combat.peut_miser(Mise.en_or(5)) and combat.peut_miser(Mise.en_or(10)), "10 or permettent de miser 5 ou 10")
	verifier(not combat.peut_miser(Mise.en_or(20)), "10 or ne permettent pas de miser 20")
	verifier(not combat.peut_miser(Mise.en_or(7)), "un montant non autorisé (7) est refusé")
	verifier(combat_avec(0).peut_miser(Mise.en_or(5)) == false, "sans or, pas de mise d'or")
	verifier(combat.peut_miser(Mise.quitte_ou_double()), "40 PV : quitte ou double possible")
	verifier(combat_avec(0, 6).peut_miser(Mise.quitte_ou_double()), "6 PV : quitte ou double possible")
	verifier(not combat_avec(0, 5).peut_miser(Mise.quitte_ou_double()), "5 PV : quitte ou double refusé")
	verifier(not combat_avec(0, 1).peut_miser(Mise.quitte_ou_double()), "1 PV : quitte ou double refusé")
	# L'or du combat compte (pièces tirées) et les vols aussi.
	var combat2 := combat_avec(0)
	tour(combat2, [piece, piece, piece], null)
	verifier(combat2.peut_miser(Mise.en_or(10)), "les pièces tirées pendant le combat permettent de miser (10 or)")


func test_mise_or_gagnee() -> void:
	var combat := combat_avec(20)
	var journal := tour(combat, [epee, epee, epee, bouclier, null], Mise.en_or(10))
	verifier(combat.or_gagne == 20, "mise de 10 gagnée : +20 or net (reçoit 30, mise 10) : %d" % combat.or_gagne)
	verifier(combat.or_du_joueur() == 40, "20 or + 20 de gain = 40 or : %d" % combat.or_du_joueur())
	var parle := false
	for ligne in journal:
		if "gagnée" in ligne and "30" in ligne:
			parle = true
	verifier(parle, "le journal annonce la mise gagnée et les 30 or reçus")
	verifier(combat.pv_ennemi == 100 - 15, "le tirage s'applique normalement : %d PV" % combat.pv_ennemi)

	for montant in [5, 20]:
		var c := combat_avec(20)
		tour(c, [epee, epee, epee, null, null], Mise.en_or(montant))
		verifier(c.or_gagne == montant * 2, "mise de %d gagnée : +%d or net : %d" % [montant, montant * 2, c.or_gagne])

	# Un combo de 4 ou de 5 compte aussi (au moins un combo).
	var c4 := combat_avec(20)
	tour(c4, [epee, epee, epee, epee, null], Mise.en_or(5))
	verifier(c4.or_gagne == 10, "un combo de 4 gagne la mise d'or aussi")


func test_mise_or_perdue() -> void:
	var combat := combat_avec(20)
	var journal := tour(combat, [epee, bouclier, epee, potion, null], Mise.en_or(10))
	verifier(combat.or_gagne == -10 and combat.or_du_joueur() == 10, "mise de 10 perdue : -10 or : %d" % combat.or_gagne)
	var parle := false
	for ligne in journal:
		if "perdue" in ligne:
			parle = true
	verifier(parle, "le journal annonce la mise perdue")

	# Les pièces tirées dans le même tour ne sont pas perdues avec la mise.
	var combat2 := combat_avec(10)
	tour(combat2, [piece, epee, piece, bouclier, null], Mise.en_or(10))
	verifier(combat2.or_gagne == 4 - 10 and combat2.or_du_joueur() == 4, "2 pièces (4 or) et mise perdue (10) : or %d" % combat2.or_du_joueur())

	# Miser tout son or : on se retrouve à 0, jamais en dessous.
	var combat3 := combat_avec(20)
	tour(combat3, [epee, bouclier, epee, potion, null], Mise.en_or(20))
	verifier(combat3.or_du_joueur() == 0, "miser tout son or et perdre : 0 or")


func test_combo_de_cranes_ne_compte_pas() -> void:
	var combat := combat_avec(20)
	tour(combat, [crane, crane, crane, epee, null], Mise.en_or(10))
	verifier(combat.or_gagne == -10, "un combo de crânes ne gagne pas la mise : %d" % combat.or_gagne)
	# Un combo de crânes ET un autre combo : la mise est gagnée.
	var machine6 := MachineASous.new(6, 1)
	var g: Array[SymbolData] = [crane, crane, crane, epee, epee, epee]
	var combat2 := Combat.new(ennemi_passif(), 40, 40, null, 6, 20)
	combat2.jouer_tour(machine6.resoudre(g), Mise.en_or(10))
	verifier(combat2.or_gagne == 20, "un combo de crânes et un combo d'épées : la mise est gagnée")


func test_quitte_ou_double_gagne() -> void:
	var combat := combat_avec(0, 30)
	# Aucun crâne : tous les effets positifs sont doublés.
	var resultat := machine.resoudre(grille_de([epee, epee, bouclier, potion, piece]))
	var journal := combat.jouer_tour(resultat, Mise.quitte_ou_double())
	verifier(combat.pv_ennemi == 100 - 12, "dégâts doublés : 6 deviennent 12 : %d PV" % combat.pv_ennemi)
	verifier(combat.pv_joueur == 36, "soin doublé (3 devient 6) : 30 + 6 = 36 PV : %d" % combat.pv_joueur)
	verifier(combat.armure_joueur == 0, "l'armure retombe en fin de tour comme d'habitude")
	verifier(combat.or_gagne == 4, "or doublé (2 -> 4) : %d" % combat.or_gagne)
	var parle := false
	for ligne in journal:
		if "Quitte ou double gagné" in ligne:
			parle = true
	verifier(parle, "le journal annonce le quitte ou double gagné")
	verifier(resultat.total("degats") == 12 and resultat.total("armure") == 6, "le résultat du tirage affiche les valeurs doublées")

	# L'armure doublée absorbe vraiment plus.
	var attaquant := EnemyData.new()
	attaquant.pv_max = 100
	attaquant.intentions = [{"type": "attaque", "valeur": 5}]
	var combat2 := Combat.new(attaquant, 30, 40, null, 5, 0)
	combat2.jouer_tour(machine.resoudre(grille_de([bouclier, null, null, null, null])), Mise.quitte_ou_double())
	verifier(combat2.pv_joueur == 30, "bouclier doublé (6 armure) absorbe l'attaque de 5 : %d PV" % combat2.pv_joueur)

	# Un combo est doublé aussi.
	var combat3 := combat_avec(0, 30)
	tour(combat3, [epee, epee, epee, null, null], Mise.quitte_ou_double())
	verifier(combat3.pv_ennemi == 100 - 30, "combo de 3 épées doublé : 30 dégâts : %d" % combat3.pv_ennemi)
	verifier(combat3.pv_joueur == 30, "gagner un quitte ou double ne coûte pas de PV")


func test_quitte_ou_double_perdu() -> void:
	var combat := combat_avec(0, 30)
	var journal := tour(combat, [epee, bouclier, crane, null, null], Mise.quitte_ou_double())
	verifier(combat.pv_joueur == 25, "crâne visible : -5 PV : %d" % combat.pv_joueur)
	verifier(combat.pv_ennemi == 100 - 3, "pas de doublement : 3 dégâts : %d" % combat.pv_ennemi)
	verifier(combat.armure_joueur == 0, "pas de doublement de l'armure non plus (retombée en fin de tour)")
	var parle := false
	for ligne in journal:
		if "Quitte ou double perdu" in ligne:
			parle = true
	verifier(parle, "le journal annonce le quitte ou double perdu")

	# Les PV perdus ignorent l'armure.
	var combat2 := combat_avec(0, 30)
	tour(combat2, [bouclier, bouclier, bouclier, crane, null], Mise.quitte_ou_double())
	verifier(combat2.pv_joueur == 25, "l'armure ne protège pas des 5 PV perdus : %d" % combat2.pv_joueur)

	# Perdre à 6 PV laisse 1 PV (on ne peut pas mourir du seul quitte ou double).
	var combat3 := combat_avec(0, 6)
	tour(combat3, [epee, crane, null, null, null], Mise.quitte_ou_double())
	verifier(combat3.pv_joueur == 1 and combat3.etat == Combat.Etat.EN_COURS, "6 PV - 5 = 1 PV : toujours vivant")

	# Mais un crâne en combo en plus peut tuer : c'est le risque.
	var combat4 := combat_avec(0, 6)
	tour(combat4, [crane, crane, crane, null, null], Mise.quitte_ou_double())
	verifier(combat4.etat == Combat.Etat.DEFAITE, "quitte ou double perdu + combo de crânes à 6 PV : défaite")


func test_mise_et_mort_de_l_ennemi() -> void:
	# La mise d'or est réglée même si le tirage tue l'ennemi.
	var combat := Combat.new(ennemi_passif(10), 40, 40, null, 5, 20)
	tour(combat, [epee, epee, epee, null, null], Mise.en_or(10))
	verifier(combat.etat == Combat.Etat.VICTOIRE, "le combo tue l'ennemi")
	verifier(combat.or_gagne == 20 + 5, "mise gagnée (+20) puis or de la victoire (+5) : %d" % combat.or_gagne)

	var combat2 := Combat.new(ennemi_passif(3), 40, 40, null, 5, 20)
	tour(combat2, [epee, null, null, null, null], Mise.en_or(10))
	verifier(combat2.etat == Combat.Etat.VICTOIRE and combat2.or_gagne == -10 + 5, "mise perdue malgré la victoire : %d" % combat2.or_gagne)

	# Quitte ou double gagné : dégâts doublés qui tuent.
	var combat3 := Combat.new(ennemi_passif(5), 40, 40, null, 5, 0)
	tour(combat3, [epee, epee, null, null, null], Mise.quitte_ou_double())
	verifier(combat3.etat == Combat.Etat.VICTOIRE, "6 dégâts doublés = 12 tuent un ennemi à 5 PV")


func test_mise_invalide() -> void:
	# Pas assez d'or : la mise est annulée, rien n'est perdu.
	var combat := combat_avec(5)
	var journal := tour(combat, [epee, bouclier, null, null, null], Mise.en_or(10))
	verifier(combat.or_gagne == 0 and combat.or_du_joueur() == 5, "mise impossible : aucun or perdu")
	var annulee := false
	for ligne in journal:
		if "impossible" in ligne:
			annulee = true
	verifier(annulee, "le journal annonce que la mise est annulée")
	verifier(combat.pv_ennemi == 100 - 3, "le tour se joue quand même")

	# Montant interdit.
	var combat2 := combat_avec(100)
	tour(combat2, [epee, bouclier, null, null, null], Mise.en_or(50))
	verifier(combat2.or_gagne == 0, "un montant interdit (50) est annulé")

	# Quitte ou double à 5 PV : annulé.
	var combat3 := combat_avec(0, 5)
	tour(combat3, [epee, crane, null, null, null], Mise.quitte_ou_double())
	verifier(combat3.pv_joueur == 5, "quitte ou double à 5 PV : annulé, aucun PV perdu")

	# Pas de mise : comme avant.
	var combat4 := combat_avec(10)
	tour(combat4, [epee, epee, epee, null, null], Mise.aucune())
	verifier(combat4.or_gagne == 0, "sans mise, aucun or ne bouge")


func test_jeton_porte_bonheur() -> void:
	var combat := combat_avec(50)
	combat.remboursements_de_mise = 1
	tour(combat, [epee, bouclier, null, null, null], Mise.en_or(10))
	verifier(combat.or_gagne == 0 and combat.remboursements_de_mise == 0, "Jeton porte-bonheur : la 1re mise perdue est remboursée : %d" % combat.or_gagne)
	tour(combat, [epee, bouclier, null, null, null], Mise.en_or(10))
	verifier(combat.or_gagne == -10, "la 2e mise perdue n'est pas remboursée : %d" % combat.or_gagne)

	# Une mise gagnée ne consomme pas le jeton.
	var combat2 := combat_avec(50)
	combat2.remboursements_de_mise = 1
	tour(combat2, [epee, epee, epee, null, null], Mise.en_or(10))
	verifier(combat2.remboursements_de_mise == 1 and combat2.or_gagne == 20, "une mise gagnée ne consomme pas le jeton")
	tour(combat2, [epee, bouclier, null, null, null], Mise.en_or(10))
	verifier(combat2.or_gagne == 20 and combat2.remboursements_de_mise == 0, "puis la 1re mise perdue est remboursée")

	# Le jeton ne concerne pas le quitte ou double.
	var combat3 := combat_avec(0, 30)
	combat3.remboursements_de_mise = 1
	tour(combat3, [epee, crane, null, null, null], Mise.quitte_ou_double())
	verifier(combat3.pv_joueur == 25 and combat3.remboursements_de_mise == 1, "le jeton ne rembourse pas les PV du quitte ou double")

	# Chaque combat recommence : la partie remet un jeton.
	var partie := partie_neuve(21)
	partie.ajouter_relique(Reliques.charger(&"jeton_porte_bonheur"))
	partie.or_total = 50
	var premier := partie.creer_combat()
	verifier(premier.remboursements_de_mise == 1, "un combat commence avec 1 remboursement avec le Jeton")
	premier.jouer_tour(machine.resoudre(grille_de([epee, bouclier, null, null, null])), Mise.en_or(10))
	verifier(premier.remboursements_de_mise == 0, "le jeton est consommé")
	var sans := partie_neuve(22)
	verifier(sans.creer_combat().remboursements_de_mise == 0, "sans la relique, aucun remboursement")


## Une partie neuve qui a déjà franchi sa première porte (un combat) : prête à créer son combat.
func partie_neuve(graine: int) -> Partie:
	var partie := Partie.creer(graine)
	partie.choisir_porte(0)
	return partie


## Une partie avec des reliques données, prête à jouer en deux temps.
func partie_avec_reliques(ids: Array, graine: int) -> Partie:
	var partie := partie_neuve(graine)
	for id in ids:
		partie.ajouter_relique(Reliques.charger(id))
	return partie


func test_deux_temps_equivaut_a_l_ancien_tour() -> void:
	# Sans relique, tirer() + valider() joue exactement le même tour que l'ancienne méthode
	# (tirer à la main, calculer, jouer_tour) : même graine, même partie.
	var ancien := partie_neuve(31)
	var nouveau := partie_neuve(31)
	var c_ancien := ancien.creer_combat()
	var c_nouveau := nouveau.creer_combat()
	var identique := true
	for i in 12:
		if c_ancien.est_fini() or c_nouveau.est_fini():
			break
		var bloques: Array[int] = c_ancien.rouleaux_bloques.duplicate()
		var grille := machine.tirer(ancien.sac, ancien.rng, bloques)
		c_ancien.jouer_tour(machine.resoudre(grille))
		c_nouveau.tirer()
		c_nouveau.valider()
		if c_ancien.pv_joueur != c_nouveau.pv_joueur or c_ancien.pv_ennemi != c_nouveau.pv_ennemi \
				or c_ancien.or_gagne != c_nouveau.or_gagne or c_nouveau.grille_courante != grille:
			identique = false
	verifier(identique, "tirer + valider = l'ancien tour (même graine, 12 tours)")


func test_deux_temps_etats() -> void:
	var partie := partie_neuve(32)
	var combat := partie.creer_combat()
	verifier(not combat.tirage_en_attente and not combat.peut_relancer(), "au départ, aucun tirage en attente")
	verifier(combat.valider().is_empty(), "valider sans tirage ne fait rien")
	verifier(combat.tirer(), "tirer fonctionne")
	verifier(combat.tirage_en_attente and combat.grille_courante.size() == 5 and combat.resultat_courant != null,
			"le tirage est en attente avec ses 5 rouleaux et son résultat")
	verifier(combat.pv_ennemi == combat.ennemi.pv_max, "tirer n'applique encore aucun effet")
	verifier(not combat.tirer(), "on ne peut pas tirer deux fois de suite")
	verifier(not combat.peut_relancer(), "sans relique, aucune relance possible")
	verifier(not combat.relancer_tout() and not combat.relancer_en_gardant(0), "sans relique, relancer est refusé")
	var journal := combat.valider()
	verifier(not combat.tirage_en_attente and not journal.is_empty(), "valider applique le tour et rend le journal")
	verifier(combat.numero_tour == 2 or combat.est_fini(), "le tour est passé")

	# Un combat non préparé ne tire pas.
	var brut := Combat.new(ennemi_passif())
	verifier(not brut.tirer(), "un combat sans machine ne peut pas tirer")

	# Un combat fini ne tire plus.
	var fini := partie_neuve(33).creer_combat()
	fini.etat = Combat.Etat.VICTOIRE
	verifier(not fini.tirer(), "un combat fini ne tire plus")

	# Les rouleaux bloqués par l'ennemi restent vides pendant le tirage.
	var combat2 := partie_neuve(34).creer_combat()
	combat2.rouleaux_bloques = [1, 3]
	combat2.tirer()
	verifier(combat2.grille_courante[1] == null and combat2.grille_courante[3] == null, "les rouleaux bloqués sont vides")
	verifier(combat2.bloques_du_tirage == [1, 3], "le tirage se souvient des rouleaux bloqués")
	combat2.valider()
	verifier(combat2.rouleaux_bloques.is_empty(), "valider libère les rouleaux bloqués")


func test_de_pipe() -> void:
	var partie := partie_avec_reliques([&"de_pipe"], 41)
	var combat := partie.creer_combat()
	verifier(combat.relances_gratuites == 1 and combat.relances_cinquieme_as == 0, "Dé pipé : 1 relance gratuite par combat")
	verifier(not combat.relancer_tout(), "pas de relance avant d'avoir tiré")
	combat.tirer()
	verifier(combat.peut_relancer(), "après le tirage, une relance est possible")
	var avant := combat.grille_courante.duplicate()
	verifier(combat.relancer_tout(), "relancer tous les rouleaux")
	verifier(combat.relances_gratuites == 0 and not combat.peut_relancer(), "la relance est consommée")
	verifier(not combat.relancer_tout(), "une seule relance gratuite par combat")
	verifier(combat.grille_courante.size() == 5, "5 rouleaux après la relance")
	# Le résultat suit la nouvelle grille.
	var recalcul := machine.resoudre(combat.grille_courante)
	verifier(recalcul.totaux == combat.resultat_courant.totaux, "le résultat est recalculé pour la nouvelle grille")
	var journal := combat.valider()
	var parle := false
	for ligne in journal:
		if "Dé pipé" in ligne:
			parle = true
	verifier(parle, "le journal du tour annonce la relance")

	# Une relance change vraiment les rouleaux (sur de nombreuses graines).
	var differents := 0
	for graine in 40:
		var c := partie_avec_reliques([&"de_pipe"], 100 + graine).creer_combat()
		c.tirer()
		var g1 := c.grille_courante.duplicate()
		c.relancer_tout()
		if g1 != c.grille_courante:
			differents += 1
	verifier(differents > 30, "la relance change presque toujours les rouleaux (%d sur 40)" % differents)
	verifier(avant.size() == 5, "(contrôle) la grille d'origine avait 5 rouleaux")

	# Les rouleaux bloqués restent bloqués après la relance.
	var combat2 := partie_avec_reliques([&"de_pipe"], 42).creer_combat()
	combat2.rouleaux_bloques = [2]
	combat2.tirer()
	combat2.relancer_tout()
	verifier(combat2.grille_courante[2] == null, "un rouleau bloqué reste vide après la relance")

	# Une nouvelle relance au combat suivant.
	var partie2 := partie_avec_reliques([&"de_pipe"], 43)
	var premier := partie2.creer_combat()
	premier.tirer()
	premier.relancer_tout()
	premier.valider()
	var second := partie_neuve(43)
	second.ajouter_relique(Reliques.charger(&"de_pipe"))
	verifier(second.creer_combat().relances_gratuites == 1, "chaque combat redonne la relance")


func test_cinquieme_as() -> void:
	var partie := partie_avec_reliques([&"cinquieme_as"], 51)
	var combat := partie.creer_combat()
	verifier(combat.relances_cinquieme_as == 1 and combat.relances_gratuites == 0, "Cinquième as : 1 relance par combat")
	verifier(not combat.relancer_en_gardant(0), "pas de relance avant d'avoir tiré")
	combat.tirer()
	verifier(not combat.relancer_en_gardant(-1) and not combat.relancer_en_gardant(5), "un rouleau qui n'existe pas ne se garde pas")
	verifier(combat.relances_cinquieme_as == 1, "un refus ne consomme pas la relance")
	var symbole_garde := combat.grille_courante[2]
	verifier(combat.relancer_en_gardant(2), "garder le rouleau 3 et relancer les autres")
	verifier(combat.grille_courante[2] == symbole_garde, "le rouleau gardé n'a pas changé")
	verifier(combat.relances_cinquieme_as == 0 and not combat.relancer_en_gardant(2), "une seule fois par combat")
	var recalcul := machine.resoudre(combat.grille_courante)
	verifier(recalcul.totaux == combat.resultat_courant.totaux, "le résultat est recalculé")

	# Sans remise : les symboles relancés viennent du sac privé du symbole gardé.
	var respecte := true
	var garde_ok := true
	var parties_testees := 0
	for graine in 150:
		var p := partie_avec_reliques([&"cinquieme_as"], 200 + graine)
		var c := p.creer_combat()
		c.tirer()
		var garde := graine % 5
		var symbole := c.grille_courante[garde]
		c.relancer_en_gardant(garde)
		if c.grille_courante[garde] != symbole:
			garde_ok = false
		# Aucun symbole ne sort plus de fois qu'il n'y en a dans le sac.
		var vus := {}
		for s in c.grille_courante:
			if s != null:
				var cle := "%s%s" % [s.id, s.doree]
				vus[cle] = int(vus.get(cle, 0)) + 1
		var dans_le_sac := {}
		for s in p.sac.symboles:
			var cle := "%s%s" % [s.id, s.doree]
			dans_le_sac[cle] = int(dans_le_sac.get(cle, 0)) + 1
		for cle in vus:
			if int(vus[cle]) > int(dans_le_sac.get(cle, 0)):
				respecte = false
		parties_testees += 1
	verifier(garde_ok, "le rouleau gardé reste identique (150 relances)")
	verifier(respecte and parties_testees == 150, "tirage sans remise respecté après la relance (150 relances)")

	# Sac de 5 symboles différents : la relance les remet tous, une seule fois chacun.
	var partie2 := partie_avec_reliques([&"cinquieme_as"], 52)
	var petit := Sac.new()
	for s in [epee, bouclier, potion, piece, crane]:
		petit.ajouter(s)
	partie2.sac = petit
	var combat2 := partie2.creer_combat()
	combat2.tirer()
	combat2.relancer_en_gardant(0)
	var ids := {}
	for s in combat2.grille_courante:
		ids[s.id] = true
	verifier(ids.size() == 5, "avec 5 symboles différents, la relance garde les 5 différents : %d" % ids.size())

	# On ne garde pas un rouleau bloqué ni vide.
	var combat3 := partie_avec_reliques([&"cinquieme_as"], 53).creer_combat()
	combat3.rouleaux_bloques = [4]
	combat3.tirer()
	verifier(not combat3.relancer_en_gardant(4) and combat3.relances_cinquieme_as == 1, "un rouleau bloqué ne peut pas être gardé")
	var combat4 := partie_avec_reliques([&"cinquieme_as"], 54).creer_combat()
	combat4.rouleaux_bloques = [0]
	combat4.tirer()
	combat4.relancer_en_gardant(1)
	verifier(combat4.grille_courante[0] == null, "le rouleau bloqué reste bloqué après la relance du Cinquième as")

	# Les deux reliques de relance ensemble : une relance de chaque, dans le même tour.
	var combat5 := partie_avec_reliques([&"de_pipe", &"cinquieme_as"], 55).creer_combat()
	combat5.tirer()
	verifier(combat5.relancer_en_gardant(1) and combat5.relancer_tout(), "Dé pipé et Cinquième as se cumulent dans un tour")
	verifier(not combat5.peut_relancer(), "plus aucune relance ensuite")


func test_relances_et_trefle() -> void:
	# Trèfle certain (chance 1) : jamais de crâne, même après des relances.
	var sac := Sac.new()
	sac.ajouter(crane, 5)
	var mods := Modificateurs.new()
	mods.chance_crane_en_piece = 1.0
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 3
	var combat := Combat.new(ennemi_passif(), 40, 40, hasard, 5, 0)
	combat.preparer_tirages(machine, sac, mods)
	combat.relances_gratuites = 1
	combat.relances_cinquieme_as = 1
	combat.tirer()
	var tout_piece := true
	for s in combat.grille_courante:
		if s.id != &"piece":
			tout_piece = false
	verifier(tout_piece, "Trèfle certain : 5 crânes tirés deviennent 5 pièces")
	verifier(combat.resultat_courant.nb_cranes() == 0 and combat.resultat_courant.total("perte_pv") == 0, "plus aucun crâne visible")
	combat.relancer_tout()
	combat.relancer_en_gardant(0)
	var toujours := true
	for s in combat.grille_courante:
		if s.id != &"piece":
			toujours = false
	verifier(toujours, "le Trèfle agit aussi sur les rouleaux relancés")
	verifier(combat.resultat_courant.combos.size() == 1 and combat.resultat_courant.combos[0].est_jackpot(),
			"5 pièces : jackpot (combo de pièces)")

	# Par la partie : la relique est bien branchée.
	var partie := partie_avec_reliques([&"trefle_quatre_feuilles"], 61)
	var sans_crane := Sac.new()
	sans_crane.ajouter(crane, 5)
	partie.sac = sans_crane
	var pieces := 0
	for graine in 100:
		partie.rng.seed = graine
		var c := partie.creer_combat()
		c.tirer()
		for s in c.grille_courante:
			if s.id == &"piece":
				pieces += 1
	verifier(pieces > 200 and pieces < 300, "avec le Trèfle, environ la moitié des crânes deviennent des pièces (%d sur 500)" % pieces)


func test_relances_et_mises() -> void:
	# La mise se règle sur le tirage final, après la relance.
	var sac := Sac.new()
	sac.ajouter(epee, 5)
	var partie := partie_avec_reliques([&"de_pipe"], 71)
	partie.sac = sac
	partie.or_total = 20
	var combat := partie.creer_combat()
	combat.tirer(Mise.en_or(10))
	combat.relancer_tout()
	combat.valider()
	# 5 épées tuent l'ennemi : à la mise gagnée (+20) s'ajoute l'or de la victoire.
	verifier(combat.etat == Combat.Etat.VICTOIRE and combat.or_gagne == 20 + combat.ennemi.or_victoire,
			"mise d'or gagnée sur le tirage relancé (5 épées) : %d" % combat.or_gagne)

	# Sans combo possible : la mise est perdue et le Jeton la rembourse.
	var sac2 := Sac.new()
	for s in [epee, bouclier, potion, piece, crane]:
		sac2.ajouter(s)
	var partie2 := partie_avec_reliques([&"de_pipe", &"jeton_porte_bonheur"], 72)
	partie2.sac = sac2
	partie2.or_total = 30
	var combat2 := partie2.creer_combat()
	combat2.tirer(Mise.en_or(10))
	combat2.relancer_tout()
	combat2.valider()
	# Les 5 symboles différents sortent toujours : jamais de combo, donc mise perdue puis
	# remboursée par le Jeton ; il ne reste que les 2 or de la pièce.
	verifier(combat2.or_gagne == 2 and combat2.remboursements_de_mise == 0,
			"mise perdue remboursée par le Jeton : seul l'or de la pièce reste (%d)" % combat2.or_gagne)

	# La mise est figée au premier tirage.
	var partie3 := partie_avec_reliques([&"de_pipe"], 73)
	partie3.or_total = 20
	var combat3 := partie3.creer_combat()
	combat3.tirer(Mise.quitte_ou_double())
	verifier(combat3.mise_en_cours != null and combat3.mise_en_cours.type == Mise.Type.QUITTE_OU_DOUBLE, "la mise est gardée pour le tour")
	combat3.relancer_tout()
	verifier(combat3.mise_en_cours.type == Mise.Type.QUITTE_OU_DOUBLE, "la relance ne change pas la mise")
	combat3.valider()
	verifier(combat3.mise_en_cours == null, "après valider, plus de mise en cours")


## Beaucoup de combats avec des mises au hasard et toutes les reliques de mise : ils se terminent,
## et l'or, les PV et l'armure restent cohérents.
func test_combats_aleatoires_avec_mises() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 5
	var coherent := true
	var finis := 0
	for graine in 300:
		var partie := partie_neuve(graine)
		partie.ajouter_relique(Reliques.charger(&"jeton_porte_bonheur"))
		partie.or_total = hasard.randi_range(0, 60)
		var combat := partie.creer_combat()
		var tours := 0
		while not combat.est_fini() and tours < 300:
			var mise := Mise.aucune()
			match hasard.randi_range(0, 4):
				0:
					mise = Mise.en_or(Mise.MONTANTS_OR[hasard.randi_range(0, 2)])
				1:
					mise = Mise.quitte_ou_double()
			var grille := machine.tirer(partie.sac, partie.rng, combat.rouleaux_bloques)
			combat.jouer_tour(machine.resoudre(grille), mise)
			tours += 1
			if combat.pv_joueur < 0 or combat.pv_joueur > combat.pv_max_joueur \
					or combat.armure_joueur < 0 or combat.or_du_joueur() < 0:
				coherent = false
		if combat.est_fini():
			finis += 1
	verifier(coherent, "PV, armure et or toujours cohérents sur 300 combats avec mises au hasard")
	verifier(finis == 300, "les 300 combats avec mises se terminent : %d" % finis)


## Des combats complets joués en deux temps, avec les 9 reliques, des mises et des relances au hasard :
## ils se terminent, et PV, or, armure et sac restent cohérents.
func test_combats_deux_temps_avec_toutes_les_reliques() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 9
	var coherent := true
	var finis := 0
	var relances := 0
	for graine in 200:
		var partie := partie_neuve(graine)
		for r in Reliques.toutes():
			partie.ajouter_relique(r)
		partie.or_total = hasard.randi_range(0, 80)
		var combat := partie.creer_combat()
		var tours := 0
		while not combat.est_fini() and tours < 300:
			var mise := Mise.aucune()
			match hasard.randi_range(0, 3):
				0:
					mise = Mise.en_or(Mise.MONTANTS_OR[hasard.randi_range(0, 2)])
				1:
					mise = Mise.quitte_ou_double()
			if not combat.tirer(mise):
				coherent = false
				break
			if hasard.randi_range(0, 2) == 0 and combat.relancer_tout():
				relances += 1
			if hasard.randi_range(0, 2) == 0 and combat.relancer_en_gardant(hasard.randi_range(0, partie.nb_rouleaux - 1)):
				relances += 1
			combat.valider()
			tours += 1
			if combat.pv_joueur < 0 or combat.pv_joueur > combat.pv_max_joueur or combat.armure_joueur < 0 \
					or combat.or_du_joueur() < 0 or combat.tirage_en_attente \
					or combat.grille_courante.size() != partie.nb_rouleaux:
				coherent = false
		if combat.est_fini():
			finis += 1
	verifier(coherent, "PV, armure, or et grille cohérents sur 200 combats en deux temps avec toutes les reliques")
	verifier(finis == 200, "les 200 combats en deux temps se terminent : %d" % finis)
	verifier(relances > 100, "des relances ont bien eu lieu pendant ces combats (%d)" % relances)


func verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		echecs += 1
		print("  ÉCHEC ", message)
