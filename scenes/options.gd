extends Control
## Les options : volumes de la musique et des effets, plein écran, accessibilité (réduire les tremblements
## et les flashs), crédits. Chaque changement s'applique tout de suite et s'enregistre.

const COULEUR_FOND := Color("1b1a24")

var options: Options
var curseur_musique: HSlider
var curseur_effets: HSlider
var texte_musique: Label
var texte_effets: Label
var case_plein_ecran: Button
var case_tremblements: Button
var case_flashs: Button
var bouton_credits: Button
var bouton_retour: Button
var texte_credits: Label
var texte_message: Label
var titre_options: Label
const DELAI_SAUVEGARDE := 0.5
## Écrit le fichier une demi-seconde après le dernier changement (relancé à chaque cran de curseur).
var _minuteur_sauvegarde: Timer


func _ready() -> void:
	GameState.demarrer()
	GameState.charger_options()
	options = GameState.options
	_minuteur_sauvegarde = Timer.new()
	_minuteur_sauvegarde.one_shot = true
	_minuteur_sauvegarde.wait_time = DELAI_SAUVEGARDE
	_minuteur_sauvegarde.timeout.connect(_sauvegarder_maintenant)
	add_child(_minuteur_sauvegarde)
	Musique.jouer_menu()
	_construire_interface()
	_rafraichir()
	# Alt+Entrée ou le bouton ⛶ peuvent changer le plein écran pendant qu'on est ici : la case suit.
	if is_instance_valid(PleinEcran.instance):
		PleinEcran.instance.change.connect(_plein_ecran_change)


func _plein_ecran_change(plein_ecran: bool) -> void:
	case_plein_ecran.set_pressed_no_signal(plein_ecran)
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
	if PleinEcran.est_integre() and case_plein_ecran.button_pressed != options.plein_ecran:
		# Fenêtre intégrée de l'éditeur : le plein écran est refusé, la case revient à l'état réel.
		case_plein_ecran.set_pressed_no_signal(options.plein_ecran)
		PleinEcran.avertir()
	options.plein_ecran = case_plein_ecran.button_pressed
	options.reduire_tremblements = case_tremblements.button_pressed
	options.reduire_flashs = case_flashs.button_pressed
	Cartes.regler_neon(titre_options)
	GameState.appliquer_options()
	_minuteur_sauvegarde.start()
	_rafraichir()


func _sauvegarder_maintenant() -> void:
	texte_message.text = "" if GameState.sauver_options() else tr("Les options n'ont pas pu être enregistrées.")


## Un changement encore en attente d'écriture quand on quitte l'écran, ou quand on ferme la fenêtre, est écrit
## tout de suite.
func _exit_tree() -> void:
	_sauvegarder_si_en_attente()


func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_WM_CLOSE_REQUEST:
		_sauvegarder_si_en_attente()


func _sauvegarder_si_en_attente() -> void:
	if _minuteur_sauvegarde != null and not _minuteur_sauvegarde.is_stopped():
		_minuteur_sauvegarde.stop()
		GameState.sauver_options()


## Un petit « clic » à la fin du glissement du curseur des effets, pour entendre le niveau choisi.
func _curseur_effets_relache(_valeur_changee: bool) -> void:
	Son.jouer(&"clic")


func _basculer_credits() -> void:
	texte_credits.visible = not texte_credits.visible


func _rafraichir() -> void:
	texte_musique.text = tr("Musique : %d %%") % roundi(options.volume_musique * 100.0)
	texte_effets.text = tr("Effets : %d %%") % roundi(options.volume_effets * 100.0)


func _construire_interface() -> void:
	Cartes.ajouter_fond(self, COULEUR_FOND)

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
	Habillage.titre(titre)
	titre_options = titre
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


## Une case à cocher : un bouton à bascule, cadre doré quand il est actif, et « oui » / « non » écrit
## en toutes lettres (une case dessinée par défaut est presque invisible sur ce fond sombre).
func _creer_case(texte: String, cochee: bool) -> Button:
	var case := Button.new()
	case.toggle_mode = true
	case.button_pressed = cochee
	case.alignment = HORIZONTAL_ALIGNMENT_LEFT
	case.custom_minimum_size = Vector2(0, 42)
	case.add_theme_font_size_override("font_size", 20)
	case.focus_mode = Control.FOCUS_NONE
	Cartes.habiller_bouton_mise(case)
	var mettre_a_jour := func(active: bool) -> void:
		case.text = "%s : %s" % [texte, tr("oui") if active else tr("non")]
	mettre_a_jour.call(cochee)
	case.toggled.connect(func(active: bool) -> void:
		mettre_a_jour.call(active)
		_changer())
	return case


func _creer_bouton(texte: String, action: Callable) -> Button:
	return Cartes.creer_bouton(texte, Vector2(200, 48), action)
