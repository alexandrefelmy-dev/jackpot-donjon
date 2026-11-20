class_name TableSons
extends Resource
## Une table « nom d'événement → fichiers sonores » (data/sons.tres pour les effets, data/musiques.tres
## pour la musique). On change un son en changeant un fichier ici, sans toucher au code.

## Identifiant -> liste de chemins (res://assets/...). Plusieurs chemins = des variantes tirées au hasard.
@export var evenements: Dictionary = {}


## Les chemins d'un événement (liste vide s'il n'est pas dans la table).
func chemins(evenement: StringName) -> Array[String]:
	var liste: Array[String] = []
	var valeur: Variant = evenements.get(String(evenement), evenements.get(evenement))
	if valeur is Array:
		for chemin in valeur:
			liste.append(String(chemin))
	elif valeur is String:
		liste.append(valeur)
	return liste
