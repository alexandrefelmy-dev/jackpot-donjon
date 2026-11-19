extends Control
## Écran de fin de partie : victoire (boss vaincu) ou game over, puis Rejouer.

const COULEUR_FOND := Color("1b1a24")
const COULEUR_VICTOIRE := Color("7ddc7d")
const COULEUR_DEFAITE := Color("ff6b6b")

var partie: Partie


func _ready() -> void:
	partie = GameState.partie
	_construire_interface()


func _rejouer() -> void:
	GameState.nouvelle_partie()
	GameState.aller_a(GameState.SCENE_COMBAT)


func _construire_interface() -> void:
	var fond := ColorRect.new()
	fond.color = COULEUR_FOND
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)

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
	colonne.add_child(titre)

	var sous_titre := Label.new()
	if victoire:
		sous_titre.text = tr("Le Rat-Croupier est vaincu : tu as traversé les Cryptes !")
	else:
		sous_titre.text = tr("Tu es tombé au combat %d. Le donjon recommence à zéro.") % partie.numero_combat
	sous_titre.add_theme_font_size_override("font_size", 22)
	sous_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(sous_titre)

	var stats := Label.new()
	stats.text = "\n".join([
		tr("Combats gagnés : %d / %d") % [partie.combats_gagnes, Partie.NB_COMBATS_NORMAUX + 1],
		tr("Or gagné : %d") % partie.or_total,
		tr("Symboles dans le sac : %d") % partie.sac.taille(),
		tr("Graine : %d     %s") % [partie.graine, Version.texte()],
	])
	stats.add_theme_font_size_override("font_size", 20)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(stats)

	var bouton := Button.new()
	bouton.text = tr("Rejouer")
	bouton.custom_minimum_size = Vector2(240, 56)
	bouton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bouton.focus_mode = Control.FOCUS_NONE
	bouton.pressed.connect(_rejouer)
	colonne.add_child(bouton)
