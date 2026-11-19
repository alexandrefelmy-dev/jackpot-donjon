class_name ProfilFichier
extends RefCounted
## Lire et écrire le profil sur le disque, sans jamais le perdre.
##
## - Écriture sûre : on écrit un fichier temporaire, on garde l'ancien fichier en « .bak », puis on
##   renomme : un plantage en pleine écriture laisse l'ancien profil intact.
## - Lecture prudente : fichier abîmé ou modifié à la main → on essaie le « .bak » → sinon profil neuf.
## - Version : le fichier porte un numéro ; un fichier plus ancien passe par la chaîne de migrations
##   (une par version, gardées pour toujours) ; un fichier plus récent que le jeu est REFUSÉ et jamais
##   écrasé (le joueur a peut-être lancé une vieille version du jeu).
## - Que des données simples (JSON) : jamais d'objet, qu'un fichier partagé pourrait détourner.

const CHEMIN_DEFAUT := "user://profil.save"

## Les migrations : version de départ -> fonction qui transforme ses données vers la version suivante.
## Vide tant que le fichier n'a qu'une version. Ajouter ici (et dans tests/fixtures) à chaque changement.
const MIGRATIONS: Dictionary = {}


## Ce que renvoie charger().
class Chargement:
	var profil: Profil
	## Un message à montrer au joueur ("" = rien à dire).
	var message: String = ""
	## Faux si le fichier existant ne doit pas être écrasé (version plus récente que le jeu).
	var ecriture_permise: bool = true


## Lit le profil à `chemin` (le « .bak » en secours). Ne plante jamais : au pire, profil neuf.
static func charger(chemin: String, migrations: Dictionary = MIGRATIONS) -> Chargement:
	var resultat := Chargement.new()
	resultat.profil = Profil.nouveau()
	var un_fichier_existe := false
	for candidat in [chemin, chemin + ".bak"]:
		if not FileAccess.file_exists(candidat):
			continue
		un_fichier_existe = true
		var donnees := _lire_json(candidat)
		if donnees.is_empty() or _entier_ou(donnees.get("version"), -1) < 0:
			continue
		var version := _entier_ou(donnees.get("version"), -1)
		if version > Profil.VERSION:
			resultat.ecriture_permise = false
			resultat.message = TranslationServer.translate(
				"Ton profil vient d'une version plus récente du jeu : il est ignoré et ne sera pas modifié.")
			return resultat
		var migrees := migrer(donnees, migrations)
		var profil := Profil.depuis_dictionnaire(migrees) if not migrees.is_empty() else null
		if profil == null:
			continue
		resultat.profil = profil
		if candidat != chemin:
			resultat.message = TranslationServer.translate("Ton profil était abîmé : la sauvegarde précédente a été rechargée.")
		return resultat
	if un_fichier_existe:
		resultat.message = TranslationServer.translate("Ton profil était illisible : un profil neuf a été créé.")
	return resultat


## Amène des données lues à la version actuelle, une version à la fois.
## Renvoie un dictionnaire vide si une migration manque (données inutilisables).
static func migrer(donnees: Dictionary, migrations: Dictionary = MIGRATIONS) -> Dictionary:
	var courant := donnees.duplicate(true)
	var version := _entier_ou(courant.get("version"), -1)
	while version < Profil.VERSION:
		if not migrations.has(version):
			return {}
		courant = (migrations[version] as Callable).call(courant)
		version += 1
		courant["version"] = version
	return courant


## Écrit le profil à `chemin`, de façon sûre. Renvoie OK ou le code d'erreur (à montrer au joueur).
static func sauver(profil: Profil, chemin: String) -> Error:
	var absolu := ProjectSettings.globalize_path(chemin)
	var temporaire := absolu + ".tmp"
	var fichier := FileAccess.open(temporaire, FileAccess.WRITE)
	if fichier == null:
		return FileAccess.get_open_error()
	var ecrit := fichier.store_string(JSON.stringify(profil.en_dictionnaire(), "\t"))
	fichier.close()
	if not ecrit:
		return ERR_FILE_CANT_WRITE
	if FileAccess.file_exists(chemin):
		if _lire_json(chemin).is_empty():
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
static func _lire_json(chemin: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(chemin)) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


static func _entier_ou(valeur: Variant, par_defaut: int) -> int:
	if valeur is int:
		return valeur
	if valeur is float and is_equal_approx(valeur, roundf(valeur)):
		return int(valeur)
	return par_defaut
