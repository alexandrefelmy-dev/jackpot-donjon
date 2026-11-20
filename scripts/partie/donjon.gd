class_name Donjon
extends RefCounted
## La disposition du donjon : 3 étages, chacun 5 combats obligatoires (les « pas ») puis un boss. Après certains
## pas (BONUS_APRES_PAS), le joueur choisit entre 2 salles bonus (coffre, boutique ou repos).
## Pas d'interface ici. Tout le donjon ne dépend QUE de la graine de la partie : il est généré
## d'un coup au début, avec un générateur par étage, séparé de celui du jeu (tirages, récompenses).
## Même graine = même donjon, quoi que le joueur ait fait avant (voir tests/test_donjon.gd).

const NB_ETAGES := 3
const NB_PAS := 5
## Après la victoire du combat de ces pas, on choisit entre 2 salles bonus (le combat de chaque pas, lui, est obligatoire).
const BONUS_APRES_PAS: Array[int] = [2, 4]
## Un étage dont les salles cassent une contrainte est rejeté et retiré (graine dérivée).
const MAX_TENTATIVES := 60
## Un coffre sur 3 est une Mimique, à l'étage 3 seulement.
const MIMIQUE_UN_SUR := 3
const ETAGE_DES_MIMIQUES := 3

## Poids du tirage du type de chaque salle bonus.
const POIDS: Dictionary = {
	Salle.Type.COFFRE: 20.0,
	Salle.Type.BOUTIQUE: 15.0,
	Salle.Type.REPOS: 15.0,
}

## Les étages : nom, ennemis des combats, boss. La Mimique n'est pas dans les ennemis :
## elle n'apparaît que dans les coffres de l'étage 3.
const ETAGES: Array[Dictionary] = [
	{
		"nom": "Les Cryptes",
		"ennemis": [
			"res://data/enemies/rat_egout.tres",
			"res://data/enemies/squelette.tres",
			"res://data/enemies/gobelin_tricheur.tres",
		],
		"boss": "res://data/enemies/rat_croupier.tres",
	},
	{
		"nom": "La Salle de jeu maudite",
		"ennemis": [
			"res://data/enemies/fantome_joueur.tres",
			"res://data/enemies/golem_jetons.tres",
			"res://data/enemies/pickpocket.tres",
		],
		"boss": "res://data/enemies/dame_de_pique.tres",
	},
	{
		"nom": "Le Coffre-fort",
		"ennemis": [
			"res://data/enemies/garde_du_coffre.tres",
			"res://data/enemies/usurier.tres",
		],
		"boss": "res://data/enemies/grand_croupier.tres",
	},
]
const MIMIQUE := "res://data/enemies/mimique.tres"

var graine: int
## Les étages (0 = étage 1) : chaque étage est une liste de 5 pas, chaque pas un dictionnaire
## { "combat": Salle (le combat obligatoire), "bonus": Array[Salle] (2 salles bonus, ou vide) }.
var etages: Array[Array] = []
## Le boss de chaque étage.
var boss: Array[EnemyData] = []
## Combien d'étages générés ont été rejetés puis retirés (pour les tests et l'équilibrage).
var rejets: int = 0
## Étages qu'aucune tentative n'a rendus conformes (doit rester 0 : sinon une contrainte est trop dure).
var echecs: int = 0


## Génère tout le donjon à partir de la graine de la partie.
static func creer(graine_voulue: int) -> Donjon:
	var donjon := Donjon.new()
	donjon.graine = graine_voulue
	for etage in range(1, NB_ETAGES + 1):
		donjon.etages.append(donjon._generer_etage(etage))
		donjon.boss.append(load(ETAGES[etage - 1]["boss"]) as EnemyData)
	return donjon


## Le combat obligatoire du pas `pas` (1 à 5) de l'étage `etage` (1 à 3).
func combat(etage: int, pas: int) -> Salle:
	return etages[etage - 1][pas - 1]["combat"]


## Les 2 salles bonus à choisir après le combat du pas `pas` (vide si ce pas n'en propose pas).
func portes(etage: int, pas: int) -> Array[Salle]:
	var liste: Array[Salle] = []
	liste.assign(etages[etage - 1][pas - 1]["bonus"])
	return liste


func boss_de(etage: int) -> EnemyData:
	return boss[etage - 1]


static func nom_etage(etage: int) -> String:
	return TranslationServer.translate(ETAGES[etage - 1]["nom"])


