class_name EnemyData
extends Resource
## Décrit un ennemi (rat, squelette, golem...).
## Chaque ennemi est un fichier .tres dans res://data/enemies/.
## Ce fichier est partagé : les PV restants d'un ennemi vivent dans Combat, jamais ici.

## Identifiant unique.
@export var id: StringName
## Nom affiché au joueur.
@export var nom: String = ""
## Couleur de l'ennemi, en attendant les vrais graphismes.
@export var couleur: Color = Color.GRAY
@export var pv_max: int = 10
## Or gagné en cas de victoire (affiché seulement en v0.2).
@export var or_victoire: int = 5
## Les intentions de l'ennemi, jouées en boucle : une par tour.
## Chaque intention est un Dictionary { "type": ..., "valeur": ... }.
## Types possibles (voir Intentions) : "attaque", "protection".
@export var intentions: Array[Dictionary] = []
