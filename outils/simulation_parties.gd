extends SceneTree
## OUTIL : joue des parties ENTIÈRES à travers les vraies scènes (Comptoir, portes, combat, récompense,
## relique, boutique, repos, fin), en cliquant comme un joueur : portes au hasard, mises, relances,
## achats, soins, dorures. Vérifie qu'aucun écran ne bloque ni ne plante.
## Trois passes : sans relique, avec les 9 reliques, puis « increvable » (beaucoup de PV, pour
## aller jusqu'aux étages 2 et 3 : Dame de Pique, mimiques, Grand Croupier, victoire).
##
## Lancer :  godot --headless --path . -s res://outils/simulation_parties.gd
## (avec `timeout` et la sortie redirigée vers un fichier : voir CLAUDE.md)
## Code de sortie 0 = aucune erreur ; 1 = au moins une erreur (affichée).
##
## À relancer après tout changement d'écran ou d'enchaînement des écrans.

const PARTIES_PAR_PASSE := 20

var etats := {"victoire": 0, "defaite": 0}
var erreurs := 0
var vu := {
	"porte_combat": 0, "porte_boutique": 0, "porte_coffre": 0, "porte_repos": 0,
	"mimique": 0, "fuite": 0, "boss": 0, "relique_offerte": 0, "relique_achetee": 0,
	"repos_soin": 0, "repos_dore": 0, "mise": 0, "relance_pipe": 0, "relance_as": 0,
	"attente": 0, "etage_2": 0, "etage_3": 0,
	"achat_comptoir": 0, "malediction_en_partie": 0, "symbole_debloque_en_sac": 0,
}
var hasard := RandomNumberGenerator.new()
var toutes_les_reliques := false
var increvable := false
## La dernière partie dont les réglages de la passe (reliques, PV) ont été appliqués.
var derniere_partie: Partie


func _initialize() -> void:
	hasard.seed = 12
	# Le profil vit en mémoire et évolue d'une partie à l'autre (jamais écrit sur le disque : mode sans fenêtre).
	GameState.profil = Profil.nouveau()
	await process_frame
	await _jouer(PARTIES_PAR_PASSE)
	print("passe 1 (sans relique) : ", etats, " erreurs ", erreurs)
	# Si la première passe a échoué, la suite n'aurait pas de sens : on s'arrête là.
	if erreurs == 0:
		toutes_les_reliques = true
		etats = {"victoire": 0, "defaite": 0}
		await _jouer(PARTIES_PAR_PASSE)
		print("passe 2 (9 reliques) : ", etats, " erreurs ", erreurs)
	if erreurs == 0:
		increvable = true
		etats = {"victoire": 0, "defaite": 0}
		await _jouer(PARTIES_PAR_PASSE)
		print("passe 3 (increvable) : ", etats, " erreurs ", erreurs)
		# Les parties increvables doivent tout avoir vu : sinon une salle ou un ennemi n'est jamais joué.
		for obligatoire in ["porte_combat", "porte_boutique", "porte_coffre", "porte_repos", "mimique", "fuite",
				"boss", "relique_offerte", "repos_soin", "repos_dore", "etage_2", "etage_3"]:
			if int(vu[obligatoire]) == 0:
				print("ERREUR : « %s » n'a jamais été joué pendant la simulation" % obligatoire)
				erreurs += 1
		if int(etats["victoire"]) == 0:
			print("ERREUR : aucune victoire en passe 3 (le donjon n'est pas finissable ?)")
			erreurs += 1
	print("vu : ", vu)
	print("RÉSULTAT : ", "OK" if erreurs == 0 else "%d ERREUR(S)" % erreurs)
	quit(1 if erreurs > 0 else 0)


func _nom_scene() -> String:
	return current_scene.name if current_scene else "(aucune)"


func _attendre() -> void:
	await process_frame
	await process_frame


## Les réglages propres à la passe, appliqués une fois au début de chaque partie (reliques, PV).
func _regler_la_partie() -> void:
	var partie := GameState.partie
	if partie == derniere_partie:
		return
	derniere_partie = partie
	if not partie.maledictions.is_empty():
		vu["malediction_en_partie"] += 1
	for symbole in partie.sac.symboles:
		if symbole.id in Profil.SYMBOLES_A_DEBLOQUER:
			vu["symbole_debloque_en_sac"] += 1
			break
	if toutes_les_reliques:
		for relique in Reliques.toutes():
			partie.ajouter_relique(relique)
	if increvable:
		partie.pv_max = 400
		partie.pv = 400


