extends SceneTree
## Tests des reliques, à lancer en ligne de commande :
## godot --headless --path . -s res://tests/test_reliques.gd

var echecs := 0

var epee: SymbolData
var bouclier: SymbolData
var piece: SymbolData
var crane: SymbolData


func _init() -> void:
	epee = load("res://data/symbols/epee.tres")
	bouclier = load("res://data/symbols/bouclier.tres")
	piece = load("res://data/symbols/piece.tres")
	crane = load("res://data/symbols/crane.tres")

	test_donnees()
	test_possession()
	test_effets_immediats()
	test_modificateurs()
	test_lame_aimantee()
	test_tirelire()
	test_jackpot_maudit()
	test_trefle()
	test_six_rouleaux()
	test_propositions()
	test_relique_offerte()
	test_boutique_reliques()

	print("TERMINÉ : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


# --- Outils -----------------------------------------------------------------

func relique(id: StringName) -> RelicData:
	return Reliques.charger(id)


func grille_de(symboles: Array) -> Array[SymbolData]:
	var grille: Array[SymbolData] = []
	for s in symboles:
		grille.append(s)
	return grille


func mods_avec(ids: Array) -> Modificateurs:
	var liste: Array[RelicData] = []
	for id in ids:
		liste.append(relique(id))
	return Modificateurs.depuis_reliques(liste)


# --- Tests ------------------------------------------------------------------

func test_donnees() -> void:
	var toutes := Reliques.toutes()
	verifier(toutes.size() == 9, "9 reliques dans le jeu : %d" % toutes.size())
	var ids := {}
	var prix_ok := true
	var textes_ok := true
	var params_ok := true
	for r in toutes:
		ids[r.id] = true
		if r.prix < 25 or r.prix > 40:
			prix_ok = false
		if r.nom == "" or r.description == "":
			textes_ok = false
		if r.parametres.is_empty():
			params_ok = false
	verifier(ids.size() == 9, "les 9 reliques ont des identifiants différents")
	verifier(prix_ok, "tous les prix sont entre 25 et 40 or")
	verifier(textes_ok, "toutes les reliques ont un nom et une description")
	verifier(params_ok, "toutes les reliques ont au moins un paramètre")
	for id in [&"coeur_de_pierre", &"tirelire", &"lame_aimantee", &"trefle_quatre_feuilles", &"jackpot_maudit",
			&"jeton_porte_bonheur", &"sixieme_rouleau", &"de_pipe", &"cinquieme_as"]:
		verifier(relique(id) != null, "la relique %s existe" % id)
	verifier(relique(&"inconnue") == null, "une relique inconnue renvoie null")
	verifier(relique(&"jeton_porte_bonheur").prix == 25 and relique(&"jackpot_maudit").prix == 40,
			"prix du Jeton porte-bonheur (25) et du Jackpot maudit (40)")
	verifier(relique(&"tirelire").valeur("or_sans_combo") == 2.0, "la Tirelire donne 2 or")
	verifier(relique(&"tirelire").valeur("inexistant") == 0.0, "un paramètre absent vaut 0")


func test_possession() -> void:
	var partie := Partie.creer(1)
	verifier(partie.reliques.is_empty() and not partie.a_relique(&"tirelire"), "une partie commence sans relique")
	verifier(partie.ajouter_relique(relique(&"tirelire")), "ajouter une relique")
	verifier(partie.a_relique(&"tirelire") and partie.reliques.size() == 1, "la relique est possédée")
	verifier(not partie.ajouter_relique(relique(&"tirelire")) and partie.reliques.size() == 1,
			"on ne possède jamais une relique deux fois")


func test_effets_immediats() -> void:
	# Cœur de pierre : +10 PV max et +10 PV.
	var partie := Partie.creer(2)
	partie.pv = 25
	partie.ajouter_relique(relique(&"coeur_de_pierre"))
	verifier(partie.pv_max == 50 and partie.pv == 35, "Cœur de pierre : 50 PV max et +10 PV : %d / %d" % [partie.pv, partie.pv_max])
	var partie_pleine := Partie.creer(2)
	partie_pleine.ajouter_relique(relique(&"coeur_de_pierre"))
	verifier(partie_pleine.pv == 50, "à PV pleins, le Cœur de pierre donne aussi 10 PV : %d" % partie_pleine.pv)

	# Jackpot maudit : 2 crânes de plus dans le sac.
	var partie2 := Partie.creer(3)
	var cranes_avant := 0
	for s in partie2.sac.symboles:
		if s.id == &"crane":
			cranes_avant += 1
	partie2.ajouter_relique(relique(&"jackpot_maudit"))
	var cranes_apres := 0
	for s in partie2.sac.symboles:
		if s.id == &"crane":
			cranes_apres += 1
	verifier(partie2.sac.taille() == 17 and cranes_apres == cranes_avant + 2,
			"Jackpot maudit : 2 crânes de plus, sac à %d, crânes %d" % [partie2.sac.taille(), cranes_apres])
	verifier(crane.effet_base["malus_ennemi"] == 1, "le crâne d'origine n'est pas modifié")

	# Sixième rouleau.
	var partie3 := Partie.creer(4)
	verifier(partie3.nb_rouleaux == 5 and partie3.creer_machine().nb_cases() == 5, "5 rouleaux au départ")
	partie3.ajouter_relique(relique(&"sixieme_rouleau"))
	verifier(partie3.nb_rouleaux == 6 and partie3.creer_machine().nb_cases() == 6, "Sixième rouleau : 6 rouleaux")
	partie3.choisir_porte(0)
	verifier(partie3.creer_combat().rouleaux_bloques.is_empty(), "le combat se crée avec 6 rouleaux")

	# Les autres reliques n'ont pas d'effet immédiat.
	var partie4 := Partie.creer(5)
	for id in [&"tirelire", &"lame_aimantee", &"trefle_quatre_feuilles", &"jeton_porte_bonheur", &"de_pipe", &"cinquieme_as"]:
		partie4.ajouter_relique(relique(id))
	verifier(partie4.pv == 40 and partie4.pv_max == 40 and partie4.sac.taille() == 15 and partie4.nb_rouleaux == 5,
			"les autres reliques ne changent ni PV, ni sac, ni rouleaux à l'achat")


func test_modificateurs() -> void:
	var rien := Modificateurs.depuis_reliques([] as Array[RelicData])
	verifier(rien.facteur_combo == 1 and rien.degats_par_piece == 0 and rien.or_sans_combo == 0 \
			and rien.chance_crane_en_piece == 0.0, "sans relique, aucun modificateur")
	var tout := mods_avec([&"tirelire", &"lame_aimantee", &"trefle_quatre_feuilles", &"jackpot_maudit"])
	verifier(tout.facteur_combo == 2 and tout.degats_par_piece == 1 and tout.or_sans_combo == 2 \
			and tout.chance_crane_en_piece == 0.5, "les 4 reliques de la machine sont lues")
	var partie := Partie.creer(6)
	partie.ajouter_relique(relique(&"lame_aimantee"))
	verifier(partie.modificateurs().degats_par_piece == 1, "la partie calcule ses modificateurs")


func test_lame_aimantee() -> void:
	var machine := MachineASous.new(5, 1)
	var mods := mods_avec([&"lame_aimantee"])
	var g := grille_de([piece, bouclier, piece, crane, epee])
	var avec := machine.resoudre(g, mods)
	verifier(avec.total("degats") == 5, "2 pièces : 2 dégâts de plus + 3 de l'épée = 5 : %d" % avec.total("degats"))
	verifier(avec.total("or") == 4, "les pièces donnent toujours leur or (4)")
	verifier(machine.resoudre(g).total("degats") == 3, "sans relique, les pièces n'infligent rien")
	var sans_piece := grille_de([epee, bouclier, crane, bouclier, null])
	verifier(machine.resoudre(sans_piece, mods).total("degats") == 3, "sans pièce, pas de dégât en plus")

	# Une pièce dans un combo compte aussi.
	var combo := grille_de([piece, piece, piece, epee, crane])
	var r := machine.resoudre(combo, mods)
	verifier(r.total("degats") == 3 + 3, "3 pièces en combo : 3 dégâts de Lame + 3 de l'épée : %d" % r.total("degats"))
	verifier(r.total("or") == 10, "le combo de 3 pièces donne 10 or")
	var doree := grille_de([piece.creer_doree(), epee, null, null, null])
	verifier(machine.resoudre(doree, mods).total("degats") == 4, "une pièce dorée compte comme une pièce")


func test_tirelire() -> void:
	var machine := MachineASous.new(5, 1)
	var mods := mods_avec([&"tirelire"])
	var sans_combo := grille_de([epee, bouclier, epee, crane, null])
	verifier(machine.resoudre(sans_combo, mods).total("or") == 2, "Tirelire : +2 or sans combo")
	verifier(machine.resoudre(sans_combo).total("or") == 0, "sans relique, pas d'or en plus")
	var avec_combo := grille_de([epee, epee, epee, crane, null])
	verifier(machine.resoudre(avec_combo, mods).total("or") == 0, "Tirelire : rien quand il y a un combo")
	var combo_cranes := grille_de([crane, crane, crane, epee, null])
	verifier(machine.resoudre(combo_cranes, mods).total("or") == 0, "un combo de crânes compte comme un combo")
	var vide := grille_de([null, null, null, null, null])
	verifier(machine.resoudre(vide, mods).total("or") == 2, "un tirage vide n'a pas de combo : +2 or")


func test_jackpot_maudit() -> void:
	var machine := MachineASous.new(5, 1)
	var mods := mods_avec([&"jackpot_maudit"])
	var combo := grille_de([epee, epee, epee, crane, null])
	var r := machine.resoudre(combo, mods)
	verifier(r.total("degats") == 30, "combo de 3 épées avec Jackpot maudit : 30 dégâts : %d" % r.total("degats"))
	verifier(r.combos[0].multiplicateur == 2, "le combo est affiché ×2")
	var quatre := grille_de([epee, epee, epee, epee, null])
	verifier(machine.resoudre(quatre, mods).total("degats") == 60, "combo de 4 : 15 × 2 × 2 = 60")
	var dore := grille_de([epee.creer_doree(), epee, epee, null, null])
	verifier(machine.resoudre(dore, mods).total("degats") == 60, "doré (×2) et Jackpot maudit (×2) se cumulent : 60")
	var sans_combo := grille_de([epee, bouclier, epee, crane, null])
	verifier(machine.resoudre(sans_combo, mods).total("degats") == 6, "sans combo, rien ne change : 6 dégâts")


func test_trefle() -> void:
	var machine := MachineASous.new(5, 1)
	var g := grille_de([crane, epee, crane, crane, null])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1

	var chance_nulle := machine.transformer_craniens(g, 0.0, rng)
	verifier(chance_nulle == g, "chance nulle : la grille ne change pas")
	var etat_rng := rng.state
	machine.transformer_craniens(g, 0.0, rng)
	verifier(rng.state == etat_rng, "chance nulle : le hasard n'est pas consommé")

	var certaine := machine.transformer_craniens(g, 1.0, rng)
	var cranes := 0
	for s in certaine:
		if s != null and s.id == &"crane":
			cranes += 1
	verifier(cranes == 0 and certaine[1].id == &"epee" and certaine[0].id == &"piece" and certaine[4] == null,
			"chance 1,0 : tous les crânes deviennent des pièces, le reste ne bouge pas")
	verifier(g[0].id == &"crane", "la grille d'origine n'est pas modifiée")

	# Environ la moitié sur 1000 crânes.
	var mille: Array[SymbolData] = []
	for i in 1000:
		mille.append(crane)
	var transformes := MachineASous.new(1000, 1).transformer_craniens(mille, 0.5, rng)
	var pieces := 0
	for s in transformes:
		if s.id == &"piece":
			pieces += 1
	verifier(pieces > 430 and pieces < 570, "chance 0,5 : environ la moitié des crânes deviennent des pièces (%d sur 1000)" % pieces)

	# Même graine, même résultat.
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 9
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 9
	var a := machine.transformer_craniens(g, 0.5, rng_a)
	var b := machine.transformer_craniens(g, 0.5, rng_b)
	verifier(a == b, "même graine, même transformation")

	# Les pièces nées d'un crâne peuvent former un combo.
	var combo_de_cranes := grille_de([crane, crane, crane, epee, null])
	var apres := machine.transformer_craniens(combo_de_cranes, 1.0, rng)
	var r := machine.resoudre(apres)
	verifier(r.combos.size() == 1 and r.combos[0].symbole.id == &"piece" and r.total("or") == 10 and r.total("perte_pv") == 0,
			"3 crânes devenus pièces forment un combo de pièces (10 or, aucune perte de PV)")


func test_six_rouleaux() -> void:
	var machine := MachineASous.new(6, 1)
	var six := grille_de([epee, epee, epee, epee, epee, epee])
	var r := machine.resoudre(six)
	verifier(r.combos.size() == 1 and r.combos[0].longueur == 6 and r.combos[0].multiplicateur == 8,
			"combo de 6 : ×8")
	verifier(r.total("degats") == 120, "6 épées = 15 × 8 = 120 dégâts : %d" % r.total("degats"))
	var cinq := grille_de([epee, epee, epee, epee, epee, piece])
	verifier(machine.resoudre(cinq).total("degats") == 60 and machine.resoudre(cinq).total("or") == 2,
			"5 épées + 1 pièce sur 6 rouleaux : jackpot ×4 = 60 dégâts, 2 or")
	var deux_combos := grille_de([epee, epee, epee, crane, crane, crane])
	var r2 := machine.resoudre(deux_combos)
	verifier(r2.combos.size() == 2 and r2.total("degats") == 15 and r2.total("perte_pv") == 6, "2 combos de 3 sur 6 rouleaux")

	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var grille := machine.tirer(Sac.creer_sac_de_depart(), rng)
	verifier(grille.size() == 6 and not grille.has(null), "un tirage à 6 rouleaux remplit 6 cases")
	var petit := Sac.new()
	petit.ajouter(epee, 4)
	verifier(machine.tirer(petit, rng).count(null) == 2, "un sac de 4 symboles laisse 2 rouleaux vides sur 6")

	# Un boss peut bloquer parmi 6 rouleaux.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 2
	var bloqueur := EnemyData.new()
	bloqueur.pv_max = 10
	bloqueur.intentions = [{"type": "blocage", "valeur": 6}]
	var combat := Combat.new(bloqueur, 40, 40, hasard, 6)
	combat.jouer_tour(machine.resoudre(grille_de([null, null, null, null, null, null])))
	verifier(combat.rouleaux_bloques.size() == 6, "un blocage de 6 touche les 6 rouleaux : %d" % combat.rouleaux_bloques.size())


func test_propositions() -> void:
	var partie := Partie.creer(7)
	var bon := true
	var vues := {}
	for essai in 100:
		var offre := partie.proposer_reliques(2)
		if offre.size() != 2 or offre[0].id == offre[1].id:
			bon = false
		for r in offre:
			vues[r.id] = true
	verifier(bon, "toujours 2 reliques différentes proposées (100 essais)")
	verifier(vues.size() == 9, "les 9 reliques peuvent être proposées : %d" % vues.size())

	# Les reliques possédées ne sont jamais proposées.
	partie.ajouter_relique(relique(&"tirelire"))
	partie.ajouter_relique(relique(&"de_pipe"))
	var jamais := true
	for essai in 100:
		for r in partie.proposer_reliques(2):
			if r.id == &"tirelire" or r.id == &"de_pipe":
				jamais = false
	verifier(jamais, "une relique possédée n'est plus proposée")

	# Il peut en rester moins de 2, ou aucune.
	for r in Reliques.toutes():
		partie.ajouter_relique(r)
	verifier(partie.proposer_reliques(2).is_empty(), "toutes possédées : plus rien à proposer")
	var presque := Partie.creer(8)
	for r in Reliques.toutes().slice(0, 8):
		presque.ajouter_relique(r)
	verifier(presque.proposer_reliques(2).size() == 1, "il ne reste qu'une relique : une seule proposée")

	# Même graine, mêmes propositions.
	var a := Partie.creer(11).proposer_reliques(2)
	var b := Partie.creer(11).proposer_reliques(2)
	verifier(a[0].id == b[0].id and a[1].id == b[1].id, "même graine, mêmes reliques proposées")

	# Regarder s'il reste des reliques n'est pas un tirage : peut_recevoir_relique ne touche pas au hasard.
	var p := Partie.creer(12)
	var etat_rng := p.rng.state
	p.peut_recevoir_relique()
	verifier(p.rng.state == etat_rng, "peut_recevoir_relique ne consomme pas le hasard")


func test_relique_offerte() -> void:
	# Une relique est offerte par un coffre ou un boss : l'écran « relique » demande un choix.
	var partie := Partie.creer(13)
	partie.ecran = Partie.Ecran.RELIQUE
	var choix := partie.proposer_reliques(2)[0]
	partie.choisir_relique(choix)
	verifier(partie.a_relique(choix.id), "la relique choisie est possédée")
	verifier(partie.ecran != Partie.Ecran.RELIQUE, "l'écran de relique est quitté")

	# Hors de l'écran de relique, choisir ne donne rien (pas de relique gratuite par erreur).
	var partie2 := Partie.creer(14)
	partie2.choisir_relique(partie2.proposer_reliques(2)[0])
	verifier(partie2.reliques.is_empty(), "pas de relique hors de l'écran de relique")

	# Plus aucune relique à offrir quand on les a toutes.
	var partie3 := Partie.creer(15)
	for r in Reliques.toutes():
		partie3.ajouter_relique(r)
	verifier(not partie3.peut_recevoir_relique(), "toutes possédées : plus rien à offrir")


func test_boutique_reliques() -> void:
	var partie := Partie.creer(81)
	partie.or_total = 200
	var boutique := Boutique.creer(partie)
	verifier(boutique.offres_reliques.size() == 2, "la boutique propose 2 reliques")
	verifier(boutique.offres_reliques[0].id != boutique.offres_reliques[1].id, "2 reliques différentes")
	verifier(boutique.reliques_vendues == [false, false], "au début, aucune relique n'est vendue")
	verifier(boutique.prix_relique(0) == boutique.offres_reliques[0].prix, "le prix vient de la relique")

	# Achat : or débité, relique possédée, offre disparue.
	var premiere := boutique.offres_reliques[0]
	var prix := boutique.prix_relique(0)
	verifier(boutique.peut_acheter_relique(0) and boutique.acheter_relique(0), "acheter une relique")
	verifier(partie.or_total == 200 - prix, "l'or est débité : %d" % partie.or_total)
	verifier(partie.a_relique(premiere.id), "la relique achetée est possédée")
	verifier(boutique.reliques_vendues[0] and not boutique.peut_acheter_relique(0), "l'offre achetée disparaît")
	verifier(not boutique.acheter_relique(0) and partie.or_total == 200 - prix, "on ne rachète pas la même offre")
	verifier(not boutique.acheter_relique(5) and not boutique.acheter_relique(-1), "une offre qui n'existe pas ne s'achète pas")

	# Refus faute d'or : rien ne change.
	var pauvre := Partie.creer(82)
	var boutique2 := Boutique.creer(pauvre)
	pauvre.or_total = 24
	verifier(not boutique2.peut_acheter_relique(0) and not boutique2.peut_acheter_relique(1), "24 or ne suffisent pour aucune relique (prix 25 à 40)")
	verifier(not boutique2.acheter_relique(0) and pauvre.or_total == 24 and pauvre.reliques.is_empty(), "achat refusé : rien ne change")
	pauvre.or_total = boutique2.prix_relique(1)
	verifier(boutique2.acheter_relique(1) and pauvre.or_total == 0, "avec exactement le prix, l'achat passe")

	# L'effet immédiat s'applique à l'achat (Cœur de pierre, Jackpot maudit, Sixième rouleau).
	for id in [&"coeur_de_pierre", &"jackpot_maudit", &"sixieme_rouleau"]:
		var p := Partie.creer(83)
		p.or_total = 100
		var b := Boutique.creer(p)
		b.offres_reliques = [relique(id)] as Array[RelicData]
		b.reliques_vendues = [false]
		b.acheter_relique(0)
		match id:
			&"coeur_de_pierre":
				verifier(p.pv_max == 50 and p.pv == 50, "acheté en boutique, le Cœur de pierre donne 50 PV max")
			&"jackpot_maudit":
				verifier(p.sac.taille() == 17, "acheté en boutique, le Jackpot maudit ajoute 2 crânes")
			_:
				verifier(p.nb_rouleaux == 6, "acheté en boutique, le Sixième rouleau donne 6 rouleaux")

	# Les reliques possédées ne sont plus proposées.
	var partie3 := Partie.creer(84)
	for r in Reliques.toutes().slice(0, 7):
		partie3.ajouter_relique(r)
	var boutique3 := Boutique.creer(partie3)
	verifier(boutique3.offres_reliques.size() == 2, "il reste 2 reliques à proposer")
	for r in boutique3.offres_reliques:
		verifier(not partie3.a_relique(r.id), "la relique proposée (%s) n'est pas déjà possédée" % r.id)
	var partie4 := Partie.creer(85)
	for r in Reliques.toutes():
		partie4.ajouter_relique(r)
	var boutique4 := Boutique.creer(partie4)
	verifier(boutique4.offres_reliques.is_empty(), "toutes les reliques possédées : la boutique n'en propose plus")
	partie4.or_total = 100
	verifier(not boutique4.peut_acheter_relique(0), "rien à acheter quand il n'y a pas d'offre")

	# Une relique déjà possédée (achetée ailleurs) ne peut pas être achetée.
	var partie5 := Partie.creer(86)
	partie5.or_total = 100
	var boutique5 := Boutique.creer(partie5)
	partie5.ajouter_relique(boutique5.offres_reliques[0])
	verifier(not boutique5.peut_acheter_relique(0), "une relique déjà possédée ne s'achète pas")

	# Même graine, mêmes offres de reliques.
	var a := Boutique.creer(Partie.creer(87))
	var b := Boutique.creer(Partie.creer(87))
	verifier(a.offres_reliques[0].id == b.offres_reliques[0].id and a.offres_reliques[1].id == b.offres_reliques[1].id,
			"même graine, mêmes reliques en boutique")


func verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		echecs += 1
		print("  ÉCHEC ", message)
