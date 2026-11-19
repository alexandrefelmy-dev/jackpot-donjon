class_name Boutique
extends RefCounted
## Une visite de la boutique : acheter un symbole, retirer un symbole du sac, rendre un
## symbole doré, se soigner. Toutes les règles de prix sont ici ; l'écran ne fait qu'afficher
## et appeler ces méthodes. Chaque action vérifie l'or, le débite dans partie.or_total,
## puis s'applique ; un refus ne change rien.

const PRIX_RETRAIT_BASE := 10
## Chaque retrait de la partie rend le suivant plus cher : 10, 15, 20...
const PRIX_RETRAIT_PAS := 5
const PRIX_DOREE := 20
const PRIX_SOIN := 10
const SOIN_PV := 10
const NB_OFFRES := 3
## Reliques à vendre (au prix de leur fichier de données, entre 25 et 40 or).
const NB_OFFRES_RELIQUES := 2

var partie: Partie
## Les symboles à vendre (3 différents).
var offres: Array[SymbolData] = []
## Une offre achetée disparaît de l'étal.
var vendues: Array[bool] = []
## Les reliques à vendre (2 différentes, que le joueur ne possède pas encore).
var offres_reliques: Array[RelicData] = []
var reliques_vendues: Array[bool] = []


## Ouvre la boutique : tire les offres avec le générateur de la partie.
static func creer(la_partie: Partie) -> Boutique:
	var boutique := Boutique.new()
	boutique.partie = la_partie
	boutique.offres = la_partie.tirer_symboles(NB_OFFRES)
	for i in boutique.offres.size():
		boutique.vendues.append(false)
	boutique.offres_reliques = la_partie.proposer_reliques(NB_OFFRES_RELIQUES)
	for i in boutique.offres_reliques.size():
		boutique.reliques_vendues.append(false)
	return boutique


# --- Acheter un symbole ------------------------------------------------------

func prix_offre(index: int) -> int:
	return partie.prix_ajuste(offres[index].prix)


func peut_acheter(index: int) -> bool:
	return index >= 0 and index < offres.size() and not vendues[index] \
			and partie.or_total >= prix_offre(index)


## Achète une offre : le symbole va dans le sac. Renvoie faux (sans rien changer) si impossible.
func acheter(index: int) -> bool:
	if not peut_acheter(index):
		return false
	partie.or_total -= prix_offre(index)
	partie.sac.ajouter(offres[index])
	vendues[index] = true
	return true


# --- Acheter une relique -----------------------------------------------------

func prix_relique(index: int) -> int:
	return partie.prix_ajuste(offres_reliques[index].prix)


func peut_acheter_relique(index: int) -> bool:
	return index >= 0 and index < offres_reliques.size() and not reliques_vendues[index] \
			and not partie.a_relique(offres_reliques[index].id) \
			and partie.or_total >= prix_relique(index)


## Achète une relique : elle s'ajoute à la partie (ses effets immédiats s'appliquent aussitôt).
## Renvoie faux (sans rien changer) si impossible.
func acheter_relique(index: int) -> bool:
	if not peut_acheter_relique(index):
		return false
	partie.or_total -= prix_relique(index)
	partie.ajouter_relique(offres_reliques[index])
	reliques_vendues[index] = true
	return true


# --- Retirer un symbole du sac ----------------------------------------------

## Prix du prochain retrait : 10 or, puis 5 de plus à chaque retrait de la partie.
func prix_retrait() -> int:
	return partie.prix_ajuste(PRIX_RETRAIT_BASE + PRIX_RETRAIT_PAS * partie.nb_retraits)


## On garde toujours au moins 1 symbole dans le sac.
func peut_retirer(index_sac: int) -> bool:
	return index_sac >= 0 and index_sac < partie.sac.taille() and partie.sac.taille() > 1 \
			and partie.or_total >= prix_retrait()


func retirer(index_sac: int) -> bool:
	if not peut_retirer(index_sac):
		return false
	partie.or_total -= prix_retrait()
	partie.sac.retirer(index_sac)
	partie.nb_retraits += 1
	return true


# --- Rendre un symbole doré -------------------------------------------------

func prix_amelioration() -> int:
	return partie.prix_ajuste(PRIX_DOREE)


## Un symbole déjà doré ne peut pas l'être deux fois.
func peut_ameliorer(index_sac: int) -> bool:
	return index_sac >= 0 and index_sac < partie.sac.taille() \
			and not partie.sac.symboles[index_sac].doree and partie.or_total >= prix_amelioration()


func ameliorer(index_sac: int) -> bool:
	if not peut_ameliorer(index_sac):
		return false
	partie.or_total -= prix_amelioration()
	partie.sac.ameliorer(index_sac)
	return true


# --- Se soigner --------------------------------------------------------------

func prix_soin() -> int:
	return partie.prix_ajuste(PRIX_SOIN)


## Possible tant que les PV ne sont pas au maximum.
func peut_soigner() -> bool:
	return partie.pv < partie.pv_max and partie.or_total >= prix_soin()


func soigner() -> bool:
	if not peut_soigner():
		return false
	partie.or_total -= prix_soin()
	partie.pv = mini(partie.pv_max, partie.pv + SOIN_PV)
	return true
