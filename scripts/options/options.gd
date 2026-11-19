class_name Options
extends RefCounted
## Les réglages du joueur : volumes, plein écran, accessibilité. Que des données simples, enregistrées
## dans user://options.save (voir OptionsFichier). Sans rapport avec le profil : un joueur qui efface sa
## progression garde ses réglages.

## Le numéro de version du fichier : à augmenter à chaque changement de forme.
const VERSION := 1

var volume_musique: float = 0.6
var volume_effets: float = 0.8
var plein_ecran: bool = false
## Accessibilité : coupe la secousse d'écran et l'arrêt sur image / coupe le pulsement des néons et les flashs.
var reduire_tremblements: bool = false
var reduire_flashs: bool = false


func en_dictionnaire() -> Dictionary:
	return {
		"version": VERSION,
		"volume_musique": volume_musique,
		"volume_effets": volume_effets,
		"plein_ecran": plein_ecran,
		"reduire_tremblements": reduire_tremblements,
		"reduire_flashs": reduire_flashs,
	}


## Relit des options depuis des données (déjà à la version actuelle). Renvoie null si quelque chose est
## faux : type inattendu, volume hors de 0 à 1. Un fichier de ce genre est abîmé : on ne le charge pas à moitié.
static func depuis_dictionnaire(donnees: Dictionary) -> Options:
	var options := Options.new()
	for cle in ["volume_musique", "volume_effets"]:
		var valeur: Variant = donnees.get(cle)
		if not (valeur is float or valeur is int) or valeur < 0.0 or valeur > 1.0:
			return null
	for cle in ["plein_ecran", "reduire_tremblements", "reduire_flashs"]:
		if not (donnees.get(cle) is bool):
			return null
	options.volume_musique = float(donnees["volume_musique"])
	options.volume_effets = float(donnees["volume_effets"])
	options.plein_ecran = donnees["plein_ecran"]
	options.reduire_tremblements = donnees["reduire_tremblements"]
	options.reduire_flashs = donnees["reduire_flashs"]
	return options
