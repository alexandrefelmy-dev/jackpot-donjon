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
	test_nouveaux_ennemis()
	test_blocage()
	test_vol_d_or()
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


## Ennemis de test aux valeurs fixes : les vrais ennemis (data/enemies/*.tres) sont réglés
## en jouant, ces tests de règles ne doivent pas casser quand on change leurs chiffres.
func ennemi(nom: String) -> EnemyData:
	match nom:
		"rat_egout":
			return creer_ennemi(12, [{"type": "attaque", "valeur": 3}])
		"squelette":
			return creer_ennemi(22, [{"type": "protection", "valeur": 5}, {"type": "attaque", "valeur": 6}])
		"golem_jetons":
			return creer_ennemi(40, [{"type": "attaque", "valeur": 14}])
		"rat_croupier":
			return creer_ennemi(60, [{"type": "attaque", "valeur": 6}, {"type": "blocage", "valeur": 1}])
	return null


## Les vrais ennemis, chargés depuis leur fichier de données.
func donnees(nom_fichier: String) -> EnemyData:
	return load("res://data/enemies/%s.tres" % nom_fichier)


func creer_ennemi(pv: int, intentions: Array[Dictionary]) -> EnemyData:
	var e := EnemyData.new()
	e.nom = "Ennemi de test"
	e.pv_max = pv
	e.or_victoire = 5
	e.intentions = intentions
	return e


# --- Tests ------------------------------------------------------------------

func test_donnees_ennemis() -> void:
	var rat := donnees("rat_egout")
	verifier(rat != null and rat.pv_max == 11, "le rat d'égout a 11 PV")
	verifier(rat.intentions.size() == 1 and rat.intentions[0]["type"] == "attaque",
			"le rat attaque à chaque tour")
	var squelette := donnees("squelette")
	verifier(squelette != null and squelette.pv_max == 20, "le squelette a 20 PV")
	verifier(squelette.intentions.size() == 2 and squelette.intentions[0]["type"] == "protection"
			and squelette.intentions[1]["type"] == "attaque", "le squelette se protège puis attaque")
	var golem := donnees("golem_jetons")
	verifier(golem != null and golem.pv_max > 0, "le golem a des PV (réglés dans le .tres)")
	# Les valeurs d'attaque se règlent dans les .tres : on vérifie juste qu'elles sont positives
	# (sauf « charge » et « fuite », qui n'ont pas de chiffre).
	var valeurs_ok := true
	for nom in ["rat_egout", "squelette", "gobelin_tricheur", "golem_jetons", "rat_croupier"]:
		var e := donnees(nom)
		for intention in e.intentions:
			var sans_chiffre: bool = intention["type"] in [Intentions.CHARGE, Intentions.FUITE]
			if (int(intention["valeur"]) <= 0 and not sans_chiffre) or not Intentions.FORMATS.has(intention["type"]):
				valeurs_ok = false
		if e.pv_max <= 0 or e.or_victoire <= 0 or e.intentions.is_empty():
			valeurs_ok = false
	verifier(valeurs_ok, "tous les ennemis ont des PV, de l'or et des intentions valides")


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
	var partage := donnees("rat_egout")
	var pv_avant := partage.pv_max
	var combat_reel := Combat.new(partage)
	tour(combat_reel, [epee, epee, epee, epee, epee])
	verifier(partage.pv_max == pv_avant and combat_reel.pv_ennemi == 0,
			"les données partagées de l'ennemi ne sont pas modifiées")


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


func test_nouveaux_ennemis() -> void:
	var gobelin := donnees("gobelin_tricheur")
	verifier(gobelin != null and gobelin.pv_max == 16 and gobelin.etage == 1 and not gobelin.est_boss,
			"le gobelin tricheur : 16 PV, étage 1, pas un boss")
	verifier(gobelin.intentions[0]["type"] == "attaque" and gobelin.intentions[1]["type"] == "vol",
			"le gobelin alterne attaque et vol d'or")
	verifier(gobelin.intentions[1]["valeur"] == 3, "le gobelin vole 3 or")
	var boss := donnees("rat_croupier")
	verifier(boss != null and boss.pv_max >= 40 and boss.est_boss and boss.etage == 1,
			"le Rat-Croupier : un boss de l'étage 1 bien costaud")
	verifier(boss.intentions[0]["type"] == "attaque" and boss.intentions[1]["type"] == "blocage",
			"le Rat-Croupier alterne attaque et blocage")
	verifier(donnees("golem_jetons").etage == 2, "le golem est un ennemi de l'étage 2")
	verifier(donnees("rat_egout").etage == 1 and not donnees("rat_egout").est_boss, "le rat : étage 1, pas un boss")


