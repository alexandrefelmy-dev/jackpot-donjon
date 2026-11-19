class_name Effets
extends RefCounted
## Outils pour lire et afficher les effets des symboles.
## Un effet est un Dictionary { clé: valeur }, par exemple { "degats": 2 }.

## Ordre d'affichage et de résolution des effets.
const ORDRE := ["degats", "armure", "soin", "or", "malus_ennemi", "perte_pv", "soin_ennemi"]

## Texte affiché pour chaque clé (%d = la valeur).
const FORMATS: Dictionary = {
	"degats": "%d dégâts",
	"armure": "+%d armure",
	"soin": "soigne %d PV",
	"or": "+%d or",
	"malus_ennemi": "attaque ennemie +%d",
	"perte_pv": "perd %d PV",
	"soin_ennemi": "soigne l'ennemi de %d PV",
}


## Transforme un effet en texte lisible, ex. "2 dégâts, +1 or".
static func decrire(effet: Dictionary, separateur: String = ", ") -> String:
	var morceaux := PackedStringArray()
	for cle: String in ORDRE:
		if effet.has(cle):
			var format := String(TranslationServer.translate(FORMATS[cle]))
			morceaux.append(format % effet[cle])
	return separateur.join(morceaux)
