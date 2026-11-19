class_name Combat
extends RefCounted
## Un combat au tour par tour entre le joueur et un ennemi.
## Pas d'interface ici : la scène donne le résultat d'un tirage à jouer_tour()
## et lit l'état (PV, armure, intention, victoire...) pour l'afficher.
##
## Déroulé d'un tour (voir « Combat » dans le cahier des charges) :
## 1. les effets du tirage s'appliquent ;
## 2. si l'ennemi est à 0 PV : victoire (même si le joueur est aussi à 0 PV) ;
## 3. si le joueur est à 0 PV : défaite ;
## 4. sinon l'ennemi exécute son intention ;
## 5. fin de tour : l'armure du joueur retombe à 0.

enum Etat { EN_COURS, VICTOIRE, DEFAITE }

const PV_JOUEUR_DEPART := 40

var pv_max_joueur: int
var pv_joueur: int
var armure_joueur: int = 0

## Les données de l'ennemi (partagées, jamais modifiées).
var ennemi: EnemyData
var pv_ennemi: int
var armure_ennemi: int = 0

## Position dans la liste d'intentions de l'ennemi (jouées en boucle).
var index_intention: int = 0
var numero_tour: int = 1
var etat: Etat = Etat.EN_COURS
## Or gagné pendant ce combat : pièces tirées, puis or de la victoire.
var or_gagne: int = 0
## Rouleaux (index de cases) bloqués pour le prochain tirage du joueur.
## La scène les lit avant de tirer ; jouer_tour() les vide ensuite.
var rouleaux_bloques: Array[int] = []
## Or volé au joueur pendant ce combat (par le Gobelin tricheur, par exemple).
var or_vole: int = 0

var _hasard: RandomNumberGenerator
var _nb_rouleaux: int
## L'or que le joueur avait en entrant dans le combat.
var _or_depart: int


## `hasard` sert à choisir les rouleaux bloqués : on passe le générateur de la partie
## pour garder un seul hasard rejouable. `nb_rouleaux` = nombre de cases de la machine.
## `or_joueur` = l'or que le joueur possède, pour savoir combien un voleur peut lui prendre.
func _init(donnees: EnemyData, pv_depart: int = PV_JOUEUR_DEPART, pv_max: int = PV_JOUEUR_DEPART,
		hasard: RandomNumberGenerator = null, nb_rouleaux: int = 5, or_joueur: int = 0) -> void:
	ennemi = donnees
	pv_ennemi = donnees.pv_max
	pv_joueur = pv_depart
	pv_max_joueur = pv_max
	_hasard = hasard if hasard != null else RandomNumberGenerator.new()
	_nb_rouleaux = nb_rouleaux
	_or_depart = or_joueur


## L'or que le joueur possède en ce moment : celui d'avant le combat, plus les pièces
## tirées, moins ce qu'on lui a volé.
func or_du_joueur() -> int:
	return _or_depart + or_gagne - or_vole


func est_fini() -> bool:
	return etat != Etat.EN_COURS


## L'intention de l'ennemi pour ce tour ({} si l'ennemi n'a aucune intention).
func intention_actuelle() -> Dictionary:
	if ennemi.intentions.is_empty():
		return {}
	return ennemi.intentions[index_intention % ennemi.intentions.size()]


## Joue un tour complet à partir du résultat du tirage.
## Renvoie le détail du tour, ligne par ligne. Ne fait rien si le combat est fini.
func jouer_tour(resultat: ResultatTirage) -> Array[String]:
	var journal: Array[String] = []
	if est_fini():
		return journal

	# Les rouleaux bloqués ont servi pour ce tirage : ils sont libres à nouveau.
	rouleaux_bloques = []

	# 1. Effets du tirage, dans l'ordre de Effets.ORDRE.
	var degats := resultat.total("degats")
	if degats > 0:
		var absorbes := mini(armure_ennemi, degats)
		armure_ennemi -= absorbes
		pv_ennemi = maxi(0, pv_ennemi - (degats - absorbes))
		journal.append(tr("Tu infliges %d dégâts") % degats)
		if absorbes > 0:
			journal.append(tr("Son armure absorbe %d") % absorbes)

	var armure := resultat.total("armure")
	if armure > 0:
		armure_joueur += armure
		journal.append(tr("Tu gagnes %d armure") % armure)

	var soin := mini(resultat.total("soin"), pv_max_joueur - pv_joueur)
	if soin > 0:
		pv_joueur += soin
		journal.append(tr("Tu te soignes de %d PV") % soin)

	var or_tire := resultat.total("or")
	if or_tire > 0:
		or_gagne += or_tire
		journal.append(tr("Tu gagnes %d or") % or_tire)

	var perte := resultat.total("perte_pv")
	if perte > 0:
		# Les crânes font mal « immédiatement » : l'armure ne protège pas.
		pv_joueur = maxi(0, pv_joueur - perte)
		journal.append(tr("Les crânes te font perdre %d PV") % perte)

	# 2. Victoire ou défaite avant l'action de l'ennemi.
	if pv_ennemi <= 0:
		etat = Etat.VICTOIRE
		or_gagne += ennemi.or_victoire
		journal.append(tr("%s est vaincu !") % tr(ennemi.nom))
		return journal
	if pv_joueur <= 0:
		etat = Etat.DEFAITE
		journal.append(tr("Tu es à terre..."))
		return journal

	# 3. Action de l'ennemi.
	_jouer_intention(resultat.total("malus_ennemi"), journal)
	if pv_joueur <= 0:
		etat = Etat.DEFAITE
		journal.append(tr("Tu es à terre..."))
		return journal

	# 4. Fin de tour.
	armure_joueur = 0
	index_intention += 1
	numero_tour += 1
	return journal


## L'ennemi exécute son intention. `bonus_attaque` vient des crânes du tirage.
func _jouer_intention(bonus_attaque: int, journal: Array[String]) -> void:
	# L'armure de l'ennemi a protégé pendant le tirage : elle retombe maintenant.
	armure_ennemi = 0

	var intention := intention_actuelle()
	var valeur := int(intention.get("valeur", 0))
	match intention.get("type", ""):
		Intentions.ATTAQUE:
			var total := valeur + bonus_attaque
			var absorbes := mini(armure_joueur, total)
			armure_joueur -= absorbes
			pv_joueur = maxi(0, pv_joueur - (total - absorbes))
			journal.append(tr("%s attaque : %d dégâts") % [tr(ennemi.nom), total])
			if absorbes > 0:
				journal.append(tr("Ton armure absorbe %d") % absorbes)
		Intentions.PROTECTION:
			armure_ennemi += valeur
			journal.append(tr("%s se protège (+%d armure)") % [tr(ennemi.nom), valeur])
		Intentions.BLOCAGE:
			# Des rouleaux différents, tirés au hasard, restent vides au prochain tirage.
			var libres: Array[int] = []
			for i in _nb_rouleaux:
				libres.append(i)
			for k in mini(valeur, libres.size()):
				var choisi := _hasard.randi_range(0, libres.size() - 1)
				rouleaux_bloques.append(libres[choisi])
				libres.remove_at(choisi)
			journal.append(tr("%s bloque %d rouleau au prochain tirage") % [tr(ennemi.nom), valeur])
		Intentions.VOL:
			# Il ne peut pas voler plus que ce que le joueur possède.
			var vole := mini(valeur, maxi(0, or_du_joueur()))
			or_vole += vole
			if vole > 0:
				journal.append(tr("%s te vole %d or") % [tr(ennemi.nom), vole])
			else:
				journal.append(tr("%s tente de te voler mais tu n'as pas d'or") % tr(ennemi.nom))
