class_name RelicData
extends Resource
## Décrit une relique : un objet passif qui change les règles (Tirelire, Sixième rouleau...).
## Chaque relique est un fichier .tres dans res://data/relics/.
## Ce fichier est partagé et jamais modifié en jeu : la partie garde la liste des reliques possédées.
##
## Les effets sont des PARAMÈTRES lus par le code (voir Modificateurs, Partie.ajouter_relique
## et Combat) : on règle une relique en changeant ses valeurs ici, sans toucher au code.
## Clés connues : "pv_max_bonus", "or_sans_combo", "degats_par_piece", "chance_crane_en_piece",
## "facteur_combo", "cranes_ajoutes", "mise_remboursee_par_combat", "rouleaux_en_plus",
## "relances_gratuites", "relances_cinquieme_as".

## Identifiant unique.
@export var id: StringName
## Nom affiché au joueur.
@export var nom: String = ""
## Ce que fait la relique, en une phrase (bulle d'aide et cartes).
@export var description: String = ""
## Couleur de la carte, en attendant les vrais graphismes.
@export var couleur: Color = Color.GRAY
## Prix en boutique, en or.
@export var prix: int = 30
## Les valeurs de ses effets, ex. { "or_sans_combo": 2 }.
@export var parametres: Dictionary = {}


## Une valeur de paramètre (0 si la relique ne l'a pas).
func valeur(cle: String, par_defaut: float = 0.0) -> float:
	return float(parametres.get(cle, par_defaut))
