extends SceneTree
## OUTIL : joue des parties ENTIÈRES à travers les vraies scènes (combat, récompense, relique
## offerte, boutique, fin), en cliquant comme un joueur : mises, relances, achats, soins.
## Vérifie qu'aucun écran ne bloque ni ne plante. Deux passes : sans relique, puis avec les 9.
##
## Lancer :  godot --headless --path . -s res://outils/simulation_parties.gd
## (avec `timeout` et la sortie redirigée vers un fichier : voir CLAUDE.md)
## Code de sortie 0 = aucune erreur ; 1 = au moins une erreur (affichée).
##
## À relancer après tout changement d'écran ou d'enchaînement des écrans.

const PARTIES_PAR_PASSE := 25

var etats := {"victoire": 0, "defaite": 0}
var erreurs := 0
var vu := {"relique_offerte": 0, "mise": 0, "relance_pipe": 0, "relance_as": 0, "relique_achetee": 0, "attente": 0}
var hasard := RandomNumberGenerator.new()
var toutes_les_reliques := false


func _initialize() -> void:
	hasard.seed = 12
	await process_frame
	await _jouer(PARTIES_PAR_PASSE)
	print("passe 1 (sans relique) : ", etats, " ", vu, " erreurs ", erreurs)
	# Si la première passe a échoué, la seconde n'aurait pas de sens : on s'arrête là.
	if erreurs == 0:
		toutes_les_reliques = true
		etats = {"victoire": 0, "defaite": 0}
		await _jouer(PARTIES_PAR_PASSE)
		print("passe 2 (9 reliques) : ", etats, " ", vu, " erreurs ", erreurs)
	print("RÉSULTAT : ", "OK" if erreurs == 0 else "%d ERREUR(S)" % erreurs)
	quit(1 if erreurs > 0 else 0)


func _nom_scene() -> String:
	return current_scene.name if current_scene else "(aucune)"


func _attendre() -> void:
	await process_frame
	await process_frame


func _nouvelle_partie() -> void:
	GameState.nouvelle_partie()
	if toutes_les_reliques:
		for relique in Reliques.toutes():
			GameState.partie.ajouter_relique(relique)


func _jouer(nb_parties: int) -> void:
	_nouvelle_partie()
	GameState.aller_a(GameState.SCENE_COMBAT)
	await _attendre()
	var parties := 0
	var etapes := 0
	while parties < nb_parties and etapes < 12000:
		etapes += 1
		match _nom_scene():
			"Combat":
				_jouer_combat()
				current_scene._continuer()
				await _attendre()
			"Recompense":
				var recompense: Control = current_scene
				recompense._choisir(recompense.propositions[0] if etapes % 3 != 0 else null)
				await _attendre()
			"Relique":
				var relique: Control = current_scene
				vu["relique_offerte"] += 1
				relique._choisir(relique.propositions[hasard.randi_range(0, relique.propositions.size() - 1)])
				await _attendre()
			"Boutique":
				await _jouer_boutique()
			"FinPartie":
				etats["victoire" if current_scene.partie.etat == Partie.Etat.VICTOIRE else "defaite"] += 1
				parties += 1
				_nouvelle_partie()
				GameState.aller_a(GameState.SCENE_COMBAT)
				await _attendre()
			var inattendue:
				print("ERREUR : écran inattendu « %s »" % inattendue)
				erreurs += 1
				return
	# Les parties demandées doivent toutes avoir été jouées : sinon un écran est bloqué.
	if parties < nb_parties:
		print("ERREUR : seulement %d parties sur %d ont été jouées jusqu'à l'écran de fin (écran bloqué ?)" % [parties, nb_parties])
		erreurs += 1


## Un combat entier : mise au hasard, levier, relances au hasard, validation.
func _jouer_combat() -> void:
	var ecran: Control = current_scene
	var tours := 0
	while not ecran.combat.est_fini() and tours < 400:
		var possibles: Array[int] = []
		for i in ecran.boutons_mise.size():
			if not ecran.boutons_mise[i].disabled:
				possibles.append(i)
		var choix := possibles[hasard.randi_range(0, possibles.size() - 1)]
		ecran.boutons_mise[choix].pressed.emit()
		if choix > 0:
			vu["mise"] += 1
		ecran._tirer()
		if ecran.combat.tirage_en_attente:
			vu["attente"] += 1
			if hasard.randi_range(0, 1) == 0 and ecran.bouton_de_pipe.visible and not ecran.bouton_de_pipe.disabled:
				ecran.bouton_de_pipe.pressed.emit()
				vu["relance_pipe"] += 1
			if hasard.randi_range(0, 1) == 0 and ecran.bouton_cinquieme_as.visible and not ecran.bouton_cinquieme_as.disabled:
				# On ne peut garder qu'un rouleau qui montre un symbole (pas un rouleau vide ou bloqué).
				var gardables: Array[int] = []
				for i in ecran.cases.size():
					if ecran.combat.grille_courante[i] != null:
						gardables.append(i)
				if not gardables.is_empty():
					ecran.bouton_cinquieme_as.pressed.emit()
					# Le vrai chemin du code : le clic sur un rouleau appelle _garder_rouleau
					# (les vrais clics de souris sont vérifiés par clics_reels.gd).
					ecran._garder_rouleau(gardables[hasard.randi_range(0, gardables.size() - 1)])
					vu["relance_as"] += 1
					if ecran.choix_du_rouleau:
						print("ERREUR : le choix du rouleau reste ouvert après avoir gardé un rouleau")
						erreurs += 1
			ecran.bouton_valider.pressed.emit()
			if ecran.combat.tirage_en_attente:
				print("ERREUR : le tirage attend encore après « Valider »")
				erreurs += 1
		tours += 1
	if not ecran.bouton_continuer.visible:
		print("ERREUR : le bouton « Continuer » n'apparaît pas en fin de combat")
		erreurs += 1


## La boutique : de l'or de test, achat des reliques, soin, un achat de symbole.
func _jouer_boutique() -> void:
	var boutique: Control = current_scene
	var partie: Partie = boutique.partie
	boutique._donner_or_debug()
	for i in boutique.cartes_reliques.size():
		if boutique.boutique.peut_acheter_relique(i):
			boutique._acheter_relique(i)
			vu["relique_achetee"] += 1
	if boutique.boutique.peut_soigner() and partie.pv < partie.pv_max:
		boutique._soigner()
	for i in 3:
		if boutique.boutique.peut_acheter(i):
			boutique._acheter(i)
			break
	await _attendre()
	if partie.or_total < 0:
		print("ERREUR : or négatif (%d)" % partie.or_total)
		erreurs += 1
	boutique._quitter()
	await _attendre()
