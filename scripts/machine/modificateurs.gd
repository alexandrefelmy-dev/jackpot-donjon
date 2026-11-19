class_name Modificateurs
extends RefCounted
## Ce que les reliques changent dans le calcul d'un tirage. Sans relique, rien ne change :
## les valeurs par défaut laissent la machine comme avant.

## Multiplie l'effet de chaque combo (Jackpot maudit : 2).
var facteur_combo: int = 1
## Dégâts supplémentaires par pièce visible (Lame aimantée : 1).
var degats_par_piece: int = 0
## Or gagné quand le tirage ne contient aucun combo (Tirelire : 2).
var or_sans_combo: int = 0
## Chance qu'un crâne devienne une pièce au tirage (Trèfle à quatre feuilles : 0,5).
var chance_crane_en_piece: float = 0.0


## Calcule les modificateurs à partir des reliques possédées (leurs paramètres).
static func depuis_reliques(reliques: Array[RelicData]) -> Modificateurs:
	var mods := Modificateurs.new()
	for relique in reliques:
		mods.facteur_combo *= int(relique.valeur("facteur_combo", 1.0))
		mods.degats_par_piece += int(relique.valeur("degats_par_piece"))
		mods.or_sans_combo += int(relique.valeur("or_sans_combo"))
		mods.chance_crane_en_piece = maxf(mods.chance_crane_en_piece, relique.valeur("chance_crane_en_piece"))
	return mods
