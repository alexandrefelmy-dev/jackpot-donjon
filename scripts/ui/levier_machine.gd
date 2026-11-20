class_name LevierMachine
extends Button
## Le levier de la machine, à droite du meuble : un bouton (clic, ou Espace via l'action « levier » de l'écran) qui
## se dessine lui-même : une plaque, un bras et une boule rouge. `animer()` le tire vers le bas puis le relâche.
## Grisé (bouton désactivé) quand on ne peut pas tirer. Pur affichage : le tour est lancé par le signal `pressed`.

const COULEUR_BRAS := Color("b8b8c8")
const COULEUR_BOULE := Color("e0352b")
const COULEUR_PLAQUE := Color("3a2a1c")
const COULEUR_OR := Color("ffd34d")
## Course du levier (pixels) et durée d'un aller-retour.
const COURSE := 70.0
const DUREE := 0.3

## 0 = levier en haut, 1 = tiré à fond.
var abaissement: float = 0.0:
	set(valeur):
		abaissement = valeur
		queue_redraw()
var _tween: Tween


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE  # sinon Espace déclencherait 2 tirages
	custom_minimum_size = Vector2(84, 200)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for etat in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(etat, StyleBoxEmpty.new())


## Tire le levier vers le bas puis le relâche (le dernier tween est remplacé s'il tourne encore).
func animer() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "abaissement", 1.0, DUREE * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "abaissement", 0.0, DUREE * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_DISABLED or quoi == NOTIFICATION_ENABLED or quoi == NOTIFICATION_MOUSE_ENTER or quoi == NOTIFICATION_MOUSE_EXIT:
		queue_redraw()


func _draw() -> void:
	var teinte := 0.45 if disabled else (1.25 if is_hovered() else 1.0)
	var x := size.x * 0.5
	var bas := size.y - 14.0
	# La plaque fixée au meuble, en bas.
	draw_rect(Rect2(x - 22, bas - 6, 44, 20), COULEUR_PLAQUE * teinte)
	draw_rect(Rect2(x - 22, bas - 6, 44, 20), COULEUR_OR * teinte, false, 2.0)
	# Le bras : de la plaque vers la boule. En haut la boule est loin, tiré elle descend et se rapproche de la plaque.
	var haut := 34.0
	var boule := Vector2(x, haut + COURSE * abaissement)
	var pied := Vector2(x, bas - 6)
	draw_line(pied, boule, Color(COULEUR_BRAS.r * teinte, COULEUR_BRAS.g * teinte, COULEUR_BRAS.b * teinte), 8.0)
	draw_line(pied + Vector2(-2, 0), boule + Vector2(-2, 0), Color(1, 1, 1, 0.35 * teinte), 2.0)
	# La boule rouge avec son reflet.
	var rouge := Color(COULEUR_BOULE.r * teinte, COULEUR_BOULE.g * teinte, COULEUR_BOULE.b * teinte)
	draw_circle(boule, 22.0, rouge.darkened(0.35))
	draw_circle(boule, 19.0, rouge)
	draw_circle(boule + Vector2(-6, -7), 6.0, Color(1, 1, 1, 0.5 * teinte))
