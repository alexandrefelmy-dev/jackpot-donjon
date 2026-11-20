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
## Gardées pour toujours : une ancienne version sans sa migration serait perdue. Ajouter ici (et dans
## tests/fixtures un fichier de cette version) à chaque changement de Profil.VERSION.
static func migrations_reelles() -> Dictionary:
	return {1: Callable(ProfilFichier, "_migrer_1_vers_2")}


## Version 1 -> 2 : les records n'existaient pas, ils partent de 0. (La liste des clés est écrite ici en toutes
## lettres, pas lue dans Profil.CLES_RECORDS : une migration ne doit jamais changer quand Profil évolue.)
static func _migrer_1_vers_2(donnees: Dictionary) -> Dictionary:
	var suite := donnees.duplicate()
	for cle in ["record_salles", "record_degats", "record_combo", "record_jackpots"]:
		suite[cle] = 0
	return suite


## Ce que renvoie charger().
class Chargement:
	var profil: Profil
	## Un message à montrer au joueur ("" = rien à dire).
	var message: String = ""
	## Faux si le fichier existant ne doit pas être écrasé (version plus récente que le jeu).
	var ecriture_permise: bool = true


## Lit le profil à `chemin` (le « .bak » en secours). Ne plante jamais : au pire, profil neuf.
static func charger(chemin: String, migrations: Dictionary = migrations_reelles()) -> Chargement:
	var resultat := Chargement.new()
	resultat.profil = Profil.nouveau()
	var un_fichier_existe := false
	for candidat in [chemin, chemin + ".bak"]:
		if not FileAccess.file_exists(candidat):
			continue
		un_fichier_existe = true
		var donnees := FichierSur.lire_json(candidat)
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


## Amène des données lues à la version actuelle, une version à la fois. `migrations` : la chaîne à utiliser
## (par défaut les vraies, voir migrations_reelles ; les tests en passent une à eux, `{}` = aucune).
## Renvoie un dictionnaire vide si une migration manque (données inutilisables).
static func migrer(donnees: Dictionary, migrations: Dictionary = migrations_reelles()) -> Dictionary:
	var courant := donnees.duplicate(true)
	var version := _entier_ou(courant.get("version"), -1)
	while version < Profil.VERSION:
		if not migrations.has(version):
			return {}
		courant = (migrations[version] as Callable).call(courant)
		version += 1
		courant["version"] = version
	return courant


## Écrit le profil à `chemin`, de façon sûre (voir FichierSur). Renvoie OK ou le code d'erreur.
static func sauver(profil: Profil, chemin: String) -> Error:
	return FichierSur.ecrire(profil.en_dictionnaire(), chemin)


static func _entier_ou(valeur: Variant, par_defaut: int) -> int:
	var entier: Variant = Profil.entier_ou_null(valeur)
	return entier if entier != null else par_defaut
