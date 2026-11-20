extends SceneTree
## Tests des ennemis de la v0.6 (passifs, ouverture, fuite, charge, règles du Grand Croupier),
## à lancer en ligne de commande :
## godot --headless --path . -s res://tests/test_ennemis.gd

var echecs := 0
var machine := MachineASous.new(5, 1)

const TOUS_LES_ENNEMIS: Array[String] = [
	"rat_egout", "squelette", "gobelin_tricheur", "rat_croupier",
	"fantome_joueur", "golem_jetons", "pickpocket", "dame_de_pique",
	"garde_du_coffre", "mimique", "usurier", "grand_croupier",
]


func _init() -> void:
	test_donnees()
	test_cranes_temporaires()
	test_usurier()
	test_pickpocket()
	test_golem()
	test_mimique()
	test_regles_de_la_machine()
	test_regles_dans_le_combat()
	test_intentions_affichees()
	test_combats_au_hasard()

	print("TERMINÉ : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


# --- Outils -----------------------------------------------------------------

func verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		echecs += 1
		print("  ÉCHEC ", message)


func symbole(id: String) -> SymbolData:
	return load("res://data/symbols/%s.tres" % id) as SymbolData


func charger(id: String) -> EnemyData:
	return load("res://data/enemies/%s.tres" % id) as EnemyData


## Un ennemi de test aux valeurs fixes (les .tres sont réglés en jouant, pas ici).
func ennemi_de_test(pv: int, intentions: Array[Dictionary], passif: Dictionary = {}, ouverture: Dictionary = {}) -> EnemyData:
	var ennemi := EnemyData.new()
	ennemi.id = &"test"
	ennemi.nom = "Test"
	ennemi.pv_max = pv
	ennemi.or_victoire = 5
	ennemi.intentions = intentions
	ennemi.passif = passif
	ennemi.ouverture = ouverture
	return ennemi


func intention(type: String, valeur: int = 0) -> Dictionary:
	return {"type": type, "valeur": valeur}


## Un combat prêt à tirer, avec un sac de `symboles` (id -> quantité).
func combat_de(ennemi: EnemyData, pv: int = 100, or_joueur: int = 100, graine: int = 1, sac_voulu: Sac = null) -> Combat:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var combat := Combat.new(ennemi, pv, pv, rng, 5, or_joueur)
	combat.preparer_tirages(machine, sac_voulu if sac_voulu != null else Sac.creer_sac_de_depart(), null)
	return combat


## Une grille de 5 symboles sans combo ni bouclier : [épée, pièce, épée, pièce, épée].
func grille_calme() -> Array[SymbolData]:
	var epee := symbole("epee")
	var piece := symbole("piece")
	return [epee, piece, epee, piece, epee] as Array[SymbolData]


func jouer(combat: Combat, grille: Array[SymbolData], mise: Mise = null) -> Array[String]:
	return combat.jouer_tour(machine.resoudre(grille), mise)


func journal_contient(journal: Array[String], morceau: String) -> bool:
	for ligne in journal:
		if morceau in ligne:
			return true
	return false


# --- Tests ------------------------------------------------------------------

func test_donnees() -> void:
	print("Les 12 ennemis et la mimique se chargent")
	for id in TOUS_LES_ENNEMIS:
		var ennemi := charger(id)
		verifier(ennemi != null and ennemi.id == StringName(id) and ennemi.pv_max > 0 and not ennemi.intentions.is_empty(),
				"%s : fichier valide, PV et intentions" % id)
	verifier(charger("dame_de_pique").passif.get("cranes_par_tour") == 1, "Dame de Pique : 1 crâne par tour")
	verifier(charger("fantome_joueur").passif.get("cranes_par_tour") == 1, "Fantôme : 1 crâne par tour")
	verifier(charger("usurier").passif.get("attaque_par_mise") == 2, "Usurier : +2 attaque par mise")
	verifier(charger("grand_croupier").passif.get("regle_par_tour") == true, "Grand Croupier : une règle par tour")
	verifier(charger("mimique").ouverture.get("type") == "attaque", "Mimique : ouverture d'attaque")
	verifier(charger("pickpocket").intentions[3].get("type") == "fuite", "Pickpocket : fuit au 4e tour")
	verifier(charger("golem_jetons").intentions[0].get("type") == "charge", "Golem : se charge d'abord")


func test_cranes_temporaires() -> void:
	print("Crânes temporaires")
	var sac_reel := Sac.new()
	sac_reel.ajouter(symbole("epee"), 5)
	var combat := combat_de(ennemi_de_test(1000, [intention("attaque", 1)], {"cranes_par_tour": 2}), 100, 0, 3, sac_reel)
	var journal := jouer(combat, grille_calme())
	verifier(combat.cranes_temporaires == 2, "après 1 tour : 2 crânes temporaires")
	verifier(journal_contient(journal, "crâne"), "le journal le dit")
	for i in 10:
		jouer(combat, grille_calme())
	verifier(combat.cranes_temporaires == Combat.MAX_CRANES_TEMPORAIRES, "plafond de %d crânes temporaires" % Combat.MAX_CRANES_TEMPORAIRES)
	verifier(sac_reel.taille() == 5, "le vrai sac n'a pas bougé (5 épées)")

	# Les crânes arrivent vraiment dans les tirages du combat.
	var sac_neuf := Sac.new()
	sac_neuf.ajouter(symbole("epee"), 5)
	var combat2 := combat_de(ennemi_de_test(1000, [intention("attaque", 1)], {"cranes_par_tour": 2}), 100, 0, 5, sac_neuf)
	for i in 5:
		combat2.tirer()
		combat2.valider()
	combat2.tirer()
	var cranes := 0
	for s in combat2.grille_courante:
		if s != null and s.id == &"crane":
			cranes += 1
	verifier(cranes >= 1, "après 5 tours, le tirage contient des crânes (%d sur 5 rouleaux)" % cranes)
	verifier(sac_neuf.taille() == 5, "le vrai sac est toujours intact")

	# Un nouveau combat repart d'un sac propre.
	var combat3 := combat_de(ennemi_de_test(1000, [intention("attaque", 1)]), 100, 0, 5, sac_neuf)
	verifier(combat3.cranes_temporaires == 0, "un nouveau combat n'a aucun crâne temporaire")

	# Sans passif : rien n'est ajouté.
	var calme := combat_de(ennemi_de_test(1000, [intention("attaque", 1)]))
	jouer(calme, grille_calme())
	verifier(calme.cranes_temporaires == 0, "un ennemi sans passif n'ajoute rien")


func test_usurier() -> void:
	print("Usurier : se renforce quand on mise")
	var ennemi := ennemi_de_test(1000, [intention("attaque", 10)], {"attaque_par_mise": 2})
	var combat := combat_de(ennemi)
	jouer(combat, grille_calme())
	verifier(combat.pv_joueur == 90 and combat.bonus_attaque_ennemi == 0, "sans mise : attaque 10, aucun renfort")
	jouer(combat, grille_calme(), Mise.en_or(5))
	verifier(combat.bonus_attaque_ennemi == 2 and combat.pv_joueur == 90 - 12, "avec une mise d'or : +2, il attaque pour 12 ce tour-là")
	verifier(combat.intention_affichee().get("valeur") == 12, "l'intention affichée montre 12")
	jouer(combat, grille_calme())
	verifier(combat.pv_joueur == 90 - 12 - 12, "sans mise ensuite : le renfort reste (12)")
	jouer(combat, grille_calme(), Mise.quitte_ou_double())
	verifier(combat.bonus_attaque_ennemi == 4, "un quitte ou double renforce aussi (+4 au total)")
	# Une mise impossible (pas d'or) ne renforce pas.
	var pauvre := combat_de(ennemi, 100, 0)
	jouer(pauvre, grille_calme(), Mise.en_or(5))
	verifier(pauvre.bonus_attaque_ennemi == 0, "une mise annulée faute d'or ne renforce pas l'Usurier")
	# Les .tres ne sont pas touchés.
	verifier(charger("usurier").intentions[0].get("valeur") == 9, "le fichier de l'Usurier n'est pas modifié")


func test_pickpocket() -> void:
	print("Pickpocket : vole puis fuit")
	var ennemi := ennemi_de_test(1000, [intention("vol", 4), intention("attaque", 9), intention("vol", 4), intention("fuite")])
	var combat := combat_de(ennemi, 100, 20)
	jouer(combat, grille_calme())
	verifier(combat.or_vole == 4, "tour 1 : il vole 4 or")
	jouer(combat, grille_calme())
	verifier(combat.pv_joueur == 91, "tour 2 : attaque 9")
	jouer(combat, grille_calme())
	verifier(combat.or_vole == 8 and not combat.est_fini(), "tour 3 : il vole encore 4 or, le combat continue")
	var avant := combat.or_gagne
	var journal := jouer(combat, grille_calme())
	verifier(combat.etat == Combat.Etat.FUITE and combat.est_fini(), "tour 4 : il s'enfuit, le combat est fini")
	verifier(journal_contient(journal, "s'enfuit"), "le journal le dit")
	verifier(combat.or_gagne == avant + 4, "pas d'or de victoire quand il s'enfuit (seulement les 2 pièces du tirage)")
	var apres := jouer(combat, grille_calme())
	verifier(apres.is_empty() and combat.pv_joueur == 91, "un combat fini ne rejoue pas")
	# Tué avant de fuir : victoire normale.
	var tue := combat_de(ennemi_de_test(10, [intention("vol", 4), intention("fuite")]))
	jouer(tue, [symbole("epee"), symbole("epee"), symbole("epee"), symbole("epee"), symbole("epee")] as Array[SymbolData])
	verifier(tue.etat == Combat.Etat.VICTOIRE, "un Pickpocket tué avant sa fuite est vaincu normalement")
	# Les vraies données : vol 4, attaque 9, vol 4, fuite.
	var vrai := combat_de(charger("pickpocket"), 100, 50)
	for i in 4:
		jouer(vrai, grille_calme())
	verifier(vrai.etat == Combat.Etat.FUITE or vrai.etat == Combat.Etat.VICTOIRE, "le vrai Pickpocket est fini au 4e tour (fuite ou victoire)")


func test_golem() -> void:
	print("Golem : se charge puis frappe fort")
	var combat := combat_de(charger("golem_jetons"), 100)
	# La grosse attaque se règle dans le .tres : on lit sa valeur.
	var grosse: int = charger("golem_jetons").intentions[1]["valeur"]
	verifier(grosse > 12, "la grosse attaque du Golem est grosse (%d)" % grosse)
	var journal := jouer(combat, grille_calme())
	verifier(combat.pv_joueur == 100, "tour 1 : il se charge, aucun dégât")
	verifier(journal_contient(journal, "se prépare"), "le journal annonce la charge")
	verifier(Intentions.decrire(combat.intention_actuelle()) != "", "l'intention suivante se décrit")
	jouer(combat, grille_calme())
	verifier(combat.pv_joueur == 100 - grosse, "tour 2 : sa grosse attaque (%d)" % grosse)
	jouer(combat, grille_calme())
	verifier(combat.pv_joueur == 100 - grosse, "tour 3 : il se recharge, aucun dégât")


func test_mimique() -> void:
	print("Mimique : attaque surprise avant le premier tirage")
	var combat := combat_de(charger("mimique"), 40)
	var journal := combat.jouer_ouverture()
	verifier(combat.pv_joueur == 30, "la surprise fait 10 dégâts (PV 40 -> 30)")
	verifier(journal_contient(journal, "surprise"), "le journal le dit")
	verifier(combat.journal_ouverture == journal, "le combat garde le texte pour l'écran")
	verifier(combat.jouer_ouverture().is_empty() and combat.pv_joueur == 30, "elle ne se rejoue pas")
	jouer(combat, grille_calme())
	var attaque: int = charger("mimique").intentions[0]["valeur"]
	verifier(combat.pv_joueur == 30 - attaque, "puis elle attaque à chaque tour (%d)" % attaque)
	var faible := combat_de(charger("mimique"), 6)
	faible.jouer_ouverture()
	verifier(faible.pv_joueur == 1 and not faible.est_fini(), "la surprise ne tue jamais : il reste 1 PV")
	var normal := combat_de(charger("rat_egout"), 40)
	verifier(normal.jouer_ouverture().is_empty() and normal.pv_joueur == 40, "un ennemi sans ouverture ne fait rien")
	# Par la partie : la surprise tombe à la création du combat.
	var partie := Partie.creer(3)
	partie.pv = 40
	var depuis_partie := Combat.new(charger("mimique"), 40, 40, partie.rng)
	depuis_partie.jouer_ouverture()
	verifier(depuis_partie.pv_joueur == 30, "le même résultat quand le combat vient d'une partie")


func test_regles_de_la_machine() -> void:
	print("Règles du Grand Croupier : effets exacts")
	var epee := symbole("epee")
	var bouclier := symbole("bouclier")
	var potion := symbole("potion")
	var crane := symbole("crane")
	var piece := symbole("piece")

	# Épées : les dégâts deviennent des soins de l'ennemi (base et combo).
	var mods := Modificateurs.new().avec_regle(ReglesMachine.EPEES_SOIGNENT)
	var res := machine.resoudre([epee, piece, epee, piece, epee] as Array[SymbolData], mods)
	verifier(res.total("degats") == 0 and res.total("soin_ennemi") == 9 and res.total("or") == 4, "épées soignent : 3 épées de base -> 9 de soin ennemi, pièces normales")
	res = machine.resoudre([epee, epee, epee, piece, piece] as Array[SymbolData], mods)
	verifier(res.total("degats") == 0 and res.total("soin_ennemi") == 15, "épées soignent : un combo de 3 épées soigne 15")
	var lame := Modificateurs.new()
	lame.degats_par_piece = 1
	res = machine.resoudre([epee, piece, piece, bouclier, potion] as Array[SymbolData], lame.avec_regle(ReglesMachine.EPEES_SOIGNENT))
	verifier(res.total("degats") == 2 and res.total("soin_ennemi") == 3, "épées soignent : la Lame aimantée blesse encore, et la copie garde les reliques")

	# Boucliers : plus d'armure.
	mods = Modificateurs.new().avec_regle(ReglesMachine.BOUCLIERS_INUTILES)
	res = machine.resoudre([bouclier, epee, bouclier, epee, bouclier] as Array[SymbolData], mods)
	verifier(res.total("armure") == 0 and res.total("degats") == 6, "boucliers inutiles : 0 armure, épées normales")
	res = machine.resoudre([bouclier, bouclier, bouclier, epee, piece] as Array[SymbolData], mods)
	verifier(res.total("armure") == 0, "boucliers inutiles : un combo de boucliers ne donne rien non plus")

	# Potions : plus de soin.
	mods = Modificateurs.new().avec_regle(ReglesMachine.POTIONS_INUTILES)
	res = machine.resoudre([potion, epee, potion, epee, bouclier] as Array[SymbolData], mods)
	verifier(res.total("soin") == 0 and res.total("armure") == 3, "potions inutiles : 0 soin, le bouclier compte")

	# Crânes : malus et perte de PV doublés.
	mods = Modificateurs.new().avec_regle(ReglesMachine.CRANES_DOUBLES)
	res = machine.resoudre([crane, epee, crane, epee, bouclier] as Array[SymbolData], mods)
	verifier(res.total("malus_ennemi") == 4, "crânes doubles : 2 crânes -> malus 4 au lieu de 2")
	res = machine.resoudre([crane, crane, crane, epee, bouclier] as Array[SymbolData], mods)
	verifier(res.total("perte_pv") == 12, "crânes doubles : un combo de crânes fait perdre 12 PV au lieu de 6")

	# Sans règle : rien ne change.
	res = machine.resoudre([crane, epee, crane, epee, bouclier] as Array[SymbolData], Modificateurs.new().avec_regle(""))
	verifier(res.total("malus_ennemi") == 2 and res.total("degats") == 6, "sans règle, les effets sont normaux")
	verifier(ReglesMachine.TOUTES.size() == 4, "4 règles")
	for regle in ReglesMachine.TOUTES:
		verifier(ReglesMachine.decrire(regle) != "", "la règle %s a un texte" % regle)


func test_regles_dans_le_combat() -> void:
	print("Règles du Grand Croupier : dans le combat")
	var combat := combat_de(charger("grand_croupier"), 400, 0, 11)
	verifier(combat.regle_active in ReglesMachine.TOUTES, "une règle est annoncée dès le début : %s" % combat.regle_active)
	var precedente := combat.regle_active
	var toujours_differente := true
	var vues := {}
	for i in 30:
		combat.tirer()
		var regle_du_tirage := combat.regle_active
		combat.valider()
		if combat.est_fini():
			break
		vues[combat.regle_active] = true
		if combat.regle_active == regle_du_tirage:
			toujours_differente = false
	verifier(toujours_differente, "la règle change à chaque tour (jamais la même deux fois de suite)")
	verifier(vues.size() >= 3, "au fil des tours, au moins 3 règles différentes apparaissent (%d)" % vues.size())

	# Les épées soignent vraiment l'ennemi dans un vrai tour.
	var soigne := combat_de(ennemi_de_test(100, [intention("attaque", 1)], {"regle_par_tour": true}), 400, 0, 2)
	soigne.regle_active = ReglesMachine.EPEES_SOIGNENT
	soigne.pv_ennemi = 50
	var epee := symbole("epee")
	var res := machine.resoudre([epee, epee, epee, epee, epee] as Array[SymbolData], Modificateurs.new().avec_regle(ReglesMachine.EPEES_SOIGNENT))
	var journal := soigne.jouer_tour(res)
	verifier(soigne.pv_ennemi == 100, "un jackpot d'épées sous cette règle soigne l'ennemi (50 -> 100, plafonné)")
	verifier(journal_contient(journal, "se soigne"), "le journal le dit")

	# Rejouable : même graine, mêmes règles.
	var suite_a := _suite_de_regles(21)
	var suite_b := _suite_de_regles(21)
	verifier(suite_a == suite_b and suite_a.size() > 3, "même graine : mêmes règles dans le même ordre")
	verifier(suite_a != _suite_de_regles(22), "une autre graine : d'autres règles")


func _suite_de_regles(graine: int) -> Array[String]:
	var combat := combat_de(charger("grand_croupier"), 1000, 0, graine)
	var suite: Array[String] = [combat.regle_active]
	for i in 10:
		combat.tirer()
		combat.valider()
		suite.append(combat.regle_active)
	return suite


func test_intentions_affichees() -> void:
	print("Textes des intentions et des passifs")
	verifier(Intentions.decrire(intention("charge")) == "Se prépare à frapper", "intention « charge »")
	verifier(Intentions.decrire(intention("fuite")) == "Va s'enfuir", "intention « fuite »")
	verifier(Intentions.decrire(intention("attaque", 7)) == "Attaque 7", "intention « attaque » inchangée")
	verifier(Intentions.decrire_passif({}) == "", "pas de passif : pas de texte")
	verifier("2" in Intentions.decrire_passif({"cranes_par_tour": 2}), "texte du passif des crânes")
	verifier("2" in Intentions.decrire_passif({"attaque_par_mise": 2}), "texte du passif de l'Usurier")
	verifier(Intentions.decrire_passif({"regle_par_tour": true}) != "", "texte du passif du Grand Croupier")
	verifier(Intentions.decrire_passif(charger("dame_de_pique").passif) != "", "texte du passif de la Dame de Pique")


## 300 combats pour chaque ennemi, au hasard : tous finissent et les nombres restent cohérents.
func test_combats_au_hasard() -> void:
	print("Combats au hasard contre chaque ennemi")
	var tous_finis := true
	var coherents := true
	var issues := {}
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 99
	for id in TOUS_LES_ENNEMIS:
		for essai in 300:
			var combat := combat_de(charger(id), 40, hasard.randi_range(0, 30), hasard.randi())
			combat.jouer_ouverture()
			var tours := 0
			while not combat.est_fini() and tours < 400:
				var mise: Mise = null
				match hasard.randi_range(0, 3):
					1:
						mise = Mise.en_or(5)
					2:
						mise = Mise.quitte_ou_double()
				if not combat.peut_miser(mise):
					mise = null
				combat.tirer(mise)
				combat.valider()
				if combat.pv_joueur < 0 or combat.pv_joueur > 40 or combat.armure_joueur < 0 or combat.armure_ennemi < 0 \
						or combat.pv_ennemi < 0 or combat.pv_ennemi > combat.ennemi.pv_max \
						or combat.or_du_joueur() < 0 or combat.cranes_temporaires > Combat.MAX_CRANES_TEMPORAIRES:
					coherents = false
					print("    incohérence contre %s : PV %d, armure %d, PV ennemi %d, or %d" % [
						id, combat.pv_joueur, combat.armure_joueur, combat.pv_ennemi, combat.or_du_joueur()])
				tours += 1
			if not combat.est_fini():
				tous_finis = false
				print("    combat non fini contre %s après %d tours" % [id, tours])
			issues[combat.etat] = int(issues.get(combat.etat, 0)) + 1
	verifier(tous_finis, "les %d combats se terminent" % (TOUS_LES_ENNEMIS.size() * 300))
	verifier(coherents, "PV, armure et or toujours cohérents")
	verifier(int(issues.get(Combat.Etat.FUITE, 0)) > 0, "des Pickpockets se sont enfuis (%d fuites)" % int(issues.get(Combat.Etat.FUITE, 0)))
	verifier(int(issues.get(Combat.Etat.VICTOIRE, 0)) > 0 and int(issues.get(Combat.Etat.DEFAITE, 0)) > 0, "victoires et défaites existent")
