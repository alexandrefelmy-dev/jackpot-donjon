class_name Maledictions
extends RefCounted
## Les malédictions : à chaque défaite, une malédiction tirée au hasard s'ajoute à la partie suivante
## (3 au maximum, toutes différentes). Pas d'état ici : le profil garde la liste des ids actifs,
## et ces fonctions disent ce que chacune change (la partie, la boutique et le combat les lisent).

const SAC_LESTE := &"sac_leste"
const BOURSE_TROUEE := &"bourse_trouee"
const FATIGUE := &"fatigue"
const CROUPIER_RANCUNIER := &"croupier_rancunier"
const MAUVAIS_OEIL := &"mauvais_oeil"

## Toutes les malédictions, dans un ordre fixe (le hasard en tire une).
const TOUTES: Array[StringName] = [SAC_LESTE, BOURSE_TROUEE, FATIGUE, CROUPIER_RANCUNIER, MAUVAIS_OEIL]
## On ne cumule jamais plus de malédictions que cela.
const MAX := 3

## Valeurs des effets (réglables ici, en un seul endroit).
const CRANES_EN_PLUS := 1
const SURCOUT_PRIX_POURCENT := 20
const PV_MAX_EN_MOINS := 5
const PV_ENNEMI_EN_PLUS_POURCENT := 20
const GAIN_MISE_OR := 2

const NOMS: Dictionary = {
	SAC_LESTE: "Sac lesté",
	BOURSE_TROUEE: "Bourse trouée",
	FATIGUE: "Fatigue",
	CROUPIER_RANCUNIER: "Croupier rancunier",
	MAUVAIS_OEIL: "Mauvais œil",
}

const DESCRIPTIONS: Dictionary = {
	SAC_LESTE: "+1 crâne dans le sac de départ",
	BOURSE_TROUEE: "Prix de la boutique +20 %",
	FATIGUE: "−5 PV max",
	CROUPIER_RANCUNIER: "Le premier ennemi de chaque étage a +20 % de PV",
	MAUVAIS_OEIL: "Les mises d'or gagnées rapportent ×2 au lieu de ×3",
}


static func nom(id: StringName) -> String:
	return TranslationServer.translate(NOMS.get(id, ""))


static func description(id: StringName) -> String:
	return TranslationServer.translate(DESCRIPTIONS.get(id, ""))


## « Nom : description », pour les écrans.
static func texte(id: StringName) -> String:
	return "%s : %s" % [nom(id), description(id)]


## Une malédiction que `actives` ne contient pas encore, tirée avec `hasard` (et pas une de `exclues` :
## celles qui viennent d'être effacées ne reviennent pas aussitôt, tant qu'il en reste d'autres).
## Renvoie &"" si on en a déjà le maximum (ou toutes).
static func tirer(actives: Array[StringName], hasard: RandomNumberGenerator, exclues: Array[StringName] = []) -> StringName:
	if actives.size() >= MAX:
		return &""
	var possibles: Array[StringName] = []
	for id in TOUTES:
		if not (id in actives) and not (id in exclues):
			possibles.append(id)
	if possibles.is_empty():
		for id in TOUTES:
			if not (id in actives):
				possibles.append(id)
	if possibles.is_empty():
		return &""
	return possibles[hasard.randi_range(0, possibles.size() - 1)]


# --- Ce que chaque malédiction change ------------------------------------------

static func cranes_en_plus(actives: Array[StringName]) -> int:
	return CRANES_EN_PLUS if SAC_LESTE in actives else 0


## Un prix de boutique avec la Bourse trouée (arrondi au-dessus).
static func prix_ajuste(prix: int, actives: Array[StringName]) -> int:
	if not (BOURSE_TROUEE in actives):
		return prix
	return ceili(prix * (100 + SURCOUT_PRIX_POURCENT) / 100.0)


static func pv_max_en_moins(actives: Array[StringName]) -> int:
	return PV_MAX_EN_MOINS if FATIGUE in actives else 0


## Les PV d'un ennemi renforcé par le Croupier rancunier (arrondi au-dessus).
static func pv_ennemi_renforces(pv: int) -> int:
	return ceili(pv * (100 + PV_ENNEMI_EN_PLUS_POURCENT) / 100.0)


static func renforce_le_premier_ennemi(actives: Array[StringName]) -> bool:
	return CROUPIER_RANCUNIER in actives


## Le multiplicateur d'une mise d'or gagnée (3 normalement, 2 avec le Mauvais œil).
static func multiplicateur_gain_or(actives: Array[StringName]) -> int:
	return GAIN_MISE_OR if MAUVAIS_OEIL in actives else Mise.MULTIPLICATEUR_GAIN_OR
