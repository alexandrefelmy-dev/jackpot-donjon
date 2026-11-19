class_name ReglesMachine
extends RefCounted
## Les règles que le Grand Croupier change à chaque tour. Une règle modifie les effets de
## certains symboles pour UN tirage ; elle est annoncée avant le tirage (le joueur la voit).
## Pas d'état ici : MachineASous.resoudre() appelle effet_modifie() pour chaque effet de symbole.

const EPEES_SOIGNENT := "epees_soignent"
const BOUCLIERS_INUTILES := "boucliers_inutiles"
const POTIONS_INUTILES := "potions_inutiles"
const CRANES_DOUBLES := "cranes_doubles"

## Toutes les règles possibles, dans un ordre fixe (le hasard en tire une).
const TOUTES: Array[String] = [EPEES_SOIGNENT, BOUCLIERS_INUTILES, POTIONS_INUTILES, CRANES_DOUBLES]

## Texte affiché au joueur pour chaque règle.
const TEXTES: Dictionary = {
	EPEES_SOIGNENT: "Les épées soignent l'ennemi au lieu de le blesser",
	BOUCLIERS_INUTILES: "Les boucliers ne donnent pas d'armure",
	POTIONS_INUTILES: "Les potions ne soignent pas",
	CRANES_DOUBLES: "Les crânes comptent double",
}


static func decrire(regle: String) -> String:
	if not TEXTES.has(regle):
		return ""
	return TranslationServer.translate(TEXTES[regle])


## L'effet d'un symbole (de base ou de combo) une fois la règle appliquée.
## `regle` vide = aucune règle : l'effet reste tel quel.
static func effet_modifie(regle: String, symbole: SymbolData, effet: Dictionary) -> Dictionary:
	if regle.is_empty() or effet.is_empty():
		return effet
	var resultat := effet.duplicate()
	match regle:
		EPEES_SOIGNENT:
			if symbole.id == &"epee" and resultat.has("degats"):
				resultat["soin_ennemi"] = resultat["degats"]
				resultat.erase("degats")
		BOUCLIERS_INUTILES:
			if symbole.id == &"bouclier":
				resultat.erase("armure")
		POTIONS_INUTILES:
			if symbole.id == &"potion":
				resultat.erase("soin")
		CRANES_DOUBLES:
			if symbole.id == &"crane":
				for cle: String in resultat:
					resultat[cle] = int(resultat[cle]) * 2
	return resultat
