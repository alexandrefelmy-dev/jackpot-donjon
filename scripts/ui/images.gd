class_name Images
extends RefCounted
## Les images du jeu (pack 0x72, 16x16 « pixel art »). Les sprites ont des tailles variées (une pièce fait 6×7, un ogre
## 32×36) : ces fonctions les agrandissent d'un facteur ENTIER, en « plus proche voisin » (jamais flou), et centrent
## les icônes dans une case carrée pour que toutes aient la même taille à l'écran.
## Tout est mis en cache : une image n'est agrandie qu'une fois.

const DOSSIER := "res://assets/images/"

static var _cache: Dictionary = {}


## Le fichier d'une image existe-t-il ? (`nom` sans le « .png »)
static func existe(nom: String) -> bool:
	return not nom.is_empty() and ResourceLoader.exists(DOSSIER + nom + ".png")


## L'image brute, telle que dans le pack (petite : à agrandir avec icone() ou cadres()).
static func texture(nom: String) -> Texture2D:
	if not existe(nom):
		return null
	return load(DOSSIER + nom + ".png") as Texture2D


## Une icône carrée de `case_px` pixels de côté : l'image, agrandie d'un facteur entier pour remplir la case,
## centrée, avec des pixels nets. null si l'image n'existe pas.
static func icone(nom: String, case_px: int) -> Texture2D:
	var cle := "%s@%d" % [nom, case_px]
	if _cache.has(cle):
		return _cache[cle]
	var brute := texture(nom)
	if brute == null:
		_cache[cle] = null  # on ne cherche pas deux fois une image absente
		return null
	var image := brute.get_image()
	var facteur := maxi(1, mini(case_px / image.get_width(), case_px / image.get_height()))
	image.resize(image.get_width() * facteur, image.get_height() * facteur, Image.INTERPOLATE_NEAREST)
	var carre := Image.create_empty(case_px, case_px, false, Image.FORMAT_RGBA8)
	carre.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i((case_px - image.get_width()) / 2, (case_px - image.get_height()) / 2))
	var resultat := ImageTexture.create_from_image(carre)
	_cache[cle] = resultat
	return resultat


## Combien d'images compte une animation (`prefixe_f0`, `prefixe_f1`...) ?
static func nb_cadres(prefixe: String) -> int:
	var nombre := 0
	while existe("%s_f%d" % [prefixe, nombre]):
		nombre += 1
	return nombre


## Comme cadres(), mais d'abord recadrées sur ce que l'animation dessine vraiment (sans la marge transparente du
## pack) : le sprite visible a alors la hauteur voulue, et son bas touche le bas de l'image. Le facteur d'agrandissement
## (entier) est entre 2 et `facteur_max` : un petit ennemi (un rat) ne devient pas géant.
static func cadres_rognes(prefixe: String, hauteur_voulue: int, facteur_max: int = 12) -> Array[Texture2D]:
	var cle := "%s@rogne%d" % [prefixe, hauteur_voulue]
	if _cache.has(cle):
		return _cache[cle]
	var liste: Array[Texture2D] = []
	var images: Array[Image] = []
	var zone := Rect2i()
	for i in nb_cadres(prefixe):
		var image := texture("%s_f%d" % [prefixe, i]).get_image()
		images.append(image)
		var utilisee := image.get_used_rect()
		zone = utilisee if i == 0 else zone.merge(utilisee)
	if zone.size.y > 0:
		var facteur := clampi(int(float(hauteur_voulue) / zone.size.y), 2, facteur_max)
		for image in images:
			var rogne := image.get_region(zone)
			rogne.resize(rogne.get_width() * facteur, rogne.get_height() * facteur, Image.INTERPOLATE_NEAREST)
			liste.append(ImageTexture.create_from_image(rogne))
	_cache[cle] = liste
	return liste


## Les images d'une animation, agrandies d'un facteur entier pour approcher `hauteur_voulue` pixels de haut
## (facteur arrondi au plus proche, au moins 2). Liste vide si l'animation n'existe pas.
static func cadres(prefixe: String, hauteur_voulue: int) -> Array[Texture2D]:
	var cle := "%s@h%d" % [prefixe, hauteur_voulue]
	if _cache.has(cle):
		return _cache[cle]
	var liste: Array[Texture2D] = []
	for i in nb_cadres(prefixe):
		var image := texture("%s_f%d" % [prefixe, i]).get_image()
		var facteur := maxi(2, roundi(float(hauteur_voulue) / image.get_height()))
		image.resize(image.get_width() * facteur, image.get_height() * facteur, Image.INTERPOLATE_NEAREST)
		liste.append(ImageTexture.create_from_image(image))
	_cache[cle] = liste
	return liste
