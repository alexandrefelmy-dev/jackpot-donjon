class_name RetourTour
extends RefCounted
## Ce que le joueur doit ENTENDRE (et plus tard voir) après un tour : les événements sonores déduits du
## résultat du tirage et de la variation de PV. Pas de règle de jeu ici : on lit ce que Combat a déjà décidé.


## Les événements sonores d'un tour, dans l'ordre où ils sonnent : le combo (jackpot s'il y en a un de
## 5 symboles, sinon ding), la bombe, les coups, puis armure, soin et pièces.
static func sons(resultat: ResultatTirage, pv_joueur_avant: int, pv_joueur_apres: int) -> Array[StringName]:
	var liste: Array[StringName] = []
	if not resultat.combos.is_empty():
		var jackpot := false
		for combo in resultat.combos:
			if combo.est_jackpot():
				jackpot = true
		liste.append(&"jackpot" if jackpot else &"ding")
	for symbole in resultat.grille:
		if symbole != null and symbole.usage_unique:
			liste.append(&"bombe")
			break
	if resultat.total("degats") > 0:
		liste.append(&"coup_donne")
	if pv_joueur_apres < pv_joueur_avant:
		liste.append(&"coup_recu")
	if resultat.total("armure") > 0:
		liste.append(&"bouclier")
	if resultat.total("soin") > 0:
		liste.append(&"soin")
	if resultat.total("or") > 0:
		liste.append(&"pieces")
	return liste
