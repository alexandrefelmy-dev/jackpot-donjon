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
	## Combien de symboles dorés font partie du combo.
	var nb_dores: int = 0
	## Multiplicateur final de l'effet du combo : 3 symboles ×1, 4 symboles ×2, 5 symboles ×4...
	## puis ×2 par symbole doré.
	var multiplicateur: int

	func est_jackpot() -> bool:
		return longueur >= 5


## Y a-t-il un jackpot (combo de 5) dans ce tirage ?
func a_un_jackpot() -> bool:
	for combo in combos:
		if combo.est_jackpot():
			return true
	return false


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


## Vrai s'il y a au moins un combo qui n'est pas un combo de crânes (condition d'une mise d'or gagnée).
func a_combo_hors_cranes() -> bool:
	for combo in combos:
		if combo.symbole.id != &"crane":
			return true
	return false


## Combien de crânes sont visibles sur les rouleaux (condition du quitte ou double).
func nb_cranes() -> int:
	var nombre := 0
	for symbole in grille:
		if symbole != null and symbole.id == &"crane":
			nombre += 1
	return nombre


## Quitte ou double gagné : les effets positifs (dégâts, armure, soin, or) sont doublés.
## Les effets négatifs (malus des crânes, perte de PV) ne le sont pas.
func doubler_effets_positifs() -> void:
	for cle in ["degats", "armure", "soin", "or"]:
		if totaux.has(cle):
			totaux[cle] = int(totaux[cle]) * 2
	journal.append(TranslationServer.translate("Quitte ou double : effets positifs doublés"))


## Total d'une clé d'effet (0 si absente).
func total(cle: String) -> int:
	return int(totaux.get(cle, 0))
