extends SceneTree
## Tests du donjon (génération des étages, portes, mimiques), à lancer en ligne de commande :
## godot --headless --path . -s res://tests/test_donjon.gd

var echecs := 0
const NB_GRAINES := 500


func _init() -> void:
	test_structure()
	test_contraintes_sur_beaucoup_de_graines()
	test_determinisme()
	test_graines_differentes()
	test_ennemis_par_etage()
	test_mimiques()
	test_erreur_etage()

	print("TERMINÉ : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


# --- Outils -----------------------------------------------------------------

func verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		echecs += 1
		print("  ÉCHEC ", message)


func salle(type: Salle.Type, ennemi_id: String = "") -> Salle:
	var ennemi: EnemyData = null
	if ennemi_id != "":
		ennemi = load("res://data/enemies/%s.tres" % ennemi_id) as EnemyData
	return Salle.creer(type, ennemi)


# --- Tests ------------------------------------------------------------------

func test_structure() -> void:
	print("Structure du donjon")
	var donjon := Donjon.creer(42)
	verifier(donjon.etages.size() == 3, "3 étages")
	verifier(donjon.boss.size() == 3, "3 boss")
	var bien_forme := true
	for etage in range(1, 4):
		for pas in range(1, 6):
			if donjon.portes(etage, pas).size() != 2:
				bien_forme = false
	verifier(bien_forme, "chaque étage a 5 pas de 2 portes")
	verifier(donjon.boss_de(1).id == &"rat_croupier", "boss de l'étage 1 : Rat-Croupier")
	verifier(donjon.boss_de(2).id == &"dame_de_pique", "boss de l'étage 2 : Dame de Pique")
	verifier(donjon.boss_de(3).id == &"grand_croupier", "boss de l'étage 3 : Grand Croupier")
	verifier(donjon.boss_de(1).est_boss and donjon.boss_de(2).est_boss and donjon.boss_de(3).est_boss, "ce sont bien des boss")
	verifier(Donjon.nom_etage(1) == "Les Cryptes" and Donjon.nom_etage(3) == "Le Coffre-fort", "noms des étages")


## 500 graines x 3 étages : toutes les contraintes respectées, aucun étage non conforme.
func test_contraintes_sur_beaucoup_de_graines() -> void:
	print("Contraintes sur %d graines" % NB_GRAINES)
	var erreurs := 0
	var echecs_generation := 0
	var rejets := 0
	var premiers_combats := true
	var types_vus := {}
	for graine in NB_GRAINES:
		var donjon := Donjon.creer(graine)
		rejets += donjon.rejets
		echecs_generation += donjon.echecs
		for etage in range(1, 4):
			if not Donjon.erreur_etage(donjon.etages[etage - 1]).is_empty():
				erreurs += 1
				print("    graine %d, étage %d : %s" % [graine, etage, Donjon.erreur_etage(donjon.etages[etage - 1])])
			for salle_du_pas in donjon.portes(etage, 1):
				if salle_du_pas.type != Salle.Type.COMBAT:
					premiers_combats = false
			for pas in range(1, 6):
				for porte in donjon.portes(etage, pas):
					types_vus[porte.type] = int(types_vus.get(porte.type, 0)) + 1
	verifier(erreurs == 0, "aucun étage ne casse une contrainte (%d erreurs)" % erreurs)
	verifier(echecs_generation == 0, "aucun étage n'a épuisé ses tentatives (%d)" % echecs_generation)
	verifier(premiers_combats, "le pas 1 de chaque étage propose 2 combats")
	var total := NB_GRAINES * 3
	print("    étages rejetés puis retirés : %d sur %d (%.1f %%)" % [rejets, total + rejets, 100.0 * rejets / (total + rejets)])
	# Environ la moitié des étages tirés sont retirés (il manque souvent une boutique ou un repos) : sans danger, le plafond de 60 tentatives est loin.
	verifier(float(rejets) / (total + rejets) < 0.7, "le taux de rejet reste raisonnable")
	# Fréquence des types : le combat domine (poids 50 / 100, un peu plus à cause du pas 1 forcé).
	var nb_portes: int = 0
	for type: int in types_vus:
		nb_portes += int(types_vus[type])
	var part_combat: float = float(types_vus[Salle.Type.COMBAT]) / nb_portes
	print("    part des portes : combat %.0f %%, coffre %.0f %%, boutique %.0f %%, repos %.0f %%" % [
		100.0 * part_combat, 100.0 * types_vus[Salle.Type.COFFRE] / nb_portes,
		100.0 * types_vus[Salle.Type.BOUTIQUE] / nb_portes, 100.0 * types_vus[Salle.Type.REPOS] / nb_portes])
	verifier(part_combat > 0.4 and part_combat < 0.7, "le combat est le type le plus fréquent")
	verifier(types_vus[Salle.Type.COMBAT] > types_vus[Salle.Type.COFFRE] and types_vus[Salle.Type.COFFRE] > types_vus[Salle.Type.REPOS],
			"ordre de fréquence : combat > coffre > repos")


## Même graine = même donjon, même après avoir consommé du hasard (le jeu ne change pas le donjon).
func test_determinisme() -> void:
	print("Déterminisme")
	var identiques := true
	for graine in 100:
		var a := Donjon.creer(graine)
		# On joue une partie entre les deux : le hasard du jeu ne doit pas toucher au donjon.
		var partie := Partie.creer(graine)
		for i in 200:
			partie.rng.randi()
		partie.tirer_symboles(3)
		var b := Donjon.creer(graine)
		if a.empreinte() != b.empreinte():
			identiques = false
	verifier(identiques, "même graine : même donjon, avant et après des tirages de la partie")
	verifier(Donjon.creer(7).empreinte() == Donjon.creer(7).empreinte(), "deux générations de la graine 7 sont identiques")


func test_graines_differentes() -> void:
	print("Graines différentes")
	var vues := {}
	for graine in 200:
		vues[Donjon.creer(graine).empreinte()] = true
	verifier(vues.size() >= 195, "200 graines donnent presque toujours 200 donjons différents (%d)" % vues.size())
	# Les étages d'une même partie ne sont pas des copies les uns des autres.
	var donjon := Donjon.creer(5)
	verifier(donjon.etages[0] != donjon.etages[1], "les étages d'un donjon diffèrent")


func test_ennemis_par_etage() -> void:
	print("Ennemis de chaque étage")
	var bons := true
	for graine in 100:
		var donjon := Donjon.creer(graine)
		for etage in range(1, 4):
			var chemins: Array = Donjon.ETAGES[etage - 1]["ennemis"]
			var ids: Array[StringName] = []
			for chemin: String in chemins:
				ids.append((load(chemin) as EnemyData).id)
			for pas in range(1, 6):
				for porte in donjon.portes(etage, pas):
					if porte.type == Salle.Type.COMBAT and not (porte.ennemi.id in ids):
						bons = false
					if porte.type == Salle.Type.COMBAT and porte.ennemi.est_boss:
						bons = false
	verifier(bons, "chaque porte de combat porte un ennemi de son étage, jamais un boss")
	for etage in range(1, 4):
		for chemin: String in Donjon.ETAGES[etage - 1]["ennemis"]:
			var ennemi := load(chemin) as EnemyData
			verifier(ennemi != null and ennemi.etage == etage, "%s est bien un ennemi de l'étage %d" % [ennemi.nom, etage])
	var mimique := load(Donjon.MIMIQUE) as EnemyData
	verifier(mimique != null and mimique.etage == 3 and not mimique.ouverture.is_empty(), "la Mimique est de l'étage 3 et attaque par surprise")
	for etage in range(1, 4):
		var boss := load(Donjon.ETAGES[etage - 1]["boss"]) as EnemyData
		verifier(boss.est_boss and boss.etage == etage, "le boss de l'étage %d est de cet étage" % etage)


func test_mimiques() -> void:
	print("Mimiques")
	var coffres := [0, 0, 0]
	var mimiques := [0, 0, 0]
	var bien_formees := true
	for graine in NB_GRAINES:
		var donjon := Donjon.creer(graine)
		for etage in range(1, 4):
			for pas in range(1, 6):
				for porte in donjon.portes(etage, pas):
					if porte.type == Salle.Type.COFFRE:
						coffres[etage - 1] += 1
						if porte.mimique:
							mimiques[etage - 1] += 1
							if porte.ennemi == null or porte.ennemi.id != &"mimique":
								bien_formees = false
					elif porte.mimique:
						bien_formees = false
	verifier(mimiques[0] == 0 and mimiques[1] == 0, "aucune mimique aux étages 1 et 2")
	verifier(coffres[2] > 100, "il y a des coffres à l'étage 3 (%d)" % coffres[2])
	var part: float = float(mimiques[2]) / coffres[2]
	print("    mimiques à l'étage 3 : %d coffres sur %d (%.0f %%)" % [mimiques[2], coffres[2], 100.0 * part])
	verifier(part > 0.25 and part < 0.42, "environ 1 coffre sur 3 est une mimique à l'étage 3")
	verifier(bien_formees, "seuls des coffres sont des mimiques, et ils portent l'ennemi Mimique")


func test_erreur_etage() -> void:
	print("Le contrôle d'un étage refuse ce qu'il doit refuser")
	var combat_rat := salle(Salle.Type.COMBAT, "rat_egout")
	var combat_squelette := salle(Salle.Type.COMBAT, "squelette")
	var bon: Array = [
		[combat_rat, combat_squelette],
		[salle(Salle.Type.COFFRE), salle(Salle.Type.BOUTIQUE)],
		[salle(Salle.Type.REPOS), combat_rat],
		[combat_rat, salle(Salle.Type.COFFRE)],
		[combat_squelette, combat_rat],
	]
	verifier(Donjon.erreur_etage(bon).is_empty(), "un étage correct est accepté")

	var trop_court := bon.duplicate()
	trop_court.pop_back()
	verifier(not Donjon.erreur_etage(trop_court).is_empty(), "un étage de 4 pas est refusé")

	var portes_identiques := bon.duplicate(true)
	portes_identiques[1] = [salle(Salle.Type.COFFRE), salle(Salle.Type.COFFRE)]
	verifier(not Donjon.erreur_etage(portes_identiques).is_empty(), "deux coffres côte à côte sont refusés")

	var deux_combats_pareils := bon.duplicate(true)
	deux_combats_pareils[3] = [combat_rat, combat_rat]
	verifier(not Donjon.erreur_etage(deux_combats_pareils).is_empty(), "deux combats contre le même ennemi sont refusés")

	var deux_combats_differents := bon.duplicate(true)
	deux_combats_differents[3] = [combat_rat, combat_squelette]
	verifier(Donjon.erreur_etage(deux_combats_differents).is_empty(), "deux combats contre des ennemis différents sont permis")

	var pas_1_sans_combat := bon.duplicate(true)
	pas_1_sans_combat[0] = [combat_rat, salle(Salle.Type.COFFRE)]
	verifier(not Donjon.erreur_etage(pas_1_sans_combat).is_empty(), "le pas 1 doit proposer 2 combats")

	var sans_repos := bon.duplicate(true)
	sans_repos[2] = [combat_squelette, combat_rat]
	verifier(not Donjon.erreur_etage(sans_repos).is_empty(), "un étage sans repos est refusé")
