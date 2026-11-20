class_name Profil
extends RefCounted
## Le profil du joueur : ce qui survit d'une partie à l'autre (jetons d'âme, déblocages, avantages
## permanents, malédictions). Que des données simples : il s'écrit tel quel dans un fichier JSON
## (voir ProfilFichier). Les règles d'achat sont dans Comptoir, le bilan d'une partie dans Bilan.

## Le numéro de version du fichier : à augmenter à chaque changement de forme, avec une migration
## (voir ProfilFichier.migrations_reelles). Version 2 : les records.
const VERSION := 2

## Borne de bon sens du record de plus long combo (la machine a 5 ou 6 rouleaux aujourd'hui) : large, pour qu'une
## machine plus grande plus tard ne fasse jamais passer un profil pour abîmé.
const RECORD_COMBO_MAX := 20
const NIVEAU_MAX := 3
const PV_PAR_NIVEAU := 5
const OR_PAR_NIVEAU := 10

## Ce qui est débloqué dès la première partie (les autres se débloquent au Comptoir).
const SYMBOLES_DE_DEPART: Array[StringName] = [&"epee", &"bouclier", &"potion", &"piece"]
const SYMBOLES_A_DEBLOQUER: Array[StringName] = [&"bombe", &"fleche", &"aimant", &"trefle"]
const RELIQUES_DE_DEPART: Array[StringName] = [
	Reliques.COEUR_DE_PIERRE, Reliques.TIRELIRE, Reliques.LAME_AIMANTEE, Reliques.DE_PIPE]
const RELIQUES_A_DEBLOQUER: Array[StringName] = [
	Reliques.TREFLE, Reliques.JACKPOT_MAUDIT, Reliques.JETON_PORTE_BONHEUR,
	Reliques.SIXIEME_ROULEAU, Reliques.CINQUIEME_AS]

var jetons: int = 0
var symboles_debloques: Array[StringName] = []
var reliques_debloquees: Array[StringName] = []
## Niveaux des avantages « PV max » et « or de départ » (0 à NIVEAU_MAX).
var niveau_pv: int = 0
var niveau_or: int = 0
## Avantages à acheter une fois : une relance gratuite par partie, un Trèfle dans le sac de départ.
var relance_de_partie: bool = false
var trefle_au_depart: bool = false
## Les malédictions de la prochaine partie (ids de Maledictions, 3 au plus).
var maledictions: Array[StringName] = []
var parties_jouees: int = 0
var victoires: int = 0
## Les records d'une partie (0 = aucun) : salles franchies, dégâts infligés, plus long combo, jackpots.
var record_salles: int = 0
var record_degats: int = 0
var record_combo: int = 0
var record_jackpots: int = 0


## Un profil neuf : rien d'acheté, les éléments de départ débloqués.
static func nouveau() -> Profil:
	var profil := Profil.new()
	profil.symboles_debloques.assign(SYMBOLES_DE_DEPART)
	profil.reliques_debloquees.assign(RELIQUES_DE_DEPART)
	return profil


func a_debloque_symbole(id: StringName) -> bool:
	return id in symboles_debloques


func a_debloque_relique(id: StringName) -> bool:
	return id in reliques_debloquees


func symboles_verrouilles() -> Array[StringName]:
	var liste: Array[StringName] = []
	for id in SYMBOLES_A_DEBLOQUER:
		if not (id in symboles_debloques):
			liste.append(id)
	return liste


func reliques_verrouillees() -> Array[StringName]:
	var liste: Array[StringName] = []
	for id in RELIQUES_A_DEBLOQUER:
		if not (id in reliques_debloquees):
			liste.append(id)
	return liste


## Les PV max et l'or de départ que les avantages achetés ajoutent.
func pv_bonus() -> int:
	return niveau_pv * PV_PAR_NIVEAU


func or_bonus() -> int:
	return niveau_or * OR_PAR_NIVEAU


# --- Conversion en données simples ------------------------------------------------

func en_dictionnaire() -> Dictionary:
	return {
		"version": VERSION,
		"jetons": jetons,
		"symboles_debloques": _en_textes(symboles_debloques),
		"reliques_debloquees": _en_textes(reliques_debloquees),
		"niveau_pv": niveau_pv,
		"niveau_or": niveau_or,
		"relance_de_partie": relance_de_partie,
		"trefle_au_depart": trefle_au_depart,
		"maledictions": _en_textes(maledictions),
		"parties_jouees": parties_jouees,
		"victoires": victoires,
		"record_salles": record_salles,
		"record_degats": record_degats,
		"record_combo": record_combo,
		"record_jackpots": record_jackpots,
	}


