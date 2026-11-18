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
