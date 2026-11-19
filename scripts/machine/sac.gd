class_name Sac
extends RefCounted
## Le sac du joueur : tous les symboles qu'il possède.
## À chaque tirage, la machine pioche dedans au hasard.

## Composition du sac de départ : chemin du symbole -> quantité.
const DEPART: Dictionary = {
	"res://data/symbols/epee.tres": 6,
	"res://data/symbols/bouclier.tres": 3,
	"res://data/symbols/potion.tres": 2,
	"res://data/symbols/piece.tres": 2,
	"res://data/symbols/crane.tres": 2,
}

var symboles: Array[SymbolData] = []


## Crée le sac avec lequel commence chaque partie (15 symboles).
static func creer_sac_de_depart() -> Sac:
	var sac := Sac.new()
	for chemin: String in DEPART:
		var symbole := load(chemin) as SymbolData
		sac.ajouter(symbole, int(DEPART[chemin]))
	return sac


func ajouter(symbole: SymbolData, quantite: int = 1) -> void:
	for i in quantite:
		symboles.append(symbole)


func taille() -> int:
	return symboles.size()


## Retire le symbole à cet index du sac. Renvoie faux si l'index n'existe pas.
func retirer(index: int) -> bool:
	if index < 0 or index >= symboles.size():
		return false
	symboles.remove_at(index)
	return true


## Remplace le symbole à cet index par sa version dorée (une copie, le .tres reste intact).
## Renvoie faux si l'index n'existe pas ou si le symbole est déjà doré.
func ameliorer(index: int) -> bool:
	if index < 0 or index >= symboles.size() or symboles[index].doree:
		return false
	symboles[index] = symboles[index].creer_doree()
	return true


## Les symboles identiques regroupés (même id et même état doré), pour l'affichage du sac :
## [{ "symbole": SymbolData, "quantite": int, "index": int (1er exemplaire dans le sac) }, ...].
## Dans l'ordre d'apparition dans le sac.
func groupes() -> Array[Dictionary]:
	var resultat: Array[Dictionary] = []
	for i in symboles.size():
		var symbole := symboles[i]
		var trouve := false
		for groupe in resultat:
			var modele: SymbolData = groupe["symbole"]
			if modele.id == symbole.id and modele.doree == symbole.doree:
				groupe["quantite"] = int(groupe["quantite"]) + 1
				trouve = true
				break
		if not trouve:
			resultat.append({"symbole": symbole, "quantite": 1, "index": i})
	return resultat


## Pioche `nombre` symboles au hasard, sans remise.
## S'il n'y en a pas assez, les places restantes valent null (cases vides).
func tirer(nombre: int, rng: RandomNumberGenerator) -> Array[SymbolData]:
	var melange: Array[SymbolData] = symboles.duplicate()
	# Mélange de Fisher-Yates avec notre propre générateur,
	# pour pouvoir rejouer exactement un tirage à partir de sa graine.
	for i in range(melange.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := melange[i]
		melange[i] = melange[j]
		melange[j] = temp

	var resultat: Array[SymbolData] = []
	for i in nombre:
		resultat.append(melange[i] if i < melange.size() else null)
	return resultat
