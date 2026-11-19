class_name Bilan
extends RefCounted
## Ce qu'une partie finie rapporte au profil : des jetons d'âme, et la malédiction de la partie suivante.
## Pas d'interface ici : l'écran de fin affiche le résultat (Partie.bilan), le profil est sauvegardé par l'appelant.

const JETONS_PAR_SALLE := 1
const JETONS_PAR_BOSS := 5
const JETONS_VICTOIRE := 10


## Les jetons d'une partie finie : 1 par salle franchie, 5 par boss battu, 10 pour une victoire.
static func jetons_gagnes(partie: Partie) -> int:
	var jetons := partie.salles_franchies * JETONS_PAR_SALLE + partie.boss_vaincus * JETONS_PAR_BOSS
	if partie.etat == Partie.Etat.VICTOIRE:
		jetons += JETONS_VICTOIRE
	return jetons


## Enregistre le résultat de la partie dans le profil, UNE seule fois (les appels suivants ne font rien) :
## jetons, statistiques, malédictions. Une partie qui n'est pas finie ne rapporte rien.
## Malédictions : une victoire les efface toutes ; sinon chaque boss battu en efface une (la plus
## ancienne) ; puis une défaite en ajoute une tirée au hasard (3 au maximum).
## Renvoie le détail, aussi gardé dans partie.bilan, pour l'écran de fin :
## { "jetons": int, "malediction_recue": StringName, "maledictions_effacees": Array[StringName] }.
static func appliquer(partie: Partie, profil: Profil, hasard: RandomNumberGenerator) -> Dictionary:
	if partie.bilan_applique or partie.etat == Partie.Etat.EN_COURS:
		return partie.bilan
	var jetons := jetons_gagnes(partie)
	profil.jetons += jetons
	profil.parties_jouees += 1

	var effacees: Array[StringName] = []
	if partie.etat == Partie.Etat.VICTOIRE:
		profil.victoires += 1
		effacees.assign(profil.maledictions)
		profil.maledictions.clear()
	else:
		for i in mini(partie.boss_vaincus, profil.maledictions.size()):
			effacees.append(profil.maledictions.pop_front())

	var recue: StringName = &""
	if partie.etat == Partie.Etat.DEFAITE:
		recue = Maledictions.tirer(profil.maledictions, hasard)
		if recue != &"":
			profil.maledictions.append(recue)

	partie.bilan_applique = true
	partie.bilan = {"jetons": jetons, "malediction_recue": recue, "maledictions_effacees": effacees}
	return partie.bilan
