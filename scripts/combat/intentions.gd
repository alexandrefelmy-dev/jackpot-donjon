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


## Ce que l'ennemi fait en plus de son intention, une ligne par passif ("" s'il n'en a pas).
## Affiché sous l'intention : le joueur sait toujours ce qui l'attend.
static func decrire_passif(passif: Dictionary) -> String:
	var lignes := PackedStringArray()
	if int(passif.get("cranes_par_tour", 0)) > 0:
		lignes.append(String(TranslationServer.translate("Chaque tour : +%d crâne(s) dans ta machine")) % int(passif["cranes_par_tour"]))
	if int(passif.get("attaque_par_mise", 0)) > 0:
		lignes.append(String(TranslationServer.translate("Chaque mise : +%d attaque pour de bon")) % int(passif["attaque_par_mise"]))
	if bool(passif.get("regle_par_tour", false)):
		lignes.append(TranslationServer.translate("Chaque tour : une règle de la machine change"))
	return "\n".join(lignes)
