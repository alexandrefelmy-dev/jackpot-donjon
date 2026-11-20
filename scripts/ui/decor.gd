class_name Decor
extends RefCounted
## Le décor commun à tous les écrans : une moquette de casino (shader `moquette`), parfois des rideaux de velours
## rouge sur les côtés (shader `rideau`), des bords sombres (vignette) pour que les cartes et les textes ressortent,
## et une frise d'ampoules en haut et en bas de l'écran. Tout est dessiné ici, sans fichier image.

const SHADER_MOQUETTE := "res://assets/shaders/moquette.gdshader"
const SHADER_RIDEAU := "res://assets/shaders/rideau.gdshader"
## Taille d'un motif de la moquette à l'écran, et largeur d'un rideau.
const TAILLE_MOTIF := 72.0
const LARGEUR_RIDEAU := 84.0
## Noirceur des bords de l'écran (0 = aucune vignette, 1 = noir complet dans les coins).
const NOIRCEUR_BORDS := 0.7

static var _shader_moquette: Shader
static var _shader_rideau: Shader


## Ajoute à `parent` (en plein écran, sous tout le reste) l'aplat `couleur`, la moquette, les rideaux si
## `rideaux`, la vignette et la frise d'ampoules.
static func ajouter(parent: Control, couleur: Color, rideaux: bool = false) -> void:
	var fond := ColorRect.new()
	fond.name = "Fond"
	fond.color = couleur
	_plein_ecran(fond)
	parent.add_child(fond)

	var sol := ColorRect.new()
	sol.name = "Sol"
	if _shader_moquette == null:
		_shader_moquette = load(SHADER_MOQUETTE) as Shader
	var materiau := ShaderMaterial.new()
	materiau.shader = _shader_moquette
	sol.material = materiau
	_plein_ecran(sol)
	parent.add_child(sol)
	# Les losanges restent carrés quelle que soit la taille de l'écran.
	sol.resized.connect(_regler_moquette.bind(sol))
	_regler_moquette(sol)

	if rideaux:
		parent.add_child(_rideau(true))
		parent.add_child(_rideau(false))

	var vignette := TextureRect.new()
	vignette.name = "Vignette"
	vignette.texture = _texture_vignette()
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plein_ecran(vignette)
	parent.add_child(vignette)

	for en_haut in [true, false]:
		var frise := Ampoules.new()
		frise.name = "FriseHaut" if en_haut else "FriseBas"
		frise.set_anchors_preset(Control.PRESET_TOP_WIDE if en_haut else Control.PRESET_BOTTOM_WIDE)
		frise.offset_top = 2.0 if en_haut else -16.0
		frise.offset_bottom = 16.0 if en_haut else -2.0
		parent.add_child(frise)


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


static func _regler_moquette(sol: ColorRect) -> void:
	var materiau := sol.material as ShaderMaterial
	if materiau != null and sol.size.x > 0.0:
		materiau.set_shader_parameter("repetitions", sol.size / TAILLE_MOTIF)


## Un rideau de velours collé au bord gauche ou droit de l'écran.
static func _rideau(a_gauche: bool) -> ColorRect:
	var rideau := ColorRect.new()
	rideau.name = "RideauGauche" if a_gauche else "RideauDroit"
	if _shader_rideau == null:
		_shader_rideau = load(SHADER_RIDEAU) as Shader
	var materiau := ShaderMaterial.new()
	materiau.shader = _shader_rideau
	materiau.set_shader_parameter("cote_gauche", a_gauche)
	rideau.material = materiau
	rideau.set_anchors_preset(Control.PRESET_LEFT_WIDE if a_gauche else Control.PRESET_RIGHT_WIDE)
	if a_gauche:
		rideau.offset_right = LARGEUR_RIDEAU
	else:
		rideau.offset_left = -LARGEUR_RIDEAU
	rideau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rideau


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
