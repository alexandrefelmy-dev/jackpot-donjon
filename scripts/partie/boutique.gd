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

var partie: Partie
## Les symboles à vendre (3 différents).
var offres: Array[SymbolData] = []
## Une offre achetée disparaît de l'étal.
var vendues: Array[bool] = []


## Ouvre la boutique : tire les offres avec le générateur de la partie.
static func creer(la_partie: Partie) -> Boutique:
	var boutique := Boutique.new()
	boutique.partie = la_partie
	boutique.offres = la_partie.tirer_symboles(NB_OFFRES)
	for i in boutique.offres.size():
		boutique.vendues.append(false)
	return boutique


# --- Acheter un symbole ------------------------------------------------------

func prix_offre(index: int) -> int:
	return offres[index].prix


func peut_acheter(index: int) -> bool:
	return index >= 0 and index < offres.size() and not vendues[index] \
			and partie.or_total >= offres[index].prix


## Achète une offre : le symbole va dans le sac. Renvoie faux (sans rien changer) si impossible.
func acheter(index: int) -> bool:
	if not peut_acheter(index):
		return false
	partie.or_total -= offres[index].prix
	partie.sac.ajouter(offres[index])
	vendues[index] = true
	return true


# --- Retirer un symbole du sac ----------------------------------------------

## Prix du prochain retrait : 10 or, puis 5 de plus à chaque retrait de la partie.
func prix_retrait() -> int:
	return PRIX_RETRAIT_BASE + PRIX_RETRAIT_PAS * partie.nb_retraits


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
	return PRIX_DOREE


## Un symbole déjà doré ne peut pas l'être deux fois.
func peut_ameliorer(index_sac: int) -> bool:
	return index_sac >= 0 and index_sac < partie.sac.taille() \
			and not partie.sac.symboles[index_sac].doree and partie.or_total >= PRIX_DOREE


func ameliorer(index_sac: int) -> bool:
	if not peut_ameliorer(index_sac):
		return false
	partie.or_total -= PRIX_DOREE
	partie.sac.ameliorer(index_sac)
	return true


# --- Se soigner --------------------------------------------------------------

## Possible tant que les PV ne sont pas au maximum.
func peut_soigner() -> bool:
	return partie.pv < partie.pv_max and partie.or_total >= PRIX_SOIN


func soigner() -> bool:
	if not peut_soigner():
		return false
	partie.or_total -= PRIX_SOIN
	partie.pv = mini(partie.pv_max, partie.pv + SOIN_PV)
	return true
