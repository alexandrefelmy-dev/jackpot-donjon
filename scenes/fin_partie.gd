extends Control
## Écran de fin de partie : victoire (boss vaincu) ou game over, les jetons d'âme gagnés et la
## malédiction reçue ou effacée, puis Rejouer ou le Comptoir du Croupier.

const COULEUR_FOND := Color("1b1a24")
const COULEUR_VICTOIRE := Color("7ddc7d")
const COULEUR_DEFAITE := Color("ff6b6b")


var partie: Partie
var texte_jetons: Label
var texte_malediction: Label
var bouton_rejouer: Button
var bouton_comptoir: Button
var bouton_menu: Button


func _ready() -> void:
	partie = GameState.partie
	# Les jetons et la malédiction sont inscrits au profil une seule fois, même si l'écran est rechargé.
	GameState.demarrer()
	Musique.jouer(&"")
	# Pas de jingle ici : celui de la victoire ou de la défaite a déjà sonné à la fin du dernier combat.
	GameState.enregistrer_bilan()
	_construire_interface()


func _rejouer() -> void:
	GameState.nouvelle_partie()
	GameState.aller_a_suivant()


func _aller_au_menu() -> void:
	GameState.vers_le_menu()


func _aller_au_comptoir() -> void:
	GameState.vers_le_comptoir()


func _construire_interface() -> void:
	Cartes.ajouter_fond(self, COULEUR_FOND, true)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 16)
	centre.add_child(colonne)

	var victoire := partie.etat == Partie.Etat.VICTOIRE
	var titre := Label.new()
	titre.text = tr("VICTOIRE !") if victoire else tr("GAME OVER")
	titre.add_theme_font_size_override("font_size", 56)
	titre.add_theme_color_override("font_color", COULEUR_VICTOIRE if victoire else COULEUR_DEFAITE)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Cartes.neon(titre, COULEUR_VICTOIRE if victoire else COULEUR_DEFAITE)
	colonne.add_child(titre)

	var sous_titre := Label.new()
	if victoire:
		sous_titre.text = tr("%s est vaincu : tu as dévalisé le casino maudit !") % tr(partie.donjon.boss_de(Donjon.NB_ETAGES).nom)
	elif partie.est_combat_de_boss():
		sous_titre.text = tr("Tu es tombé face au boss de l'étage %d. Le donjon recommence à zéro.") % partie.etage
	else:
		sous_titre.text = tr("Tu es tombé à l'étage %d, salle %d. Le donjon recommence à zéro.") % [partie.etage, partie.pas]
	sous_titre.add_theme_font_size_override("font_size", 22)
	sous_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(sous_titre)

	var stats := Label.new()
	stats.text = "\n".join([
		tr("Salles franchies : %d   Boss vaincus : %d / %d") % [partie.salles_franchies, partie.boss_vaincus, Donjon.NB_ETAGES],
		tr("Or gagné : %d") % partie.or_total,
		tr("Symboles dans le sac : %d") % partie.sac.taille(),
		tr("Graine : %d") % partie.graine + "     " + Version.texte(),
	])
	stats.add_theme_font_size_override("font_size", 20)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(stats)

	# Ce que la partie rapporte au profil (rien sans profil : tests et outils).
	if not partie.bilan.is_empty():
		texte_jetons = Label.new()
		texte_jetons.text = tr("Jetons d'âme gagnés : %d   (total : %d)") % [int(partie.bilan["jetons"]), GameState.profil.jetons]
		texte_jetons.add_theme_font_size_override("font_size", 22)
		texte_jetons.add_theme_color_override("font_color", Cartes.COULEUR_JETONS)
		texte_jetons.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		colonne.add_child(texte_jetons)
		var lignes := PackedStringArray()
		var recue: StringName = partie.bilan["malediction_recue"]
		if recue != &"":
			lignes.append(tr("Malédiction reçue : %s") % Maledictions.texte(recue))
		var effacees: Array = partie.bilan["maledictions_effacees"]
		if not effacees.is_empty():
			var noms := PackedStringArray()
			for id: StringName in effacees:
				noms.append(Maledictions.nom(id))
			lignes.append(tr("Malédiction effacée : %s") % ", ".join(noms))
		if not lignes.is_empty():
			texte_malediction = Label.new()
			texte_malediction.text = "\n".join(lignes)
			texte_malediction.add_theme_font_size_override("font_size", 18)
			texte_malediction.add_theme_color_override("font_color", Cartes.COULEUR_MALEDICTION)
			texte_malediction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			colonne.add_child(texte_malediction)

	var boutons := HBoxContainer.new()
	boutons.add_theme_constant_override("separation", 16)
	boutons.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_child(boutons)
	bouton_rejouer = _creer_bouton(tr("Rejouer"), _rejouer)
	boutons.add_child(bouton_rejouer)
	bouton_comptoir = _creer_bouton(tr("Comptoir du Croupier"), _aller_au_comptoir)
	boutons.add_child(bouton_comptoir)
	bouton_menu = _creer_bouton(tr("Menu"), _aller_au_menu)
	bouton_menu.custom_minimum_size = Vector2(160, 56)
	boutons.add_child(bouton_menu)


func _creer_bouton(texte: String, action: Callable) -> Button:
	return Cartes.creer_bouton(texte, Vector2(240, 56), action)
