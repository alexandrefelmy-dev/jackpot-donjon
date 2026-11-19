extends SceneTree
## Tests des 4 symboles à débloquer (Bombe, Flèche, Aimant, Trèfle), à lancer en ligne de commande :
## godot --headless --path . -s res://tests/test_symboles.gd

var echecs := 0
var machine := MachineASous.new(5, 1)


func _init() -> void:
	test_donnees()
	test_fleche()
	test_aimant()
	test_trefle()
	test_bombe()
	test_dores()
	test_textes()
	print("TERMINÉ : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


# --- Outils -----------------------------------------------------------------

func verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		echecs += 1
		print("  ÉCHEC ", message)


func s(id: String) -> SymbolData:
	return load("res://data/symbols/%s.tres" % id) as SymbolData


func grille(ids: Array) -> Array[SymbolData]:
	var liste: Array[SymbolData] = []
	for id: String in ids:
		liste.append(null if id == "" else s(id))
	return liste


func resoudre(ids: Array) -> ResultatTirage:
	return machine.resoudre(machine.transformer_voisins(grille(ids)))


# --- Tests ------------------------------------------------------------------

func test_donnees() -> void:
	print("Les 4 symboles se chargent")
	for id in ["bombe", "fleche", "aimant", "trefle"]:
		var symbole := s(id)
		verifier(symbole != null and symbole.id == StringName(id) and symbole.prix > 0 and not symbole.effet_combo.is_empty(),
				"%s : fichier valide, prix et effet de combo" % id)
	verifier(s("bombe").usage_unique and not s("epee").usage_unique, "seule la Bombe est à usage unique")
	verifier(s("fleche").compte_id == &"fleche" and s("aimant").compte_id == &"piece", "Flèche compte les flèches, Aimant les pièces")
	verifier(Profil.SYMBOLES_A_DEBLOQUER.all(func(id: StringName) -> bool: return s(String(id)) != null), "tous les symboles à débloquer du profil existent")


func test_fleche() -> void:
	print("Flèche : autant de dégâts que de flèches visibles, par flèche")
	verifier(resoudre(["fleche", "bouclier", "potion", "", ""]).total("degats") == 1, "1 flèche : 1 dégât")
	verifier(resoudre(["fleche", "bouclier", "fleche", "", ""]).total("degats") == 4, "2 flèches : 2 × 2 = 4 dégâts")
	verifier(resoudre(["fleche", "epee", "fleche", "", ""]).total("degats") == 7, "2 flèches et une épée : 4 + 3 = 7")
	var combo := resoudre(["fleche", "fleche", "fleche", "bouclier", "potion"])
	verifier(combo.total("degats") == 12 and combo.combos.size() == 1, "combo de 3 flèches : 12 dégâts (et non 3 × 3 de plus)")
	var jackpot := resoudre(["fleche", "fleche", "fleche", "fleche", "fleche"])
	verifier(jackpot.total("degats") == 48, "jackpot de 5 flèches : 12 × 4 = 48")
	verifier(resoudre(["bouclier", "potion", "", "", ""]).total("degats") == 0, "sans flèche : rien")


func test_aimant() -> void:
	print("Aimant : +1 or par pièce visible, par aimant")
	verifier(resoudre(["aimant", "epee", "bouclier", "", ""]).total("or") == 0, "un aimant sans pièce : 0 or")
	verifier(resoudre(["aimant", "piece", "epee", "piece", ""]).total("or") == 2 + 2 * 2, "1 aimant et 2 pièces : 2 (aimant) + 4 (pièces) = 6 or")
	verifier(resoudre(["aimant", "piece", "aimant", "", ""]).total("or") == 2 + 2, "2 aimants et 1 pièce : 1 + 1 + 2 = 4 or")
	var combo := resoudre(["aimant", "aimant", "aimant", "piece", ""])
	verifier(combo.total("or") == 8 + 2, "combo de 3 aimants : 8 or + la pièce (2)")


func test_trefle() -> void:
	print("Trèfle : transforme un crâne voisin en pièce")
	var apres := machine.transformer_voisins(grille(["crane", "trefle", "epee", "epee", "epee"]))
	verifier(apres[0].id == &"piece" and apres[1].id == &"trefle", "le crâne à gauche devient une pièce")
	apres = machine.transformer_voisins(grille(["epee", "trefle", "crane", "epee", "epee"]))
	verifier(apres[2].id == &"piece", "le crâne à droite devient une pièce")
	apres = machine.transformer_voisins(grille(["crane", "trefle", "crane", "epee", "epee"]))
	verifier(apres[0].id == &"piece" and apres[2].id == &"crane", "un trèfle ne transforme qu'un crâne (celui de gauche d'abord)")
	apres = machine.transformer_voisins(grille(["trefle", "crane", "trefle", "crane", "epee"]))
	verifier(apres[1].id == &"piece" and apres[3].id == &"piece", "deux trèfles transforment deux crânes différents")
	apres = machine.transformer_voisins(grille(["crane", "epee", "trefle", "epee", "crane"]))
	verifier(apres[0].id == &"crane" and apres[4].id == &"crane", "un crâne qui n'est pas voisin ne change pas")
	apres = machine.transformer_voisins(grille(["crane", "trefle", "", "", ""]))
	verifier(apres[0].id == &"piece" and apres[2] == null, "les rouleaux vides restent vides")
	var original := grille(["crane", "trefle", "epee", "epee", "epee"])
	machine.transformer_voisins(original)
	verifier(original[0].id == &"crane", "la grille d'origine n'est pas modifiée")
	# Les pièces nées d'un crâne peuvent former un combo.
	var trois := resoudre(["trefle", "crane", "piece", "piece", "epee"])
	verifier(trois.combos.size() == 1 and trois.total("or") == 10, "trèfle, crâne→pièce, pièce, pièce : un combo de 3 pièces (10 or)")
	verifier(resoudre(["trefle", "trefle", "trefle", "epee", "epee"]).total("or") == 6, "combo de 3 trèfles : 6 or")
	var avec_crane := resoudre(["crane", "trefle", "epee", "", ""])
	verifier(avec_crane.total("malus_ennemi") == 0 and avec_crane.total("or") == 2 and avec_crane.total("degats") == 3, "le crâne transformé n'attaque plus et rapporte 2 or")


func test_bombe() -> void:
	print("Bombe : 8 dégâts, puis retirée du sac du combat")
	verifier(resoudre(["bombe", "bouclier", "", "", ""]).total("degats") == 8, "une bombe : 8 dégâts")
	verifier(resoudre(["bombe", "bombe", "bombe", "", ""]).total("degats") == 40, "combo de 3 bombes : 40 dégâts")

	var sac := Sac.new()
	sac.ajouter(s("bombe"), 2)
	sac.ajouter(s("epee"), 3)
	var ennemi := EnemyData.new()
	ennemi.id = &"test"
	ennemi.nom = "Test"
	ennemi.pv_max = 1000
	ennemi.intentions = [{"type": "attaque", "valeur": 1}]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var combat := Combat.new(ennemi, 100, 100, rng, 5, 0)
	combat.preparer_tirages(machine, sac, null)
	combat.tirer()
	var bombes_vues := 0
	for symbole in combat.grille_courante:
		if symbole != null and symbole.id == &"bombe":
			bombes_vues += 1
	verifier(bombes_vues == 2, "le 1er tirage (le sac entier) montre les 2 bombes")
	var journal := combat.valider()
	verifier(journal.any(func(ligne: String) -> bool: return ligne.contains("retiré du sac")), "le journal annonce le retrait")
	combat.tirer()
	var encore := 0
	for symbole in combat.grille_courante:
		if symbole != null and symbole.id == &"bombe":
			encore += 1
	verifier(encore == 0, "les bombes ont quitté le sac du combat : plus aucune au tirage suivant")
	verifier(sac.taille() == 5, "le vrai sac du joueur n'a pas bougé (5 symboles)")
	var suivant := Combat.new(ennemi, 100, 100, rng, 5, 0)
	suivant.preparer_tirages(machine, sac, null)
	suivant.tirer()
	var revenues := 0
	for symbole in suivant.grille_courante:
		if symbole != null and symbole.id == &"bombe":
			revenues += 1
	verifier(revenues == 2, "au combat suivant, les bombes sont revenues")

	# Une bombe qui n'est pas sortie reste dans le sac du combat.
	var sac2 := Sac.new()
	sac2.ajouter(s("bombe"), 1)
	sac2.ajouter(s("epee"), 10)
	var vues := 0
	var combat2 := Combat.new(ennemi, 100, 100, rng, 5, 0)
	combat2.preparer_tirages(machine, sac2, null)
	for tour in 6:
		combat2.tirer()
		for symbole in combat2.grille_courante:
			if symbole != null and symbole.id == &"bombe":
				vues += 1
		combat2.valider()
	verifier(vues == 1, "une bombe n'apparaît qu'une fois par combat (%d fois en 6 tours)" % vues)


func test_dores() -> void:
	print("Symboles dorés")
	var fleche_doree := s("fleche").creer_doree()
	verifier(int(fleche_doree.effet_par_compte["degats"]) == 2 and int(s("fleche").effet_par_compte["degats"]) == 1,
			"une flèche dorée double son effet par flèche, sans toucher au fichier")
	var g := grille(["fleche", "bouclier", "", "", ""])
	g[2] = fleche_doree
	verifier(machine.resoudre(g).total("degats") == 2 * 2 + 1 * 2, "1 flèche dorée + 1 normale : (2 + 1) × 2 flèches visibles = 6")
	var bombe_doree := s("bombe").creer_doree()
	verifier(int(bombe_doree.effet_base["degats"]) == 16 and bombe_doree.usage_unique, "une bombe dorée : 16 dégâts, toujours à usage unique")


func test_textes() -> void:
	print("Textes affichés")
	verifier(s("epee").decrire_base() == Effets.decrire(s("epee").effet_base), "un symbole ordinaire se décrit par ses chiffres")
	for id in ["fleche", "aimant", "trefle"]:
		verifier(s(id).decrire_base() != "", "%s a un texte d'effet" % id)
	verifier(s("bombe").decrire_base() != "" and s("bombe").decrire_combo() != "", "la Bombe se décrit par ses chiffres")
