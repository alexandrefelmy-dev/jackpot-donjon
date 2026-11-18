class_name ResultatTirage
extends RefCounted
## Tout ce qu'a produit un tirage : les symboles, les combos,
## le total des effets et le détail ligne par ligne.


## Un combo : plusieurs symboles identiques côte à côte sur une ligne.
class Combo:
	var ligne: int
	## Colonne du premier symbole du combo (0 = rouleau de gauche).
	var debut: int
	## Nombre de symboles identiques (3, 4, 5...).
	var longueur: int
	var symbole: SymbolData
	## 3 symboles ×1, 4 symboles ×2, 5 symboles ×4...
	var multiplicateur: int

	func est_jackpot() -> bool:
		return longueur >= 5


## Les symboles tirés, lus ligne par ligne (null = rouleau vide).
var grille: Array[SymbolData] = []
## Les combos trouvés, de gauche à droite.
var combos: Array[Combo] = []
## Index des cases qui font partie d'un combo (pour les mettre en valeur).
var cases_en_combo: Array[int] = []
## Somme des effets, ex. { "degats": 12, "or": 2 }.
var totaux: Dictionary = {}
## Détail lisible de chaque effet appliqué, dans l'ordre.
var journal: Array[String] = []


## Ajoute un effet (multiplié si besoin) au total et note d'où il vient.
func appliquer(effet: Dictionary, source: String, multiplicateur: int = 1) -> void:
	if effet.is_empty():
		return
	var effet_final := {}
	for cle: String in effet:
		effet_final[cle] = int(effet[cle]) * multiplicateur
		totaux[cle] = int(totaux.get(cle, 0)) + int(effet_final[cle])
	journal.append("%s : %s" % [source, Effets.decrire(effet_final)])


## Total d'une clé d'effet (0 si absente).
func total(cle: String) -> int:
	return int(totaux.get(cle, 0))
