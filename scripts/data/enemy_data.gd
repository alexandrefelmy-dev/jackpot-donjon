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
## Étage où l'ennemi apparaît (1 = Les Cryptes).
@export var etage: int = 1
## Vrai pour le boss qui garde la fin de l'étage.
@export var est_boss: bool = false
@export var pv_max: int = 10
## Or gagné en cas de victoire (affiché seulement en v0.2).
@export var or_victoire: int = 5
## Les intentions de l'ennemi, jouées en boucle : une par tour.
## Chaque intention est un Dictionary { "type": ..., "valeur": ... }.
## Types possibles (voir Intentions) : "attaque", "protection", "blocage", "vol", "charge", "fuite".
@export var intentions: Array[Dictionary] = []
## Intention jouée une seule fois AVANT le premier tirage du joueur (attaque surprise de la Mimique).
## Même forme qu'une intention : { "type": ..., "valeur": ... }. Vide = aucune.
@export var ouverture: Dictionary = {}
## Effets qui se produisent à chaque tour en plus de l'intention. Clés connues :
## "cranes_par_tour" (crânes temporaires ajoutés au sac du combat), "attaque_par_mise"
## (attaque gagnée pour de bon à chaque tour où le joueur a misé), "regle_par_tour" (vrai :
## une règle de la machine change à chaque tour, Grand Croupier).
@export var passif: Dictionary = {}
