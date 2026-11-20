class_name MeubleMachine
extends PanelContainer
## Le meuble de la machine à sous : un corps rouge à cadre doré, un bandeau « JACKPOT » en néon entouré
## d'ampoules, une vitre avec une fenêtre par rouleau (ombrée en haut et en bas comme un vrai cylindre), des
## flèches rouges qui marquent la ligne de gain, puis la zone des mises et celle des actions (relance, continuer).
## Il ne connaît pas les règles : l'écran de combat remplit les cases (`cases`, `etiquettes`, `icones`) et
## pilote les rouleaux qui défilent (`fenetres`, `bandes`).

const HAUTEUR_CASE := 104
## Largeur d'un rouleau : 5 rouleaux, ou 6 avec le Sixième rouleau (un peu plus étroits).
const LARGEUR_CASE := 104
const LARGEUR_CASE_ETROITE := 88
## Côté (en pixels) de l'icône d'un rouleau, et nombre d'icônes dans la bande qui défile.
const ICONE_ROULEAU := 48
const NB_ICONES_BANDE := 4
const COULEUR_CORPS := Color("5b1220")
const COULEUR_OR := Habillage.COULEUR_OR
const COULEUR_OR_SOMBRE := Habillage.COULEUR_OR_SOMBRE
const COULEUR_VITRE := Color("0c0a10")
const COULEUR_PAPIER := Color("e8e0cc")
const COULEUR_ENSEIGNE := Color("ff4a3a")

## Le même fond pour tous les rouleaux qui tournent : un seul exemplaire.
static var _style_papier: StyleBoxFlat

var cases: Array[PanelContainer] = []
var etiquettes: Array[Label] = []
var icones: Array[TextureRect] = []
## Un rouleau qui tourne : sa fenêtre (masque ce qui dépasse) et les icônes de sa bande.
var fenetres: Array[Control] = []
var bandes: Array[Array] = []
## Les deux rangées d'ampoules de l'enseigne (au-dessus et au-dessous du titre).
var ampoules: Array[Ampoules] = []
## Les boutons de mise, centrés sous la vitre.
var zone_mises: HFlowContainer
## Sous les mises : les boutons de relance, ou « Continuer » (jamais les deux ensemble).
var zone_actions: VBoxContainer


## Construit le meuble pour `nb_cases` rouleaux rangés sur `colonnes` colonnes. `sur_case(evenement, index)` reçoit les
## clics sur un rouleau (choix du rouleau à garder avec le Cinquième as).
func construire(colonnes: int, nb_cases: int, sur_case: Callable) -> void:
	add_theme_stylebox_override("panel", _style(COULEUR_CORPS, COULEUR_OR, 5, 20, 12))
	var pile := VBoxContainer.new()
	pile.add_theme_constant_override("separation", 6)
	add_child(pile)

	pile.add_child(_construire_enseigne())

	# La vitre : flèche de la ligne de gain, rouleaux, flèche.
	var ligne_vitre := HBoxContainer.new()
	ligne_vitre.alignment = BoxContainer.ALIGNMENT_CENTER
	ligne_vitre.add_theme_constant_override("separation", 4)
	pile.add_child(ligne_vitre)
	ligne_vitre.add_child(_Fleche.new(false))
	var vitre := PanelContainer.new()
	vitre.add_theme_stylebox_override("panel", _style(COULEUR_VITRE, COULEUR_OR_SOMBRE, 4, 10, 8))
	ligne_vitre.add_child(vitre)
	ligne_vitre.add_child(_Fleche.new(true))

	var grille := GridContainer.new()
	grille.columns = colonnes
	grille.add_theme_constant_override("h_separation", 6)
	grille.add_theme_constant_override("v_separation", 6)
	vitre.add_child(grille)
	var largeur_case := LARGEUR_CASE if colonnes <= 5 else LARGEUR_CASE_ETROITE
	var ombre := _texture_cylindre()
	for i in nb_cases:
		grille.add_child(_construire_case(i, largeur_case, colonnes, ombre, sur_case))

	zone_mises = HFlowContainer.new()
	zone_mises.alignment = FlowContainer.ALIGNMENT_CENTER
	zone_mises.add_theme_constant_override("h_separation", 6)
	zone_mises.add_theme_constant_override("v_separation", 6)
	pile.add_child(zone_mises)

	zone_actions = VBoxContainer.new()
	zone_actions.add_theme_constant_override("separation", 4)
	pile.add_child(zone_actions)


## Les ampoules s'allument de la même façon sur tout le meuble.
func definir_ampoules(mode: Ampoules.Mode) -> void:
	for rangee in ampoules:
		rangee.mode = mode


