extends Node
## Autoload « GameState » : garde la partie en cours et change d'écran.
## Aucune règle ici : elles vivent dans Partie, Combat... (testables en ligne de commande).

const SCENE_COMBAT := "res://scenes/combat.tscn"
const SCENE_RECOMPENSE := "res://scenes/recompense.tscn"
const SCENE_BOUTIQUE := "res://scenes/boutique.tscn"
const SCENE_FIN := "res://scenes/fin_partie.tscn"

## La partie en cours. Une partie existe dès le lancement du jeu.
var partie: Partie


func _ready() -> void:
	nouvelle_partie()


## Remet tout à zéro : nouveau sac, PV pleins, nouvelle graine.
func nouvelle_partie() -> void:
	partie = Partie.creer()


func aller_a(chemin_scene: String) -> void:
	get_tree().change_scene_to_file(chemin_scene)
