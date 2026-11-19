class_name GameState
extends RefCounted
## Garde la partie en cours et change d'écran. Aucune règle ici : elles vivent dans Partie,
## Combat, Boutique... (testables en ligne de commande).
##
## Ce n'est volontairement PAS un autoload : un autoload est déclaré dans project.godot,
## que l'éditeur Godot ouvert peut réécrire sans la déclaration (le jeu plantait alors avec
## « Identifier not found: GameState »). Une classe à membres statiques se trouve partout.

const SCENE_COMBAT := "res://scenes/combat.tscn"
const SCENE_RECOMPENSE := "res://scenes/recompense.tscn"
const SCENE_RELIQUE := "res://scenes/relique.tscn"
const SCENE_BOUTIQUE := "res://scenes/boutique.tscn"
const SCENE_FIN := "res://scenes/fin_partie.tscn"

## La partie en cours. Elle est créée au premier accès, donc il y en a toujours une.
static var partie: Partie = Partie.creer()


## Remet tout à zéro : nouveau sac, PV pleins, nouvelle graine.
static func nouvelle_partie() -> void:
	partie = Partie.creer()


static func aller_a(chemin_scene: String) -> void:
	var arbre := Engine.get_main_loop() as SceneTree
	arbre.change_scene_to_file(chemin_scene)
