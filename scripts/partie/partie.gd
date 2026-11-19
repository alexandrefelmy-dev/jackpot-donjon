class_name Partie
extends RefCounted
## Une partie : tout ce qui traverse les combats (PV, or, sac) et l'enchaînement des
## rencontres : 5 combats contre des ennemis de l'étage 1, puis le boss.
## Pas d'interface ici : les écrans lisent cet état et appellent ses méthodes.

enum Etat { EN_COURS, VICTOIRE, DEFAITE }

const PV_DEPART := 40
const NB_COMBATS_NORMAUX := 5
const NB_RECOMPENSES := 3

## Ennemis possibles pour les 5 combats normaux de l'étage 1.
const ENNEMIS_ETAGE_1: Array[String] = [
	"res://data/enemies/rat_egout.tres",
	"res://data/enemies/squelette.tres",
	"res://data/enemies/gobelin_tricheur.tres",
]
const BOSS_ETAGE_1 := "res://data/enemies/rat_croupier.tres"

## Symboles proposés en récompense (les symboles de base, sans le crâne).
const RECOMPENSES: Array[String] = [
	"res://data/symbols/epee.tres",
	"res://data/symbols/bouclier.tres",
	"res://data/symbols/potion.tres",
	"res://data/symbols/piece.tres",
]

## Graine du générateur aléatoire (affichée, pour pouvoir rejouer la partie).
var graine: int
## Le seul générateur aléatoire de la partie : tirages, rencontres, récompenses, blocages.
var rng := RandomNumberGenerator.new()

var pv: int = PV_DEPART
var pv_max: int = PV_DEPART
var or_total: int = 0
var sac: Sac
## Les 5 ennemis normaux puis le boss, dans l'ordre.
var rencontres: Array[EnemyData] = []
## Numéro du combat en cours ou à venir : 1 à 5 = combats normaux, 6 = boss.
var numero_combat: int = 1
var combats_gagnes: int = 0
## Combien de symboles ont été retirés du sac en boutique : chaque retrait coûte plus cher.
var nb_retraits: int = 0
var etat: Etat = Etat.EN_COURS
## Le combat en cours (créé par creer_combat, rendu à terminer_combat).
var combat_courant: Combat


## Crée une partie neuve. Une graine positive rend la partie rejouable à l'identique.
static func creer(graine_voulue: int = -1) -> Partie:
	var partie := Partie.new()
	# Une graine toujours positive : on peut la retaper pour rejouer la partie.
	partie.graine = graine_voulue if graine_voulue >= 0 else randi()
	partie.rng.seed = partie.graine
	partie.sac = Sac.creer_sac_de_depart()
	partie._choisir_rencontres()
	return partie


## Tire les 5 ennemis normaux (jamais le même deux fois de suite), puis ajoute le boss.
func _choisir_rencontres() -> void:
	var precedent := -1
	for i in NB_COMBATS_NORMAUX:
		var candidats: Array[int] = []
		for k in ENNEMIS_ETAGE_1.size():
			if k != precedent:
				candidats.append(k)
		precedent = candidats[rng.randi_range(0, candidats.size() - 1)]
		rencontres.append(load(ENNEMIS_ETAGE_1[precedent]) as EnemyData)
	rencontres.append(load(BOSS_ETAGE_1) as EnemyData)


func ennemi_actuel() -> EnemyData:
	return rencontres[numero_combat - 1]


func est_combat_de_boss() -> bool:
	return ennemi_actuel().est_boss


## Prépare le combat en cours avec les PV actuels du joueur.
func creer_combat() -> Combat:
	combat_courant = Combat.new(ennemi_actuel(), pv, pv_max, rng, 5, or_total)
	return combat_courant


## Reporte le résultat d'un combat fini sur la partie : PV, or, puis suite ou fin de partie.
## Un combat n'est compté qu'une fois (les appels répétés sont ignorés).
func terminer_combat(combat: Combat) -> void:
	if etat != Etat.EN_COURS or combat != combat_courant or not combat.est_fini():
		return
	combat_courant = null
	pv = combat.pv_joueur
	or_total += combat.or_gagne - combat.or_vole

	if combat.etat == Combat.Etat.DEFAITE:
		etat = Etat.DEFAITE
		return

	combats_gagnes += 1
	if combat.ennemi.est_boss:
		etat = Etat.VICTOIRE
	else:
		numero_combat += 1


## Trois symboles différents à proposer après un combat normal.
func proposer_recompenses() -> Array[SymbolData]:
	return tirer_symboles(NB_RECOMPENSES)


## Tire `nombre` symboles différents parmi les symboles de base (sans le crâne),
## avec le générateur de la partie. Sert aux récompenses et aux offres de la boutique.
func tirer_symboles(nombre: int) -> Array[SymbolData]:
	var chemins: Array[String] = RECOMPENSES.duplicate()
	# Mélange de Fisher-Yates avec notre générateur (Array.shuffle() utiliserait un autre hasard).
	for i in range(chemins.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := chemins[i]
		chemins[i] = chemins[j]
		chemins[j] = temp

	var symboles: Array[SymbolData] = []
	for i in mini(nombre, chemins.size()):
		symboles.append(load(chemins[i]) as SymbolData)
	return symboles


## Ajoute le symbole choisi au sac. Passer = ne rien appeler.
func choisir_recompense(symbole: SymbolData) -> void:
	sac.ajouter(symbole)


## Pour les tests en jeu : saute directement au boss (touche F9 dans le build debug).
func aller_au_boss() -> void:
	if etat == Etat.EN_COURS:
		numero_combat = rencontres.size()
		combat_courant = null
