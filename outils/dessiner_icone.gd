extends SceneTree
## OUTIL : dessine l'icône du jeu (une petite machine à sous : bandeau d'ampoules, trois rouleaux avec une épée,
## une pièce et un crâne du pack 0x72, un levier) et l'écrit dans assets/icone/ : `icone.png` (256 × 256, pour la
## fenêtre du jeu) et `icone.ico` (16, 32, 48, 64 et 256 pixels, pour le .exe Windows).
##
## Lancer :  godot --headless --path . -s res://outils/dessiner_icone.gd
## (les images du pack doivent être importées : `godot --headless --path . --import` d'abord).
## Tout est dessiné ici, sans fichier source : aucune licence en plus de celle du pack 0x72 (CC0).

const DOSSIER := "res://assets/icone/"
const TAILLE := 256
const TAILLES_ICO: Array[int] = [16, 32, 48, 64, 256]

const VIOLET := Color("1a1030")
const OR := Color("ffd34d")
const OR_SOMBRE := Color("a8801f")
const ROUGE := Color("5b1220")
const NOIR := Color("14090d")
const PAPIER := Color("e8e0cc")
const ROUGE_VIF := Color("e0352b")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER))
	var image := _dessiner()
	image.save_png(DOSSIER + "icone.png")
	_ecrire_ico(image, DOSSIER + "icone.ico")
	print("icône écrite dans ", ProjectSettings.globalize_path(DOSSIER))
	quit()


func _dessiner() -> Image:
	var image := Image.create_empty(TAILLE, TAILLE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# Le meuble : un carré arrondi rouge à cadre doré, sur un fond violet.
	_carre_arrondi(image, Rect2i(8, 8, 240, 240), 40, OR_SOMBRE)
	_carre_arrondi(image, Rect2i(14, 14, 228, 228), 34, ROUGE)
	# Le bandeau : noir, cadre doré, une rangée d'ampoules.
	_carre_arrondi(image, Rect2i(30, 28, 196, 52), 14, OR)
	_carre_arrondi(image, Rect2i(34, 32, 188, 44), 11, NOIR)
	for i in 9:
		var centre := Vector2i(52 + i * 19, 54)
		_disque(image, centre, 6, OR if i % 2 == 0 else Color("ff6b4a"))
		_disque(image, centre + Vector2i(-2, -2), 2, Color(1, 1, 1, 0.8))
	# La vitre et trois rouleaux crème, chacun avec son symbole.
	_carre_arrondi(image, Rect2i(24, 94, 170, 124), 14, OR_SOMBRE)
	_carre_arrondi(image, Rect2i(28, 98, 162, 116), 11, VIOLET)
	var symboles := ["weapon_regular_sword", "coin_anim_f0", "skull"]
	for i in 3:
		var x := 34 + i * 52
		_carre_arrondi(image, Rect2i(x, 104, 46, 104), 8, PAPIER)
		_symbole(image, symboles[i], Vector2i(x + 23, 156))
		# L'ombre du cylindre : sombre en haut et en bas.
		for y in 20:
			var alpha := 0.5 * (1.0 - float(y) / 20.0)
			_ligne_ombre(image, x, 104 + y, 46, alpha)
			_ligne_ombre(image, x, 207 - y, 46, alpha)
	# Le levier à droite : un bras gris et une boule rouge.
	for y in range(112, 196):
		for x in range(212, 220):
			image.set_pixel(x, y, Color("b8b8c8"))
	_disque(image, Vector2i(216, 108), 18, Color("7a1a14"))
	_disque(image, Vector2i(216, 108), 15, ROUGE_VIF)
	_disque(image, Vector2i(210, 102), 5, Color(1, 1, 1, 0.55))
	return image


## Un symbole du pack, agrandi d'un facteur entier sans flou, centré en `centre`.
func _symbole(image: Image, nom: String, centre: Vector2i) -> void:
	var brute := Images.texture(nom).get_image()
	brute.convert(Image.FORMAT_RGBA8)
	brute = brute.get_region(brute.get_used_rect())  # sans la marge transparente : il remplit le rouleau
	var facteur := maxi(1, mini(38 / brute.get_width(), 70 / brute.get_height()))
	brute.resize(brute.get_width() * facteur, brute.get_height() * facteur, Image.INTERPOLATE_NEAREST)
	var depart := centre - brute.get_size() / 2
	image.blend_rect(brute, Rect2i(Vector2i.ZERO, brute.get_size()), depart)


func _carre_arrondi(image: Image, zone: Rect2i, rayon: int, couleur: Color) -> void:
	for y in range(zone.position.y, zone.end.y):
		for x in range(zone.position.x, zone.end.x):
			var dx := maxi(maxi(zone.position.x + rayon - x, x - (zone.end.x - 1 - rayon)), 0)
			var dy := maxi(maxi(zone.position.y + rayon - y, y - (zone.end.y - 1 - rayon)), 0)
			if dx * dx + dy * dy <= rayon * rayon:
				image.set_pixel(x, y, couleur)


func _disque(image: Image, centre: Vector2i, rayon: int, couleur: Color) -> void:
	for y in range(centre.y - rayon, centre.y + rayon + 1):
		for x in range(centre.x - rayon, centre.x + rayon + 1):
			if (x - centre.x) * (x - centre.x) + (y - centre.y) * (y - centre.y) <= rayon * rayon \
					and x >= 0 and y >= 0 and x < TAILLE and y < TAILLE:
				image.set_pixel(x, y, couleur)


## Assombrit une ligne de pixels (l'ombre du haut et du bas d'un rouleau).
func _ligne_ombre(image: Image, x: int, y: int, largeur: int, alpha: float) -> void:
	for i in range(x + 3, x + largeur - 3):
		var base := image.get_pixel(i, y)
		image.set_pixel(i, y, base.lerp(Color.BLACK, alpha))


## Écrit un .ico : plusieurs tailles, chacune en PNG (accepté par Windows depuis Vista).
func _ecrire_ico(image: Image, chemin: String) -> void:
	var png: Array[PackedByteArray] = []
	for taille in TAILLES_ICO:
		var copie := image.duplicate() as Image
		if taille != TAILLE:
			copie.resize(taille, taille, Image.INTERPOLATE_LANCZOS)
		png.append(copie.save_png_to_buffer())
	var fichier := FileAccess.open(chemin, FileAccess.WRITE)
	fichier.store_16(0)  # réservé
	fichier.store_16(1)  # type : icône
	fichier.store_16(TAILLES_ICO.size())
	var decalage := 6 + 16 * TAILLES_ICO.size()
	for i in TAILLES_ICO.size():
		var taille := TAILLES_ICO[i]
		fichier.store_8(0 if taille >= 256 else taille)  # largeur (0 = 256)
		fichier.store_8(0 if taille >= 256 else taille)  # hauteur
		fichier.store_8(0)  # couleurs de la palette (aucune)
		fichier.store_8(0)  # réservé
		fichier.store_16(1)  # plans
		fichier.store_16(32)  # bits par pixel
		fichier.store_32(png[i].size())
		fichier.store_32(decalage)
		decalage += png[i].size()
	for donnees in png:
		fichier.store_buffer(donnees)
	fichier.close()
