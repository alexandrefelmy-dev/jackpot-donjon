extends SceneTree
## Tests de la machine, à lancer en ligne de commande :
## godot --headless --path . -s res://tests/test_machine.gd

var echecs := 0


func _init() -> void:
	var epee := load("res://data/symbols/epee.tres") as SymbolData
	var piece := load("res://data/symbols/piece.tres") as SymbolData
	var crane := load("res://data/symbols/crane.tres") as SymbolData
	var machine := MachineASous.new(5, 1)

	# Sac de départ.
	var sac := Sac.creer_sac_de_depart()
	verifier(sac.taille() == 15, "le sac de départ contient 15 symboles")

	# Un tirage remplit les 5 rouleaux.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var grille := machine.tirer(sac, rng)
	verifier(grille.size() == 5, "un tirage remplit 5 rouleaux")
	verifier(not grille.has(null), "pas de rouleau vide avec 15 symboles")

	# Même graine = même tirage.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	verifier(machine.tirer(sac, rng2) == grille, "même graine, même tirage")

	# Combo de 3 au milieu : 15 dégâts au lieu de 3 × 3.
	var g1: Array[SymbolData] = [piece, epee, epee, epee, crane]
	var r1 := machine.resoudre(g1)
	verifier(r1.combos.size() == 1 and r1.combos[0].debut == 1, "combo de 3 trouvé au milieu")
	verifier(r1.total("degats") == 15, "combo de 3 épées = 15 dégâts : %d" % r1.total("degats"))
	verifier(r1.total("or") == 2, "1 pièce = 2 or : %d" % r1.total("or"))
	verifier(r1.total("malus_ennemi") == 1, "1 crâne = malus 1")

	# Combo de 4 : ×2.
	var g2: Array[SymbolData] = [epee, epee, epee, epee, piece]
	var r2 := machine.resoudre(g2)
	verifier(r2.total("degats") == 30, "combo de 4 épées = 30 dégâts : %d" % r2.total("degats"))

	# Jackpot : ×4.
	var g3: Array[SymbolData] = [epee, epee, epee, epee, epee]
	var r3 := machine.resoudre(g3)
	verifier(r3.combos[0].est_jackpot(), "5 épées = jackpot")
	verifier(r3.total("degats") == 60, "jackpot d'épées = 60 dégâts : %d" % r3.total("degats"))

	# Pas de combo si les symboles ne sont pas côte à côte.
	var g4: Array[SymbolData] = [epee, epee, piece, epee, epee]
	var r4 := machine.resoudre(g4)
	verifier(r4.combos.is_empty(), "4 épées séparées = pas de combo")
	verifier(r4.total("degats") == 12, "4 épées séparées = 12 dégâts : %d" % r4.total("degats"))

	# Combo de crânes : perte de PV, pas de malus de base.
	var g5: Array[SymbolData] = [epee, crane, crane, crane, piece]
	var r5 := machine.resoudre(g5)
	verifier(r5.total("perte_pv") == 6, "combo de crânes = 6 PV perdus")
	verifier(r5.total("malus_ennemi") == 0, "pas de malus de base dans un combo de crânes")

	# Sac trop petit : rouleaux vides.
	var petit := Sac.new()
	petit.ajouter(epee, 2)
	var g6 := machine.tirer(petit, rng)
	verifier(g6.count(null) == 3, "2 symboles -> 3 rouleaux vides")

	# Rouleau bloqué : la case reste vide et casse le combo.
	var bloques: Array[int] = [2]
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 5
	var sac_epees := Sac.new()
	sac_epees.ajouter(epee, 10)
	var g7 := machine.tirer(sac_epees, rng3, bloques)
	verifier(g7[2] == null and g7.count(null) == 1, "un rouleau bloqué reste vide")
	var r7 := machine.resoudre(g7)
	verifier(r7.combos.is_empty(), "le rouleau bloqué casse le combo de 5 épées")
	verifier(r7.total("degats") == 12, "4 épées séparées par un rouleau vide = 12 dégâts : %d" % r7.total("degats"))
	var g8 := machine.tirer(sac_epees, rng3, [])
	verifier(not g8.has(null), "sans blocage, aucun rouleau vide")

	print("TERMINÉ : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


func verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		echecs += 1
		print("  ÉCHEC ", message)
