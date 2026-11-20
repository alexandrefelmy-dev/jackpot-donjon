extends SceneTree
## Tests des statistiques d'une partie (dégâts, combos, jackpots, mises, or dépensé), à lancer en ligne de commande :
## godot --headless --path . -s res://tests/test_stats.gd
## Les records du profil qui en découlent sont testés dans test_profil.gd.

var echecs := 0
var machine := MachineASous.new(5, 1)
var epee: SymbolData
var bouclier: SymbolData
var crane: SymbolData


func _init() -> void:
	epee = load("res://data/symbols/epee.tres")
	bouclier = load("res://data/symbols/bouclier.tres")
	crane = load("res://data/symbols/crane.tres")
	test_une_instance()
	test_combat()
	test_mises()
	test_partie()
	test_boutique()
	print("TERMINÉ : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


func verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		echecs += 1
		print("  ÉCHEC ", message)


## Un ennemi de test à valeurs fixes (pas les .tres, réglés en jouant) : beaucoup de PV, une petite attaque.
func ennemi_costaud() -> EnemyData:
	var e := EnemyData.new()
	e.nom = "Ennemi de test"
	e.pv_max = 1000
	e.or_victoire = 5
	e.intentions = [{"type": "attaque", "valeur": 1}] as Array[Dictionary]
	return e


func grille_de(symboles: Array) -> Array[SymbolData]:
	var grille: Array[SymbolData] = []
	for i in 5:
		grille.append(symboles[i] if i < symboles.size() else null)
	return grille


func jouer(combat: Combat, symboles: Array, mise: Mise = null) -> void:
	combat.jouer_tour(machine.resoudre(grille_de(symboles)), mise)


func test_une_instance() -> void:
	print("Les compteurs")
	var stats := StatsPartie.new()
	verifier(stats.degats_infliges == 0 and stats.tours_joues == 0 and stats.jackpots == 0 and stats.plus_long_combo == 0
			and stats.mises_jouees == 0 and stats.mises_gagnees == 0 and stats.or_depense == 0, "tout part de 0")
	var autre := StatsPartie.new()
	autre.degats_infliges = 10
	autre.plus_long_combo = 4
	autre.jackpots = 1
	autre.mises_jouees = 2
	autre.mises_gagnees = 1
	stats.plus_long_combo = 3
	stats.ajouter(autre)
	stats.ajouter(autre)
	verifier(stats.degats_infliges == 20 and stats.jackpots == 2 and stats.mises_jouees == 4 and stats.mises_gagnees == 2,
			"ajouter additionne les compteurs")
	verifier(stats.plus_long_combo == 4, "…mais garde le plus long combo (un maximum, pas une somme)")


func test_combat() -> void:
	print("Statistiques d'un combat")
	var combat := Combat.new(ennemi_costaud(), 40, 40, RandomNumberGenerator.new(), 5, 50)
	jouer(combat, [epee, bouclier, null, null, null])
	verifier(combat.stats.tours_joues == 1 and combat.stats.degats_infliges == 3, "1 tour, 1 épée : 3 dégâts")
	verifier(combat.stats.plus_long_combo == 0 and combat.stats.jackpots == 0, "pas de combo")
	jouer(combat, [epee, epee, epee, null, null])
	verifier(combat.stats.degats_infliges == 18 and combat.stats.plus_long_combo == 3 and combat.stats.jackpots == 0,
			"un combo de 3 épées : +15 dégâts, plus long combo 3 : %d dégâts" % combat.stats.degats_infliges)
	jouer(combat, [epee, epee, epee, epee, epee])
	verifier(combat.stats.plus_long_combo == 5 and combat.stats.jackpots == 1, "un jackpot : combo de 5, 1 jackpot")
	jouer(combat, [bouclier, bouclier, bouclier, bouclier, null])
	verifier(combat.stats.plus_long_combo == 5 and combat.stats.jackpots == 1 and combat.stats.tours_joues == 4,
			"un combo de 4 plus court ne baisse pas le plus long ; 4 tours joués")
	var fini := Combat.new(ennemi_costaud(), 40, 40, RandomNumberGenerator.new(), 5, 0)
	fini.etat = Combat.Etat.VICTOIRE
	jouer(fini, [epee, epee, epee, epee, epee])
	verifier(fini.stats.tours_joues == 0 and fini.stats.degats_infliges == 0, "un combat fini ne compte plus rien")


func test_mises() -> void:
	print("Mises jouées et gagnées")
	var combat := Combat.new(ennemi_costaud(), 40, 40, RandomNumberGenerator.new(), 5, 100)
	jouer(combat, [epee, epee, epee, null, null], Mise.en_or(10))
	verifier(combat.stats.mises_jouees == 1 and combat.stats.mises_gagnees == 1, "mise d'or avec un combo : jouée et gagnée")
	jouer(combat, [epee, bouclier, null, null, null], Mise.en_or(10))
	verifier(combat.stats.mises_jouees == 2 and combat.stats.mises_gagnees == 1, "mise d'or sans combo : jouée, pas gagnée")
	jouer(combat, [epee, bouclier, null, null, null], Mise.quitte_ou_double())
	verifier(combat.stats.mises_jouees == 3 and combat.stats.mises_gagnees == 2, "quitte ou double sans crâne : gagné")
	jouer(combat, [epee, crane, null, null, null], Mise.quitte_ou_double())
	verifier(combat.stats.mises_jouees == 4 and combat.stats.mises_gagnees == 2, "quitte ou double avec un crâne : perdu")
	jouer(combat, [epee, epee, epee, null, null], Mise.aucune())
	verifier(combat.stats.mises_jouees == 4, "sans mise, rien n'est compté")
	var pauvre := Combat.new(ennemi_costaud(), 40, 40, RandomNumberGenerator.new(), 5, 3)
	jouer(pauvre, [epee, epee, epee, null, null], Mise.en_or(10))
	verifier(pauvre.stats.mises_jouees == 0, "une mise impossible (pas assez d'or) n'est pas comptée")


func test_partie() -> void:
	print("Statistiques de la partie")
	var partie := Partie.creer(5)
	partie.ennemi_courant = ennemi_costaud()  # le vrai rat mourrait au premier jackpot : plus de tour à compter
	var combat := partie.creer_combat()
	jouer(combat, [epee, epee, epee, epee, epee])
	jouer(combat, [epee, epee, epee, null, null])
	combat.etat = Combat.Etat.VICTOIRE
	partie.terminer_combat(combat)
	verifier(partie.stats.tours_joues == 2 and partie.stats.jackpots == 1 and partie.stats.plus_long_combo == 5,
			"un combat fini est reporté sur la partie : %d tours" % partie.stats.tours_joues)
	var degats := partie.stats.degats_infliges
	partie.terminer_combat(combat)
	verifier(partie.stats.degats_infliges == degats, "un combat n'est compté qu'une fois")
	partie.terminer_recompense()
	partie.ennemi_courant = ennemi_costaud()
	var combat2 := partie.creer_combat()
	jouer(combat2, [epee, epee, epee, epee, null])
	combat2.etat = Combat.Etat.DEFAITE
	partie.terminer_combat(combat2)
	verifier(partie.stats.tours_joues == 3 and partie.stats.plus_long_combo == 5 and partie.stats.degats_infliges > degats,
			"un combat perdu compte aussi (et le plus long combo reste 5)")


func test_boutique() -> void:
	print("Or dépensé")
	var partie := Partie.creer(6)
	partie.or_total = 100
	verifier(partie.stats.or_depense == 0, "rien dépensé au départ")
	partie.depenser(12)
	verifier(partie.or_total == 88 and partie.stats.or_depense == 12, "dépenser retire l'or et le compte")
	var boutique := Boutique.creer(partie)
	var avant_or := partie.or_total
	var avant_depense := partie.stats.or_depense
	var achete := boutique.acheter(0)
	verifier(achete and partie.stats.or_depense - avant_depense == avant_or - partie.or_total and partie.or_total < avant_or,
			"un achat en boutique est compté : %d or" % (partie.stats.or_depense - avant_depense))
