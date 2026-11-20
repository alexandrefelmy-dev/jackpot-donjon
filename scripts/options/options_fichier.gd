class_name OptionsFichier
extends RefCounted
## Lire et écrire les options sur le disque, sans jamais les perdre (voir FichierSur).
## Lecture : fichier abîmé → on essaie le « .bak » → sinon options par défaut. Un fichier d'une version
## plus récente que le jeu est ignoré et jamais écrasé.

const CHEMIN_DEFAUT := "user://options.save"


class Chargement:
	var options: Options
	## Faux si le fichier existant ne doit pas être écrasé (version plus récente que le jeu).
	var ecriture_permise: bool = true


## Lit les options à `chemin` (le « .bak » en secours). Ne plante jamais : au pire, les options par défaut.
static func charger(chemin: String) -> Chargement:
	var resultat := Chargement.new()
	resultat.options = Options.new()
	for candidat in [chemin, chemin + ".bak"]:
		var donnees := FichierSur.lire_json(candidat)
		var version: Variant = Profil.entier_ou_null(donnees.get("version"))
		if donnees.is_empty() or version == null:
			continue
		if version > Options.VERSION:
			resultat.ecriture_permise = false
			return resultat
		var lues := Options.depuis_dictionnaire(donnees) if version == Options.VERSION else null
		if lues != null:
			resultat.options = lues
			return resultat
	return resultat


static func sauver(options: Options, chemin: String) -> Error:
	return FichierSur.ecrire(options.en_dictionnaire(), chemin)
