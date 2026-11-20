class_name ChronologieRouleaux
extends RefCounted
## Le minutage d'un tirage : à quel instant (en secondes après le levier) chaque rouleau s'arrête.
## Les rouleaux s'arrêtent de gauche à droite ; le dernier se fait attendre pour garder le suspense,
## encore plus si les rouleaux précédents annoncent déjà un combo.
## Affichage seulement : le résultat du tirage est calculé avant, rien ici ne change une règle.

## Arrêt du premier rouleau.
const PREMIER_ARRET := 0.45
## Écart entre deux arrêts successifs.
const ECART := 0.28
## Attente supplémentaire avant le dernier rouleau (le suspense).
const ATTENTE_DERNIER := 0.9
## Attente en plus quand les rouleaux d'avant forment déjà 3 symboles identiques de suite, ou 4.
const ATTENTE_COMBO_DE_3 := 0.3
const ATTENTE_COMBO_DE_4 := 0.6
## Durée du ralentissement avant l'arrêt : court pour un rouleau normal, long pour le dernier.
const RALENTI_NORMAL := 0.2
const RALENTI_DERNIER := 0.8


## Les instants d'arrêt, un par rouleau, pour la grille tirée (même ordre que les cases).
static func instants_d_arret(grille: Array[SymbolData]) -> Array[float]:
	var instants: Array[float] = []
	for i in grille.size():
		instants.append(PREMIER_ARRET + ECART * i)
	if grille.size() >= 2:
		instants[grille.size() - 1] += ATTENTE_DERNIER + _attente_combo(grille)
	return instants


## Durée du ralentissement du rouleau `index` parmi `nombre`.
static func duree_ralenti(index: int, nombre: int) -> float:
	return RALENTI_DERNIER if index == nombre - 1 else RALENTI_NORMAL


## Combien de symboles identiques de suite se terminent juste avant le dernier rouleau (cases vides exclues).
static func suite_avant_le_dernier(grille: Array[SymbolData]) -> int:
	var fin := grille.size() - 2
	if fin < 0 or grille[fin] == null:
		return 0
	var longueur := 1
	var i := fin - 1
	while i >= 0 and grille[i] != null and grille[i].id == grille[fin].id:
		longueur += 1
		i -= 1
	return longueur


static func _attente_combo(grille: Array[SymbolData]) -> float:
	var suite := suite_avant_le_dernier(grille)
	if suite >= 4:
		return ATTENTE_COMBO_DE_4
	if suite >= 3:
		return ATTENTE_COMBO_DE_3
	return 0.0
