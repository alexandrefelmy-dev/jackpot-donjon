class_name Mise
extends RefCounted
## Une mise : le côté « gambling ». On la choisit avant le tirage (une seule par tour).
## Les règles de gain et de perte sont dans Combat.jouer_tour ; ici, seulement ce qu'on mise.

enum Type { AUCUNE, OR, QUITTE_OU_DOUBLE }

## Montants possibles pour une mise d'or.
const MONTANTS_OR: Array[int] = [5, 10, 20]
## PV risqués par un quitte ou double.
const PV_QUITTE_OU_DOUBLE := 5
## Une mise d'or gagnée « revient ×3 » : on reçoit 3 fois la mise (gain net : 2 fois la mise).
const MULTIPLICATEUR_GAIN_OR := 3

var type: Type = Type.AUCUNE
## Or misé (mise d'or seulement).
var montant: int = 0


static func aucune() -> Mise:
	return Mise.new()


static func en_or(or_mise: int) -> Mise:
	var mise := Mise.new()
	mise.type = Type.OR
	mise.montant = or_mise
	return mise


static func quitte_ou_double() -> Mise:
	var mise := Mise.new()
	mise.type = Type.QUITTE_OU_DOUBLE
	return mise


## Le texte du bouton de mise, ex. « 10 or » ou « Quitte ou double (5 PV) ».
func libelle() -> String:
	match type:
		Type.OR:
			return TranslationServer.translate("%d or") % montant
		Type.QUITTE_OU_DOUBLE:
			return TranslationServer.translate("Quitte ou double (%d PV)") % PV_QUITTE_OU_DOUBLE
		_:
			return TranslationServer.translate("Pas de mise")
