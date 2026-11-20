extends SceneTree
## Tests des options (réglages du joueur) et de leur fichier, à lancer en ligne de commande :
## godot --headless --path . -s res://tests/test_options.gd
## Les fichiers de test sont écrits dans user://tests_options/ : jamais dans les vraies options du joueur.

var echecs := 0
const DOSSIER := "user://tests_options/"
const CHEMIN := DOSSIER + "options.save"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER))
	test_valeurs_par_defaut()
	test_validation()
	test_aller_retour()
	test_fichier_absent_ou_abime()
	test_version_future()
	test_fichier_sur()
	test_entrees()
	_nettoyer()
	print("TERMINÉ : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


func verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		echecs += 1
		print("  ÉCHEC ", message)


func _effacer() -> void:
	for nom in ["options.save", "options.save.bak", "options.save.tmp", "autre.json", "autre.json.bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DOSSIER + nom))


func _nettoyer() -> void:
	_effacer()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DOSSIER))


func _ecrire(chemin: String, texte: String) -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(texte)
	f.close()


func test_valeurs_par_defaut() -> void:
	print("Valeurs par défaut")
	var o := Options.new()
	verifier(o.volume_musique == 0.6 and o.volume_effets == 0.8, "musique 60 %, effets 80 %")
	verifier(not o.plein_ecran and not o.reduire_tremblements and not o.reduire_flashs, "fenêtré, effets de mouvement et de flash activés")


func test_validation() -> void:
	print("Validation des données")
	var bon := Options.new().en_dictionnaire()
	verifier(Options.depuis_dictionnaire(bon) != null, "des données correctes sont acceptées")
	var cas := {
		"musique négative": ["volume_musique", -0.1],
		"effets au-dessus de 1": ["volume_effets", 1.5],
		"volume en texte": ["volume_musique", "fort"],
		"plein écran qui n'est pas un booléen": ["plein_ecran", 1],
		"réduction de secousse absente": ["reduire_tremblements", null],
	}
	for nom: String in cas:
		var donnees := bon.duplicate(true)
		donnees[cas[nom][0]] = cas[nom][1]
		verifier(Options.depuis_dictionnaire(donnees) == null, "refusé : %s" % nom)
	var extremes := bon.duplicate(true)
	extremes["volume_musique"] = 0
	extremes["volume_effets"] = 1
	var o := Options.depuis_dictionnaire(extremes)
	verifier(o != null and o.volume_musique == 0.0 and o.volume_effets == 1.0, "0 et 1 (entiers) sont des volumes valides")


func test_aller_retour() -> void:
	print("Aller-retour fichier")
	_effacer()
	var avant := Options.new()
	avant.volume_musique = 0.25
	avant.volume_effets = 1.0
	avant.plein_ecran = true
	avant.reduire_tremblements = true
	verifier(OptionsFichier.sauver(avant, CHEMIN) == OK, "l'écriture réussit")
	var charge := OptionsFichier.charger(CHEMIN)
	verifier(charge.options.en_dictionnaire() == avant.en_dictionnaire() and charge.ecriture_permise, "les options relues sont identiques")
	var deuxieme := Options.new()
	deuxieme.volume_musique = 0.9
	OptionsFichier.sauver(deuxieme, CHEMIN)
	verifier(FileAccess.file_exists(CHEMIN + ".bak") and not FileAccess.file_exists(CHEMIN + ".tmp"), "l'ancien fichier est gardé en .bak, aucun temporaire ne reste")
	verifier(OptionsFichier.charger(CHEMIN).options.volume_musique == 0.9, "la dernière écriture est celle qu'on relit")


