extends SceneTree
## Tests du Comptoir, du bilan d'une partie, des avantages et des malédictions, à lancer en ligne de commande :
## godot --headless --path . -s res://tests/test_comptoir.gd

var echecs := 0
var machine := MachineASous.new(5, 1)


func _init() -> void:
	test_prix_et_refus()
	test_deblocages_au_hasard()
	test_avantages_et_plafonds()
	test_textes()
	test_bilan_jetons()
	test_bilan_unique()
	test_bilan_maledictions()
	test_avantages_dans_la_partie()
	test_maledictions_dans_la_partie()
	test_rancunier()
	test_mauvais_oeil()
	test_relance_de_partie()
	test_filtres_de_deblocage()
	test_partie_sans_profil()
	print("TERMINÉ : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


# --- Outils -----------------------------------------------------------------

func verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		echecs += 1
		print("  ÉCHEC ", message)


func profil_avec(jetons: int) -> Profil:
	var profil := Profil.nouveau()
	profil.jetons = jetons
	return profil


func comptoir_de(profil: Profil, graine: int = 1) -> Comptoir:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine
	return Comptoir.creer(profil, hasard)


func maledictions_de(ids: Array) -> Array[StringName]:
	var liste: Array[StringName] = []
	for id in ids:
		liste.append(StringName(id))
	return liste


## Une partie finie : `salles` salles franchies, `boss` boss battus, et son issue.
func partie_finie(profil: Profil, salles: int, boss: int, issue: Partie.Etat) -> Partie:
	var partie := Partie.creer(1, profil)
	partie.salles_franchies = salles
	partie.boss_vaincus = boss
	partie.etat = issue
	return partie


# --- Tests ------------------------------------------------------------------

func test_prix_et_refus() -> void:
	print("Prix et refus")
	var c := comptoir_de(profil_avec(0))
	verifier(c.prix(Comptoir.Achat.SYMBOLE) == 10 and c.prix(Comptoir.Achat.RELIQUE) == 15 and c.prix(Comptoir.Achat.PV_MAX) == 20
			and c.prix(Comptoir.Achat.OR_DE_DEPART) == 15 and c.prix(Comptoir.Achat.RELANCE) == 30 and c.prix(Comptoir.Achat.TREFLE) == 25,
			"les prix du cahier des charges : 10, 15, 20, 15, 30, 25")
	for achat in Comptoir.ORDRE:
		verifier(not c.peut_acheter(achat) and not c.acheter(achat), "sans jeton, l'achat %d est refusé" % achat)
	var presque := comptoir_de(profil_avec(9))
	verifier(not presque.acheter(Comptoir.Achat.SYMBOLE) and presque.profil.jetons == 9, "9 jetons ne suffisent pas pour un symbole (10) : rien ne change")
	var juste := comptoir_de(profil_avec(10))
	verifier(juste.acheter(Comptoir.Achat.SYMBOLE) and juste.profil.jetons == 0, "10 jetons : le symbole est acheté, 0 jeton restant")


func test_deblocages_au_hasard() -> void:
	print("Déblocages au hasard")
	var c := comptoir_de(profil_avec(1000), 3)
	var obtenus: Array[StringName] = []
	for i in 4:
		verifier(c.acheter(Comptoir.Achat.SYMBOLE), "déblocage de symbole %d" % (i + 1))
		obtenus.append(c.dernier_deblocage)
	var uniques := {}
	for id in obtenus:
		uniques[id] = true
	verifier(uniques.size() == 4 and c.profil.symboles_verrouilles().is_empty(), "les 4 symboles sont débloqués, sans doublon : %s" % str(obtenus))
	verifier(c.est_epuise(Comptoir.Achat.SYMBOLE) and not c.acheter(Comptoir.Achat.SYMBOLE) and c.profil.jetons == 960,
			"le 5e déblocage est refusé et ne coûte rien (960 jetons restants)")
	var reliques: Array[StringName] = []
	for i in 5:
		verifier(c.acheter(Comptoir.Achat.RELIQUE), "déblocage de relique %d" % (i + 1))
		reliques.append(c.dernier_deblocage)
	uniques = {}
	for id in reliques:
		uniques[id] = true
	verifier(uniques.size() == 5 and c.est_epuise(Comptoir.Achat.RELIQUE) and not c.acheter(Comptoir.Achat.RELIQUE), "les 5 reliques sont débloquées, puis le bouton est épuisé")
	verifier(c.profil.a_debloque_relique(&"cinquieme_as") and c.profil.a_debloque_symbole(&"trefle"), "le profil a bien tout débloqué")

	# Rejouable : même graine, mêmes déblocages ; d'autres graines donnent d'autres résultats.
	var a := comptoir_de(profil_avec(100), 11)
	var b := comptoir_de(profil_avec(100), 11)
	a.acheter(Comptoir.Achat.SYMBOLE)
	b.acheter(Comptoir.Achat.SYMBOLE)
	verifier(a.dernier_deblocage == b.dernier_deblocage, "même graine : même déblocage")
	var premiers := {}
	for graine in 40:
		var autre := comptoir_de(profil_avec(10), graine)
		autre.acheter(Comptoir.Achat.SYMBOLE)
		premiers[autre.dernier_deblocage] = true
	verifier(premiers.size() == 4, "selon la graine, chacun des 4 symboles peut sortir en premier")
	var sans_graine := Comptoir.creer(profil_avec(10))
	verifier(sans_graine.acheter(Comptoir.Achat.SYMBOLE), "un Comptoir sans graine donnée fonctionne aussi")


func test_avantages_et_plafonds() -> void:
	print("Avantages et plafonds")
	var c := comptoir_de(profil_avec(1000))
	for niveau in 3:
		verifier(c.acheter(Comptoir.Achat.PV_MAX) and c.profil.niveau_pv == niveau + 1, "PV max niveau %d" % (niveau + 1))
	verifier(not c.acheter(Comptoir.Achat.PV_MAX) and c.profil.niveau_pv == 3 and c.est_epuise(Comptoir.Achat.PV_MAX), "PV max : 3 niveaux au maximum")
	for niveau in 3:
		c.acheter(Comptoir.Achat.OR_DE_DEPART)
	verifier(not c.acheter(Comptoir.Achat.OR_DE_DEPART) and c.profil.niveau_or == 3, "or de départ : 3 niveaux au maximum")
	verifier(c.acheter(Comptoir.Achat.RELANCE) and c.profil.relance_de_partie and not c.acheter(Comptoir.Achat.RELANCE), "la relance s'achète une fois")
	verifier(c.acheter(Comptoir.Achat.TREFLE) and c.profil.trefle_au_depart and not c.acheter(Comptoir.Achat.TREFLE), "le trèfle s'achète une fois")
	# Tout acheté : 3 × 20 + 3 × 15 + 30 + 25 = 160 jetons.
	verifier(c.profil.jetons == 1000 - 160, "avantages : 160 jetons dépensés (%d restants)" % c.profil.jetons)
	verifier(c.profil.pv_bonus() == 15 and c.profil.or_bonus() == 30, "bonus : +15 PV max, +30 or")


func test_textes() -> void:
	print("Textes")
	var c := comptoir_de(profil_avec(0))
	for achat in Comptoir.ORDRE:
		verifier(c.titre(achat) != "" and c.detail(achat) != "", "l'achat %d a un titre et un détail" % achat)
	verifier("1" in c.detail(Comptoir.Achat.PV_MAX) or "0" in c.detail(Comptoir.Achat.PV_MAX), "le détail des PV donne le niveau")
	var tout := comptoir_de(profil_avec(1000))
	for achat in [Comptoir.Achat.RELANCE, Comptoir.Achat.TREFLE]:
		tout.acheter(achat)
		verifier(tout.detail(achat).contains("acheté"), "un avantage acheté le dit")


func test_bilan_jetons() -> void:
	print("Bilan : les jetons")
	verifier(Bilan.jetons_gagnes(partie_finie(Profil.nouveau(), 7, 1, Partie.Etat.DEFAITE)) == 7 + 5, "7 salles et 1 boss : 12 jetons")
	verifier(Bilan.jetons_gagnes(partie_finie(Profil.nouveau(), 0, 0, Partie.Etat.DEFAITE)) == 0, "une défaite immédiate : 0 jeton")
	verifier(Bilan.jetons_gagnes(partie_finie(Profil.nouveau(), 18, 3, Partie.Etat.VICTOIRE)) == 18 + 15 + 10, "victoire : 18 salles + 3 boss + 10 = 43 jetons")
	var profil := profil_avec(5)
	var partie := partie_finie(profil, 4, 0, Partie.Etat.DEFAITE)
	var bilan := Bilan.appliquer(partie, profil, RandomNumberGenerator.new())
	verifier(profil.jetons == 9 and int(bilan["jetons"]) == 4, "le profil reçoit les jetons (5 + 4 = 9)")
	verifier(profil.parties_jouees == 1 and profil.victoires == 0, "une partie jouée, aucune victoire")
	var gagnee := partie_finie(profil, 18, 3, Partie.Etat.VICTOIRE)
	Bilan.appliquer(gagnee, profil, RandomNumberGenerator.new())
	verifier(profil.parties_jouees == 2 and profil.victoires == 1, "une victoire de plus")
	var en_cours := Partie.creer(1, profil)
	en_cours.salles_franchies = 5
	var avant := profil.jetons
	Bilan.appliquer(en_cours, profil, RandomNumberGenerator.new())
	verifier(profil.jetons == avant and not en_cours.bilan_applique, "une partie qui n'est pas finie ne rapporte rien")


func test_bilan_unique() -> void:
	print("Bilan : crédité une seule fois")
	var profil := profil_avec(0)
	var partie := partie_finie(profil, 6, 1, Partie.Etat.DEFAITE)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 1
	Bilan.appliquer(partie, profil, hasard)
	var jetons := profil.jetons
	var maledictions := profil.maledictions.duplicate()
	Bilan.appliquer(partie, profil, hasard)
	Bilan.appliquer(partie, profil, hasard)
	verifier(profil.jetons == jetons and profil.parties_jouees == 1 and profil.maledictions == maledictions,
			"recharger l'écran de fin ne crédite pas deux fois (jetons, parties, malédictions)")
	verifier(int(partie.bilan["jetons"]) == 11, "le bilan reste lisible pour l'écran : 11 jetons")


func test_bilan_maledictions() -> void:
	print("Bilan : les malédictions")
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 2
	# Défaite sans boss : une malédiction de plus.
	var profil := profil_avec(0)
	var bilan := Bilan.appliquer(partie_finie(profil, 3, 0, Partie.Etat.DEFAITE), profil, hasard)
	verifier(profil.maledictions.size() == 1 and bilan["malediction_recue"] == profil.maledictions[0], "une défaite ajoute une malédiction")
	# On cumule jusqu'à 3, toutes différentes, puis plus rien.
	for i in 4:
		Bilan.appliquer(partie_finie(profil, 3, 0, Partie.Etat.DEFAITE), profil, hasard)
	verifier(profil.maledictions.size() == 3, "3 malédictions au maximum")
	var uniques := {}
	for id in profil.maledictions:
		uniques[id] = true
	verifier(uniques.size() == 3, "toutes différentes")
	var pleine := Bilan.appliquer(partie_finie(profil, 3, 0, Partie.Etat.DEFAITE), profil, hasard)
	verifier(pleine["malediction_recue"] == &"" and profil.maledictions.size() == 3, "à 3 malédictions, une défaite n'en ajoute plus")

	# Un boss battu en efface une (la plus ancienne), avant l'ajout de la défaite.
	var p2 := profil_avec(0)
	p2.maledictions.assign(maledictions_de(["fatigue", "mauvais_oeil"]))
	var b2 := Bilan.appliquer(partie_finie(p2, 8, 1, Partie.Etat.DEFAITE), p2, hasard)
	verifier(b2["maledictions_effacees"] == maledictions_de(["fatigue"]), "le boss efface la plus ancienne (Fatigue)")
	verifier(not (&"fatigue" in p2.maledictions) and &"mauvais_oeil" in p2.maledictions and p2.maledictions.size() == 2,
			"reste Mauvais œil, plus la nouvelle de la défaite")
	# Deux boss en effacent deux ; pas plus qu'il n'y en a.
	var p3 := profil_avec(0)
	p3.maledictions.assign(maledictions_de(["sac_leste"]))
	var b3 := Bilan.appliquer(partie_finie(p3, 14, 2, Partie.Etat.DEFAITE), p3, hasard)
	verifier(b3["maledictions_effacees"].size() == 1 and p3.maledictions.size() == 1, "2 boss mais 1 seule malédiction : elle est effacée, puis la défaite en ajoute une")
	# La malédiction qui vient d'être effacée ne revient pas aussitôt.
	var jamais_la_meme := true
	for graine in 60:
		hasard.seed = graine
		var p5 := profil_avec(0)
		p5.maledictions.assign(maledictions_de(["fatigue"]))
		var b5 := Bilan.appliquer(partie_finie(p5, 8, 1, Partie.Etat.DEFAITE), p5, hasard)
		if b5["malediction_recue"] == &"fatigue":
			jamais_la_meme = false
	verifier(jamais_la_meme, "la malédiction effacée par le boss ne revient pas aussitôt (60 tirages)")
	# Une victoire efface tout et n'ajoute rien.
	var p4 := profil_avec(0)
	p4.maledictions.assign(maledictions_de(["fatigue", "mauvais_oeil", "sac_leste"]))
	var b4 := Bilan.appliquer(partie_finie(p4, 18, 3, Partie.Etat.VICTOIRE), p4, hasard)
	verifier(p4.maledictions.is_empty() and b4["maledictions_effacees"].size() == 3 and b4["malediction_recue"] == &"", "une victoire efface toutes les malédictions et n'en ajoute pas")


func test_avantages_dans_la_partie() -> void:
	print("Avantages au départ de la partie")
	var profil := profil_avec(0)
	profil.niveau_pv = 2
	profil.niveau_or = 1
	profil.trefle_au_depart = true
	profil.relance_de_partie = true
	var partie := Partie.creer(1, profil)
	verifier(partie.pv_max == 50 and partie.pv == 50, "PV max et PV de départ : 40 + 2 × 5 = 50")
	verifier(partie.or_total == 10, "or de départ : +10")
	verifier(partie.sac.taille() == 16 and partie.sac.symboles.any(func(x: SymbolData) -> bool: return x.id == &"trefle"), "un Trèfle dans le sac de départ (16 symboles)")
	verifier(partie.relances_de_partie == 1, "une relance gratuite par partie")
	verifier(profil.niveau_pv == 2, "le profil n'est pas modifié par la partie")
	var neuve := Partie.creer(1, Profil.nouveau())
	verifier(neuve.pv_max == 40 and neuve.or_total == 0 and neuve.sac.taille() == 15 and neuve.relances_de_partie == 0, "un profil neuf ne change rien")


func test_maledictions_dans_la_partie() -> void:
	print("Malédictions dans la partie")
	var profil := profil_avec(0)
	profil.maledictions.assign(maledictions_de(["sac_leste", "fatigue", "bourse_trouee"]))
	var partie := Partie.creer(1, profil)
	verifier(partie.maledictions == profil.maledictions, "la partie garde les malédictions du lancement")
	verifier(partie.pv_max == 35 and partie.pv == 35, "Fatigue : 35 PV max")
	var cranes := 0
	for symbole in partie.sac.symboles:
		if symbole.id == &"crane":
			cranes += 1
	verifier(cranes == 3 and partie.sac.taille() == 16, "Sac lesté : 3 crânes au lieu de 2 (16 symboles)")
	# Bourse trouée : tous les prix de la boutique +20 %.
	partie.or_total = 1000
	var boutique := Boutique.creer(partie)
	verifier(boutique.prix_retrait() == 12 and boutique.prix_amelioration() == 24 and boutique.prix_soin() == 12, "retrait 10→12, dorure 20→24, soin 10→12")
	var prix_ok := true
	for i in boutique.offres.size():
		if boutique.prix_offre(i) != ceili(boutique.offres[i].prix * 1.2):
			prix_ok = false
	for i in boutique.offres_reliques.size():
		if boutique.prix_relique(i) != ceili(boutique.offres_reliques[i].prix * 1.2):
			prix_ok = false
	verifier(prix_ok, "les offres de symboles et de reliques coûtent 20 % de plus (arrondi au-dessus)")
	var avant := partie.or_total
	boutique.acheter(0)
	verifier(avant - partie.or_total == boutique.prix_offre(0), "on paie le prix majoré")
	verifier(boutique.ameliorer(0) and partie.or_total == avant - boutique.prix_offre(0) - 24, "la dorure est payée au prix majoré")
	var sans := Boutique.creer(Partie.creer(1, Profil.nouveau()))
	verifier(sans.prix_retrait() == 10 and sans.prix_soin() == 10, "sans malédiction, les prix sont ceux de base")


func test_rancunier() -> void:
	print("Croupier rancunier : le premier combat de chaque étage")
	var profil := profil_avec(0)
	profil.maledictions.assign(maledictions_de(["croupier_rancunier"]))
	var partie := Partie.creer(5, profil)
	partie.choisir_porte(0)
	var ennemi := partie.ennemi_courant
	var combat := partie.creer_combat()
	verifier(combat.pv_max_ennemi == Maledictions.pv_ennemi_renforces(ennemi.pv_max) and combat.pv_ennemi == combat.pv_max_ennemi,
			"premier combat de l'étage 1 : %d PV au lieu de %d" % [combat.pv_max_ennemi, ennemi.pv_max])
	verifier(ennemi.pv_max == load("res://data/enemies/%s.tres" % ennemi.id).pv_max, "le fichier de l'ennemi n'est pas modifié")
	var recharge := partie.creer_combat()
	verifier(recharge.pv_max_ennemi == combat.pv_max_ennemi, "recharger l'écran garde le même renfort (pas de cumul, pas de perte)")
	# On gagne ; le combat suivant du même étage n'est pas renforcé.
	combat = partie.creer_combat()
	combat.pv_ennemi = 0
	combat.etat = Combat.Etat.VICTOIRE
	partie.terminer_combat(combat)
	partie.terminer_recompense()
	partie.choisir_porte(0)
	var garde_fou := 0
	while partie.ecran != Partie.Ecran.COMBAT and garde_fou < 50:
		garde_fou += 1
		partie.choisir_porte(0)
		if partie.ecran == Partie.Ecran.RELIQUE:
			partie.choisir_relique(partie.proposer_reliques(1)[0])
		elif partie.ecran == Partie.Ecran.BOUTIQUE:
			partie.quitter_boutique()
		elif partie.ecran == Partie.Ecran.REPOS:
			partie.repos_soigner()
			if partie.ecran == Partie.Ecran.REPOS:
				partie.quitter_repos()
	var suivant := partie.creer_combat()
	verifier(suivant.pv_max_ennemi == partie.ennemi_courant.pv_max, "le 2e combat du même étage a ses PV normaux")
	# À l'étage suivant, le premier combat est de nouveau renforcé.
	partie.sauter_etage()
	partie.choisir_porte(0)
	var etage2 := partie.creer_combat()
	verifier(partie.etage == 2 and etage2.pv_max_ennemi == Maledictions.pv_ennemi_renforces(partie.ennemi_courant.pv_max), "étage 2 : le premier combat est renforcé à son tour")
	# Sans la malédiction : jamais.
	var normale := Partie.creer(5, Profil.nouveau())
	normale.choisir_porte(0)
	verifier(normale.creer_combat().pv_max_ennemi == normale.ennemi_courant.pv_max, "sans malédiction, PV normaux")


func test_mauvais_oeil() -> void:
	print("Mauvais œil : une mise gagnée rapporte ×2")
	var profil := profil_avec(0)
	profil.maledictions.assign(maledictions_de(["mauvais_oeil"]))
	var partie := Partie.creer(1, profil)
	partie.choisir_porte(0)
	var combat := partie.creer_combat()
	verifier(combat.gain_mise_or == 2, "le combat rapporte ×2")
	partie.or_total = 100
	combat = partie.creer_combat()
	var epee := load("res://data/symbols/epee.tres") as SymbolData
	var grille: Array[SymbolData] = [epee, epee, epee, null, null]
	var avant := combat.or_gagne
	combat.jouer_tour(machine.resoudre(grille), Mise.en_or(10))
	verifier(combat.or_gagne - avant == 10 or combat.est_fini(), "mise de 10 or gagnée : +10 net (×2) au lieu de +20 (%d)" % (combat.or_gagne - avant))
	var normal := Partie.creer(1, Profil.nouveau())
	normal.choisir_porte(0)
	normal.or_total = 100
	var c3 := normal.creer_combat()
	verifier(c3.gain_mise_or == 3, "sans malédiction : ×3")
	var avant3 := c3.or_gagne
	c3.jouer_tour(machine.resoudre(grille), Mise.en_or(10))
	verifier(c3.or_gagne - avant3 == 20 or c3.est_fini(), "mise de 10 or gagnée : +20 net (×3)")


func test_relance_de_partie() -> void:
	print("Relance gratuite par partie")
	var profil := profil_avec(0)
	profil.relance_de_partie = true
	var partie := Partie.creer(1, profil)
	partie.choisir_porte(0)
	var combat := partie.creer_combat()
	verifier(combat.relances_de_partie == 1 and combat.relances_toutes_les_cases() == 1, "le combat reçoit la relance")
	combat.tirer()
	verifier(combat.peut_relancer(), "le tirage peut être relancé")
	verifier(combat.relancer_tout() and combat.relances_de_partie == 0 and not combat.peut_relancer(), "relancer consomme la relance de partie")
	combat.valider()
	# Elle n'est reprise par la partie qu'à la fin du combat.
	combat.pv_ennemi = 0
	combat.etat = Combat.Etat.VICTOIRE
	partie.terminer_combat(combat)
	verifier(partie.relances_de_partie == 0, "après usage, la partie n'a plus de relance")
	partie.terminer_recompense()
	partie.choisir_porte(0)
	if partie.ecran == Partie.Ecran.COMBAT:
		verifier(partie.creer_combat().relances_de_partie == 0, "le combat suivant n'a plus de relance")
	# Non utilisée : elle reste pour plus tard.
	var intacte := Partie.creer(2, profil)
	intacte.choisir_porte(0)
	var c2 := intacte.creer_combat()
	c2.pv_ennemi = 0
	c2.etat = Combat.Etat.VICTOIRE
	intacte.terminer_combat(c2)
	verifier(intacte.relances_de_partie == 1, "une relance non utilisée est gardée pour un autre combat")
	# Avec le Dé pipé : on dépense d'abord celle de la relique.
	var avec_de := Partie.creer(3, profil)
	avec_de.ajouter_relique(Reliques.charger(&"de_pipe"))
	avec_de.choisir_porte(0)
	var c3 := avec_de.creer_combat()
	verifier(c3.relances_toutes_les_cases() == 2, "Dé pipé + relance de partie : 2 relances de tous les rouleaux")
	c3.tirer()
	c3.relancer_tout()
	verifier(c3.relances_gratuites == 0 and c3.relances_de_partie == 1, "la relique sert d'abord, la relance de partie est gardée")
	var sans := Partie.creer(4, Profil.nouveau())
	sans.choisir_porte(0)
	var c4 := sans.creer_combat()
	c4.tirer()
	verifier(not c4.peut_relancer() and not c4.relancer_tout(), "sans avantage ni relique, pas de relance")


func test_filtres_de_deblocage() -> void:
	print("Ce que le profil permet de proposer")
	var profil := Profil.nouveau()
	var partie := Partie.creer(7, profil)
	var vus := {}
	for i in 200:
		for symbole in partie.tirer_symboles(3):
			vus[symbole.id] = true
	verifier(vus.size() == 4 and not vus.has(&"bombe") and not vus.has(&"crane"), "profil neuf : seulement les 4 symboles de base (%s)" % str(vus.keys()))
	profil.symboles_debloques.append(&"bombe")
	profil.symboles_debloques.append(&"trefle")
	var avec := Partie.creer(7, profil)
	vus = {}
	for i in 300:
		for symbole in avec.tirer_symboles(3):
			vus[symbole.id] = true
	verifier(vus.size() == 6 and vus.has(&"bombe") and vus.has(&"trefle") and not vus.has(&"aimant"), "Bombe et Trèfle débloqués : ils peuvent sortir, pas l'Aimant")
	# Reliques : seulement les 4 débloquées.
	var reliques_vues := {}
	for i in 100:
		for relique in Partie.creer(i, Profil.nouveau()).proposer_reliques(2):
			reliques_vues[relique.id] = true
	verifier(reliques_vues.size() == 4 and not reliques_vues.has(&"jackpot_maudit"), "profil neuf : 4 reliques proposables (%s)" % str(reliques_vues.keys()))
	var p := Partie.creer(1, Profil.nouveau())
	verifier(p.peut_recevoir_relique(), "il reste des reliques à recevoir")
	for id in Profil.RELIQUES_DE_DEPART:
		p.ajouter_relique(Reliques.charger(id))
	verifier(not p.peut_recevoir_relique() and p.proposer_reliques(2).is_empty(), "les 4 reliques débloquées possédées : plus rien à proposer (les verrouillées ne comptent pas)")
	var boutique := Boutique.creer(Partie.creer(3, Profil.nouveau()))
	var ok := true
	for relique in boutique.offres_reliques:
		if not (relique.id in Profil.RELIQUES_DE_DEPART):
			ok = false
	verifier(ok, "la boutique ne vend que des reliques débloquées")


func test_partie_sans_profil() -> void:
	print("Sans profil : comme en v0.6")
	var partie := Partie.creer(1)
	verifier(partie.profil == null and partie.maledictions.is_empty() and partie.pv_max == 40 and partie.sac.taille() == 15, "aucun avantage, aucune malédiction")
	var reliques_vues := {}
	for i in 100:
		for relique in Partie.creer(i).proposer_reliques(2):
			reliques_vues[relique.id] = true
	verifier(reliques_vues.size() == 9, "les 9 reliques sont proposables")
	verifier(partie.prix_ajuste(10) == 10, "aucun surcoût")
