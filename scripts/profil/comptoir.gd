class_name Comptoir
extends RefCounted
## Le Comptoir du Croupier : on y dépense ses jetons d'âme en avantages permanents.
## Toutes les règles de prix et de plafond sont ici ; l'écran ne fait qu'afficher et appeler
## (comme Boutique pour la boutique d'une partie).

enum Achat { SYMBOLE, RELIQUE, PV_MAX, OR_DE_DEPART, RELANCE, TREFLE }

## Prix en jetons d'âme (valeurs de départ, à équilibrer).
const PRIX: Dictionary = {
	Achat.SYMBOLE: 10,
	Achat.RELIQUE: 15,
	Achat.PV_MAX: 20,
	Achat.OR_DE_DEPART: 15,
	Achat.RELANCE: 30,
	Achat.TREFLE: 25,
}

const ORDRE: Array[Achat] = [Achat.SYMBOLE, Achat.RELIQUE, Achat.PV_MAX, Achat.OR_DE_DEPART, Achat.RELANCE, Achat.TREFLE]

var profil: Profil
## Le hasard des déblocages (un déblocage tire au hasard un élément encore verrouillé).
var hasard: RandomNumberGenerator
## Ce que le dernier déblocage a donné (id d'un symbole ou d'une relique), pour l'afficher.
var dernier_deblocage: StringName = &""


static func creer(le_profil: Profil, le_hasard: RandomNumberGenerator = null) -> Comptoir:
	var comptoir := Comptoir.new()
	comptoir.profil = le_profil
	comptoir.hasard = le_hasard if le_hasard != null else RandomNumberGenerator.new()
	if le_hasard == null:
		comptoir.hasard.randomize()
	return comptoir


func prix(achat: Achat) -> int:
	return PRIX[achat]


## Plus rien à acheter : tout est débloqué, ou le niveau maximum est atteint, ou c'est déjà acheté.
func est_epuise(achat: Achat) -> bool:
	match achat:
		Achat.SYMBOLE:
			return profil.symboles_verrouilles().is_empty()
		Achat.RELIQUE:
			return profil.reliques_verrouillees().is_empty()
		Achat.PV_MAX:
			return profil.niveau_pv >= Profil.NIVEAU_MAX
		Achat.OR_DE_DEPART:
			return profil.niveau_or >= Profil.NIVEAU_MAX
		Achat.RELANCE:
			return profil.relance_de_partie
		Achat.TREFLE:
			return profil.trefle_au_depart
	return true


func peut_acheter(achat: Achat) -> bool:
	return not est_epuise(achat) and profil.jetons >= prix(achat)


## Achète : les jetons sont dépensés et l'effet appliqué. Renvoie faux, sans rien changer, si impossible.
func acheter(achat: Achat) -> bool:
	if not peut_acheter(achat):
		return false
	profil.jetons -= prix(achat)
	dernier_deblocage = &""
	match achat:
		Achat.SYMBOLE:
			dernier_deblocage = _debloquer_au_hasard(profil.symboles_verrouilles())
			profil.symboles_debloques.append(dernier_deblocage)
		Achat.RELIQUE:
			dernier_deblocage = _debloquer_au_hasard(profil.reliques_verrouillees())
			profil.reliques_debloquees.append(dernier_deblocage)
		Achat.PV_MAX:
			profil.niveau_pv += 1
		Achat.OR_DE_DEPART:
			profil.niveau_or += 1
		Achat.RELANCE:
			profil.relance_de_partie = true
		Achat.TREFLE:
			profil.trefle_au_depart = true
	return true


func _debloquer_au_hasard(verrouilles: Array[StringName]) -> StringName:
	return verrouilles[hasard.randi_range(0, verrouilles.size() - 1)]


# --- Textes (pour l'écran et les tests) -----------------------------------------

func titre(achat: Achat) -> String:
	match achat:
		Achat.SYMBOLE:
			return TranslationServer.translate("Débloquer un symbole")
		Achat.RELIQUE:
			return TranslationServer.translate("Débloquer une relique")
		Achat.PV_MAX:
			return TranslationServer.translate("+%d PV max au départ") % Profil.PV_PAR_NIVEAU
		Achat.OR_DE_DEPART:
			return TranslationServer.translate("+%d or au départ") % Profil.OR_PAR_NIVEAU
		Achat.RELANCE:
			return TranslationServer.translate("Relance gratuite par partie")
		Achat.TREFLE:
			return TranslationServer.translate("Commencer avec un trèfle")
	return ""


## Ce que l'achat donne et où on en est (niveau, éléments restants, déjà acheté).
func detail(achat: Achat) -> String:
	if est_epuise(achat):
		match achat:
			Achat.SYMBOLE, Achat.RELIQUE:
				return TranslationServer.translate("Tout est débloqué.")
			Achat.PV_MAX, Achat.OR_DE_DEPART:
				return TranslationServer.translate("Niveau maximum (%d / %d).") % [Profil.NIVEAU_MAX, Profil.NIVEAU_MAX]
			_:
				return TranslationServer.translate("Déjà acheté.")
	match achat:
		Achat.SYMBOLE:
			return TranslationServer.translate("Au hasard : %d encore verrouillés.") % profil.symboles_verrouilles().size()
		Achat.RELIQUE:
			return TranslationServer.translate("Au hasard : %d encore verrouillées.") % profil.reliques_verrouillees().size()
		Achat.PV_MAX:
			return TranslationServer.translate("Niveau %d / %d.") % [profil.niveau_pv, Profil.NIVEAU_MAX]
		Achat.OR_DE_DEPART:
			return TranslationServer.translate("Niveau %d / %d.") % [profil.niveau_or, Profil.NIVEAU_MAX]
		Achat.RELANCE:
			return TranslationServer.translate("Tous les rouleaux, une fois par partie.")
		Achat.TREFLE:
			return TranslationServer.translate("Un Trèfle dans le sac de départ.")
	return ""
