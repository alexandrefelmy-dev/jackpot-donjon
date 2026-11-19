class_name Donjon
extends RefCounted
## La disposition du donjon : 3 étages, chacun 5 pas avec 2 portes au choix, puis un boss.
## Pas d'interface ici. Tout le donjon ne dépend QUE de la graine de la partie : il est généré
## d'un coup au début, avec un générateur par étage, séparé de celui du jeu (tirages, récompenses).
## Même graine = même donjon, quoi que le joueur ait fait avant (voir tests/test_donjon.gd).

const NB_ETAGES := 3
const NB_PAS := 5
## Un étage dont les portes cassent une contrainte est rejeté et retiré (graine dérivée).
const MAX_TENTATIVES := 60
## Un coffre sur 3 est une Mimique, à l'étage 3 seulement.
const MIMIQUE_UN_SUR := 3
const ETAGE_DES_MIMIQUES := 3

## Poids du tirage du type de chaque porte (le combat est le plus fréquent).
const POIDS: Dictionary = {
	Salle.Type.COMBAT: 50.0,
	Salle.Type.COFFRE: 20.0,
	Salle.Type.BOUTIQUE: 15.0,
	Salle.Type.REPOS: 15.0,
}

## Les étages : nom, ennemis des salles de combat, boss. La Mimique n'est pas dans les ennemis :
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
## Les étages (0 = étage 1) : chaque étage est une liste de 5 pas, chaque pas une liste de 2 salles.
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


## Les 2 portes du pas `pas` (1 à 5) de l'étage `etage` (1 à 3).
func portes(etage: int, pas: int) -> Array[Salle]:
	var liste: Array[Salle] = []
	liste.assign(etages[etage - 1][pas - 1])
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
	for pas in range(1, NB_PAS + 1):
		var premiere := _tirer_salle(etage, rng, pas == 1)
		var seconde := _tirer_salle(etage, rng, pas == 1)
		# Les 2 portes d'un pas ne se ressemblent jamais : on retire la seconde si besoin.
		var essais := 0
		while seconde.ressemble_a(premiere) and essais < 30:
			seconde = _tirer_salle(etage, rng, pas == 1)
			essais += 1
		pas_liste.append([premiere, seconde])
	return pas_liste


## Une salle au hasard. `combat_force` : la porte est un combat (1re salle de l'étage).
func _tirer_salle(etage: int, rng: RandomNumberGenerator, combat_force: bool) -> Salle:
	var type_choisi := Salle.Type.COMBAT
	if not combat_force:
		var types := POIDS.keys()
		var poids := PackedFloat32Array()
		for type_possible: Salle.Type in types:
			poids.append(POIDS[type_possible])
		type_choisi = types[rng.rand_weighted(poids)]

	match type_choisi:
		Salle.Type.COMBAT:
			var ennemis: Array = ETAGES[etage - 1]["ennemis"]
			var chemin: String = ennemis[rng.randi_range(0, ennemis.size() - 1)]
			return Salle.creer(type_choisi, load(chemin) as EnemyData)
		Salle.Type.COFFRE:
			if etage == ETAGE_DES_MIMIQUES and rng.randi_range(1, MIMIQUE_UN_SUR) == 1:
				return Salle.creer(type_choisi, load(MIMIQUE) as EnemyData, true)
	return Salle.creer(type_choisi)


## Pourquoi cet étage (liste de 5 pas) est refusé ; "" s'il respecte toutes les contraintes.
static func erreur_etage(pas_liste: Array) -> String:
	if pas_liste.size() != NB_PAS:
		return "il n'y a pas %d pas" % NB_PAS
	var types_vus := {}
	for k in pas_liste.size():
		var portes_du_pas: Array = pas_liste[k]
		if portes_du_pas.size() != 2:
			return "le pas %d n'a pas 2 portes" % (k + 1)
		var a: Salle = portes_du_pas[0]
		var b: Salle = portes_du_pas[1]
		if a.ressemble_a(b):
			return "le pas %d a deux portes identiques" % (k + 1)
		if k == 0 and (a.type != Salle.Type.COMBAT or b.type != Salle.Type.COMBAT):
			return "le pas 1 doit proposer 2 combats"
		types_vus[a.type] = true
		types_vus[b.type] = true
	for obligatoire in [Salle.Type.COFFRE, Salle.Type.BOUTIQUE, Salle.Type.REPOS]:
		if not types_vus.has(obligatoire):
			return "il manque un type de salle : %s" % Salle.Type.keys()[obligatoire]
	return ""


## Une empreinte de tout le donjon (comparer deux donjons dans les tests).
func empreinte() -> String:
	var morceaux: Array[String] = []
	for etage in etages.size():
		for portes_du_pas: Array in etages[etage]:
			for salle: Salle in portes_du_pas:
				morceaux.append(salle.empreinte() + ("!" if salle.mimique else ""))
		morceaux.append("|" + String(boss[etage].id))
	return ",".join(morceaux)
