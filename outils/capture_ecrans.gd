extends SceneTree
## OUTIL : prend des captures d'écran RÉELLES des écrans du jeu (fenêtre réelle, rendu réel),
## pour vérifier l'aspect : texte coupé, cadre mal dimensionné, rien d'illisible. Les tests de
## position ne voient pas ça.
##
## Lancer (SANS --headless : il faut une vraie fenêtre) :
##   godot --path . -s res://outils/capture_ecrans.gd
## Les images sont écrites dans le dossier user:// du jeu, dont le chemin est affiché :
##   %APPDATA%\Godot\app_userdata\jackpot donjon\captures\
## Ensuite, les ouvrir (par exemple avec l'outil de lecture d'images de Claude).

const DOSSIER := "user://captures/"
## Nombre d'images à attendre après chaque changement d'écran avant de photographier.
const IMAGES_D_ATTENTE := 6

var _etape := 0
var _attente := 0
var _erreurs := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DOSSIER)
	print("Captures écrites dans : ", ProjectSettings.globalize_path(DOSSIER))
	_preparer(0)


func _process(_delta: float) -> bool:
	_attente += 1
	if _attente < IMAGES_D_ATTENTE:
		return false
	_attente = 0
	_photographier(_etape)
	_etape += 1
	if _etape >= 8:
		quit(1 if _erreurs > 0 else 0)
	else:
		_preparer(_etape)
	return false


## Met le jeu dans l'état de l'écran n°etape.
func _preparer(etape: int) -> void:
	match etape:
		0:  # combat au départ, sans relique
			GameState.nouvelle_partie()
			GameState.aller_a(GameState.SCENE_COMBAT)
		1:  # combat avec les 9 reliques, tirage en attente de validation
			_partie_avec_toutes_les_reliques()
			GameState.partie.or_total = 50
			GameState.aller_a(GameState.SCENE_COMBAT)
		2:  # …choix du rouleau à garder (Cinquième as)
			var combat: Control = current_scene
			combat.boutons_mise[2].pressed.emit()
			combat._tirer()
			combat.bouton_cinquieme_as.pressed.emit()
			_controler(combat.combat.tirage_en_attente and combat.choix_du_rouleau,
					"l'écran « choix du rouleau » n'est pas dans le bon état (tirage en attente, choix ouvert)")
		3:  # …après le tour joué
			var combat: Control = current_scene
			combat._garder_rouleau(1)
			combat._valider()
			_controler(not combat.combat.tirage_en_attente, "le tour n'a pas été joué")
		4:  # récompense
			GameState.nouvelle_partie()
			GameState.aller_a(GameState.SCENE_RECOMPENSE)
		5:  # relique offerte après le combat 3
			GameState.nouvelle_partie()
			GameState.partie.combats_gagnes = 3
			GameState.aller_a(GameState.SCENE_RELIQUE)
		6:  # boutique
			GameState.nouvelle_partie()
			GameState.partie.or_total = 100
			GameState.aller_a(GameState.SCENE_BOUTIQUE)
		7:  # fin de partie (victoire)
			GameState.nouvelle_partie()
			GameState.partie.etat = Partie.Etat.VICTOIRE
			GameState.aller_a(GameState.SCENE_FIN)


## Si un écran n'est pas dans l'état voulu, la capture serait trompeuse : on le dit et on sort en erreur.
func _controler(condition: bool, message: String) -> void:
	if not condition:
		print("ERREUR : ", message)
		_erreurs += 1


func _partie_avec_toutes_les_reliques() -> void:
	GameState.nouvelle_partie()
	for relique in Reliques.toutes():
		GameState.partie.ajouter_relique(relique)


func _photographier(etape: int) -> void:
	var noms := ["combat_depart", "combat_attente", "combat_choix_rouleau", "combat_apres_tour",
			"recompense", "relique", "boutique", "fin_partie"]
	var image := root.get_texture().get_image()
	image.save_png(DOSSIER + noms[etape] + ".png")
	print("capture : ", noms[etape])