func test_fichier_absent_ou_abime() -> void:
	print("Fichier absent ou abîmé")
	_effacer()
	var par_defaut := OptionsFichier.charger(CHEMIN)
	verifier(par_defaut.options.volume_musique == 0.6 and par_defaut.ecriture_permise, "fichier absent : options par défaut")
	var a := Options.new()
	a.volume_musique = 0.3
	var b := Options.new()
	b.volume_musique = 0.7
	OptionsFichier.sauver(a, CHEMIN)
	OptionsFichier.sauver(b, CHEMIN)
	_ecrire(CHEMIN, "{\"version\": 1, \"volume_mu")
	verifier(OptionsFichier.charger(CHEMIN).options.volume_musique == 0.3, "fichier tronqué : la sauvegarde (.bak) est rechargée")
	_ecrire(CHEMIN + ".bak", "abîmé aussi")
	verifier(OptionsFichier.charger(CHEMIN).options.volume_musique == 0.6, "tout est abîmé : options par défaut")
	# Des valeurs fausses ne sont pas chargées à moitié.
	var faux := Options.new().en_dictionnaire()
	faux["volume_effets"] = 7
	_ecrire(CHEMIN, JSON.stringify(faux))
	_effacer_bak()
	verifier(OptionsFichier.charger(CHEMIN).options.volume_effets == 0.8, "un volume hors bornes : options par défaut")


func _effacer_bak() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CHEMIN + ".bak"))


func test_version_future() -> void:
	print("Version plus récente que le jeu")
	_effacer()
	var texte := "{\"version\": %d, \"volume_musique\": 0.1}" % (Options.VERSION + 1)
	_ecrire(CHEMIN, texte)
	var charge := OptionsFichier.charger(CHEMIN)
	verifier(not charge.ecriture_permise and charge.options.volume_musique == 0.6, "options d'une version future : ignorées, écriture interdite")
	verifier(FileAccess.get_file_as_string(CHEMIN) == texte, "le fichier n'a pas été touché")


func test_fichier_sur() -> void:
	print("FichierSur (partagé avec le profil)")
	_effacer()
	var chemin := DOSSIER + "autre.json"
	verifier(FichierSur.lire_json(chemin).is_empty(), "un fichier absent se lit comme {}")
	verifier(FichierSur.ecrire({"a": 1, "b": "deux"}, chemin) == OK, "écrire un dictionnaire")
	var lu := FichierSur.lire_json(chemin)
	verifier(int(lu.get("a", 0)) == 1 and lu.get("b") == "deux", "relu tel quel")
	verifier(FichierSur.ecrire({"a": 2}, chemin) == OK and FileAccess.file_exists(chemin + ".bak"), "la 2e écriture garde l'ancien en .bak")
	_ecrire(chemin, "[1, 2, 3]")
	verifier(FichierSur.lire_json(chemin).is_empty(), "un JSON qui n'est pas un dictionnaire se lit comme {}")
	verifier(FichierSur.ecrire({"a": 3}, "user://dossier_qui_n_existe_pas/x.json") != OK, "une écriture impossible renvoie une erreur")


func test_entrees() -> void:
	print("Actions d'entrée")
	Entrees.enregistrer()
	Entrees.enregistrer()
	verifier(InputMap.has_action(Entrees.LEVIER) and InputMap.has_action(Entrees.RETOUR), "les actions levier et retour existent")
	verifier(InputMap.action_get_events(Entrees.LEVIER).size() == 4, "levier : Espace, Entrée, Entrée du pavé, bouton A (rappeler ne double rien)")
	verifier(InputMap.action_get_events(Entrees.RETOUR).size() == 2, "retour : Échap et bouton B")
	var espace := InputEventKey.new()
	espace.physical_keycode = KEY_SPACE
	espace.pressed = true
	verifier(InputMap.event_is_action(espace, Entrees.LEVIER), "la barre d'espace déclenche le levier")
	var echap := InputEventKey.new()
	echap.physical_keycode = KEY_ESCAPE
	echap.pressed = true
	verifier(InputMap.event_is_action(echap, Entrees.RETOUR) and not InputMap.event_is_action(echap, Entrees.LEVIER), "Échap déclenche retour, pas levier")
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.device = 3
	a.pressed = true
	verifier(InputMap.event_is_action(a, Entrees.LEVIER), "le bouton A de n'importe quelle manette déclenche le levier")
