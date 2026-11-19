extends SceneTree
## Tests du son et de la musique (bus, volumes, lecteurs, fondu), à lancer en ligne de commande :
## godot --headless --path . -s res://tests/test_audio.gd
## Les sons réels ne s'entendent pas ici : ces tests vérifient le câblage, pas la qualité (à écouter).

var echecs := 0


func _init() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	await process_frame
	await test_bus_et_volumes()
	await test_lecteurs_des_effets()
	await test_evenements_sans_fichier()
	await test_musique()
	await test_tables_de_donnees()
	await test_fichiers_et_manifeste()
	await test_retour_du_tour()
	print("TERMINÉ : %d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)


func verifier(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		echecs += 1
		print("  ÉCHEC ", message)


## Un son muet de 0,1 s, fabriqué en mémoire (en boucle si `boucle` : la musique ne s'arrête jamais).
func silence(boucle: bool = false) -> AudioStreamWAV:
	var flux := AudioStreamWAV.new()
	if boucle:
		flux.loop_mode = AudioStreamWAV.LOOP_FORWARD
		flux.loop_end = 2205
	flux.format = AudioStreamWAV.FORMAT_16_BITS
	flux.mix_rate = 22050
	var donnees := PackedByteArray()
	donnees.resize(4410)
	flux.data = donnees
	return flux


func test_bus_et_volumes() -> void:
	print("Bus et volumes")
	Son.preparer_bus()
	Son.preparer_bus()
	var nb := AudioServer.bus_count
	verifier(AudioServer.get_bus_index(Son.BUS_MUSIQUE) > 0 and AudioServer.get_bus_index(Son.BUS_EFFETS) > 0, "les bus Musique et Effets existent")
	Son.preparer_bus()
	verifier(AudioServer.bus_count == nb, "rappeler preparer_bus ne crée pas de bus en double")
	verifier(AudioServer.get_bus_send(AudioServer.get_bus_index(Son.BUS_EFFETS)) == &"Master", "les bus sont renvoyés à Master")
	verifier(is_equal_approx(Son.gain_du_curseur(0.5), 0.25) and Son.gain_du_curseur(1.0) == 1.0 and Son.gain_du_curseur(0.0) == 0.0, "curseur 50 % : gain 0,25 (au carré)")
	verifier(Son.gain_du_curseur(-1.0) == 0.0 and Son.gain_du_curseur(3.0) == 1.0, "un curseur hors de 0 à 1 est ramené dans les bornes")
	var options := Options.new()
	options.volume_musique = 0.5
	options.volume_effets = 0.0
	Son.appliquer_options(options)
	var musique := AudioServer.get_bus_index(Son.BUS_MUSIQUE)
	var effets := AudioServer.get_bus_index(Son.BUS_EFFETS)
	verifier(is_equal_approx(AudioServer.get_bus_volume_linear(musique), 0.25) and not AudioServer.is_bus_mute(musique), "musique à 50 % : gain 0,25, pas coupée")
	verifier(AudioServer.is_bus_mute(effets), "effets à 0 : le bus est vraiment coupé")
	options.volume_effets = 1.0
	Son.appliquer_options(options)
	verifier(not AudioServer.is_bus_mute(effets) and is_equal_approx(AudioServer.get_bus_volume_linear(effets), 1.0), "remonter le curseur rend le son")


func test_lecteurs_des_effets() -> void:
	print("Lecteurs d'effets")
	verifier(Son.jouer_flux(silence()), "jouer un son chargé renvoie vrai")
	await process_frame
	verifier(Son.lecteurs().size() == Son.NB_LECTEURS, "%d lecteurs partagés" % Son.NB_LECTEURS)
	var tous_sur_effets := true
	var aucun_sur_master := true
	for lecteur in Son.lecteurs():
		if lecteur.bus != Son.BUS_EFFETS:
			tous_sur_effets = false
		if lecteur.bus == &"Master":
			aucun_sur_master = false
	verifier(tous_sur_effets and aucun_sur_master, "tous les lecteurs sont sur le bus Effets, aucun sur Master")
	verifier(Son.lecteurs()[0].is_inside_tree(), "les lecteurs sont posés sur l'arbre (ils survivent aux changements d'écran)")
	for i in Son.NB_LECTEURS * 2:
		Son.jouer_flux(silence(), 1.0)
	verifier(Son.lecteurs().size() == Son.NB_LECTEURS, "beaucoup de sons d'affilée : toujours %d lecteurs (pas de fuite)" % Son.NB_LECTEURS)
	Son.jouer_flux(silence(), 1.0)
	var hauteurs := {}
	for i in 30:
		Son.jouer_flux(silence(), 1.0)
		for lecteur in Son.lecteurs():
			hauteurs[snappedf(lecteur.pitch_scale, 0.001)] = true
	var min_h := 10.0
	var max_h := 0.0
	for h: float in hauteurs:
		min_h = minf(min_h, h)
		max_h = maxf(max_h, h)
	verifier(min_h >= 0.93 and max_h <= 1.07 and hauteurs.size() > 5, "la hauteur varie de ± 6 %% (de %.3f à %.3f)" % [min_h, max_h])
	verifier(not Son.jouer_flux(null), "un son absent ne joue pas")


func test_evenements_sans_fichier() -> void:
	print("Événements")
	verifier(not Son.jouer(&"evenement_inconnu"), "un événement inconnu ne plante pas et renvoie faux")
	var table := TableSons.new()
	table.evenements = {"un": ["res://a.ogg", "res://b.ogg"], "deux": "res://c.ogg"}
	verifier(table.chemins(&"un").size() == 2 and table.chemins(&"deux") == ["res://c.ogg"] and table.chemins(&"trois").is_empty(), "la table donne les chemins d'un événement (une ou plusieurs variantes)")
	var doublons := {}
	for id in Son.EVENEMENTS:
		doublons[id] = true
	verifier(doublons.size() == Son.EVENEMENTS.size() and Son.EVENEMENTS.size() == 15, "15 événements sonores, sans doublon")


func test_musique() -> void:
	print("Musique")
	verifier(Musique.piste_pour(1, false) == &"etage_1" and Musique.piste_pour(3, false) == &"etage_3", "une piste par étage")
	verifier(Musique.piste_pour(2, true) == &"boss" and Musique.piste_pour(1, true) == &"boss", "le boss a sa propre piste")
	verifier(Musique.piste_pour(0, false) == &"etage_1" and Musique.piste_pour(9, false) == &"etage_3", "un étage hors de 1 à 3 est ramené dans les bornes")
	Musique.jouer_flux(&"etage_1", silence(true), 0.2)
	await process_frame
	verifier(Musique.piste_courante == &"etage_1", "la piste courante est notée")
	var liste := Musique.lecteurs()
	verifier(liste.size() == 2 and liste[0].bus == Son.BUS_MUSIQUE and liste[1].bus == Son.BUS_MUSIQUE and liste[0].is_inside_tree(), "deux lecteurs sur le bus Musique, posés sur l'arbre")
	await create_timer(0.35).timeout
	var actuel := Musique.lecteurs()[0]
	verifier(is_equal_approx(actuel.volume_linear, 1.0) and actuel.playing, "après le fondu : la piste joue à plein volume")
	# Même piste : rien ne redémarre.
	Musique.jouer(&"etage_1")
	verifier(Musique.lecteurs()[0] == actuel and actuel.playing, "redemander la même piste ne la relance pas")
	# Changement de piste : fondu enchaîné.
	Musique.jouer_flux(&"boss", silence(true), 0.2)
	await process_frame
	var entrant := Musique.lecteurs()[0]
	var sortant := Musique.lecteurs()[1]
	verifier(entrant != actuel and sortant == actuel, "le nouveau lecteur prend la suite de l'ancien")
	await create_timer(0.1).timeout
	verifier(entrant.volume_linear > 0.1 and entrant.volume_linear < 0.95 and sortant.volume_linear > 0.05 and sortant.volume_linear < 0.95,
			"à mi-fondu les deux pistes s'entendent (entrant %.2f, sortant %.2f)" % [entrant.volume_linear, sortant.volume_linear])
	await create_timer(0.3).timeout
	verifier(is_equal_approx(entrant.volume_linear, 1.0) and not sortant.playing, "après le fondu : la nouvelle piste à plein volume, l'ancienne arrêtée")
	# Silence.
	Musique.jouer_flux(&"", null, 0.1)
	await create_timer(0.25).timeout
	verifier(not Musique.lecteurs()[0].playing and not Musique.lecteurs()[1].playing, "une piste sans fichier : silence après le fondu")
	# Deux changements rapprochés : seule la dernière piste reste.
	Musique.jouer_flux(&"etage_2", silence(true), 0.3)
	Musique.jouer_flux(&"etage_3", silence(true), 0.1)
	await create_timer(0.4).timeout
	verifier(Musique.piste_courante == &"etage_3" and Musique.lecteurs()[0].playing and is_equal_approx(Musique.lecteurs()[0].volume_linear, 1.0),
			"deux changements d'affilée : la dernière piste est celle qui joue, à plein volume")
	# Un fondu interrompu puis le silence : aucune piste ne reste « fantôme » à mi-volume.
	Musique.jouer_flux(&"etage_1", silence(true), 0.4)
	Musique.jouer_flux(&"boss", silence(true), 0.4)
	await create_timer(0.1).timeout
	Musique.jouer_flux(&"", null, 0.1)
	await create_timer(0.3).timeout
	verifier(not Musique.lecteurs()[0].playing and not Musique.lecteurs()[1].playing, "fondu interrompu puis silence : plus aucune piste ne joue")
	Musique.jouer_flux(&"", null, 0.01)


func test_tables_de_donnees() -> void:
	print("Tables de données")
	for chemin in [Son.TABLE, Musique.TABLE]:
		verifier(load(chemin) is TableSons, "%s se charge comme table" % chemin)
	# Chaque fichier cité par une table existe (aucune fois une faute de frappe dans un chemin).
	var tous_existent := true
	for chemin in [Son.TABLE, Musique.TABLE]:
		var table := load(chemin) as TableSons
		for evenement: String in table.evenements:
			for fichier in table.chemins(StringName(evenement)):
				if not ResourceLoader.exists(fichier):
					tous_existent = false
					print("    fichier manquant : ", fichier)
	verifier(tous_existent, "tous les fichiers cités par les tables existent")


func test_fichiers_et_manifeste() -> void:
	print("Fichiers sonores et manifeste")
	var effets := load(Son.TABLE) as TableSons
	var sans_fichier: Array[StringName] = []
	for id in Son.EVENEMENTS:
		var existent := 0
		for chemin in effets.chemins(id):
			if ResourceLoader.exists(chemin):
				existent += 1
		if existent == 0:
			sans_fichier.append(id)
	verifier(sans_fichier.is_empty(), "chaque événement sonore a au moins un fichier (manquants : %s)" % str(sans_fichier))
	var musiques := load(Musique.TABLE) as TableSons
	var toutes_les_pistes := true
	for piste in [&"etage_1", &"etage_2", &"etage_3", &"boss"]:
		if musiques.chemins(piste).is_empty() or not ResourceLoader.exists(musiques.chemins(piste)[0]):
			toutes_les_pistes = false
	verifier(toutes_les_pistes, "les 4 pistes (étages 1 à 3 et boss) ont un fichier")
	# Chaque fichier de assets/sons et assets/musiques figure au manifeste, avec sa source et sa licence.
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string("res://assets/manifeste.json"))
	var manifeste: Array = json.data if json.data is Array else []
	var connus := {}
	var complets := true
	for entree: Dictionary in manifeste:
		connus[entree.get("fichier")] = true
		for cle in ["auteur", "source", "licence"]:
			if String(entree.get(cle, "")).is_empty():
				complets = false
	verifier(complets and not manifeste.is_empty(), "chaque entrée du manifeste a un auteur, une source et une licence")
	var oublies: Array[String] = []
	for dossier in ["res://assets/sons/", "res://assets/musiques/"]:
		for fichier in DirAccess.get_files_at(dossier):
			if fichier.get_extension() in ["ogg", "wav", "mp3"] and not connus.has(dossier.trim_prefix("res://") + fichier):
				oublies.append(dossier + fichier)
	verifier(oublies.is_empty(), "aucun fichier sonore absent du manifeste (%s)" % str(oublies))
	var existants := true
	for fichier: String in connus:
		if not FileAccess.file_exists("res://" + fichier):
			existants = false
			print("    cité au manifeste mais absent : ", fichier)
	verifier(existants, "tout ce que cite le manifeste existe")


func test_retour_du_tour() -> void:
	print("Sons d'un tour (RetourTour)")
	var machine := MachineASous.new(5, 1)
	var epee := load("res://data/symbols/epee.tres") as SymbolData
	var bouclier := load("res://data/symbols/bouclier.tres") as SymbolData
	var potion := load("res://data/symbols/potion.tres") as SymbolData
	var piece := load("res://data/symbols/piece.tres") as SymbolData
	var bombe := load("res://data/symbols/bombe.tres") as SymbolData
	var vide: Array[SymbolData] = [epee, bouclier, potion, piece, null]
	var sons := RetourTour.sons(machine.resoudre(vide), 40, 40)
	verifier(sons == [&"coup_donne", &"bouclier", &"soin", &"pieces"], "un tour sans combo : coup, bouclier, soin, pièces (%s)" % str(sons))
	var combo: Array[SymbolData] = [epee, epee, epee, null, null]
	verifier(RetourTour.sons(machine.resoudre(combo), 40, 40) == [&"ding", &"coup_donne"], "un combo : ding puis coup")
	var jackpot: Array[SymbolData] = [epee, epee, epee, epee, epee]
	verifier(RetourTour.sons(machine.resoudre(jackpot), 40, 40) == [&"jackpot", &"coup_donne"], "un jackpot : fanfare (pas de ding en plus)")
	verifier(RetourTour.sons(machine.resoudre(vide), 40, 31).has(&"coup_recu"), "perdre des PV : coup reçu")
	verifier(not RetourTour.sons(machine.resoudre(vide), 40, 40).has(&"coup_recu"), "ne rien perdre : pas de coup reçu")
	var avec_bombe: Array[SymbolData] = [bombe, null, null, null, null]
	verifier(RetourTour.sons(machine.resoudre(avec_bombe), 40, 40).has(&"bombe"), "une bombe visible : son de bombe")
	var rien: Array[SymbolData] = [null, null, null, null, null]
	verifier(RetourTour.sons(machine.resoudre(rien), 40, 40).is_empty(), "des rouleaux vides : aucun son")

