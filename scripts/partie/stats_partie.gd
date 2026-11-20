class_name StatsPartie
extends RefCounted
## Les statistiques d'une partie (ou d'un seul combat) : ce que l'écran de fin affiche et ce dont les records du profil
## se nourrissent (voir Bilan). Que des compteurs : Combat compte les siens, Partie les additionne (ajouter).

## Dégâts infligés aux ennemis (ceux que le journal annonce : « Tu infliges N dégâts »).
var degats_infliges: int = 0
## Tours joués (un tirage validé = un tour).
var tours_joues: int = 0
## Combos de 5 symboles (jackpots) tirés, et longueur du plus long combo (3, 4 ou 5 ; 0 = aucun).
var jackpots: int = 0
var plus_long_combo: int = 0
## Mises jouées, et mises gagnées parmi elles (or ou quitte ou double).
var mises_jouees: int = 0
var mises_gagnees: int = 0
## Or dépensé en boutique (compté par Partie.depenser, au niveau de la partie : un combat ne dépense rien).
var or_depense: int = 0


## Compte les combos d'un tirage joué.
func compter_combos(resultat: ResultatTirage) -> void:
	for combo in resultat.combos:
		plus_long_combo = maxi(plus_long_combo, combo.longueur)
		if combo.est_jackpot():
			jackpots += 1


## Compte une mise réglée.
func compter_mise(gagnee: bool) -> void:
	mises_jouees += 1
	if gagnee:
		mises_gagnees += 1


## Additionne les statistiques d'un combat à celles de la partie.
func ajouter(autre: StatsPartie) -> void:
	degats_infliges += autre.degats_infliges
	tours_joues += autre.tours_joues
	jackpots += autre.jackpots
	plus_long_combo = maxi(plus_long_combo, autre.plus_long_combo)
	mises_jouees += autre.mises_jouees
	mises_gagnees += autre.mises_gagnees
