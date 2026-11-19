extends SceneTree
## OUTIL : mesure ce que deviennent des « robots » qui traversent le donjon sans réfléchir,
## pour régler la difficulté (valeurs des ennemis dans data/enemies/*.tres, prix, soins).
##
## Lancer :  godot --headless --path . -s res://outils/equilibrage.gd
## (avec `timeout` et la sortie redirigée vers un fichier : voir CLAUDE.md)
##
## L'outil lit les valeurs ACTUELLES des .tres : pour essayer un réglage, modifier le .tres
## puis relancer. Pour chaque robot : le taux de victoire, la part de parties qui atteignent
## chaque boss, et le nombre de reliques à la fin.
##
## Cible (voir le cahier des charges, « Précisions de règles (v0.6) ») : le robot « prudent »
## gagne environ 35 à 45 % de ses parties, le robot « hasard » au moins 10 %, et le boss de
## l'étage 1 est atteint dans plus de 85 % des parties ; un vrai joueur fait mieux.

## Nombre de parties jouées par robot.
const NB_PARTIES := 400

## Essais EN MÉMOIRE (les .tres ne bougent pas) : identifiant d'ennemi -> [facteur de PV, facteur
## d'attaque, facteur d'or de victoire]. Vide = les valeurs des .tres. Une fois de bonnes valeurs
## trouvées, les recopier dans data/enemies/*.tres.
const REGLAGES: Dictionary = {}
## Garde les ennemis modifiés en mémoire (Godot décharge sinon les ressources non utilisées).
var gardees: Array[EnemyData] = []

## Les robots :
##  hasard   : choisit ses portes au hasard, n'achète aucune relique, ne mise pas
##  prudent  : repos s'il est blessé, boutique s'il a de l'or, sinon coffre puis combat ; achète des reliques
##  tout     : comme prudent + mise 5 or quand il a au moins 25 or
const ROBOTS: Array[String] = ["hasard", "prudent", "tout"]

var hasard := RandomNumberGenerator.new()
## Pour chaque ennemi : combien de fois il a été affronté, et combien de fois le robot y est mort.
var affrontements := {}
var morts := {}


func _initialize() -> void:
	_appliquer_reglages()
	for robot in ROBOTS:
		_essayer(robot)
	# Le robot « prudent » avec un profil : neuf (4 reliques et 4 symboles seulement), avec 3 malédictions,
	# et avec tous les avantages achetés. Le jeu doit rester jouable dans chaque cas.
	for variante in ["profil neuf", "3 malédictions", "tous les avantages"]:
		_essayer("prudent", variante)
	quit()


## Le profil d'une variante (null = pas de profil : le jeu de la v0.6).
func _profil_de(variante: String) -> Profil:
	if variante == "":
		return null
	var profil := Profil.nouveau()
	if variante == "3 malédictions":
		profil.maledictions.assign([Maledictions.FATIGUE, Maledictions.CROUPIER_RANCUNIER, Maledictions.BOURSE_TROUEE] as Array[StringName])
	elif variante == "tous les avantages":
		profil.niveau_pv = Profil.NIVEAU_MAX
		profil.niveau_or = Profil.NIVEAU_MAX
		profil.relance_de_partie = true
		profil.trefle_au_depart = true
		profil.symboles_debloques.assign(Profil.SYMBOLES_DE_DEPART + Profil.SYMBOLES_A_DEBLOQUER)
		profil.reliques_debloquees.assign(Profil.RELIQUES_DE_DEPART + Profil.RELIQUES_A_DEBLOQUER)
	return profil


func _appliquer_reglages() -> void:
	# Des essais peuvent aussi venir de la ligne de commande, en JSON, après « -- » :
	#   ... -s res://outils/equilibrage.gd -- {"rat_croupier":[0.8,0.7,1.0]}
	var reglages: Dictionary = REGLAGES
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		var lu: Variant = JSON.parse_string(arguments[0])
		if lu is Dictionary:
			reglages = lu
	for id: String in reglages:
		var facteurs: Array = reglages[id]
		var ennemi := load("res://data/enemies/%s.tres" % id) as EnemyData
		gardees.append(ennemi)
		ennemi.pv_max = roundi(ennemi.pv_max * float(facteurs[0]))
		ennemi.or_victoire = roundi(ennemi.or_victoire * float(facteurs[2]))
		var nouvelles: Array[Dictionary] = []
		for intention in ennemi.intentions:
			var copie: Dictionary = intention.duplicate()
			if copie["type"] == "attaque":
				copie["valeur"] = roundi(int(copie["valeur"]) * float(facteurs[1]))
			nouvelles.append(copie)
		ennemi.intentions = nouvelles
	print("réglages essayés : ", reglages)