func _construire_enseigne() -> PanelContainer:
	var enseigne := PanelContainer.new()
	enseigne.add_theme_stylebox_override("panel", _style(Color("14090d"), COULEUR_OR, 3, 10, 4))
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 0)
	enseigne.add_child(colonne)
	var ampoules_haut := Ampoules.new()
	var ampoules_bas := Ampoules.new()
	ampoules.assign([ampoules_haut, ampoules_bas])
	var titre := Label.new()
	titre.text = tr("JACKPOT DONJON")
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 28)
	titre.add_theme_color_override("font_color", COULEUR_OR)
	Habillage.contour(titre, COULEUR_ENSEIGNE.darkened(0.4), 4)
	Cartes.neon(titre, COULEUR_ENSEIGNE)
	colonne.add_child(ampoules_haut)
	colonne.add_child(titre)
	colonne.add_child(ampoules_bas)
	return enseigne


func _construire_case(index: int, largeur: int, colonnes: int, ombre: Texture2D, sur_case: Callable) -> PanelContainer:
	var case_grille := PanelContainer.new()
	case_grille.custom_minimum_size = Vector2(largeur, HAUTEUR_CASE)
	case_grille.gui_input.connect(sur_case.bind(index))
	var etiquette := Label.new()
	etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiquette.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiquette.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiquette.add_theme_font_size_override("font_size", 20 if colonnes <= 5 else 16)
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var contenu := VBoxContainer.new()
	contenu.alignment = BoxContainer.ALIGNMENT_CENTER
	contenu.add_theme_constant_override("separation", 0)
	contenu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icone := TextureRect.new()
	icone.custom_minimum_size = Vector2(ICONE_ROULEAU, ICONE_ROULEAU)
	icone.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenu.add_child(icone)
	contenu.add_child(etiquette)
	case_grille.add_child(contenu)

	# Le rouleau qui tourne : une fenêtre qui masque ce qui dépasse, et des icônes qui glissent dedans.
	var fenetre := Control.new()
	fenetre.clip_contents = true
	fenetre.visible = false
	fenetre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bande: Array = []
	for j in NB_ICONES_BANDE:
		var icone_bande := TextureRect.new()
		icone_bande.set_anchors_preset(Control.PRESET_TOP_WIDE)
		icone_bande.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icone_bande.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone_bande.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icone_bande.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icone_bande.modulate = Color(1, 1, 1, 0.85)
		fenetre.add_child(icone_bande)
		bande.append(icone_bande)
	case_grille.add_child(fenetre)

	# Par-dessus tout : l'ombre du cylindre (sombre en haut et en bas, claire au milieu).
	var cylindre := TextureRect.new()
	cylindre.texture = ombre
	cylindre.stretch_mode = TextureRect.STRETCH_SCALE
	cylindre.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cylindre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	case_grille.add_child(cylindre)

	cases.append(case_grille)
	etiquettes.append(etiquette)
	icones.append(icone)
	fenetres.append(fenetre)
	bandes.append(bande)
	return case_grille


## Le fond d'un rouleau qui tourne : du papier crème, comme les bandes d'un vrai rouleau.
static func style_papier() -> StyleBoxFlat:
	if _style_papier == null:
		_style_papier = StyleBoxFlat.new()
		_style_papier.set_corner_radius_all(6)
		_style_papier.bg_color = COULEUR_PAPIER
	return _style_papier


static func _style(fond: Color, bordure: Color, epaisseur: int, rayon: int, marge: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.border_color = bordure
	style.set_border_width_all(epaisseur)
	style.set_corner_radius_all(rayon)
	style.set_content_margin_all(marge)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	return style


static func _texture_cylindre() -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.width = 4
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	var degrade := Gradient.new()
	degrade.offsets = PackedFloat32Array([0.0, 0.28, 0.72, 1.0])
	degrade.colors = PackedColorArray([Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.6)])
	texture.gradient = degrade
	return texture


## Une flèche rouge qui marque la ligne de gain, de chaque côté de la vitre.
class _Fleche extends Control:
	var pointe_a_gauche: bool

	func _init(vers_la_gauche: bool) -> void:
		pointe_a_gauche = vers_la_gauche
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(16, 28)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var milieu := size.y / 2.0
		var pointe := Vector2(1, milieu) if pointe_a_gauche else Vector2(size.x - 1, milieu)
		var base_x := size.x - 1 if pointe_a_gauche else 1.0
		var triangle := PackedVector2Array([Vector2(base_x, milieu - 11), pointe, Vector2(base_x, milieu + 11)])
		draw_colored_polygon(triangle, Color("e0352b"))
		draw_polyline(PackedVector2Array([triangle[0], triangle[1], triangle[2], triangle[0]]), Habillage.COULEUR_OR, 2.0)
