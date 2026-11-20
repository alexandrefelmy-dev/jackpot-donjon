extends SceneTree
## OUTIL : mesure le temps de chaque image (en millisecondes) du menu, d'un combat au repos et d'un combat pendant
## que les rouleaux tournent, à deux tailles de fenêtre. La synchronisation verticale est coupée : on mesure le
## travail réel de chaque image, pas la fréquence de l'écran. Budget : 16,6 ms (60 images par seconde).
##
## Lancer (SANS --headless : il faut une vraie fenêtre et la carte graphique) :
##   godot --path . -s res://outils/mesure_images.gd
## Code de sortie 0 = la moyenne et le « p95 » (95 % des images font mieux) tiennent dans le budget partout.
## Seul le travail du processeur ET de la carte graphique mélangés est mesuré (pas leur répartition) : pour la
## détailler, ouvrir le profileur de Godot.

const BUDGET_MS := 16.6
const IMAGES_CHAUFFE := 40
const IMAGES_MESUREES := 300
const TAILLES: Array[Vector2i] = [Vector2i(1152, 648), Vector2i(1920, 1080)]
const SCENES := ["menu", "combat au repos", "combat, rouleaux qui tournent"]

var _taille := 0
var _scene := 0
var _images := 0
var _derniere := 0
var _durees: Array[float] = []
var _echecs := 0


func _initialize() -> void:
	# Son propre profil et ses propres options : jamais les vrais (voir capture_ecrans.gd).
	GameState.profil = Profil.nouveau()
	GameState.options = Options.new()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_preparer()


func _preparer() -> void:
	_images = 0
	_durees.clear()
	DisplayServer.window_set_size(TAILLES[_taille])
	match _scene:
		0:
			GameState.en_partie = false
			GameState.aller_a(GameState.SCENE_MENU)
		1, 2:
			GameState.nouvelle_partie()
			GameState.partie.ennemi_courant = load("res://data/enemies/squelette.tres") as EnemyData
			GameState.partie.ecran = Partie.Ecran.COMBAT
			GameState.aller_a(GameState.SCENE_COMBAT)


func _process(_delta: float) -> bool:
	_images += 1
	var maintenant := Time.get_ticks_usec()
	if _images == IMAGES_CHAUFFE and _scene == 2:
		_lancer_un_tirage()
	if _images > IMAGES_CHAUFFE:
		_durees.append((maintenant - _derniere) / 1000.0)
	_derniere = maintenant
	if _images >= IMAGES_CHAUFFE + IMAGES_MESUREES:
		_rapporter()
		_scene += 1
		if _scene >= SCENES.size():
			_scene = 0
			_taille += 1
		if _taille >= TAILLES.size():
			print("RÉSULTAT : ", "OK" if _echecs == 0 else "%d MESURE(S) HORS BUDGET" % _echecs)
			quit(1 if _echecs > 0 else 0)
		else:
			_preparer()
	return false


## Tire le levier avec l'animation des rouleaux (en vraie fenêtre elle joue toute seule).
func _lancer_un_tirage() -> void:
	var combat := current_scene
	combat.combat.pv_ennemi = 500  # le combat dure : on mesure l'animation, pas une fin de combat
	combat.combat.pv_joueur = 500
	combat._tirer()


func _rapporter() -> void:
	var tri := _durees.duplicate()
	tri.sort()
	var somme := 0.0
	for duree in _durees:
		somme += duree
	var moyenne := somme / _durees.size()
	var p95: float = tri[int(tri.size() * 0.95)]
	var maximum: float = tri[tri.size() - 1]
	var tient := moyenne <= BUDGET_MS and p95 <= BUDGET_MS
	if not tient:
		_echecs += 1
	print("%dx%d  %-30s moyenne %.2f ms | p95 %.2f ms | max %.2f ms  %s" % [
		TAILLES[_taille].x, TAILLES[_taille].y, SCENES[_scene], moyenne, p95, maximum, "ok" if tient else "HORS BUDGET"])
