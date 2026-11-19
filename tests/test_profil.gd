extends SceneTree
## Tests du profil et de sa sauvegarde, à lancer en ligne de commande :
## godot --headless --path . -s res://tests/test_profil.gd
## Les fichiers de test sont écrits dans user://tests_profil/ : jamais dans le vrai profil du joueur.

var echecs := 0
const DOSSIER := "user://tests_profil/"
const CHEMIN := DOSSIER + "profil.save"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER))
	test_profil_neuf()
	test_aller_retour()
	test_fichier_absent()
	test_fichier_abime_et_sauvegarde()
	test_ecriture_sure()
	test_version_future()
	test_migrations()
	test_fixture_v1()
	test_validation()
	test_donnees_simples()
	test_maledictions()
	_nettoyer()
	print("TERMINÉ : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


# --- Outils -----------------------------------------------------------------

func verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		echecs += 1
		print("  ÉCHEC ", message)


func _nettoyer() -> void:
	for nom in ["profil.save", "profil.save.bak", "profil.save.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DOSSIER + nom))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DOSSIER))


func _ecrire(chemin: String, texte: String) -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(texte)
	f.close()


func _effacer_tout() -> void:
	for nom in ["profil.save", "profil.save.bak", "profil.save.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DOSSIER + nom))


func _profil_riche() -> Profil:
	var profil := Profil.nouveau()
	profil.jetons = 42
	profil.symboles_debloques.append(&"bombe")
	profil.reliques_debloquees.append(&"sixieme_rouleau")
	profil.niveau_pv = 3
	profil.niveau_or = 2
	profil.relance_de_partie = true
	profil.trefle_au_depart = true
	profil.maledictions.assign([&"fatigue", &"mauvais_oeil"])
	profil.parties_jouees = 7
	profil.victoires = 2
	return profil


# --- Tests ------------------------------------------------------------------

func test_profil_neuf() -> void:
	print("Profil neuf")
	var profil := Profil.nouveau()
	verifier(profil.jetons == 0 and profil.maledictions.is_empty(), "0 jeton, aucune malédiction")
	verifier(profil.a_debloque_symbole(&"epee") and profil.a_debloque_symbole(&"piece"), "les 4 symboles de base sont débloqués")
	verifier(not profil.a_debloque_symbole(&"bombe") and profil.symboles_verrouilles().size() == 4, "4 symboles verrouillés")
	verifier(profil.a_debloque_relique(&"de_pipe") and not profil.a_debloque_relique(&"cinquieme_as"), "4 reliques débloquées, les autres non")
	verifier(profil.reliques_verrouillees().size() == 5, "5 reliques verrouillées")
	verifier(profil.pv_bonus() == 0 and profil.or_bonus() == 0, "aucun bonus de départ")
	# Tout ce qui est verrouillé ou débloqué existe vraiment dans le jeu.
	var toutes_connues := true
	for id in Profil.SYMBOLES_A_DEBLOQUER + Profil.SYMBOLES_DE_DEPART:
		if not FileAccess.file_exists("res://data/symbols/%s.tres" % id):
			toutes_connues = false
			print("    symbole sans fichier : ", id)
	for id in Profil.RELIQUES_A_DEBLOQUER + Profil.RELIQUES_DE_DEPART:
		if Reliques.charger(id) == null:
			toutes_connues = false
			print("    relique inconnue : ", id)
	verifier(toutes_connues, "tous les éléments cités existent dans les données du jeu")


func test_aller_retour() -> void:
	print("Aller-retour fichier")
	_effacer_tout()
	var avant := _profil_riche()
	verifier(ProfilFichier.sauver(avant, CHEMIN) == OK, "l'écriture réussit")
	var charge := ProfilFichier.charger(CHEMIN)
	var apres := charge.profil
	verifier(charge.message.is_empty() and charge.ecriture_permise, "rien à signaler, écriture permise")
	verifier(apres.en_dictionnaire() == avant.en_dictionnaire(), "le profil relu est identique")
	verifier(apres.jetons is int and apres.niveau_pv is int and apres.parties_jouees is int, "les nombres sont relus en entiers (JSON les rend en flottants)")
	verifier(apres.a_debloque_symbole(&"bombe") and apres.maledictions == avant.maledictions, "déblocages et malédictions conservés")
	verifier(apres.pv_bonus() == 15 and apres.or_bonus() == 20, "bonus de départ : +15 PV, +20 or")


func test_fichier_absent() -> void:
	print("Fichier absent")
	_effacer_tout()
	var charge := ProfilFichier.charger(CHEMIN)
	verifier(charge.profil.jetons == 0 and charge.message.is_empty() and charge.ecriture_permise, "profil neuf, sans message : c'est le premier lancement")


func test_fichier_abime_et_sauvegarde() -> void:
	print("Fichier abîmé et sauvegarde .bak")
	_effacer_tout()
	var premier := _profil_riche()
	premier.jetons = 10
	var second := _profil_riche()
	second.jetons = 20
	ProfilFichier.sauver(premier, CHEMIN)
	ProfilFichier.sauver(second, CHEMIN)
	verifier(FileAccess.file_exists(CHEMIN + ".bak"), "la 2e écriture garde l'ancien fichier en .bak")
	verifier(ProfilFichier.charger(CHEMIN).profil.jetons == 20, "le fichier courant a les 20 jetons")

	# Le fichier courant est tronqué : on retombe sur le .bak, avec un message.
	_ecrire(CHEMIN, "{\"version\": 1, \"jeto")
	var charge := ProfilFichier.charger(CHEMIN)
	verifier(charge.profil.jetons == 10, "fichier tronqué : la sauvegarde (10 jetons) est rechargée")
	verifier(not charge.message.is_empty() and charge.ecriture_permise, "un message prévient le joueur")

	# Écrire ensuite ne doit pas écraser le bon .bak par le fichier abîmé.
	var troisieme := _profil_riche()
	troisieme.jetons = 30
	ProfilFichier.sauver(troisieme, CHEMIN)
	verifier(ProfilFichier.charger(CHEMIN).profil.jetons == 30, "la nouvelle écriture est bonne")
	_ecrire(CHEMIN, "n'importe quoi")
	verifier(ProfilFichier.charger(CHEMIN).profil.jetons == 10, "le .bak est resté le bon profil (10 jetons), pas le fichier abîmé")

	# Tout est abîmé : profil neuf, avec un message.
	_ecrire(CHEMIN + ".bak", "abîmé aussi")
	var perdu := ProfilFichier.charger(CHEMIN)
	verifier(perdu.profil.jetons == 0 and not perdu.message.is_empty(), "fichier et .bak abîmés : profil neuf et un message")


func test_ecriture_sure() -> void:
	print("Écriture sûre")
	_effacer_tout()
	ProfilFichier.sauver(_profil_riche(), CHEMIN)
	verifier(not FileAccess.file_exists(CHEMIN + ".tmp"), "aucun fichier temporaire ne reste")
	verifier(ProfilFichier.sauver(Profil.nouveau(), "user://dossier_qui_n_existe_pas/profil.save") != OK, "une écriture impossible renvoie une erreur")


func test_version_future() -> void:
	print("Version plus récente que le jeu")
	_effacer_tout()
	var texte := "{\"version\": %d, \"jetons\": 999, \"truc_nouveau\": true}" % (Profil.VERSION + 1)
	_ecrire(CHEMIN, texte)
	var charge := ProfilFichier.charger(CHEMIN)
	verifier(charge.profil.jetons == 0, "un profil d'une version future n'est pas lu")
	verifier(not charge.ecriture_permise and not charge.message.is_empty(), "l'écriture est interdite et un message l'explique")
	verifier(FileAccess.get_file_as_string(CHEMIN) == texte, "le fichier n'a pas été touché")


func test_migrations() -> void:
	print("Chaîne de migrations")
	# Une fausse migration 0 -> 1 : l'ancien format avait « or » au lieu de « jetons ».
	var migrations := {0: func(d: Dictionary) -> Dictionary:
		d["jetons"] = d.get("or", 0)
		d.erase("or")
		return d}
	var ancien := Profil.nouveau().en_dictionnaire()
	ancien["version"] = 0
	ancien.erase("jetons")
	ancien["or"] = 12
	var migre := ProfilFichier.migrer(ancien, migrations)
	verifier(int(migre.get("version", -1)) == Profil.VERSION and int(migre.get("jetons", -1)) == 12, "une version 0 est amenée à la version actuelle")
	verifier(Profil.depuis_dictionnaire(migre) != null, "et le résultat est un profil valide")
	verifier(ancien.has("or") and int(ancien["version"]) == 0, "les données d'origine ne sont pas modifiées")
	verifier(ProfilFichier.migrer(ancien, {}).is_empty(), "sans migration pour cette version, les données sont refusées")
	_effacer_tout()
	_ecrire(CHEMIN, JSON.stringify(ancien))
	var charge := ProfilFichier.charger(CHEMIN, migrations)
	verifier(charge.profil.jetons == 12, "charger applique les migrations : 12 jetons")


func test_fixture_v1() -> void:
	print("Fichier réel de la version 1 (tests/fixtures/profil_v1.json)")
	_effacer_tout()
	_ecrire(CHEMIN, FileAccess.get_file_as_string("res://tests/fixtures/profil_v1.json"))
	var charge := ProfilFichier.charger(CHEMIN)
	var p := charge.profil
	verifier(charge.message.is_empty(), "chargé sans message")
	verifier(p.jetons == 37 and p.niveau_pv == 2 and p.niveau_or == 1 and p.relance_de_partie and not p.trefle_au_depart, "valeurs lues")
	verifier(p.a_debloque_symbole(&"bombe") and p.a_debloque_relique(&"jackpot_maudit"), "déblocages lus")
	verifier(p.maledictions == [&"fatigue", &"mauvais_oeil"] and p.parties_jouees == 9 and p.victoires == 1, "malédictions et statistiques lues")


func test_validation() -> void:
	print("Validation des données")
	var bon := _profil_riche().en_dictionnaire()
	verifier(Profil.depuis_dictionnaire(bon) != null, "des données correctes sont acceptées")
	var cas := {
		"jetons négatifs": ["jetons", -1],
		"jetons décimaux": ["jetons", 3.5],
		"jetons en texte": ["jetons", "beaucoup"],
		"niveau PV trop haut": ["niveau_pv", 4],
		"niveau or négatif": ["niveau_or", -1],
		"relance qui n'est pas un booléen": ["relance_de_partie", 1],
		"symbole inconnu": ["symboles_debloques", ["epee", "excalibur"]],
		"relique en double": ["reliques_debloquees", ["tirelire", "tirelire"]],
		"malédiction inconnue": ["maledictions", ["rhume"]],
		"4 malédictions": ["maledictions", ["fatigue", "mauvais_oeil", "sac_leste", "bourse_trouee"]],
		"liste qui n'est pas une liste": ["symboles_debloques", "epee"],
		"plus de victoires que de parties": ["victoires", 99],
	}
	for nom: String in cas:
		var donnees := bon.duplicate(true)
		donnees[cas[nom][0]] = cas[nom][1]
		verifier(Profil.depuis_dictionnaire(donnees) == null, "refusé : %s" % nom)
	var sans_cle := bon.duplicate(true)
	sans_cle.erase("jetons")
	verifier(Profil.depuis_dictionnaire(sans_cle) == null, "refusé : une clé manque")
	# Les éléments de départ restent débloqués même si le fichier ne les cite pas.
	var sans_depart := bon.duplicate(true)
	sans_depart["symboles_debloques"] = ["bombe"]
	var p := Profil.depuis_dictionnaire(sans_depart)
	verifier(p != null and p.a_debloque_symbole(&"epee") and p.a_debloque_symbole(&"bombe"), "les symboles de départ sont toujours débloqués")


func test_donnees_simples() -> void:
	print("Que des données simples dans le fichier")
	var texte := JSON.stringify(_profil_riche().en_dictionnaire())
	verifier(not texte.contains("Object") and not texte.contains("Resource") and not texte.contains("res://"), "le fichier ne cite aucun objet ni chemin de ressource")
	var relu: Variant = JSON.parse_string(texte)
	verifier(relu is Dictionary and int(relu["version"]) == Profil.VERSION, "c'est un JSON lisible, avec sa version")


func test_maledictions() -> void:
	print("Malédictions : tirage et effets")
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 3
	var actives: Array[StringName] = []
	for i in 3:
		var id := Maledictions.tirer(actives, hasard)
		verifier(id != &"" and not (id in actives), "tirage %d : une nouvelle malédiction (%s)" % [i + 1, id])
		actives.append(id)
	verifier(Maledictions.tirer(actives, hasard) == &"", "à 3 malédictions, plus de tirage")
	var vues := {}
	for graine in 60:
		hasard.seed = graine
		vues[Maledictions.tirer([] as Array[StringName], hasard)] = true
	verifier(vues.size() == 5, "les 5 malédictions peuvent sortir")
	var a: Array[StringName] = [&"sac_leste", &"fatigue"]
	var b: Array[StringName] = [&"bourse_trouee", &"croupier_rancunier", &"mauvais_oeil"]
	var aucune: Array[StringName] = []
	verifier(Maledictions.cranes_en_plus(a) == 1 and Maledictions.cranes_en_plus(aucune) == 0, "Sac lesté : +1 crâne")
	verifier(Maledictions.pv_max_en_moins(a) == 5 and Maledictions.pv_max_en_moins(b) == 0, "Fatigue : −5 PV max")
	verifier(Maledictions.prix_ajuste(10, b) == 12 and Maledictions.prix_ajuste(13, b) == 16 and Maledictions.prix_ajuste(10, a) == 10, "Bourse trouée : +20 % arrondi au-dessus (10 → 12, 13 → 16)")
	verifier(Maledictions.pv_ennemi_renforces(18) == 22 and Maledictions.pv_ennemi_renforces(12) == 15, "Rancunier : +20 % de PV arrondi au-dessus (18 → 22, 12 → 15)")
	verifier(Maledictions.renforce_le_premier_ennemi(b) and not Maledictions.renforce_le_premier_ennemi(a), "Rancunier détecté")
	verifier(Maledictions.multiplicateur_gain_or(b) == 2 and Maledictions.multiplicateur_gain_or(a) == 3, "Mauvais œil : ×2 au lieu de ×3")
	for id in Maledictions.TOUTES:
		verifier(Maledictions.nom(id) != "" and Maledictions.description(id) != "", "la malédiction %s a un nom et une description" % id)
