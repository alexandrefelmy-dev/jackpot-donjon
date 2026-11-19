class_name GameState
extends RefCounted
## Garde la partie en cours et change d'écran. Aucune règle ici : elles vivent dans Partie,
## Combat, Boutique... (testables en ligne de commande).
##
## Ce n'est volontairement PAS un autoload : un autoload est déclaré dans project.godot,
## que l'éditeur Godot ouvert peut réécrire sans la déclaration (le jeu plantait alors avec
## « Identifier not found: GameState »). Une classe à membres statiques se trouve partout.

const SCENE_COMPTOIR := "res://scenes/comptoir.tscn"
const SCENE_PORTES := "res://scenes/portes.tscn"
const SCENE_COMBAT := "res://scenes/combat.tscn"
const SCENE_RECOMPENSE := "res://scenes/recompense.tscn"
const SCENE_RELIQUE := "res://scenes/relique.tscn"
const SCENE_BOUTIQUE := "res://scenes/boutique.tscn"
const SCENE_REPOS := "res://scenes/repos.tscn"
const SCENE_FIN := "res://scenes/fin_partie.tscn"

## La partie en cours. Elle est créée au premier accès, donc il y en a toujours une.
static var partie: Partie = Partie.creer()
## Vrai pendant une partie ; faux au Comptoir (au lancement du jeu et entre deux parties).
static var en_partie: bool = false

## Le profil du joueur (jetons, déblocages, malédictions). null tant qu'il n'est pas chargé : les parties
## se jouent alors sans profil, comme en v0.6 (c'est le cas des tests et des outils).
static var profil: Profil
## Un message sur le profil à montrer au Comptoir (profil abîmé, version plus récente...).
static var message_profil: String = ""
## Le droit d'écrire le profil sur le disque : FAUX par défaut, accordé seulement par charger_profil() après
## une vraie lecture du fichier du joueur. Un test ou un outil qui prépare son propre profil ne passe jamais
## par cette lecture : il n'écrit donc jamais dans le vrai profil.
static var _ecriture_permise: bool = false

## Les réglages du joueur (volumes, plein écran, accessibilité). Chargés une seule fois, comme le profil.
static var options: Options
static var _ecriture_options_permise: bool = false
static var _demarre: bool = false
static var _hasard_du_profil: RandomNumberGenerator


## Prépare ce que tout le jeu utilise : les actions d'entrée, les bus audio, les options du joueur.
## Idempotent : chaque écran peut l'appeler dans son _ready(). C'est ce qui fait marcher le jeu quand on
## lance directement l'écran principal du projet.
static func demarrer() -> void:
	if _demarre:
		return
	_demarre = true
	Entrees.enregistrer()
	charger_options()
	appliquer_options()


## Charge les options (une seule fois). Sans sauvegarde possible (mode sans fenêtre), les options par défaut.
static func charger_options() -> void:
	if options != null:
		return
	if _sauvegarde_active():
		var chargement := OptionsFichier.charger(OptionsFichier.CHEMIN_DEFAUT)
		options = chargement.options
		_ecriture_options_permise = chargement.ecriture_permise
	else:
		options = Options.new()


## Écrit les options sur le disque (si la sauvegarde est active et permise). Renvoie faux en cas d'échec.
static func sauver_options() -> bool:
	if options == null or not _sauvegarde_active() or not _ecriture_options_permise:
		return true
	return OptionsFichier.sauver(options, OptionsFichier.CHEMIN_DEFAUT) == OK


## Applique les options : volumes des bus et plein écran (pas de changement de fenêtre en mode sans fenêtre).
static func appliquer_options() -> void:
	charger_options()
	Son.appliquer_options(options)
	if _sauvegarde_active():
		DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if options.plein_ecran else DisplayServer.WINDOW_MODE_WINDOWED)


## Commence une nouvelle partie avec le profil (s'il est chargé) : avantages et malédictions comprises.
static func nouvelle_partie() -> void:
	partie = Partie.creer(-1, profil)
	en_partie = true


## Lance une partie déjà préparée (tests et outils).
static func lancer(une_partie: Partie) -> void:
	partie = une_partie
	en_partie = true


## Retourne au Comptoir (hors partie).
static func vers_le_comptoir() -> void:
	en_partie = false
	aller_a(SCENE_COMPTOIR)


## La sauvegarde du profil n'existe que dans le jeu lui-même : jamais en mode sans fenêtre (tests,
## simulations). Avec le droit d'écrire (voir _ecriture_permise), c'est ce qui protège le vrai fichier du joueur.
static func _sauvegarde_active() -> bool:
	return DisplayServer.get_name() != "headless"


## Charge le profil (une seule fois). Sans sauvegarde possible, un profil neuf en mémoire.
static func charger_profil() -> void:
	if profil != null:
		return
	if _sauvegarde_active():
		var chargement := ProfilFichier.charger(ProfilFichier.CHEMIN_DEFAUT)
		profil = chargement.profil
		message_profil = chargement.message
		_ecriture_permise = chargement.ecriture_permise
	else:
		profil = Profil.nouveau()


## Écrit le profil sur le disque (si la sauvegarde est active et permise). Renvoie faux si l'écriture
## a échoué (le message est alors dans message_profil, que le Comptoir affiche aussitôt).
static func sauver_profil() -> bool:
	if profil == null or not _sauvegarde_active() or not _ecriture_permise:
		return true
	if ProfilFichier.sauver(profil, ProfilFichier.CHEMIN_DEFAUT) != OK:
		message_profil = TranslationServer.translate("Le profil n'a pas pu être enregistré.")
		return false
	return true


## Remet le profil à zéro (bouton de test du Comptoir).
static func reinitialiser_profil() -> void:
	profil = Profil.nouveau()
	sauver_profil()


## À la fin d'une partie : jetons et malédiction sont inscrits au profil (une seule fois), puis sauvegardés.
static func enregistrer_bilan() -> void:
	if profil == null or partie.bilan_applique:
		return
	if _hasard_du_profil == null:
		_hasard_du_profil = RandomNumberGenerator.new()
		_hasard_du_profil.randomize()
	Bilan.appliquer(partie, profil, _hasard_du_profil)
	sauver_profil()


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


## La scène à afficher maintenant : le Comptoir hors partie, sinon l'écran que la partie demande.
static func scene_attendue() -> String:
	return scene_de(partie.ecran) if en_partie else SCENE_COMPTOIR


## Va à l'écran attendu maintenant (Comptoir, portes, combat, boutique...).
static func aller_a_suivant() -> void:
	aller_a(scene_attendue())


## Comme aller_a_suivant, mais plus tard dans l'image : pour un écran qui s'aperçoit dans son
## _ready() que la partie attend un autre écran (changer de scène pendant _ready() est refusé).
static func rediriger() -> void:
	demarrer()
	var arbre := Engine.get_main_loop() as SceneTree
	arbre.call_deferred("change_scene_to_file", scene_attendue())


static func aller_a(chemin_scene: String) -> void:
	var arbre := Engine.get_main_loop() as SceneTree
	arbre.change_scene_to_file(chemin_scene)
