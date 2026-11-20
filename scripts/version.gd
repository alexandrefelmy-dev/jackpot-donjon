class_name Version
extends RefCounted
## Le numéro de version du jeu, affiché à l'écran pour que les rapports de bug disent
## quelle version était testée. À changer au début de chaque étape (voir « Git : une branche
## par étape » dans CLAUDE.md) ; l'étiquette Git de la même version est posée à la fusion.

const NUMERO := "0.8"


## Le texte affiché : « v0.6 ».
static func texte() -> String:
	return "v" + NUMERO
