class_name Reliques
extends RefCounted
## La liste des reliques du jeu (une par fichier de res://data/relics/), comme Sac.DEPART
## pour les symboles de départ.

const COEUR_DE_PIERRE := &"coeur_de_pierre"
const TIRELIRE := &"tirelire"
const LAME_AIMANTEE := &"lame_aimantee"
const TREFLE := &"trefle_quatre_feuilles"
const JACKPOT_MAUDIT := &"jackpot_maudit"
const JETON_PORTE_BONHEUR := &"jeton_porte_bonheur"
const SIXIEME_ROULEAU := &"sixieme_rouleau"
const DE_PIPE := &"de_pipe"
const CINQUIEME_AS := &"cinquieme_as"

const CHEMINS: Array[String] = [
	"res://data/relics/coeur_de_pierre.tres",
	"res://data/relics/tirelire.tres",
	"res://data/relics/lame_aimantee.tres",
	"res://data/relics/trefle_quatre_feuilles.tres",
	"res://data/relics/jackpot_maudit.tres",
	"res://data/relics/jeton_porte_bonheur.tres",
	"res://data/relics/sixieme_rouleau.tres",
	"res://data/relics/de_pipe.tres",
	"res://data/relics/cinquieme_as.tres",
]


## Toutes les reliques du jeu.
static func toutes() -> Array[RelicData]:
	var liste: Array[RelicData] = []
	for chemin in CHEMINS:
		liste.append(load(chemin) as RelicData)
	return liste


## Une relique d'après son identifiant (null si elle n'existe pas).
static func charger(id: StringName) -> RelicData:
	for relique in toutes():
		if relique.id == id:
			return relique
	return null
