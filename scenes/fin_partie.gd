extends Control
## Écran de fin de partie : victoire (boss vaincu) ou game over, les jetons d'âme gagnés et la
## malédiction reçue ou effacée, puis Rejouer ou le Comptoir du Croupier.

const COULEUR_FOND := Color("1b1a24")
const COULEUR_VICTOIRE := Color("7ddc7d")
const COULEUR_DEFAITE := Color("ff6b6b")


var partie: Partie
## Le panneau des statistiques, une case par statistique (texte et record battu), et la ligne des records.
var panneau_stats: PanelContainer
var cases_stats: Array[Label] = []
var texte_records: Label
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
	colonne.add_theme_constant_override("separation", 10)
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
		sous_titre.text = tr("Tu es tombé à l'étage %d, combat %d. Le donjon recommence à zéro.") % [partie.etage, partie.pas]
	sous_titre.add_theme_font_size_override("font_size", 22)
	sous_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(sous_titre)

	_construire_statistiques(colonne)

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


## Les statistiques de la partie, en deux colonnes dans un panneau ; une statistique qui bat un record du profil
## est en or, avec « record ! ». Dessous : les records du profil, et la graine.
func _construire_statistiques(colonne: VBoxContainer) -> void:
	var records_battus: Array = partie.bilan.get("records_battus", [])
	panneau_stats = PanelContainer.new()
	panneau_stats.add_theme_stylebox_override("panel", Habillage.panneau())
	colonne.add_child(panneau_stats)
	var grille := GridContainer.new()
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", 48)
	grille.add_theme_constant_override("v_separation", 4)
	panneau_stats.add_child(grille)
	for ligne in _lignes_de_stats():
		var etiquette := Label.new()
		etiquette.text = ligne["texte"]
		etiquette.add_theme_font_size_override("font_size", 18)
		if ligne["record"] in records_battus:
			etiquette.text = tr("%s  — record !") % etiquette.text
			etiquette.add_theme_color_override("font_color", Habillage.COULEUR_OR)
		grille.add_child(etiquette)
		cases_stats.append(etiquette)

	if GameState.profil != null:
		var profil := GameState.profil
		texte_records = Label.new()
		texte_records.text = profil.texte_records()
		texte_records.add_theme_font_size_override("font_size", 16)
		texte_records.add_theme_color_override("font_color", Habillage.COULEUR_DISCRETE)
		texte_records.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		colonne.add_child(texte_records)

	var graine := Label.new()
	graine.text = tr("Graine : %d") % partie.graine + "     " + Version.texte()
	graine.add_theme_font_size_override("font_size", 14)
	graine.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	graine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(graine)


## Les statistiques à montrer : { "texte", "record" } (le nom du record du profil que cette statistique peut battre, ou &"").
func _lignes_de_stats() -> Array[Dictionary]:
	var stats := partie.stats
	var combo := tr("Plus long combo : %d symboles") % stats.plus_long_combo if stats.plus_long_combo > 0 \
			else tr("Plus long combo : aucun")
	return [
		{"texte": tr("Étage atteint : %d") % partie.etage, "record": &""},
		{"texte": tr("Salles franchies : %d (boss : %d / %d)") % [partie.salles_franchies, partie.boss_vaincus, Donjon.NB_ETAGES], "record": &"salles"},
		{"texte": tr("Combats gagnés : %d") % partie.combats_gagnes, "record": &""},
		{"texte": tr("Tours joués : %d") % stats.tours_joues, "record": &""},
		{"texte": tr("Dégâts infligés : %d") % stats.degats_infliges, "record": &"degats"},
		{"texte": combo, "record": &"combo"},
		{"texte": tr("Jackpots : %d") % stats.jackpots, "record": &"jackpots"},
		{"texte": tr("Mises gagnées : %d / %d") % [stats.mises_gagnees, stats.mises_jouees], "record": &""},
		{"texte": tr("Or : %d (dépensé : %d)") % [partie.or_total, stats.or_depense], "record": &""},
		{"texte": tr("Symboles dans le sac : %d") % partie.sac.taille(), "record": &""},
	]


func _creer_bouton(texte: String, action: Callable) -> Button:
	return Cartes.creer_bouton(texte, Vector2(240, 56), action)
