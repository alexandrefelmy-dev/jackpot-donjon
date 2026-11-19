extends SceneTree
## OUTIL : mesure le taux de victoire de « robots » qui jouent sans réfléchir, pour régler
## la difficulté (attaques des ennemis, prix, reliques).
##
## Lancer :  godot --headless --path . -s res://outils/equilibrage.gd
## (avec `timeout` et la sortie redirigée vers un fichier : voir CLAUDE.md)
##
## Les valeurs essayées sont changées EN MÉMOIRE seulement : les fichiers .tres ne bougent pas.
## Une fois de bonnes valeurs trouvées, les recopier à la main dans data/enemies/*.tres.
##
## Cible : environ 50 à 60 % de victoires pour un robot sans réflexion (un vrai joueur fait mieux).

## Les attaques à essayer : [rat, squelette, gobelin, boss]. Ajouter des lignes pour comparer.
const REGLAGES: Array = [[8, 13, 9, 14]]
## Nombre de parties jouées par réglage et par mode.
const NB_PARTIES := 600

## Les robots : ce qu'ils font en plus de combattre.
##  sans_relique       : ignore les reliques (la relique offerte après le combat 3 est refusée)
##  relique_offerte    : prend la relique offerte après le combat 3
##  reliques_et_achats : + achète les reliques de la boutique
##  tout               : + mise 5 or quand il a au moins 25 or
const MODES: Array[String] = ["sans_relique", "relique_offerte", "reliques_et_achats", "tout"]

var machine := MachineASous.new(5, 1)
## Garde les ennemis modifiés en mémoire (Godot décharge sinon les ressources non utilisées).
## Seuls les 4 ennemis de l'étage 1 sont réglés ici : un nouvel ennemi du jeu garderait ses
## valeurs du .tres et fausserait la mesure tant qu'il n'est pas ajouté à _essayer().
var gardees: Array[EnemyData] = []


func _initialize() -> void:
	for reglage: Array in REGLAGES:
		for mode in MODES:
			_essayer(mode, reglage)
	quit()


## Change l'attaque d'un ennemi (en mémoire).
func _regler(nom: String, attaque: int) -> void:
	var ennemi := load("res://data/enemies/%s.tres" % nom) as EnemyData
	gardees.append(ennemi)
	var nouvelles: Array[Dictionary] = []
	for intention in ennemi.intentions:
		var copie: Dictionary = intention.duplicate()
		if copie["type"] == "attaque":
			copie["valeur"] = attaque
		nouvelles.append(copie)
	ennemi.intentions = nouvelles


func _essayer(mode: String, reglage: Array) -> void:
	_regler("rat_egout", reglage[0])
	_regler("squelette", reglage[1])
	_regler("gobelin_tricheur", reglage[2])
	_regler("rat_croupier", reglage[3])

	var prend_relique := mode != "sans_relique"
	var achete_reliques := mode == "reliques_et_achats" or mode == "tout"
	var mise := mode == "tout"
	var victoires := 0
	var reliques_total := 0

	for graine in NB_PARTIES:
		var partie := Partie.creer(graine)
		while partie.etat == Partie.Etat.EN_COURS:
			var combat := partie.creer_combat()
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
			if partie.etat == Partie.Etat.EN_COURS:
				partie.choisir_recompense(partie.proposer_recompenses()[0])
				if prend_relique and partie.relique_a_offrir():
					partie.choisir_relique_offerte(partie.proposer_reliques(2)[0])
				_boutique(partie, achete_reliques)
		reliques_total += partie.reliques.size()
		if partie.etat == Partie.Etat.VICTOIRE:
			victoires += 1

	print("[%s] rat %d, squelette %d, gobelin %d, boss %d : %d%% de victoires, %.1f reliques par partie" % [
		mode, reglage[0], reglage[1], reglage[2], reglage[3],
		victoires * 100 / NB_PARTIES, reliques_total / float(NB_PARTIES)])


## La boutique d'un robot : se soigne, retire un crâne, achète ce qu'il peut.
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
