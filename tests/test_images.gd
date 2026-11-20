extends SceneTree
## Tests des images : chaque ennemi et chaque symbole a ses images, elles se chargent, les agrandissements sont
## entiers et nets, et chaque fichier d'image est déclaré (auteur, source, licence) dans le manifeste. À lancer :
## godot --headless --path . -s res://tests/test_images.gd

var echecs := 0


func _init() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	await process_frame
	test_ennemis()
	test_symboles()
	test_agrandissement()
	test_manifeste()
	print("TERMINÉ : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


func verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		echecs += 1
		print("  ÉCHEC ", message)


func _fichiers(dossier: String) -> Array[String]:
	var liste: Array[String] = []
	for f in DirAccess.get_files_at(dossier):
		if f.get_extension() == "tres":
			liste.append(dossier + f)
	return liste


func test_ennemis() -> void:
	print("Ennemis")
	for chemin in _fichiers("res://data/enemies/"):
		var ennemi := load(chemin) as EnemyData
		verifier(ennemi != null and Images.nb_cadres(ennemi.images) >= 2, "%s : %d images d'animation (%s)" % [chemin.get_file(), Images.nb_cadres(ennemi.images) if ennemi != null else 0, ennemi.images if ennemi != null else "?"])
	verifier(Images.nb_cadres("knight_m_idle_anim") >= 2, "le joueur (chevalier) a son animation")
	# Les sprites recadrés (ennemis en grand derrière la machine) : de la bonne taille, sans marge transparente.
	for chemin in _fichiers("res://data/enemies/"):
		var ennemi := load(chemin) as EnemyData
		var cadres := Images.cadres_rognes(ennemi.images, 190)
		verifier(cadres.size() == Images.nb_cadres(ennemi.images), "%s : toutes les images sont recadrées" % chemin.get_file())
		var hauteur := cadres[0].get_height() if not cadres.is_empty() else 0
		verifier(hauteur >= 60 and hauteur <= 240, "%s : sprite de %d px de haut (60 à 240)" % [chemin.get_file(), hauteur])
		var meme_taille := true
		for cadre in cadres:
			meme_taille = meme_taille and cadre.get_size() == cadres[0].get_size()
		verifier(meme_taille, "%s : toutes les images ont la même taille (l'ennemi ne saute pas)" % chemin.get_file())
		if not cadres.is_empty():
			var utilisee := cadres[0].get_image().get_used_rect()
			verifier(utilisee.position.y == 0 or cadres.size() > 1, "%s : le haut du sprite touche le haut de l'image" % chemin.get_file())


func test_symboles() -> void:
	print("Symboles")
	for chemin in _fichiers("res://data/symbols/"):
		var symbole := load(chemin) as SymbolData
		verifier(symbole != null and Images.existe(symbole.icone), "%s : icône « %s » trouvée" % [chemin.get_file(), symbole.icone if symbole != null else "?"])


func test_agrandissement() -> void:
	print("Agrandissement")
	var icone := Images.icone("coin_anim_f0", 48)
	verifier(icone != null and icone.get_width() == 48 and icone.get_height() == 48, "une icône est une case carrée de 48 px")
	var image := icone.get_image()
	verifier(image.get_pixel(0, 0).a == 0.0, "le coin de la case est transparent (pas de fond)")
	var nombre_de_couleurs := {}
	for y in image.get_height():
		for x in image.get_width():
			nombre_de_couleurs[image.get_pixel(x, y)] = true
	verifier(nombre_de_couleurs.size() <= 8, "pixels nets, aucune couleur intermédiaire (%d couleurs)" % nombre_de_couleurs.size())
	verifier(Images.icone("image_qui_n_existe_pas", 48) == null, "une image inconnue donne null (pas d'erreur)")
	var cadres := Images.cadres("big_demon_idle_anim", 96)
	verifier(cadres.size() == 4 and cadres[0].get_height() == 108, "le grand démon (36 px) est agrandi ×3 : 108 px")
	var petit := Images.cadres("tiny_slug_anim", 96)
	verifier(petit[0].get_height() == 96, "la limace (16 px) est agrandie ×6 : 96 px")


func test_manifeste() -> void:
	print("Manifeste des ressources")
	var texte := FileAccess.get_file_as_string("res://assets/manifeste.json")
	var entrees: Variant = JSON.parse_string(texte)
	verifier(entrees is Array, "assets/manifeste.json se lit")
	var declares := {}
	var complet := true
	for e in entrees:
		declares[e["fichier"]] = true
		for cle in ["auteur", "source", "licence"]:
			if str(e.get(cle, "")).is_empty():
				complet = false
				print("    incomplet : ", e["fichier"], " (", cle, ")")
	verifier(complet, "chaque entrée a un auteur, une source et une licence")
	var manquants := 0
	for f in DirAccess.get_files_at("res://assets/images/"):
		if f.get_extension() == "png" and not declares.has("assets/images/" + f):
			manquants += 1
			print("    non déclaré : ", f)
	verifier(manquants == 0, "chaque image du dossier est déclarée dans le manifeste")
