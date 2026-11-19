extends SceneTree
## Tests du combat, à lancer en ligne de commande :
## godot --headless --path . -s res://tests/test_combat.gd

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

	test_donnees_ennemis()
	test_degats_a_l_ennemi()
	test_victoire()
	test_armure_du_joueur()
	test_soin()
	test_crane_et_malus()
	test_combo_de_cranes()
	test_defaite()
	test_egalite()
	test_intentions_en_boucle()
	test_armure_de_l_ennemi()
	test_combat_fini()
	test_ennemi_sans_intention()
	test_descriptions()
	test_combats_aleatoires()

	print("TERMINÉ : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


# --- Outils -----------------------------------------------------------------

## Joue un tour avec une grille de 5 cases (null = rouleau vide).
func tour(combat: Combat, symboles: Array) -> Array[String]:
	var grille: Array[SymbolData] = []
	for i in 5:
		grille.append(symboles[i] if i < symboles.size() else null)
	return combat.jouer_tour(machine.resoudre(grille))


func ennemi(nom_fichier: String) -> EnemyData:
	return load("res://data/enemies/%s.tres" % nom_fichier)


func creer_ennemi(pv: int, intentions: Array[Dictionary]) -> EnemyData:
	var donnees := EnemyData.new()
	donnees.nom = "Ennemi de test"
	donnees.pv_max = pv
	donnees.or_victoire = 5
	donnees.intentions = intentions
	return donnees


# --- Tests ------------------------------------------------------------------

func test_donnees_ennemis() -> void:
	var rat := ennemi("rat_egout")
	verifier(rat != null and rat.pv_max == 12, "le rat d'égout a 12 PV")
	verifier(rat.intentions.size() == 1 and rat.intentions[0]["type"] == "attaque",
			"le rat attaque à chaque tour")
	var squelette := ennemi("squelette")
	verifier(squelette != null and squelette.pv_max == 22, "le squelette a 22 PV")
	verifier(squelette.intentions.size() == 2, "le squelette a 2 intentions")
	var golem := ennemi("golem_jetons")
	verifier(golem != null and golem.pv_max == 40, "le golem a 40 PV")


func test_degats_a_l_ennemi() -> void:
	var combat := Combat.new(ennemi("rat_egout"))
	verifier(combat.pv_joueur == 40 and combat.pv_ennemi == 12, "début : 40 PV contre 12 PV")
	tour(combat, [epee])
	verifier(combat.pv_ennemi == 9, "1 épée = 3 dégâts : %d PV restants" % combat.pv_ennemi)
	verifier(combat.pv_joueur == 37, "le rat attaque 3 : %d PV restants" % combat.pv_joueur)
	verifier(combat.numero_tour == 2 and combat.etat == Combat.Etat.EN_COURS,
			"le combat continue au tour 2")


func test_victoire() -> void:
	var combat := Combat.new(ennemi("rat_egout"))
	tour(combat, [epee, epee, epee, epee, epee])
	verifier(combat.etat == Combat.Etat.VICTOIRE, "jackpot d'épées : victoire")
	verifier(combat.pv_ennemi == 0, "PV ennemi à 0 (jamais négatifs) : %d" % combat.pv_ennemi)
	verifier(combat.pv_joueur == 40, "l'ennemi vaincu n'attaque pas : %d PV" % combat.pv_joueur)
	verifier(combat.or_gagne == 5, "or de la victoire : %d" % combat.or_gagne)
	verifier(ennemi("rat_egout").pv_max == 12, "les données de l'ennemi ne sont pas modifiées")


func test_armure_du_joueur() -> void:
	# Armure qui absorbe toute l'attaque.
	var combat := Combat.new(ennemi("rat_egout"))
	tour(combat, [bouclier, null, bouclier])
	verifier(combat.pv_joueur == 40, "6 armure contre attaque 3 : aucun PV perdu (%d)" % combat.pv_joueur)
	verifier(combat.armure_joueur == 0, "l'armure retombe à 0 en fin de tour")

	# Armure qui absorbe une partie seulement : le reste passe aux PV.
	var combat2 := Combat.new(ennemi("golem_jetons"))
	tour(combat2, [bouclier])
	verifier(combat2.pv_joueur == 29, "3 armure contre attaque 14 : 11 PV perdus (%d)" % combat2.pv_joueur)

	# Sans armure.
	var combat3 := Combat.new(ennemi("golem_jetons"))
	tour(combat3, [])
	verifier(combat3.pv_joueur == 26, "sans armure : 14 PV perdus (%d)" % combat3.pv_joueur)


func test_soin() -> void:
	var combat := Combat.new(ennemi("rat_egout"), 30)
	tour(combat, [potion, null, potion])
	verifier(combat.pv_joueur == 33, "2 potions = +6 PV puis attaque 3 : %d" % combat.pv_joueur)

	# Le soin ne dépasse jamais les PV max.
	var combat2 := Combat.new(ennemi("rat_egout"), 38)
	tour(combat2, [potion, null, potion])
	verifier(combat2.pv_joueur == 37, "soin plafonné à 40 PV puis attaque 3 : %d" % combat2.pv_joueur)


func test_crane_et_malus() -> void:
	var combat := Combat.new(ennemi("rat_egout"))
	tour(combat, [crane])
	verifier(combat.pv_joueur == 36, "1 crâne : l'attaque du rat fait 3+1 : %d PV" % combat.pv_joueur)
	tour(combat, [])
	verifier(combat.pv_joueur == 33, "le malus du crâne ne dure qu'un tour : %d PV" % combat.pv_joueur)


func test_combo_de_cranes() -> void:
	# Combo de crânes : -6 PV, l'armure ne protège pas de cette perte.
	var combat := Combat.new(ennemi("rat_egout"))
	tour(combat, [crane, crane, crane, bouclier])
	verifier(combat.pv_joueur == 34,
			"combo de crânes : -6 PV malgré l'armure, attaque 3 absorbée : %d PV" % combat.pv_joueur)


func test_defaite() -> void:
	var combat := Combat.new(ennemi("rat_egout"), 3)
	tour(combat, [])
	verifier(combat.etat == Combat.Etat.DEFAITE, "à 0 PV après l'attaque : défaite")
	verifier(combat.pv_joueur == 0, "PV du joueur jamais négatifs : %d" % combat.pv_joueur)

	# Mort par les crânes : l'ennemi n'a même pas le temps d'attaquer.
	var combat2 := Combat.new(ennemi("rat_egout"), 6)
	var journal := tour(combat2, [crane, crane, crane])
	verifier(combat2.etat == Combat.Etat.DEFAITE, "combo de crânes à 6 PV : défaite")
	var attaque_ennemie := false
	for ligne in journal:
		if "attaque" in ligne:
			attaque_ennemie = true
	verifier(not attaque_ennemie, "l'ennemi n'attaque pas après la mort du joueur")


func test_egalite() -> void:
	# L'ennemi et le joueur tombent à 0 dans le même tirage : victoire.
	var fragile := creer_ennemi(3, [{"type": "attaque", "valeur": 1}])
	var combat := Combat.new(fragile, 6)
	tour(combat, [epee, crane, crane, crane])
	verifier(combat.etat == Combat.Etat.VICTOIRE, "égalité : la victoire est prioritaire")


func test_intentions_en_boucle() -> void:
	var combat := Combat.new(ennemi("squelette"))
	verifier(combat.intention_actuelle()["type"] == "protection", "tour 1 du squelette : il se protège")
	tour(combat, [])
	verifier(combat.intention_actuelle()["type"] == "attaque", "tour 2 du squelette : il attaque")
	tour(combat, [])
	verifier(combat.intention_actuelle()["type"] == "protection", "tour 3 : retour à la protection")


func test_armure_de_l_ennemi() -> void:
	# Tour 1 : le squelette se protège (+5 armure).
	var combat := Combat.new(ennemi("squelette"))
	tour(combat, [])
	verifier(combat.armure_ennemi == 5, "le squelette gagne 5 armure : %d" % combat.armure_ennemi)
	verifier(combat.pv_joueur == 40, "se protéger ne blesse pas le joueur")

	# Tour 2 : l'armure absorbe 3 dégâts, puis retombe quand il agit.
	tour(combat, [epee])
	verifier(combat.pv_ennemi == 22, "l'armure absorbe l'épée : %d PV" % combat.pv_ennemi)
	verifier(combat.armure_ennemi == 0, "l'armure de l'ennemi retombe quand il agit")
	verifier(combat.pv_joueur == 34, "le squelette attaque 6 : %d PV" % combat.pv_joueur)

	# L'armure absorbe d'abord, le surplus touche l'ennemi.
	var combat2 := Combat.new(ennemi("squelette"))
	tour(combat2, [])
	tour(combat2, [epee, epee, epee])
	verifier(combat2.pv_ennemi == 12, "combo de 3 épées (15) - 5 armure = 10 dégâts : %d PV" % combat2.pv_ennemi)


func test_combat_fini() -> void:
	var combat := Combat.new(ennemi("rat_egout"))
	tour(combat, [epee, epee, epee, epee, epee])
	var journal := tour(combat, [epee])
	verifier(journal.is_empty(), "plus rien ne se passe après la fin du combat")
	verifier(combat.numero_tour == 1 and combat.pv_joueur == 40, "l'état ne bouge plus après la fin")


func test_ennemi_sans_intention() -> void:
	var inerte := creer_ennemi(10, [])
	var combat := Combat.new(inerte)
	verifier(combat.intention_actuelle().is_empty(), "un ennemi sans intention renvoie {}")
	tour(combat, [epee])
	verifier(combat.pv_joueur == 40 and combat.pv_ennemi == 7, "un ennemi sans intention n'agit pas")


func test_descriptions() -> void:
	verifier(Intentions.decrire({"type": "attaque", "valeur": 3}) == "Attaque 3", "texte d'une attaque")
	verifier("5" in Intentions.decrire({"type": "protection", "valeur": 5}), "texte d'une protection")
	verifier(Intentions.decrire({"type": "inconnu"}) == "Intention inconnue", "type d'intention inconnu")


## Des centaines de combats au hasard : ils se terminent tous, PV toujours cohérents.
func test_combats_aleatoires() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ok := true
	var finis := 0
	for nom_ennemi in ["rat_egout", "squelette", "golem_jetons"]:
		for essai in 100:
			var sac := Sac.creer_sac_de_depart()
			var combat := Combat.new(ennemi(nom_ennemi))
			var tours := 0
			while not combat.est_fini() and tours < 200:
				combat.jouer_tour(machine.resoudre(machine.tirer(sac, rng)))
				tours += 1
				if combat.pv_joueur < 0 or combat.pv_joueur > combat.pv_max_joueur \
						or combat.pv_ennemi < 0 or combat.armure_joueur < 0 or combat.armure_ennemi < 0:
					ok = false
			if combat.est_fini():
				finis += 1
	verifier(ok, "PV et armure toujours cohérents sur 300 combats au hasard")
	verifier(finis == 300, "les 300 combats au hasard se terminent : %d" % finis)


func verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		echecs += 1
		print("  ÉCHEC ", message)
