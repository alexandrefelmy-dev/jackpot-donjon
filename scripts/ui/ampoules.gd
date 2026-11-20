class_name Ampoules
extends Control
## Une rangée d'ampoules de machine à sous. Au repos elles clignotent doucement une sur deux ; pendant que les
## rouleaux tournent elles « courent » en chenillard ; sur un jackpot toutes s'allument ensemble.
## « Réduire les flashs » (options) les fige : allumées sans clignoter. Pur affichage.

enum Mode { REPOS, COURSE, JACKPOT }

const COULEUR_ALLUMEE := Color("ffd34d")
const COULEUR_ALLUMEE_ROUGE := Color("ff6b4a")
const COULEUR_ETEINTE := Color("5a4a22")
const RAYON := 5.0
const ECART := 20.0

var mode: Mode = Mode.REPOS:
	set(valeur):
		mode = valeur
		queue_redraw()
var _temps: float = 0.0
var _etat: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, RAYON * 2 + 4)


func _process(delta: float) -> void:
	_temps += delta
	# Le chenillard avance 10 fois par seconde, le clignotement du repos 2 fois, le jackpot 6 fois.
	var cadence := 10.0 if mode == Mode.COURSE else (6.0 if mode == Mode.JACKPOT else 2.0)
	var nouvel_etat := int(_temps * cadence)
	if nouvel_etat != _etat:
		_etat = nouvel_etat
		queue_redraw()


func _draw() -> void:
	var nombre := maxi(2, int(size.x / ECART))
	var marge := (size.x - (nombre - 1) * ECART) / 2.0
	var fixe := Impacts.flashs_reduits()
	for i in nombre:
		var allumee := true
		match mode:
			Mode.REPOS:
				allumee = (i + _etat) % 2 == 0
			Mode.COURSE:
				allumee = (i + _etat) % 3 == 0
			Mode.JACKPOT:
				allumee = _etat % 2 == 0
		if fixe:
			allumee = i % 2 == 0
		var centre := Vector2(marge + i * ECART, size.y / 2.0)
		var couleur := COULEUR_ALLUMEE if i % 2 == 0 else COULEUR_ALLUMEE_ROUGE
		if allumee:
			draw_circle(centre, RAYON + 3.0, Color(couleur, 0.25))  # le halo
			draw_circle(centre, RAYON, couleur)
			draw_circle(centre - Vector2(1.5, 1.5), RAYON * 0.35, Color(1, 1, 1, 0.8))  # le reflet
		else:
			draw_circle(centre, RAYON, COULEUR_ETEINTE)