func test_blocage() -> void:
	var boss := ennemi("rat_croupier")
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 11
	var combat := Combat.new(boss, 40, 40, hasard)
	verifier(combat.rouleaux_bloques.is_empty(), "rien n'est bloqué au début du combat")

	# Tour 1 : le boss attaque, rien n'est bloqué.
	tour(combat, [])
	verifier(combat.rouleaux_bloques.is_empty(), "après l'attaque du boss, aucun rouleau bloqué")
	verifier(combat.intention_actuelle()["type"] == "blocage", "tour 2 : le boss annonce un blocage")
	verifier("rouleau" in Intentions.decrire(combat.intention_actuelle()), "le texte de l'intention parle d'un rouleau")

	# Tour 2 : le boss agit après le tirage et bloque un rouleau pour le tirage suivant.
	var journal := tour(combat, [])
	verifier(combat.rouleaux_bloques.size() == 1, "le boss bloque 1 rouleau")
	verifier(combat.rouleaux_bloques[0] >= 0 and combat.rouleaux_bloques[0] <= 4, "le rouleau bloqué existe (0 à 4)")
	verifier(combat.pv_joueur == 34, "le blocage ne fait pas de dégâts : %d PV" % combat.pv_joueur)
	var parle_de_blocage := false
	for ligne in journal:
		if "bloque" in ligne:
			parle_de_blocage = true
	verifier(parle_de_blocage, "le journal annonce le rouleau bloqué")

	# Tour 3 : les rouleaux bloqués servent pour ce tirage, puis sont libérés (le boss attaque).
	tour(combat, [])
	verifier(combat.rouleaux_bloques.is_empty(), "les rouleaux bloqués sont libérés après le tirage")

	# Même graine : même rouleau bloqué.
	var hasard2 := RandomNumberGenerator.new()
	hasard2.seed = 11
	var combat2 := Combat.new(boss, 40, 40, hasard2)
	tour(combat2, [])
	tour(combat2, [])
	var hasard3 := RandomNumberGenerator.new()
	hasard3.seed = 11
	var combat3 := Combat.new(boss, 40, 40, hasard3)
	tour(combat3, [])
	tour(combat3, [])
	verifier(combat2.rouleaux_bloques == combat3.rouleaux_bloques, "même graine, même rouleau bloqué")

	# Plusieurs rouleaux : tous différents.
	var triple := creer_ennemi(50, [{"type": "blocage", "valeur": 3}])
	var combat4 := Combat.new(triple, 40, 40, hasard)
	tour(combat4, [])
	var distincts := {}
	for index in combat4.rouleaux_bloques:
		distincts[index] = true
	verifier(combat4.rouleaux_bloques.size() == 3 and distincts.size() == 3, "3 rouleaux bloqués, tous différents")

	# Un blocage plus grand que la machine ne dépasse pas 5 rouleaux.
	var enorme := creer_ennemi(50, [{"type": "blocage", "valeur": 9}])
	var combat5 := Combat.new(enorme, 40, 40, hasard)
	tour(combat5, [])
	verifier(combat5.rouleaux_bloques.size() == 5, "au plus 5 rouleaux bloqués : %d" % combat5.rouleaux_bloques.size())

	# Les combats au hasard continuent de se terminer avec le boss.
	var sac := Sac.creer_sac_de_depart()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var finis := 0
	var vrai_boss := donnees("rat_croupier")
	for essai in 50:
		var c := Combat.new(vrai_boss, 40, 40, rng)
		var n := 0
		while not c.est_fini() and n < 300:
			var grille := machine.tirer(sac, rng, c.rouleaux_bloques)
			c.jouer_tour(machine.resoudre(grille))
			n += 1
		if c.est_fini():
			finis += 1
	verifier(finis == 50, "50 combats contre le boss se terminent : %d" % finis)


func test_vol_d_or() -> void:
	var voleur := creer_ennemi(30, [{"type": "vol", "valeur": 3}])

	# Le joueur a assez d'or : 3 or volés, ni PV ni armure touchés.
	var combat := Combat.new(voleur, 40, 40, null, 5, 10)
	verifier(combat.or_du_joueur() == 10, "le joueur commence le combat avec 10 or")
	var journal := tour(combat, [])
	verifier(combat.or_vole == 3 and combat.or_du_joueur() == 7, "le voleur prend 3 or : %d restants" % combat.or_du_joueur())
	verifier(combat.pv_joueur == 40, "le vol ne fait pas de dégâts")
	var parle_de_vol := false
	for ligne in journal:
		if "vole" in ligne:
			parle_de_vol = true
	verifier(parle_de_vol, "le journal annonce le vol")
	verifier("3" in Intentions.decrire({"type": "vol", "valeur": 3}) and "or" in Intentions.decrire({"type": "vol", "valeur": 3}),
			"le texte de l'intention annonce le vol d'or")

	# Jamais plus que l'or possédé.
	var combat2 := Combat.new(voleur, 40, 40, null, 5, 2)
	tour(combat2, [])
	verifier(combat2.or_vole == 2 and combat2.or_du_joueur() == 0, "le voleur ne prend que les 2 or du joueur")
	tour(combat2, [])
	verifier(combat2.or_vole == 2, "plus rien à voler : l'or volé n'augmente pas")

	# Sans or du tout.
	var combat3 := Combat.new(voleur, 40, 40)
	var journal3 := tour(combat3, [])
	verifier(combat3.or_vole == 0 and combat3.or_du_joueur() == 0, "sans or, rien n'est volé")
	var tente := false
	for ligne in journal3:
		if "tente" in ligne:
			tente = true
	verifier(tente, "le journal dit que le voleur n'a rien trouvé")

	# Les pièces tirées pendant le combat peuvent être volées aussi.
	var piece := load("res://data/symbols/piece.tres") as SymbolData
	var combat4 := Combat.new(voleur, 40, 40)
	tour(combat4, [piece, piece])
	verifier(combat4.or_gagne == 4 and combat4.or_vole == 3 and combat4.or_du_joueur() == 1,
			"2 pièces (4 or) puis vol de 3 : il reste 1 or")

	# Un voleur vaincu ne vole pas.
	var fragile := creer_ennemi(3, [{"type": "vol", "valeur": 3}])
	var combat5 := Combat.new(fragile, 40, 40, null, 5, 10)
	tour(combat5, [epee])
	verifier(combat5.etat == Combat.Etat.VICTOIRE and combat5.or_vole == 0, "un voleur vaincu ne vole pas")


## Des centaines de combats au hasard : ils se terminent tous, PV toujours cohérents.
func test_combats_aleatoires() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ok := true
	var finis := 0
	for nom_ennemi in ["rat_egout", "squelette", "golem_jetons"]:
		for essai in 100:
			var sac := Sac.creer_sac_de_depart()
			var combat := Combat.new(donnees(nom_ennemi))
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
