class_name GameState
extends RefCounted
## Garde la partie en cours et change d'écran. Aucune règle ici : elles vivent dans Partie,
## Combat, Boutique... (testables en ligne de commande).
##
## Ce n'est volontairement PAS un autoload : un autoload est déclaré dans project.godot,
## que l'éditeur Godot ouvert peut réécrire sans la déclaration (le jeu plantait alors avec
## « Identifier not found: GameState »). Une classe à membres statiques se trouve partout.

const SCENE_PORTES := "res://scenes/portes.tscn"
const SCENE_COMBAT := "res://scenes/combat.tscn"
const SCENE_RECOMPENSE := "res://scenes/recompense.tscn"
const SCENE_RELIQUE := "res://scenes/relique.tscn"
const SCENE_BOUTIQUE := "res://scenes/boutique.tscn"
const SCENE_REPOS := "res://scenes/repos.tscn"
const SCENE_FIN := "res://scenes/fin_partie.tscn"

## La partie en cours. Elle est créée au premier accès, donc il y en a toujours une.
static var partie: Partie = Partie.creer()


## Remet tout à zéro : nouveau sac, PV pleins, nouvelle graine.
static func nouvelle_partie() -> void:
	partie = Partie.creer()


## La scène de chaque écran que la partie peut demander (voir Partie.Ecran).
static func scene_de(ecran: Partie.Ecran) -> String:
	match ecran:
		Partie.Ecran.COMBAT:
			return SCENE_COMBAT
		Partie.Ecran.RECOMPENSE:
			return SCENE_RECOMPENSE
		Partie.Ecran.RELIQUE:
			return SCENE_RELIQUE
		Partie.Ecran.BOUTIQUE:
			return SCENE_BOUTIQUE
		Partie.Ecran.REPOS:
			return SCENE_REPOS
		Partie.Ecran.FIN:
			return SCENE_FIN
	return SCENE_PORTES


## Va à l'écran que la partie demande maintenant (portes, combat, boutique...).
static func aller_a_suivant() -> void:
	aller_a(scene_de(partie.ecran))


## Comme aller_a_suivant, mais plus tard dans l'image : pour un écran qui s'aperçoit dans son
## _ready() que la partie attend un autre écran (changer de scène pendant _ready() est refusé).
static func rediriger() -> void:
	var arbre := Engine.get_main_loop() as SceneTree
	arbre.call_deferred("change_scene_to_file", scene_de(partie.ecran))


static func aller_a(chemin_scene: String) -> void:
	var arbre := Engine.get_main_loop() as SceneTree
	arbre.change_scene_to_file(chemin_scene)