## Relit un profil depuis des données (déjà à la version actuelle). Renvoie null si quelque chose
## est faux : type inattendu, nombre hors bornes, identifiant inconnu. Un fichier de ce genre est
## abîmé ou modifié à la main : on ne le charge pas à moitié.
static func depuis_dictionnaire(donnees: Dictionary) -> Profil:
	var profil := Profil.nouveau()
	# JSON rend tous les nombres en flottants : on les convertit en entiers (en refusant les décimaux).
	var jetons_lus: Variant = entier_ou_null(donnees.get("jetons"))
	var niveau_pv_lu: Variant = entier_ou_null(donnees.get("niveau_pv"))
	var niveau_or_lu: Variant = entier_ou_null(donnees.get("niveau_or"))
	var parties_lues: Variant = entier_ou_null(donnees.get("parties_jouees"))
	var victoires_lues: Variant = entier_ou_null(donnees.get("victoires"))
	var records_lus: Array = []
	for cle in ["record_salles", "record_degats", "record_combo", "record_jackpots"]:
		records_lus.append(entier_ou_null(donnees.get(cle)))
	if jetons_lus == null or jetons_lus < 0 or niveau_pv_lu == null or niveau_pv_lu < 0 or niveau_pv_lu > NIVEAU_MAX \
			or niveau_or_lu == null or niveau_or_lu < 0 or niveau_or_lu > NIVEAU_MAX \
			or parties_lues == null or parties_lues < 0 or victoires_lues == null or victoires_lues < 0 \
			or victoires_lues > parties_lues:
		return null
	if not (donnees.get("relance_de_partie") is bool) or not (donnees.get("trefle_au_depart") is bool):
		return null
	# Les records : des entiers positifs ou nuls (le plus long combo reste sous une borne de bon sens).
	for record in records_lus:
		if record == null or record < 0:
			return null
	if records_lus[2] > RECORD_COMBO_MAX:
		return null
	var symboles: Variant = _ids(donnees.get("symboles_debloques"), SYMBOLES_DE_DEPART + SYMBOLES_A_DEBLOQUER)
	var reliques: Variant = _ids(donnees.get("reliques_debloquees"), RELIQUES_DE_DEPART + RELIQUES_A_DEBLOQUER)
	var maledictions: Variant = _ids(donnees.get("maledictions"), Maledictions.TOUTES)
	if symboles == null or reliques == null or maledictions == null or maledictions.size() > Maledictions.MAX:
		return null
	profil.jetons = jetons_lus
	profil.niveau_pv = niveau_pv_lu
	profil.niveau_or = niveau_or_lu
	profil.relance_de_partie = donnees["relance_de_partie"]
	profil.trefle_au_depart = donnees["trefle_au_depart"]
	profil.parties_jouees = parties_lues
	profil.victoires = victoires_lues
	profil.record_salles = records_lus[0]
	profil.record_degats = records_lus[1]
	profil.record_combo = records_lus[2]
	profil.record_jackpots = records_lus[3]
	# Les éléments de départ restent toujours débloqués, même si le fichier ne les cite pas.
	for id: StringName in symboles:
		if not (id in profil.symboles_debloques):
			profil.symboles_debloques.append(id)
	for id: StringName in reliques:
		if not (id in profil.reliques_debloquees):
			profil.reliques_debloquees.append(id)
	profil.maledictions.assign(maledictions)
	return profil


static func _en_textes(ids: Array[StringName]) -> Array:
	var textes := []
	for id in ids:
		textes.append(String(id))
	return textes


## Un nombre entier lu dans un JSON (entier ou flottant sans décimale), ou null.
static func entier_ou_null(valeur: Variant) -> Variant:
	if valeur is int:
		return valeur
	if valeur is float and is_equal_approx(valeur, roundf(valeur)) and absf(valeur) < 1.0e15:
		return int(valeur)
	return null


## Une liste de textes qui sont tous des ids connus et sans doublon, convertie en StringName ; sinon null.
static func _ids(valeur: Variant, connus: Array) -> Variant:
	if not (valeur is Array):
		return null
	var ids: Array[StringName] = []
	for element in valeur:
		if not (element is String) or not (StringName(element) in connus) or StringName(element) in ids:
			return null
		ids.append(StringName(element))
	return ids
