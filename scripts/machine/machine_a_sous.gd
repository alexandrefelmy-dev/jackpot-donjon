class_name MachineASous
extends RefCounted
## La machine à sous : remplit les rouleaux depuis le sac et calcule le résultat.
## Les symboles sont rangés dans un tableau lu ligne par ligne :
## index = ligne * colonnes + colonne. Par défaut : 1 ligne de 5 rouleaux.

## Nombre minimum de symboles identiques côte à côte pour faire un combo.
const TAILLE_MIN_COMBO := 3

## Chaque symbole doré dans un combo multiplie l'effet du combo par ce facteur
## (3 épées dont 2 dorées : 15 × 2 × 2 = 60). Une seule constante : facile à régler.
const FACTEUR_COMBO_PAR_DORE := 2

var colonnes: int
var lignes: int


func _init(nb_colonnes: int = 5, nb_lignes: int = 1) -> void:
	colonnes = nb_colonnes
	lignes = nb_lignes


func nb_cases() -> int:
	return colonnes * lignes


## Multiplicateur d'un combo selon sa longueur : 3 -> ×1, 4 -> ×2, 5 -> ×4, 6 -> ×8.
static func multiplicateur(longueur: int) -> int:
	return 1 << (longueur - TAILLE_MIN_COMBO)


## Remplit les rouleaux avec des symboles piochés dans le sac.
## Les rouleaux bloqués (index de cases, ex. par le Rat-Croupier) restent vides.
func tirer(sac: Sac, rng: RandomNumberGenerator, cases_bloquees: Array[int] = []) -> Array[SymbolData]:
	var grille := sac.tirer(nb_cases(), rng)
	for index in cases_bloquees:
		if index >= 0 and index < grille.size():
			grille[index] = null
	return grille


## Calcule les effets d'un tirage :
## 1. repère les combos (3 symboles identiques ou plus, côte à côte) ;
## 2. applique les effets de base, de gauche à droite,
##    sauf pour les symboles qui font partie d'un combo ;
## 3. applique les effets de combo en dernier, multipliés selon leur longueur.
func resoudre(grille: Array[SymbolData]) -> ResultatTirage:
	var resultat := ResultatTirage.new()
	resultat.grille = grille

	# 1. Combos.
	for ligne in lignes:
		_chercher_combos(grille, ligne, resultat)

	# 2. Effets de base.
	for i in grille.size():
		var symbole := grille[i]
		if symbole == null or i in resultat.cases_en_combo:
			continue
		resultat.appliquer(symbole.effet_base, symbole.nom_affiche())

	# 3. Effets de combo.
	for combo in resultat.combos:
		var source: String
		if combo.est_jackpot():
			source = tr("JACKPOT ! %d × %s") % [combo.longueur, tr(combo.symbole.nom)]
		else:
			source = tr("Combo %d × %s") % [combo.longueur, tr(combo.symbole.nom)]
		if combo.nb_dores > 0:
			source += " " + tr("(dont %d ★)") % combo.nb_dores
		if combo.multiplicateur > 1:
			source += " (×%d)" % combo.multiplicateur
		resultat.appliquer(combo.symbole.effet_combo, source, combo.multiplicateur)

	return resultat


## Parcourt une ligne de gauche à droite et note chaque suite
## d'au moins TAILLE_MIN_COMBO symboles identiques.
func _chercher_combos(grille: Array[SymbolData], ligne: int, resultat: ResultatTirage) -> void:
	var colonne := 0
	while colonne < colonnes:
		var symbole := grille[ligne * colonnes + colonne]
		var longueur := 1
		if symbole != null:
			while colonne + longueur < colonnes \
					and _meme_symbole(symbole, grille[ligne * colonnes + colonne + longueur]):
				longueur += 1
			if longueur >= TAILLE_MIN_COMBO:
				var combo := ResultatTirage.Combo.new()
				combo.ligne = ligne
				combo.debut = colonne
				combo.longueur = longueur
				combo.symbole = symbole
				combo.multiplicateur = multiplicateur(longueur)
				for k in longueur:
					var membre := grille[ligne * colonnes + colonne + k]
					if membre.doree:
						combo.nb_dores += 1
						combo.multiplicateur *= FACTEUR_COMBO_PAR_DORE
					resultat.cases_en_combo.append(ligne * colonnes + colonne + k)
				resultat.combos.append(combo)
		colonne += longueur


func _meme_symbole(a: SymbolData, b: SymbolData) -> bool:
	return b != null and a.id == b.id
