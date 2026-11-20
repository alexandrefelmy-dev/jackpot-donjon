class_name FichierSur
extends RefCounted
## Écrire et lire un fichier JSON sans jamais le perdre (profil du joueur, options).
## Écriture : fichier temporaire, ancien fichier gardé en « .bak », puis renommage : un plantage en
## pleine écriture laisse l'ancien fichier intact. Lecture : un fichier abîmé n'est jamais « à moitié lu ».


## Écrit `donnees` à `chemin`, de façon sûre. Renvoie OK ou le code d'erreur.
static func ecrire(donnees: Dictionary, chemin: String) -> Error:
	var absolu := ProjectSettings.globalize_path(chemin)
	var temporaire := absolu + ".tmp"
	var fichier := FileAccess.open(temporaire, FileAccess.WRITE)
	if fichier == null:
		return FileAccess.get_open_error()
	var ecrit := fichier.store_string(JSON.stringify(donnees, "\t"))
	fichier.close()
	if not ecrit:
		return ERR_FILE_CANT_WRITE
	if FileAccess.file_exists(chemin):
		if lire_json(chemin).is_empty():
			# Le fichier actuel est abîmé : il ne doit pas écraser un bon « .bak ».
			DirAccess.remove_absolute(absolu)
		else:
			if FileAccess.file_exists(chemin + ".bak"):
				DirAccess.remove_absolute(absolu + ".bak")
			var erreur := DirAccess.rename_absolute(absolu, absolu + ".bak")
			if erreur != OK:
				return erreur
	return DirAccess.rename_absolute(temporaire, absolu)


## Le contenu d'un fichier JSON sous forme de dictionnaire ({} si absent, abîmé ou pas un dictionnaire).
static func lire_json(chemin: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(chemin)) != OK:
		return {}
	return json.data if json.data is Dictionary else {}
