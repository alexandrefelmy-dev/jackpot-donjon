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

## Texte affiché pour chaque type (%d = la valeur).
const FORMATS: Dictionary = {
	ATTAQUE: "Attaque %d",
	PROTECTION: "Se protège (+%d armure)",
	BLOCAGE: "Bloque %d rouleau au prochain tirage",
	VOL: "Vole %d or",
}


## Transforme une intention en texte lisible, ex. "Attaque 3".
static func decrire(intention: Dictionary) -> String:
	var type: String = intention.get("type", "")
	if not FORMATS.has(type):
		return TranslationServer.translate("Intention inconnue")
	var format := String(TranslationServer.translate(FORMATS[type]))
	return format % int(intention.get("valeur", 0))
