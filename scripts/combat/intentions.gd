class_name Intentions
extends RefCounted
## Outils pour lire et afficher les intentions des ennemis.
## Une intention est un Dictionary { "type": ..., "valeur": ... }.

const ATTAQUE := "attaque"
const PROTECTION := "protection"
## Bloque des rouleaux (la valeur = leur nombre) au prochain tirage du joueur.
const BLOCAGE := "blocage"
## Vole de l'or au joueur (la valeur = la quantité maximale).
const VOL := "vol"
## Ne fait rien ce tour-là, mais l'annonce (le Golem se prépare à une grosse attaque).
const CHARGE := "charge"
## L'ennemi s'enfuit : le combat s'arrête sans victoire (le Pickpocket).
const FUITE := "fuite"

## Texte affiché pour chaque type (%d = la valeur).
const FORMATS: Dictionary = {
	ATTAQUE: "Attaque %d",
	PROTECTION: "Se protège (+%d armure)",
	BLOCAGE: "Bloque %d rouleau au prochain tirage",
	VOL: "Vole %d or",
	CHARGE: "Se prépare à frapper",
	FUITE: "Va s'enfuir",
}


## Transforme une intention en texte lisible, ex. "Attaque 3".
static func decrire(intention: Dictionary) -> String:
	var type: String = intention.get("type", "")
	if not FORMATS.has(type):
		return TranslationServer.translate("Intention inconnue")
	var format := String(TranslationServer.translate(FORMATS[type]))
	# Certaines intentions n'ont pas de chiffre (« Va s'enfuir ») : rien à insérer.
	if not format.contains("%d"):
		return format
	return format % int(intention.get("valeur", 0))
