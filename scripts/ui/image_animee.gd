class_name ImageAnimee
extends TextureRect
## Une image qui s'anime en boucle (l'attente d'un ennemi ou du joueur) : elle passe d'une image à la suivante
## toutes les `duree` secondes. Elle laisse passer la souris et ne change jamais la taille de ce qui l'entoure.

var cadres: Array[Texture2D] = []
var duree: float = 0.2
var _indice: int = 0
var _ecoule: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE


## Donne les images de l'animation (vide : rien ne s'affiche). L'animation démarre à un endroit au hasard :
## plusieurs ennemis identiques ne bougent pas au même rythme.
func definir(images: Array[Texture2D], duree_par_image: float = 0.2) -> void:
	cadres = images
	duree = duree_par_image
	set_process(cadres.size() >= 2)  # une seule image : rien à animer
	if cadres.is_empty():
		texture = null
		return
	_indice = randi() % cadres.size()
	texture = cadres[_indice]
	custom_minimum_size = cadres[0].get_size()


func _process(delta: float) -> void:
	if cadres.size() < 2:
		return
	_ecoule += delta
	if _ecoule >= duree:
		_ecoule = 0.0
		_indice = (_indice + 1) % cadres.size()
		texture = cadres[_indice]
