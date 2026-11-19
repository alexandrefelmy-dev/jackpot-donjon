class_name SymbolData
extends Resource
## Décrit un symbole de la machine à sous (épée, bouclier, potion...).
## Chaque symbole est un fichier .tres dans res://data/symbols/.
## Ce fichier est partagé : un symbole doré est une COPIE (creer_doree), jamais le .tres modifié.
##
## Clés d'effet possibles (voir Effets) :
## "degats", "armure", "soin", "or", "malus_ennemi", "perte_pv".

## Identifiant unique : des symboles avec le même id forment un combo
## (un symbole doré et son original ont le même id).
@export var id: StringName
## Nom affiché au joueur.
@export var nom: String = ""
## Couleur du rouleau, en attendant les vrais graphismes.
@export var couleur: Color = Color.GRAY
## Prix d'achat en boutique (0 = jamais vendu, comme le crâne).
@export var prix: int = 0
## Effet quand le symbole est visible sur la ligne.
@export var effet_base: Dictionary = {}
## Effet d'un combo de 3 symboles identiques côte à côte.
## Il remplace leurs effets de base et il est multiplié pour 4 (×2) et 5 (×4).
@export var effet_combo: Dictionary = {}

## Vrai pour la version dorée d'un symbole (créée en boutique, pas dans le .tres).
var doree: bool = false


## Une copie dorée : même identité, effet de base doublé.
## (Dans un combo, chaque symbole doré double aussi l'effet du combo : voir MachineASous.)
func creer_doree() -> SymbolData:
	var copie := duplicate_deep() as SymbolData
	for cle: String in copie.effet_base:
		copie.effet_base[cle] = int(copie.effet_base[cle]) * 2
	copie.doree = true
	return copie


## Le nom à afficher, avec une étoile pour un symbole doré (sans accord grammatical).
func nom_affiche() -> String:
	var texte := String(TranslationServer.translate(nom))
	return "★ " + texte if doree else texte
