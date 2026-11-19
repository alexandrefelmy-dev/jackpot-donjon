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

const NOMS := ["portes_etage1", "portes_etage3", "combat_depart", "combat_attente", "combat_choix_rouleau",
		"combat_apres_tour", "combat_grand_croupier", "combat_grand_croupier_tour2", "combat_dame_de_pique",
		"combat_dame_de_pique_tour3", "combat_mimique", "combat_usurier", "combat_pickpocket", "combat_pickpocket_fuite",
		"recompense", "relique", "boutique", "repos", "repos_sac", "fin_victoire", "fin_defaite", "comptoir", "comptoir_epuise", "fin_bilan"]

var _etape := 0
var _attente := 0
var _erreurs := 0


func _initialize() -> void:
	# Cet outil ouvre une vraie fenêtre : il ne doit JAMAIS lire ni écrire le vrai profil du joueur.
	GameState.sauvegarde_autorisee = false
	GameState.profil = Profil.nouveau()
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
	if _etape >= NOMS.size():
		quit(1 if _erreurs > 0 else 0)
	else:
		_preparer(_etape)
	return false


## Met le jeu dans l'état de l'écran n°etape.
func _preparer(etape: int) -> void:
	match etape:
		0:  # choix des portes, étage 1
			GameState.nouvelle_partie()
			GameState.aller_a_suivant()
		1:  # choix des portes, étage 3 (avec l'avertissement sur les mimiques)
			GameState.nouvelle_partie()
			GameState.partie.etage = 3
			GameState.partie.pas = 3
			GameState.aller_a_suivant()
		2:  # combat au départ, sans relique
			GameState.nouvelle_partie()
			GameState.partie.choisir_porte(0)
			GameState.aller_a_suivant()
		3:  # combat avec les 9 reliques, tirage en attente de validation
			_partie_avec_toutes_les_reliques()
			GameState.partie.or_total = 50
			GameState.partie.choisir_porte(0)
			GameState.aller_a_suivant()
		4:  # …choix du rouleau à garder (Cinquième as)
			var combat: Control = current_scene
			combat.boutons_mise[2].pressed.emit()
			combat._tirer()
			combat.bouton_cinquieme_as.pressed.emit()
			_controler(combat.combat.tirage_en_attente and combat.choix_du_rouleau,
					"l'écran « choix du rouleau » n'est pas dans le bon état (tirage en attente, choix ouvert)")
		5:  # …après le tour joué
			var combat: Control = current_scene
			combat._garder_rouleau(1)
			combat._valider()
			_controler(not combat.combat.tirage_en_attente, "le tour n'a pas été joué")
		6:  # combat contre le Grand Croupier : la règle du tour s'affiche
			_combat_contre("grand_croupier", 3)
		7:  # …après quelques tours (la règle a changé)
			var combat: Control = current_scene
			combat.combat.pv_joueur = 40
			combat._tirer()
			_controler(combat.texte_passif.visible, "la règle du tour devrait s'afficher")
		8:  # combat contre la Dame de Pique : crânes temporaires
			_combat_contre("dame_de_pique", 2)
		9:  # …après 3 tours : des crânes ont été glissés dans la machine
			var combat: Control = current_scene
			for i in 3:
				combat.combat.pv_joueur = 40
				combat._tirer()
			_controler(combat.combat.cranes_temporaires == 3, "3 crânes temporaires attendus : %d" % combat.combat.cranes_temporaires)
		10:  # combat contre la Mimique : l'attaque surprise est dans le journal
			_combat_contre("mimique", 3)
			_controler(GameState.partie.ennemi_courant != null, "la Mimique devrait être l'ennemi courant")
		11:  # combat contre l'Usurier (renfort quand on mise)
			_combat_contre("usurier", 3)
		12:  # combat contre le Pickpocket
			_combat_contre("pickpocket", 2)
		13:  # …qui s'enfuit
			current_scene.combat.etat = Combat.Etat.FUITE
			current_scene._rafraichir()
		14:  # récompense
			GameState.nouvelle_partie()
			GameState.partie.ecran = Partie.Ecran.RECOMPENSE
			GameState.aller_a_suivant()
		15:  # relique (coffre ou boss)
			GameState.nouvelle_partie()
			GameState.partie.ecran = Partie.Ecran.RELIQUE
			GameState.aller_a_suivant()
		16:  # boutique
			GameState.nouvelle_partie()
			GameState.partie.or_total = 100
			GameState.partie.ecran = Partie.Ecran.BOUTIQUE
			GameState.aller_a_suivant()
		17:  # repos : les deux choix
			GameState.nouvelle_partie()
			GameState.partie.pv = 17
			GameState.partie.ecran = Partie.Ecran.REPOS
			GameState.aller_a_suivant()
		18:  # repos : le sac pour dorer un symbole
			var repos: Control = current_scene
			repos._choisir_symbole()
			_controler(repos.zone_sac.visible, "le sac du repos devrait s'afficher")
		19:  # fin de partie (victoire)
			GameState.nouvelle_partie()
			GameState.partie.ecran = Partie.Ecran.FIN
			GameState.partie.etat = Partie.Etat.VICTOIRE
			GameState.aller_a_suivant()
		20:  # fin de partie (défaite face à un boss)
			GameState.nouvelle_partie()
			GameState.partie.etage = 2
			GameState.partie.aller_au_boss()
			GameState.partie.ecran = Partie.Ecran.FIN
			GameState.partie.etat = Partie.Etat.DEFAITE
			GameState.aller_a_suivant()
		21:  # Comptoir du Croupier : des jetons, des malédictions, des déblocages
			var profil := Profil.nouveau()
			profil.jetons = 47
			profil.niveau_pv = 1
			profil.symboles_debloques.append(&"bombe")
			profil.maledictions.assign([&"fatigue", &"croupier_rancunier", &"mauvais_oeil"] as Array[StringName])
			profil.parties_jouees = 6
			profil.victoires = 1
			GameState.profil = profil
			GameState.en_partie = false
			GameState.aller_a(GameState.SCENE_COMPTOIR)
		22:  # Comptoir : tout est acheté
			var profil := Profil.nouveau()
			profil.jetons = 999
			var comptoir := Comptoir.creer(profil, RandomNumberGenerator.new())
			for achat in Comptoir.ORDRE:
				for i in 6:
					comptoir.acheter(achat)
			GameState.profil = profil
			GameState.aller_a(GameState.SCENE_COMPTOIR)
		23:  # fin de partie avec son bilan (jetons, malédiction reçue et effacée)
			var profil := Profil.nouveau()
			profil.maledictions.assign([&"sac_leste"] as Array[StringName])
			GameState.profil = profil
			var perdue := Partie.creer(3, profil)
			perdue.salles_franchies = 9
			perdue.boss_vaincus = 1
			perdue.etat = Partie.Etat.DEFAITE
			perdue.ecran = Partie.Ecran.FIN
			GameState.lancer(perdue)
			GameState.aller_a_suivant()


## Un combat contre l'ennemi `id`, à l'étage `etage`, avec l'ouverture jouée si l'ennemi en a une.
func _combat_contre(id: String, etage: int) -> void:
	GameState.nouvelle_partie()
	GameState.partie.etage = etage
	GameState.partie.ennemi_courant = load("res://data/enemies/%s.tres" % id) as EnemyData
	GameState.partie.ecran = Partie.Ecran.COMBAT
	GameState.aller_a_suivant()


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
	var image := root.get_texture().get_image()
	image.save_png(DOSSIER + NOMS[etape] + ".png")
	print("capture : ", NOMS[etape])