## Le générateur d'un étage pour une tentative : une graine dérivée par arithmétique fixe
## (jamais de hash() : sa valeur n'est pas garantie d'une version à l'autre).
static func _generateur(graine_partie: int, etage: int, tentative: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine_partie * 1000003 + etage * 7919 + tentative * 104729
	return rng


## Tire un étage, le contrôle, et le retire (autre tentative) tant qu'il casse une contrainte.
func _generer_etage(etage: int) -> Array:
	var dernier: Array = []
	for tentative in MAX_TENTATIVES:
		var rng := _generateur(graine, etage, tentative)
		dernier = _tirer_etage(etage, rng)
		if erreur_etage(dernier).is_empty():
			return dernier
		rejets += 1
	echecs += 1
	return dernier


func _tirer_etage(etage: int, rng: RandomNumberGenerator) -> Array:
	var pas_liste: Array = []
	var precedent: EnemyData = null
	for pas in range(1, NB_PAS + 1):
		var ennemi := _tirer_ennemi(etage, rng, precedent)
		precedent = ennemi
		var bonus: Array = []
		if pas in BONUS_APRES_PAS:
			var premiere := _tirer_salle_bonus(etage, rng)
			var seconde := _tirer_salle_bonus(etage, rng)
			# Les 2 portes d'un pas ne se ressemblent jamais : on retire la seconde si besoin.
			var essais := 0
			while seconde.ressemble_a(premiere) and essais < 30:
				seconde = _tirer_salle_bonus(etage, rng)
				essais += 1
			bonus = [premiere, seconde]
		pas_liste.append({"combat": Salle.creer(Salle.Type.COMBAT, ennemi), "bonus": bonus})
	return pas_liste


## Un ennemi de l'étage, jamais le même que celui du combat d'avant (s'il y a le choix).
func _tirer_ennemi(etage: int, rng: RandomNumberGenerator, precedent: EnemyData) -> EnemyData:
	var chemins: Array = ETAGES[etage - 1]["ennemis"]
	var ennemi := load(chemins[rng.randi_range(0, chemins.size() - 1)]) as EnemyData
	var essais := 0
	while chemins.size() > 1 and precedent != null and ennemi.id == precedent.id and essais < 30:
		ennemi = load(chemins[rng.randi_range(0, chemins.size() - 1)]) as EnemyData
		essais += 1
	return ennemi


## Une salle bonus au hasard (coffre, boutique ou repos).
func _tirer_salle_bonus(etage: int, rng: RandomNumberGenerator) -> Salle:
	var types := POIDS.keys()
	var poids := PackedFloat32Array()
	for type_possible: Salle.Type in types:
		poids.append(POIDS[type_possible])
	var type_choisi: Salle.Type = types[rng.rand_weighted(poids)]
	if type_choisi == Salle.Type.COFFRE and etage == ETAGE_DES_MIMIQUES and rng.randi_range(1, MIMIQUE_UN_SUR) == 1:
		return Salle.creer(type_choisi, load(MIMIQUE) as EnemyData, true)
	return Salle.creer(type_choisi)


## Pourquoi cet étage (liste de 5 pas) est refusé ; "" s'il respecte toutes les contraintes.
static func erreur_etage(pas_liste: Array) -> String:
	if pas_liste.size() != NB_PAS:
		return "il n'y a pas %d pas" % NB_PAS
	var types_vus := {}
	var precedent: EnemyData = null
	for k in pas_liste.size():
		var le_pas: Dictionary = pas_liste[k]
		var combat_du_pas: Salle = le_pas["combat"]
		if combat_du_pas.type != Salle.Type.COMBAT or combat_du_pas.ennemi == null:
			return "le pas %d n'a pas de combat" % (k + 1)
		if precedent != null and combat_du_pas.ennemi.id == precedent.id:
			return "le pas %d a le même ennemi que le pas d'avant" % (k + 1)
		precedent = combat_du_pas.ennemi
		var bonus: Array = le_pas["bonus"]
		if (k + 1) in BONUS_APRES_PAS:
			if bonus.size() != 2:
				return "le pas %d n'a pas 2 salles bonus" % (k + 1)
			var a: Salle = bonus[0]
			var b: Salle = bonus[1]
			if a.type == Salle.Type.COMBAT or b.type == Salle.Type.COMBAT:
				return "le pas %d a un combat parmi ses salles bonus" % (k + 1)
			if a.ressemble_a(b):
				return "le pas %d a deux salles bonus identiques" % (k + 1)
			types_vus[a.type] = true
			types_vus[b.type] = true
		elif not bonus.is_empty():
			return "le pas %d ne devrait pas avoir de salles bonus" % (k + 1)
	for obligatoire in [Salle.Type.COFFRE, Salle.Type.BOUTIQUE, Salle.Type.REPOS]:
		if not types_vus.has(obligatoire):
			return "il manque un type de salle : %s" % Salle.Type.keys()[obligatoire]
	return ""


## Une empreinte de tout le donjon (comparer deux donjons dans les tests).
func empreinte() -> String:
	var morceaux: Array[String] = []
	for etage in etages.size():
		for le_pas: Dictionary in etages[etage]:
			var salle_combat: Salle = le_pas["combat"]
			morceaux.append(salle_combat.empreinte())
			for salle: Salle in le_pas["bonus"]:
				morceaux.append(salle.empreinte() + ("!" if salle.mimique else ""))
		morceaux.append("|" + String(boss[etage].id))
	return ",".join(morceaux)
