class_name PleinEcran
extends CanvasLayer
## Le plein écran, disponible sur tous les écrans : un petit bouton en haut à droite et le raccourci
## Alt+Entrée. Ce nœud est ajouté une seule fois à la racine par GameState.demarrer() et survit aux
## changements d'écran (ce n'est pas un autoload : voir la note de GameState). Le choix est enregistré
## avec les options ; la case « Plein écran » des Options se met à jour grâce au signal `change`.

## Émis après chaque bascule, avec le nouvel état.
signal change(plein_ecran: bool)

static var instance: PleinEcran

const TAILLE_BOUTON := 44
const MARGE := 8

var bouton: Button


## Ajoute le bouton et le raccourci à la racine, une seule fois (plus tard dans l'image : la racine est occupée
## pendant le _ready() d'un écran).
static func installer() -> void:
	if is_instance_valid(instance):
		return
	instance = PleinEcran.new()
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(instance)


## Bascule le plein écran : l'option est changée, appliquée à la fenêtre et enregistrée.
static func basculer() -> void:
	GameState.charger_options()
	GameState.options.plein_ecran = not GameState.options.plein_ecran
	GameState.appliquer_options()
	GameState.sauver_options()
	if is_instance_valid(instance):
		instance.change.emit(GameState.options.plein_ecran)


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	bouton = Button.new()
	bouton.focus_mode = Control.FOCUS_NONE  # sinon Espace ou Entrée « cliquerait » ce bouton
	bouton.icon = _icone_coins()
	bouton.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bouton.tooltip_text = tr("Plein écran (Alt+Entrée)")
	Cartes.habiller_bouton_mise(bouton)
	bouton.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bouton.offset_left = -(TAILLE_BOUTON + MARGE)
	bouton.offset_top = MARGE
	bouton.offset_right = -MARGE
	bouton.offset_bottom = MARGE + TAILLE_BOUTON
	bouton.pressed.connect(basculer)
	add_child(bouton)


func _input(evenement: InputEvent) -> void:
	var touche := evenement as InputEventKey
	if touche == null or not touche.pressed or touche.echo or not touche.alt_pressed:
		return
	if touche.keycode == KEY_ENTER or touche.keycode == KEY_KP_ENTER:
		basculer()
		# Sans cela, Alt+Entrée tirerait aussi le levier (Entrée est une touche du levier).
		get_viewport().set_input_as_handled()


## L'icône : quatre coins, comme les boutons « plein écran » habituels (dessinée ici, pas de fichier).
static func _icone_coins() -> ImageTexture:
	var taille := 20
	var longueur := 7
	var image := Image.create_empty(taille, taille, false, Image.FORMAT_RGBA8)
	for i in longueur:
		for epaisseur in 2:
			for coin in [Vector2i(2, 2), Vector2i(taille - 3, 2), Vector2i(2, taille - 3), Vector2i(taille - 3, taille - 3)]:
				var sens_x := 1 if coin.x < taille / 2 else -1
				var sens_y := 1 if coin.y < taille / 2 else -1
				image.set_pixel(coin.x + sens_x * i, coin.y + sens_y * epaisseur, Color.WHITE)
				image.set_pixel(coin.x + sens_x * epaisseur, coin.y + sens_y * i, Color.WHITE)
	return ImageTexture.create_from_image(image)
