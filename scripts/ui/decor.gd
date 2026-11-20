class_name Decor
extends RefCounted
## Le décor commun à tous les écrans : un sol de donjon (dalles du pack 0x72, agrandies sans flou), assombri par
## des bords sombres (vignette) pour que les cartes et les textes ressortent. Tout est dessiné ici, sans fichier.

## Taille d'une dalle à l'écran (le pack les fait en 16 px : ×4, facteur entier).
const TAILLE_DALLE := 64
## Part de la dalle visible : assez pour voir le sol, assez peu pour que le texte reste lisible.
const OPACITE_SOL := 0.2
## Noirceur des bords de l'écran (0 = aucune vignette, 1 = noir complet dans les coins).
const NOIRCEUR_BORDS := 0.7


## Ajoute à `parent` (en plein écran, sous tout le reste) l'aplat `couleur`, le sol et la vignette.
static func ajouter(parent: Control, couleur: Color) -> void:
	var fond := ColorRect.new()
	fond.name = "Fond"
	fond.color = couleur
	_plein_ecran(fond)
	parent.add_child(fond)

	var dalle := Images.icone("floor_1", TAILLE_DALLE)
	if dalle != null:
		var sol := TextureRect.new()
		sol.name = "Sol"
		sol.texture = dalle
		sol.stretch_mode = TextureRect.STRETCH_TILE
		sol.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sol.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sol.modulate = Color(1, 1, 1, OPACITE_SOL)
		_plein_ecran(sol)
		parent.add_child(sol)

	var vignette := TextureRect.new()
	vignette.name = "Vignette"
	vignette.texture = _texture_vignette()
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plein_ecran(vignette)
	parent.add_child(vignette)


## Un halo de lumière doux (dégradé radial, transparent sur les bords) à poser derrière un personnage.
static func halo(couleur: Color) -> TextureRect:
	var texture := GradientTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var degrade := Gradient.new()
	degrade.offsets = PackedFloat32Array([0.0, 1.0])
	degrade.colors = PackedColorArray([couleur, Color(couleur, 0.0)])
	texture.gradient = degrade
	var image := TextureRect.new()
	image.name = "Halo"
	image.texture = texture
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


static func _texture_vignette() -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var degrade := Gradient.new()
	# Clair au centre, de plus en plus sombre vers les coins (le rayon 1.0 est atteint au milieu des bords).
	degrade.offsets = PackedFloat32Array([0.45, 1.0])
	degrade.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, NOIRCEUR_BORDS)])
	texture.gradient = degrade
	return texture


static func _plein_ecran(noeud: Control) -> void:
	noeud.set_anchors_preset(Control.PRESET_FULL_RECT)
	noeud.mouse_filter = Control.MOUSE_FILTER_IGNORE
