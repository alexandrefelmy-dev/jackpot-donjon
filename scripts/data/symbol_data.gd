class_name SymbolData
extends Resource
## Décrit un symbole de la machine à sous (épée, bouclier, potion...).
## Chaque symbole est un fichier .tres dans res://data/symbols/.
##
## Clés d'effet possibles (voir Effets) :
## "degats", "armure", "soin", "or", "malus_ennemi", "perte_pv".

## Identifiant unique : des symboles avec le même id forment un combo.
@export var id: StringName
## Nom affiché au joueur.
@export var nom: String = ""
## Couleur du rouleau, en attendant les vrais graphismes.
@export var couleur: Color = Color.GRAY
## Effet quand le symbole est visible sur la ligne.
@export var effet_base: Dictionary = {}
## Effet d'un combo de 3 symboles identiques côte à côte.
## Il remplace leurs effets de base et il est multiplié pour 4 (×2) et 5 (×4).
@export var effet_combo: Dictionary = {}
