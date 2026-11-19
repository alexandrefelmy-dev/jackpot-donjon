class_name Partie
extends RefCounted
## Une partie : tout ce qui traverse les combats (PV, or, sac) et l'enchaînement des
## rencontres : 5 combats contre des ennemis de l'étage 1, puis le boss.
## Pas d'interface ici : les écrans lisent cet état et appellent ses méthodes.

enum Etat { EN_COURS, VICTOIRE, DEFAITE }

const PV_DEPART := 40
const NB_COMBATS_NORMAUX := 5
const NB_RECOMPENSES := 3
## Après ce combat gagné, une relique est offerte (1 parmi 2), en attendant les coffres de la v0.6.
const RELIQUE_APRES_COMBAT := 3
const NB_RELIQUES_OFFERTES := 2
const NB_ROULEAUX_DEPART := 5

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
## Les reliques possédées (chacune une seule fois).
var reliques: Array[RelicData] = []
## Nombre de rouleaux de la machine (5, ou 6 avec le Sixième rouleau).
var nb_rouleaux: int = NB_ROULEAUX_DEPART
## Vrai une fois la relique de l'après-combat 3 choisie.
var relique_offerte: bool = false
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
	combat_courant = Combat.new(ennemi_actuel(), pv, pv_max, rng, nb_rouleaux, or_total)
	combat_courant.preparer_tirages(creer_machine(), sac, modificateurs())
	# Reliques qui se renouvellent à chaque combat : Jeton porte-bonheur (mise remboursée),
	# Dé pipé (relance gratuite), Cinquième as (garder un rouleau et relancer les autres).
	for relique in reliques:
		combat_courant.remboursements_de_mise += int(relique.valeur("mise_remboursee_par_combat"))
		combat_courant.relances_gratuites += int(relique.valeur("relances_gratuites"))
		combat_courant.relances_cinquieme_as += int(relique.valeur("relances_cinquieme_as"))
	return combat_courant


## La machine à sous de cette partie (5 rouleaux, 6 avec le Sixième rouleau).
func creer_machine() -> MachineASous:
	return MachineASous.new(nb_rouleaux, 1)


## Ce que les reliques possédées changent dans le calcul des tirages.
func modificateurs() -> Modificateurs:
	return Modificateurs.depuis_reliques(reliques)


# --- Reliques ----------------------------------------------------------------

func a_relique(id: StringName) -> bool:
	for relique in reliques:
		if relique.id == id:
			return true
	return false


## Ajoute une relique et applique ses effets immédiats. Renvoie faux si on l'a déjà.
## Effets immédiats : PV max (Cœur de pierre), crânes ajoutés au sac (Jackpot maudit),
## rouleaux en plus (Sixième rouleau). Les autres effets sont lus à chaque tirage ou combat.
func ajouter_relique(relique: RelicData) -> bool:
	if a_relique(relique.id):
		return false
	reliques.append(relique)

	var bonus_pv := int(relique.valeur("pv_max_bonus"))
	if bonus_pv > 0:
		pv_max += bonus_pv
		pv = mini(pv_max, pv + bonus_pv)

	var nb_cranes := int(relique.valeur("cranes_ajoutes"))
	if nb_cranes > 0:
		sac.ajouter(load("res://data/symbols/crane.tres") as SymbolData, nb_cranes)

	nb_rouleaux += int(relique.valeur("rouleaux_en_plus"))
	return true


## `nombre` reliques différentes que le joueur ne possède pas encore (moins s'il n'en reste pas assez).
## Tirées avec le générateur de la partie, comme les récompenses.
func proposer_reliques(nombre: int) -> Array[RelicData]:
	var candidates := _reliques_disponibles()
	# Mélange de Fisher-Yates avec notre générateur.
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = temp
	return candidates.slice(0, mini(nombre, candidates.size()))


## Les reliques que le joueur ne possède pas encore, dans l'ordre du jeu (sans toucher au hasard).
func _reliques_disponibles() -> Array[RelicData]:
	var liste: Array[RelicData] = []
	for relique in Reliques.toutes():
		if not a_relique(relique.id):
			liste.append(relique)
	return liste


## Reste-t-il au moins une relique que le joueur ne possède pas ? (sans toucher au hasard)
func peut_recevoir_relique() -> bool:
	return not _reliques_disponibles().is_empty()


## Vrai juste après le combat 3 gagné, tant que la relique offerte n'a pas été choisie.
func relique_a_offrir() -> bool:
	return etat == Etat.EN_COURS and not relique_offerte \
			and combats_gagnes == RELIQUE_APRES_COMBAT \
			and not _reliques_disponibles().is_empty()


## Le joueur choisit sa relique offerte : elle est ajoutée et l'offre est terminée.
func choisir_relique_offerte(relique: RelicData) -> void:
	relique_offerte = true
	ajouter_relique(relique)


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


## Pour les tests en jeu : saute directement au boss (bouton « [test] » du combat).
func aller_au_boss() -> void:
	if etat == Etat.EN_COURS:
		numero_combat = rencontres.size()
		combat_courant = null
