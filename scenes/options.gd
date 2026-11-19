extends Control
## Les options : volumes de la musique et des effets, plein écran, accessibilité (réduire les tremblements
## et les flashs), crédits. Chaque changement s'applique tout de suite et s'enregistre.

const COULEUR_FOND := Color("1b1a24")

var options: Options
var curseur_musique: HSlider
var curseur_effets: HSlider
var texte_musique: Label
var texte_effets: Label
var case_plein_ecran: CheckBox
var case_tremblements: CheckBox
var case_flashs: CheckBox
var bouton_credits: Button
var bouton_retour: Button
var texte_credits: Label
var texte_message: Label


func _ready() -> void:
	GameState.demarrer()
	GameState.charger_options()
	options = GameState.options
	Musique.jouer(Musique.piste_pour(1, false))
	_construire_interface()
	_rafraichir()


func _unhandled_input(evenement: InputEvent) -> void:
	if evenement.is_action_pressed(Entrees.RETOUR):
		_retour()


func _retour() -> void:
	Son.jouer(&"clic")
	GameState.aller_a(GameState.SCENE_MENU)


## Un réglage a changé : on l'applique, on l'enregistre, on l'affiche.
func _changer() -> void:
	options.volume_musique = curseur_musique.value / 100.0
	options.volume_effets = curseur_effets.value / 100.0
	options.plein_ecran = case_plein_ecran.button_pressed
	options.reduire_tremblements = case_tremblements.button_pressed
	options.reduire_flashs = case_flashs.button_pressed
	GameState.appliquer_options()
	texte_message.text = "" if GameState.sauver_options() else tr("Les options n'ont pas pu être enregistrées.")
	_rafraichir()


## Un petit « clic » à la fin du glissement du curseur des effets, pour entendre le niveau choisi.
func _curseur_effets_relache(_valeur_changee: bool) -> void:
	Son.jouer(&"clic")


func _basculer_credits() -> void:
	texte_credits.visible = not texte_credits.visible


func _rafraichir() -> void:
	texte_musique.text = tr("Musique : %d %%") % roundi(options.volume_musique * 100.0)
	texte_effets.text = tr("Effets : %d %%") % roundi(options.volume_effets * 100.0)


func _construire_interface() -> void:
	var fond := ColorRect.new()
	fond.color = COULEUR_FOND
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)

	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for cote in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marge.add_theme_constant_override(cote, 40)
	add_child(marge)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	marge.add_child(page)

	var titre := Label.new()
	titre.text = tr("Options")
	titre.add_theme_font_size_override("font_size", 40)
	page.add_child(titre)

	texte_musique = Label.new()
	texte_musique.add_theme_font_size_override("font_size", 22)
	page.add_child(texte_musique)
	curseur_musique = _creer_curseur(options.volume_musique)
	page.add_child(curseur_musique)

	texte_effets = Label.new()
	texte_effets.add_theme_font_size_override("font_size", 22)
	page.add_child(texte_effets)
	curseur_effets = _creer_curseur(options.volume_effets)
	curseur_effets.drag_ended.connect(_curseur_effets_relache)
	page.add_child(curseur_effets)

	case_plein_ecran = _creer_case(tr("Plein écran"), options.plein_ecran)
	case_tremblements = _creer_case(tr("Réduire les tremblements d'écran (et les arrêts sur image)"), options.reduire_tremblements)
	case_flashs = _creer_case(tr("Réduire les flashs (et le pulsement des néons)"), options.reduire_flashs)
	for case in [case_plein_ecran, case_tremblements, case_flashs]:
		page.add_child(case)

	var bas := HBoxContainer.new()
	bas.add_theme_constant_override("separation", 12)
	page.add_child(bas)
	bouton_credits = _creer_bouton(tr("Crédits"), _basculer_credits)
	bouton_retour = _creer_bouton(tr("Retour"), _retour)
	bas.add_child(bouton_credits)
	bas.add_child(bouton_retour)

	texte_message = Label.new()
	texte_message.add_theme_color_override("font_color", Color("ff8a8a"))
	page.add_child(texte_message)

	texte_credits = Label.new()
	texte_credits.text = tr("Sons : Kenney (casino-audio, CC0) et sons générés pour le jeu.\nMusiques (CC0, OpenGameArt) : yd, TokyoGeisha, XCVG.\nTous les détails et les licences : docs/CREDITS.md")
	texte_credits.add_theme_font_size_override("font_size", 16)
	texte_credits.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	texte_credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte_credits.custom_minimum_size = Vector2(900, 0)
	texte_credits.visible = false
	page.add_child(texte_credits)


func _creer_curseur(valeur: float) -> HSlider:
	var curseur := HSlider.new()
	curseur.min_value = 0
	curseur.max_value = 100
	curseur.step = 5
	curseur.value = roundi(valeur * 100.0)
	curseur.custom_minimum_size = Vector2(520, 28)
	curseur.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	curseur.focus_mode = Control.FOCUS_NONE
	curseur.value_changed.connect(func(_v: float) -> void: _changer())
	return curseur


func _creer_case(texte: String, cochee: bool) -> CheckBox:
	var case := CheckBox.new()
	case.text = texte
	case.button_pressed = cochee
	case.add_theme_font_size_override("font_size", 20)
	case.focus_mode = Control.FOCUS_NONE
	case.toggled.connect(func(_v: bool) -> void: _changer())
	return case


func _creer_bouton(texte: String, action: Callable) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.custom_minimum_size = Vector2(200, 48)
	bouton.focus_mode = Control.FOCUS_NONE
	bouton.pressed.connect(action)
	return bouton
