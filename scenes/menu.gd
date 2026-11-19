extends Control
## Le menu principal : c'est l'écran qui s'ouvre au lancement du jeu. Jouer lance une partie avec le
## profil du joueur ; le Comptoir du Croupier et les Options s'ouvrent depuis ici ; Quitter ferme le jeu.

const COULEUR_FOND := Color("1b1a24")
const COULEUR_OR := Color("ffd34d")
const COULEUR_ROUGE := Color("ff5a5a")

var bouton_jouer: Button
var bouton_comptoir: Button
var bouton_options: Button
var bouton_quitter: Button
var texte_titre: Label
var texte_version: Label


func _ready() -> void:
	GameState.demarrer()
	GameState.charger_profil()
	GameState.en_partie = false
	Musique.jouer_menu()
	_construire_interface()


func _jouer() -> void:
	bouton_jouer.disabled = true
	Son.jouer(&"clic")
	GameState.nouvelle_partie()
	GameState.aller_a_suivant()


func _comptoir() -> void:
	Son.jouer(&"clic")
	GameState.vers_le_comptoir()


func _options() -> void:
	Son.jouer(&"clic")
	GameState.aller_a(GameState.SCENE_OPTIONS)


func _quitter() -> void:
	(Engine.get_main_loop() as SceneTree).quit()


func _construire_interface() -> void:
	Cartes.ajouter_fond(self, COULEUR_FOND)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 14)
	centre.add_child(colonne)

	texte_titre = Label.new()
	texte_titre.text = tr("JACKPOT DONJON")
	texte_titre.add_theme_font_size_override("font_size", 72)
	texte_titre.add_theme_color_override("font_color", COULEUR_OR)
	texte_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texte_titre.add_theme_color_override("font_outline_color", Color("7a1f1f"))
	texte_titre.add_theme_constant_override("outline_size", 8)
	Cartes.neon(texte_titre, COULEUR_ROUGE)
	colonne.add_child(texte_titre)

	var sous_titre := Label.new()
	sous_titre.text = tr("Une machine à sous. Un donjon. Un seul coup de levier.")
	sous_titre.add_theme_font_size_override("font_size", 20)
	sous_titre.add_theme_color_override("font_color", COULEUR_ROUGE)
	sous_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(sous_titre)

	var troupe := HBoxContainer.new()
	troupe.alignment = BoxContainer.ALIGNMENT_CENTER
	troupe.add_theme_constant_override("separation", 40)
	colonne.add_child(troupe)
	for prefixe in ["goblin_idle_anim", "knight_m_idle_anim", "skelet_idle_anim"]:
		var image := ImageAnimee.new()
		image.definir(Images.cadres(prefixe, 96), 0.22)
		troupe.add_child(image)

	bouton_jouer = _creer_bouton(tr("Jouer"), _jouer)
	bouton_comptoir = _creer_bouton(tr("Comptoir du Croupier"), _comptoir)
	bouton_options = _creer_bouton(tr("Options"), _options)
	bouton_quitter = _creer_bouton(tr("Quitter"), _quitter)
	for bouton in [bouton_jouer, bouton_comptoir, bouton_options, bouton_quitter]:
		colonne.add_child(bouton)

	texte_version = Label.new()
	texte_version.text = Version.texte()
	texte_version.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	texte_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(texte_version)


func _creer_bouton(texte: String, action: Callable) -> Button:
	var bouton := Cartes.creer_bouton(texte, Vector2(360, 56), action, 22)
	bouton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return bouton
