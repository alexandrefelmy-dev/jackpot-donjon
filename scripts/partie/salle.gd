class_name Salle
extends RefCounted
## Une salle du donjon : le combat obligatoire d'un pas, ou une salle bonus derrière une porte (boutique, coffre
## ou repos).
## Données pures : la disposition du donjon est décidée par Donjon, jouée par Partie.

enum Type { COMBAT, BOUTIQUE, COFFRE, REPOS }

var type: Type = Type.COMBAT
## L'ennemi à affronter : celui du combat, ou la Mimique cachée dans un coffre. null sinon.
var ennemi: EnemyData
## Vrai pour un coffre qui est en réalité une Mimique (invisible sur la porte).
var mimique: bool = false


static func creer(type_voulu: Type, ennemi_voulu: EnemyData = null, est_mimique: bool = false) -> Salle:
	var salle := Salle.new()
	salle.type = type_voulu
	salle.ennemi = ennemi_voulu
	salle.mimique = est_mimique
	return salle


## Le nom du type de salle, affiché sur la porte (jamais la mimique : elle doit surprendre).
func nom_type() -> String:
	match type:
		Type.COMBAT:
			return TranslationServer.translate("Combat")
		Type.BOUTIQUE:
			return TranslationServer.translate("Boutique")
		Type.COFFRE:
			return TranslationServer.translate("Coffre")
		Type.REPOS:
			return TranslationServer.translate("Repos")
	return ""


## Même type et même ennemi (la mimique d'un coffre compte comme un coffre).
func ressemble_a(autre: Salle) -> bool:
	if type != autre.type:
		return false
	if type == Type.COMBAT:
		return ennemi == autre.ennemi
	return true


## Un texte court qui décrit la salle (pour les tests et les messages d'erreur).
func empreinte() -> String:
	var texte: String = Type.keys()[type]
	if ennemi != null:
		texte += ":" + String(ennemi.id)
	return texte
