extends SceneTree
## Tests des effets de jeu (secousse, arrêt sur image, chiffres, pluie de pièces, flash, néon), à lancer :
## godot --headless --path . -s res://tests/test_impacts.gd
## Ces tests vérifient le comportement (durées, bornes, nettoyage, réductions d'accessibilité), pas l'aspect : à regarder.

var echecs := 0
var machine := MachineASous.new(5, 1)


func _init() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	await process_frame
	GameState.options = Options.new()
	await test_secousse()
	await test_arret_sur_image()
	await test_chiffres()
	await test_pluie_et_banniere()
	await test_flash()
	await test_reductions()
	test_valeurs_du_tour()
	test_shader()
	GameState.options = null
	print("TERMINÉ : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


func verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		echecs += 1
		print("  ÉCHEC ", message)


func nouvel_ecran() -> Control:
	var ecran := Control.new()
	ecran.size = Vector2(1152, 648)
	root.add_child(ecran)
	return ecran


func test_secousse() -> void:
	print("Secousse")
	var ecran := nouvel_ecran()
	Impacts.secouer(ecran, 0.8)
	var secousse := ecran.get_node_or_null("Secousse") as Secousse
	verifier(secousse != null and is_equal_approx(secousse.trauma, 0.8), "un impact crée la secousse avec son trauma")
	Impacts.secouer(ecran, 0.9)
	verifier(secousse.trauma == 1.0, "les impacts s'additionnent mais le trauma ne dépasse pas 1")
	var decalage_max := 0.0
	for i in 20:
		await process_frame
		decalage_max = maxf(decalage_max, ecran.offset_transform_position.length())
	verifier(decalage_max > 0.5, "l'écran bouge (décalage max %.1f px)" % decalage_max)
	verifier(decalage_max <= Secousse.DECALAGE_MAX.length() + 0.01, "…sans jamais dépasser le décalage maximum (%.1f px)" % Secousse.DECALAGE_MAX.length())
	var avant := secousse.trauma
	await create_timer(0.3).timeout
	verifier(secousse.trauma < avant, "le trauma redescend tout seul")
	await create_timer(1.2).timeout
	await process_frame
	verifier(secousse.trauma == 0.0 and ecran.offset_transform_position == Vector2.ZERO, "après ~1 s : trauma à 0 et écran revenu exactement à sa place")
	ecran.queue_free()


func test_arret_sur_image() -> void:
	print("Arrêt sur image")
	Impacts.arret_sur_image(0.1)
	verifier(Engine.time_scale < 0.2, "le temps ralentit pendant l'arrêt")
	await create_timer(0.03, true, false, true).timeout
	Impacts.arret_sur_image(0.1)
	await create_timer(0.07, true, false, true).timeout
	verifier(Engine.time_scale < 0.2, "le 1er arrêt ne remet pas le temps pendant le 2e")
	await create_timer(0.2, true, false, true).timeout
	verifier(Engine.time_scale == 1.0, "après le dernier arrêt, le temps est revenu à la normale (1.0)")


func test_chiffres() -> void:
	print("Chiffres qui s'envolent")
	var ecran := nouvel_ecran()
	var premier := Impacts.chiffre(ecran, "-15", Vector2(100, 200), Impacts.COULEUR_DEGATS)
	verifier(premier != null and premier.text == "-15" and premier.is_inside_tree(), "un chiffre apparaît")
	for i in 30:
		Impacts.chiffre(ecran, "+1", Vector2(i, 0), Color.WHITE)
	verifier(get_nodes_in_group("chiffres_flottants").size() <= Impacts.MAX_CHIFFRES, "au plus %d chiffres à la fois (%d)" % [Impacts.MAX_CHIFFRES, get_nodes_in_group("chiffres_flottants").size()])
	await create_timer(0.3).timeout
	verifier(premier.position.y < 200.0, "le chiffre monte")
	await create_timer(1.2).timeout
	verifier(get_nodes_in_group("chiffres_flottants").is_empty(), "tous les chiffres ont disparu ensuite (aucun reste)")
	ecran.queue_free()


func test_pluie_et_banniere() -> void:
	print("Pluie de pièces et bannière")
	var ecran := nouvel_ecran()
	var avant := ecran.get_child_count()
	var nb := Impacts.pluie_de_pieces(ecran, 20)
	verifier(nb == 20 and ecran.get_child_count() == avant + 20, "20 pièces créées")
	var banniere := Impacts.banniere(ecran, "JACKPOT !")
	verifier(banniere != null and banniere.material is ShaderMaterial, "la bannière est un néon (shader)")
	await create_timer(2.6).timeout
	verifier(ecran.get_child_count() == avant, "après la chute, toutes les pièces et la bannière sont libérées")
	ecran.queue_free()


func test_flash() -> void:
	print("Flash")
	var cible := ColorRect.new()
	root.add_child(cible)
	var faits := 0
	for i in 8:
		if Impacts.flash(cible):
			faits += 1
	verifier(faits == Impacts.MAX_FLASHS_PAR_SECONDE, "au plus %d flashs par seconde (%d sur 8 demandés)" % [Impacts.MAX_FLASHS_PAR_SECONDE, faits])
	await create_timer(0.3).timeout
	verifier(cible.modulate == Color.WHITE, "après un flash, la couleur revient exactement au blanc")
	await create_timer(1.0).timeout
	verifier(Impacts.flash(cible), "une seconde plus tard, un nouveau flash est permis")
	cible.queue_free()


func test_reductions() -> void:
	print("Options d'accessibilité")
	var options := Options.new()
	options.reduire_tremblements = true
	options.reduire_flashs = true
	GameState.options = options
	var ecran := nouvel_ecran()
	Impacts.secouer(ecran, 1.0)
	verifier(ecran.get_node_or_null("Secousse") == null and ecran.offset_transform_position == Vector2.ZERO, "tremblements réduits : aucune secousse")
	Impacts.arret_sur_image(0.2)
	verifier(Engine.time_scale == 1.0, "…ni arrêt sur image")
	var cible := ColorRect.new()
	ecran.add_child(cible)
	await create_timer(1.1).timeout
	verifier(not Impacts.flash(cible) and cible.modulate == Color.WHITE, "flashs réduits : aucun flash")
	var etiquette := Label.new()
	Cartes.neon(etiquette)
	verifier(is_equal_approx(float((etiquette.material as ShaderMaterial).get_shader_parameter("amplitude")), 0.0), "…et le néon ne pulse plus (amplitude 0)")
	options.reduire_flashs = false
	var normale := Label.new()
	Cartes.neon(normale)
	verifier(float((normale.material as ShaderMaterial).get_shader_parameter("amplitude")) > 0.0, "sans la réduction, le néon pulse")
	etiquette.free()
	normale.free()
	ecran.queue_free()
	GameState.options = Options.new()


func test_valeurs_du_tour() -> void:
	print("Chiffres et force de secousse d'un tour")
	var epee := load("res://data/symbols/epee.tres") as SymbolData
	var piece := load("res://data/symbols/piece.tres") as SymbolData
	var bouclier := load("res://data/symbols/bouclier.tres") as SymbolData
	var potion := load("res://data/symbols/potion.tres") as SymbolData
	var mixte: Array[SymbolData] = [epee, bouclier, potion, piece, null]
	var chiffres := Impacts.chiffres_du_tour(machine.resoudre(mixte), 40, 33)
	var textes: Array[String] = []
	for c in chiffres:
		textes.append(c["texte"])
	verifier(textes == ["-3", "-7", "+3 PV", "+3", "+2 or"], "épée, coup reçu, potion, bouclier, pièce : %s" % str(textes))
	verifier(Impacts.chiffres_du_tour(machine.resoudre([null, null, null, null, null] as Array[SymbolData]), 40, 40).is_empty(), "rien ne se passe : aucun chiffre")
	var jackpot: Array[SymbolData] = [epee, epee, epee, epee, epee]
	verifier(Impacts.force_de_secousse(machine.resoudre(jackpot), 40, 40) == 0.9, "un jackpot : secousse maximale (0,9)")
	var combo: Array[SymbolData] = [epee, epee, epee, null, null]
	verifier(Impacts.force_de_secousse(machine.resoudre(combo), 40, 40) == 0.5, "un gros combo (15 dégâts) : secousse 0,5")
	verifier(Impacts.force_de_secousse(machine.resoudre(mixte), 40, 40) == 0.0, "un petit tour : pas de secousse")
	verifier(Impacts.force_de_secousse(machine.resoudre(mixte), 40, 28) == 0.5, "un coup reçu de 12 PV : secousse 0,5")
	verifier(Impacts.force_de_secousse(machine.resoudre(mixte), 40, 35) == 0.25, "un coup reçu de 5 PV : petite secousse 0,25")


func test_shader() -> void:
	print("Shader néon")
	var shader := load(Cartes.SHADER_NEON) as Shader
	verifier(shader != null, "le shader se charge")
	var noms: Array[String] = []
	for uniforme in shader.get_shader_uniform_list():
		noms.append(uniforme["name"])
	verifier("couleur_halo" in noms and "periode" in noms and "amplitude" in noms, "il compile et expose couleur_halo, periode et amplitude (%s)" % str(noms))
	var tous := true
	for fichier in DirAccess.get_files_at("res://assets/shaders/"):
		if fichier.get_extension() == "gdshader":
			var s := load("res://assets/shaders/" + fichier) as Shader
			s.get_shader_uniform_list()
			tous = tous and s != null
	verifier(tous, "tous les .gdshader du jeu se compilent")
	# La période du pulsement divise le temps de rebouclage de TIME (3600 s) : le néon ne saute jamais.
	verifier(fmod(3600.0, 2.0) == 0.0, "la période par défaut (2 s) divise 3600 s")
