class_name OrnementCarte
extends Control
## L'ornement d'une grande carte, façon carte à jouer : un fin filet doré à l'intérieur du cadre et un petit losange
## à chacun des quatre coins. À poser par-dessus un bouton ; le clic passe à travers. Pur affichage.

const COULEUR := Habillage.COULEUR_OR
const INSET := 7.0
const DEMI_LOSANGE := 5.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var filet := StyleBoxFlat.new()
	filet.draw_center = false
	filet.border_color = Color(COULEUR, 0.55)
	filet.set_border_width_all(1)
	filet.set_corner_radius_all(8)
	draw_style_box(filet, Rect2(Vector2(INSET, INSET), size - Vector2(INSET, INSET) * 2.0))
	var coins := [
		Vector2(INSET, INSET), Vector2(size.x - INSET, INSET),
		Vector2(INSET, size.y - INSET), Vector2(size.x - INSET, size.y - INSET),
	]
	for coin: Vector2 in coins:
		draw_colored_polygon(PackedVector2Array([
			coin + Vector2(0, -DEMI_LOSANGE), coin + Vector2(DEMI_LOSANGE, 0),
			coin + Vector2(0, DEMI_LOSANGE), coin + Vector2(-DEMI_LOSANGE, 0)]), COULEUR)