func _jouer(nb_parties: int) -> void:
	GameState.en_partie = false
	GameState.aller_a_suivant()
	await _attendre()
	var parties := 0
	var etapes := 0
	while parties < nb_parties and etapes < 40000:
		etapes += 1
		match _nom_scene():
			"Comptoir":
				_jouer_comptoir()
				await _attendre()
			"Portes":
				_regler_la_partie()
				_jouer_portes()
				await _attendre()
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
			"Repos":
				await _jouer_repos()
			"FinPartie":
				etats["victoire" if current_scene.partie.etat == Partie.Etat.VICTOIRE else "defaite"] += 1
				parties += 1
				if hasard.randi_range(0, 3) == 0:
					current_scene.bouton_rejouer.pressed.emit()
				else:
					current_scene.bouton_comptoir.pressed.emit()
				await _attendre()
			var inattendue:
				print("ERREUR : écran inattendu « %s »" % inattendue)
				erreurs += 1
				return
	# Les parties demandées doivent toutes avoir été jouées : sinon un écran est bloqué.
	if parties < nb_parties:
		print("ERREUR : seulement %d parties sur %d ont été jouées jusqu'à l'écran de fin (écran bloqué ?)" % [parties, nb_parties])
		erreurs += 1


## Le Comptoir : quelques achats possibles au hasard, puis « Jouer ».
func _jouer_comptoir() -> void:
	var ecran: Control = current_scene
	var profil := GameState.profil
	var achats := 0
	for i in hasard.randi_range(0, 3):
		var achat: Comptoir.Achat = Comptoir.ORDRE[hasard.randi_range(0, Comptoir.ORDRE.size() - 1)]
		if ecran.comptoir.peut_acheter(achat):
			ecran.boutons_achats[Comptoir.ORDRE.find(achat)].pressed.emit()
			achats += 1
	vu["achat_comptoir"] += achats
	if profil.jetons < 0:
		print("ERREUR : jetons négatifs (%d)" % profil.jetons)
		erreurs += 1
	ecran.bouton_jouer.pressed.emit()


## Les portes : une au hasard, en comptant ce qu'on franchit.
func _jouer_portes() -> void:
	var ecran: Control = current_scene
	var partie: Partie = ecran.partie
	if partie.etage == 2:
		vu["etage_2"] += 1
	elif partie.etage == 3:
		vu["etage_3"] += 1
	if ecran.boutons_portes.size() != 2:
		print("ERREUR : %d portes au lieu de 2" % ecran.boutons_portes.size())
		erreurs += 1
	var index := hasard.randi_range(0, ecran.boutons_portes.size() - 1)
	var salle: Salle = ecran.portes[index]
	match salle.type:
		Salle.Type.COMBAT:
			vu["porte_combat"] += 1
		Salle.Type.BOUTIQUE:
			vu["porte_boutique"] += 1
		Salle.Type.COFFRE:
			vu["porte_coffre"] += 1
			if salle.mimique:
				vu["mimique"] += 1
		Salle.Type.REPOS:
			vu["porte_repos"] += 1
	ecran.boutons_portes[index].pressed.emit()


## Un combat entier : mise au hasard, levier, relances au hasard, validation.
func _jouer_combat() -> void:
	var ecran: Control = current_scene
	if ecran.combat.ennemi.est_boss:
		vu["boss"] += 1
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
	if ecran.combat.etat == Combat.Etat.FUITE:
		vu["fuite"] += 1
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


## Le repos : se soigner si on est blessé, sinon dorer le premier symbole possible.
func _jouer_repos() -> void:
	var repos: Control = current_scene
	var partie: Partie = repos.partie
	if partie.soin_du_repos() > 0 and hasard.randi_range(0, 1) == 0:
		repos._se_reposer()
		vu["repos_soin"] += 1
	else:
		repos._choisir_symbole()
		await _attendre()
		for i in partie.sac.taille():
			if not partie.sac.symboles[i].doree:
				repos._dorer(i)
				vu["repos_dore"] += 1
				break
		if current_scene == repos and partie.ecran == Partie.Ecran.REPOS and partie.soin_du_repos() > 0:
			repos._se_reposer()
			vu["repos_soin"] += 1
	await _attendre()
