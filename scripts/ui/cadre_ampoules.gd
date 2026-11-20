class_name CadreAmpoules
extends Control
## Un cadre d'ampoules qui suit le contour d'une porte cintrée (un arc en haut, des angles arrondis en bas), à poser
## par-dessus un bouton. Elles clignotent une sur deux au repos et se mettent à courir quand le bouton est survolé.
## « Réduire les flashs » les fige. Pur affichage : le clic passe à travers.

const ECART := 22.0
const RAYON := 4.5
const MARGE := 9.0

## Rayon de l'arc du haut (une demi-largeur : une arche complète) et des angles du bas.
var rayon_haut: float = 160.0
var rayon_bas: float = 16.0

var _ampoules: PackedVector2Array = PackedVector2Array()
var _temps: float = 0.0
var _etat: int = 0
var _course: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	resized.connect(_recalculer)
	_recalculer()


func _process(delta: float) -> void:
	var bouton := get_parent() as BaseButton
	_course = bouton != null and bouton.is_hovered() and not bouton.disabled
	_temps += delta
	var nouvel_etat := int(_temps * (12.0 if _course else 2.0))
	if nouvel_etat != _etat:
		_etat = nouvel_etat
		queue_redraw()


func _recalculer() -> void:
	_ampoules = positions_des_ampoules(size, rayon_haut, rayon_bas, MARGE, ECART)
	queue_redraw()


func _draw() -> void:
	var fixe := Impacts.flashs_reduits()
	for i in _ampoules.size():
		var allumee := (i + _etat) % 3 == 0 if _course else (i + _etat) % 2 == 0
		if fixe:
			allumee = i % 2 == 0
		Ampoules.dessiner_ampoule(self, _ampoules[i], RAYON, i, allumee)


## Les positions des ampoules, régulièrement espacées (`ecart` pixels) le long du contour d'un rectangle de
## `taille` dont les angles du haut ont le rayon `rayon_haut` et ceux du bas `rayon_bas`, à `marge` du bord.
static func positions_des_ampoules(taille: Vector2, rayon_haut: float, rayon_bas: float, marge: float, ecart: float) -> PackedVector2Array:
	var largeur := taille.x - 2.0 * marge
	var hauteur := taille.y - 2.0 * marge
	if largeur <= 0.0 or hauteur <= 0.0:
		return PackedVector2Array()
	var rh := minf(rayon_haut, minf(largeur / 2.0, hauteur - rayon_bas))
	var rb := minf(rayon_bas, minf(largeur / 2.0, hauteur - rh))
	rh = maxf(rh, 0.0)
	rb = maxf(rb, 0.0)
	var gauche := marge
	var droite := taille.x - marge
	var haut := marge
	var bas := taille.y - marge

	# Le contour, en sens horaire depuis l'angle en bas à gauche, échantillonné en petits segments.
	var contour := PackedVector2Array()
	_arc(contour, Vector2(gauche + rb, bas - rb), rb, PI / 2.0, PI)  # angle bas gauche
	_arc(contour, Vector2(gauche + rh, haut + rh), rh, PI, 1.5 * PI)  # arc haut gauche
	_arc(contour, Vector2(droite - rh, haut + rh), rh, 1.5 * PI, 2.0 * PI)  # arc haut droit
	_arc(contour, Vector2(droite - rb, bas - rb), rb, 0.0, PI / 2.0)  # angle bas droit
	contour.append(contour[0])

	# On pose une ampoule tous les `ecart` pixels de longueur de contour.
	var ampoules := PackedVector2Array()
	var reste := 0.0
	ampoules.append(contour[0])
	for i in range(1, contour.size()):
		var depart := contour[i - 1]
		var longueur := depart.distance_to(contour[i])
		var distance := ecart - reste
		while distance <= longueur:
			ampoules.append(depart.lerp(contour[i], distance / longueur))
			distance += ecart
		reste = longueur - (distance - ecart)
	return ampoules


static func _arc(contour: PackedVector2Array, centre: Vector2, rayon: float, debut: float, fin: float) -> void:
	var pas := 12
	for i in pas + 1:
		var angle := lerpf(debut, fin, float(i) / pas)
		contour.append(centre + rayon * Vector2(cos(angle), sin(angle)))
