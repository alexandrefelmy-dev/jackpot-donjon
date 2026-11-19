extends SceneTree
## OUTIL : joue un tour avec de VRAIS clics de souris dans une vraie fenêtre (mise, levier,
## Cinquième as puis clic sur un rouleau, Dé pipé, Valider). Vérifie que les boutons réagissent
## vraiment à la souris, ce que les tests par signaux ne prouvent pas.
##
## Lancer (SANS --headless : il faut une vraie fenêtre) :
##   godot --path . -s res://outils/clics_reels.gd
## Code de sortie 0 = tout répond ; 1 = au moins un contrôle ne répond pas.

var _images := 0
var _echecs := 0
var _combat: Control


func _initialize() -> void:
	var partie := Partie.creer(77)
	partie.or_total = 30
	partie.ajouter_relique(Reliques.charger(&"cinquieme_as"))
	partie.ajouter_relique(Reliques.charger(&"de_pipe"))
	GameState.partie = partie
	GameState.aller_a(GameState.SCENE_COMBAT)


func _process(_delta: float) -> bool:
	_images += 1
	_combat = current_scene
	match _images:
		6:
			_clic(_combat.boutons_mise[2])  # mise de 10 or
		8:
			_verifier(_combat.mise_choisie == 2, "clic sur « 10 or » : mise choisie")
			_clic(_combat.bouton_levier)
		10:
			_verifier(_combat.combat.tirage_en_attente and _combat.ligne_relance.visible,
					"clic sur le levier : tirage en attente avec les boutons de relance")
			_clic(_combat.bouton_cinquieme_as)
		12:
			_verifier(_combat.choix_du_rouleau, "clic sur « Cinquième as » : on choisit le rouleau")
			_clic(_combat.cases[2])
		14:
			_verifier(not _combat.choix_du_rouleau and _combat.combat.relances_cinquieme_as == 0,
					"clic sur le rouleau 3 : relance du Cinquième as faite")
			_clic(_combat.bouton_de_pipe)
		16:
			_verifier(_combat.combat.relances_gratuites == 0 and _combat.combat.tirage_en_attente,
					"clic sur « Dé pipé » : relance faite, on attend toujours la validation")
			_clic(_combat.bouton_valider)
		18:
			_verifier(not _combat.combat.tirage_en_attente and _combat.combat.numero_tour == 2,
					"clic sur « Valider » : le tour est joué")
			_verifier(_combat.texte_journal.text.contains("Mise de 10 or"), "le journal parle de la mise")
			print("RÉSULTAT : ", "OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs)
			quit(1 if _echecs > 0 else 0)
	return false


## Un vrai clic gauche au centre du contrôle (le pointeur est d'abord déplacé dessus).
func _clic(controle: Control) -> void:
	var position := controle.get_global_rect().get_center()
	var mouvement := InputEventMouseMotion.new()
	mouvement.position = position
	mouvement.global_position = position
	Input.parse_input_event(mouvement)
	for appuye in [true, false]:
		var bouton := InputEventMouseButton.new()
		bouton.position = position
		bouton.global_position = position
		bouton.button_index = MOUSE_BUTTON_LEFT
		bouton.pressed = appuye
		Input.parse_input_event(bouton)


func _verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		_echecs += 1
		print("  ÉCHEC ", message)