func _essayer(robot: String, variante: String = "") -> void:
	hasard.seed = 4
	affrontements = {}
	morts = {}
	var victoires := 0
	var reliques_total := 0
	var atteint_boss := [0, 0, 0]
	var salles_total := 0
	var fuites := 0
	for graine in NB_PARTIES:
		var partie := Partie.creer(graine, _profil_de(variante))
		var gardefou := 0
		while partie.etat == Partie.Etat.EN_COURS and gardefou < 800:
			gardefou += 1
			match partie.ecran:
				Partie.Ecran.PORTES:
					partie.choisir_porte(_porte(partie, robot))
				Partie.Ecran.COMBAT:
					if partie.est_combat_de_boss():
						atteint_boss[partie.etage - 1] += 1
					fuites += _combat(partie, robot == "tout")
				Partie.Ecran.RECOMPENSE:
					partie.choisir_recompense(partie.proposer_recompenses()[0])
					partie.terminer_recompense()
				Partie.Ecran.RELIQUE:
					partie.choisir_relique(partie.proposer_reliques(2)[0])
				Partie.Ecran.BOUTIQUE:
					_boutique(partie, robot != "hasard")
					partie.quitter_boutique()
				Partie.Ecran.REPOS:
					_repos(partie)
		reliques_total += partie.reliques.size()
		salles_total += partie.salles_franchies
		if partie.etat == Partie.Etat.VICTOIRE:
			victoires += 1

	print("[%s%s] %d%% de victoires | boss atteints : étage 1 %d%%, étage 2 %d%%, étage 3 %d%% | %.1f salles, %.1f reliques par partie, %.2f fuites par partie" % [
		robot, (" · " + variante) if variante != "" else "", victoires * 100 / NB_PARTIES,
		atteint_boss[0] * 100 / NB_PARTIES, atteint_boss[1] * 100 / NB_PARTIES, atteint_boss[2] * 100 / NB_PARTIES,
		salles_total / float(NB_PARTIES), reliques_total / float(NB_PARTIES), fuites / float(NB_PARTIES)])
	var lignes := PackedStringArray()
	for id: String in affrontements:
		lignes.append("%s %d/%d" % [id, int(morts.get(id, 0)), int(affrontements[id])])
	print("    morts / combats : ", ", ".join(lignes))


## La porte du robot.
func _porte(partie: Partie, robot: String) -> int:
	var portes := partie.portes()
	if robot == "hasard":
		return hasard.randi_range(0, portes.size() - 1)
	var voeux: Array[Salle.Type] = []
	if partie.pv * 100 < partie.pv_max * 55:
		voeux.append(Salle.Type.REPOS)
	if partie.or_total >= 30:
		voeux.append(Salle.Type.BOUTIQUE)
	voeux.append(Salle.Type.COFFRE)
	voeux.append(Salle.Type.COMBAT)
	for voulu in voeux:
		for i in portes.size():
			if portes[i].type == voulu:
				return i
	return 0


## Un combat entier. Renvoie 1 si l'ennemi s'est enfui.
func _combat(partie: Partie, mise: bool) -> int:
	var combat := partie.creer_combat()
	var id := String(combat.ennemi.id)
	affrontements[id] = int(affrontements.get(id, 0)) + 1
	var tours := 0
	while not combat.est_fini() and tours < 300:
		var la_mise := Mise.aucune()
		if mise and combat.peut_miser(Mise.en_or(5)) and combat.or_du_joueur() >= 25:
			la_mise = Mise.en_or(5)
		combat.tirer(la_mise)
		# Relance tout s'il n'a aucun combo et qu'il peut le faire.
		if combat.peut_relancer() and combat.resultat_courant.combos.is_empty():
			combat.relancer_tout()
		combat.valider()
		tours += 1
	partie.terminer_combat(combat)
	if combat.etat == Combat.Etat.DEFAITE:
		morts[id] = int(morts.get(id, 0)) + 1
	return 1 if combat.etat == Combat.Etat.FUITE else 0


## Le repos du robot : se soigne s'il est blessé, sinon dore une épée.
func _repos(partie: Partie) -> void:
	if partie.soin_du_repos() > 0:
		partie.repos_soigner()
		return
	for i in partie.sac.taille():
		if partie.sac.symboles[i].id == &"epee" and partie.repos_dorer(i):
			return
	for i in partie.sac.taille():
		if partie.repos_dorer(i):
			return


## La boutique d'un robot : achète les reliques (si voulu), se soigne, retire un crâne, achète ce qu'il peut.
func _boutique(partie: Partie, achete_reliques: bool) -> void:
	var boutique := Boutique.creer(partie)
	if achete_reliques:
		for i in boutique.offres_reliques.size():
			boutique.acheter_relique(i)
	while boutique.peut_soigner() and partie.pv <= partie.pv_max - Boutique.SOIN_PV:
		boutique.soigner()
	for i in partie.sac.taille():
		if partie.sac.symboles[i].id == &"crane" and boutique.retirer(i):
			break
	for i in boutique.offres.size():
		boutique.acheter(i)
