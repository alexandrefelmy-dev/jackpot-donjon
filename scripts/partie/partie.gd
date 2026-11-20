class_name Partie
extends RefCounted
## Une partie : tout ce qui traverse les salles (PV, or, sac, reliques) et l'avancée dans le donjon :
## 3 étages de 5 combats obligatoires, avec 2 salles bonus au choix après les pas 2 et 4, chacun fini par un boss.
## Pas d'interface ici : les écrans lisent cet état et appellent ses méthodes. `ecran` dit quel
## écran doit être affiché maintenant (GameState le traduit en scène).

enum Etat { EN_COURS, VICTOIRE, DEFAITE }
## L'écran à afficher : le combat, le choix des 2 portes bonus (après certains combats), puis selon la salle
## (boutique, repos), la récompense d'un combat, le choix d'une relique (coffre, boss), ou la fin.
enum Ecran { PORTES, COMBAT, RECOMPENSE, RELIQUE, BOUTIQUE, REPOS, FIN }

const PV_DEPART := 40
const NB_RECOMPENSES := 3
const NB_RELIQUES_OFFERTES := 2
const NB_ROULEAUX_DEPART := 5
## Un repos soigne ce pourcentage des PV max (arrondi au-dessus, jamais au-dessus du maximum).
const SOIN_REPOS_POURCENT := 30
## Pourcentage des PV max rendu au joueur quand il passe à l'étage suivant (levier d'équilibrage :
## 0 = les PV ne remontent pas, comme l'écrit le cahier des charges).
const SOIN_APRES_BOSS_POURCENT := 50

## Symboles proposés en récompense (les symboles de base, sans le crâne).
const RECOMPENSES: Array[String] = [
	"res://data/symbols/epee.tres",
	"res://data/symbols/bouclier.tres",
	"res://data/symbols/potion.tres",
	"res://data/symbols/piece.tres",
]

## Le profil du joueur (jetons, déblocages, avantages, malédictions) ou null : sans profil, la partie se
## joue comme en v0.6 (4 symboles de base, les 9 reliques, aucun avantage ni malédiction).
var profil: Profil
## Les malédictions de cette partie, fixées au lancement (ids de Maledictions).
var maledictions: Array[StringName] = []
## La relance gratuite « de partie » (avantage du Comptoir) qui reste : 0 ou 1.
var relances_de_partie: int = 0
## Vrai une fois le bilan de la partie (jetons, malédiction) enregistré dans le profil, et ce bilan
## (voir Bilan.appliquer) : { "jetons", "malediction_recue", "maledictions_effacees" }.
var bilan_applique: bool = false
var bilan: Dictionary = {}
## Étages où un combat a déjà commencé, et si le combat en cours est renforcé (Croupier rancunier).
var _etages_combattus: Array[int] = []
var _ennemi_renforce: bool = false

## Graine du générateur aléatoire (affichée, pour pouvoir rejouer la partie).
var graine: int
## Le hasard du JEU : tirages, récompenses, offres, blocages. Le donjon, lui, ne dépend que de la graine.
var rng := RandomNumberGenerator.new()
## La disposition de tout le donjon (portes, ennemis, mimiques), fixée par la graine.
var donjon: Donjon

var pv: int = PV_DEPART
var pv_max: int = PV_DEPART
var or_total: int = 0
var sac: Sac
## Étage en cours (1 à 3) et pas dans l'étage (1 à 5 : le combat obligatoire du pas ; 6 = le boss).
var etage: int = 1
var pas: int = 1
## Vrai pendant une salle bonus (choisie derrière une porte), faux pendant le combat obligatoire du pas.
var en_salle_bonus: bool = false
## L'écran à afficher maintenant.
var ecran: Ecran = Ecran.PORTES
## La salle en cours : le combat du pas, ou la salle bonus franchie (null au choix des portes et au boss).
var salle_courante: Salle
## L'ennemi du combat en cours ou à venir (celui d'une porte de combat, une Mimique ou le boss).
var ennemi_courant: EnemyData
var combats_gagnes: int = 0
## Salles terminées (combats gagnés ou fuis, boutiques, coffres, repos) et boss vaincus.
var salles_franchies: int = 0
var boss_vaincus: int = 0
## Combien de symboles ont été retirés du sac en boutique : chaque retrait coûte plus cher.
var nb_retraits: int = 0
## Les reliques possédées (chacune une seule fois).
var reliques: Array[RelicData] = []
## Nombre de rouleaux de la machine (5, ou 6 avec le Sixième rouleau).
var nb_rouleaux: int = NB_ROULEAUX_DEPART
var etat: Etat = Etat.EN_COURS
## Le combat en cours (créé par creer_combat, rendu à terminer_combat).
var combat_courant: Combat


## Crée une partie neuve. Une graine positive rend la partie rejouable à l'identique.
static func creer(graine_voulue: int = -1, profil_du_joueur: Profil = null) -> Partie:
	var partie := Partie.new()
	# Une graine toujours positive : on peut la retaper pour rejouer la partie.
	partie.graine = graine_voulue if graine_voulue >= 0 else randi()
	partie.rng.seed = partie.graine
	partie.sac = Sac.creer_sac_de_depart()
	partie.donjon = Donjon.creer(partie.graine)
	if profil_du_joueur != null:
		partie._appliquer_profil(profil_du_joueur)
	partie._commencer_combat_du_pas()  # la partie s'ouvre sur le premier combat : il est obligatoire
	return partie


## Ce que le profil change au départ : PV, or, sac, relance, malédictions.
func _appliquer_profil(profil_du_joueur: Profil) -> void:
	profil = profil_du_joueur
	maledictions.assign(profil_du_joueur.maledictions)
	pv_max = maxi(1, PV_DEPART + profil_du_joueur.pv_bonus() - Maledictions.pv_max_en_moins(maledictions))
	pv = pv_max
	or_total = profil_du_joueur.or_bonus()
	sac.ajouter(Sac.CRANE, Maledictions.cranes_en_plus(maledictions))
	if profil_du_joueur.trefle_au_depart:
		sac.ajouter(Sac.TREFLE)
	relances_de_partie = 1 if profil_du_joueur.relance_de_partie else 0


## Un prix de boutique, avec la Bourse trouée s'il y a lieu.
func prix_ajuste(prix: int) -> int:
	return Maledictions.prix_ajuste(prix, maledictions)


## Le combat qui commence est-il le premier de son étage ? (Croupier rancunier : l'ennemi a +20 % de PV.)
## Noté quand l'ennemi devient courant, donc sans effet si l'écran est rechargé.
func _preparer_renfort() -> void:
	var premier := not (etage in _etages_combattus)
	_ennemi_renforce = premier and Maledictions.renforce_le_premier_ennemi(maledictions)
	if premier:
		_etages_combattus.append(etage)


# --- Avancer dans le donjon --------------------------------------------------

## La partie est en cours et attend cet écran : les actions d'un écran n'ont d'effet qu'à ce moment-là.
func _est_a(ecran_voulu: Ecran) -> bool:
	return ecran == ecran_voulu and etat == Etat.EN_COURS


## Un pourcentage des PV max, arrondi au-dessus (soin du repos, soin à l'arrivée d'un étage).
func _pourcentage_des_pv_max(pourcent: int) -> int:
	return ceili(pv_max * pourcent / 100.0)


func est_combat_de_boss() -> bool:
	return ennemi_courant != null and ennemi_courant.est_boss


## Les 2 salles bonus à choisir maintenant (vide si on n'est pas au choix des portes).
func portes() -> Array[Salle]:
	if not _est_a(Ecran.PORTES):
		return []
	return donjon.portes(etage, pas)


func nom_etage() -> String:
	return Donjon.nom_etage(etage)


## Le joueur franchit une porte bonus (0 ou 1) : l'écran suivant dépend de la salle.
## Renvoie faux si ce n'est pas le moment ou si la porte n'existe pas.
func choisir_porte(index: int) -> bool:
	var choix := portes()
	if index < 0 or index >= choix.size():
		return false
	salle_courante = choix[index]
	en_salle_bonus = true
	match salle_courante.type:
		Salle.Type.BOUTIQUE:
			ecran = Ecran.BOUTIQUE
		Salle.Type.REPOS:
			ecran = Ecran.REPOS
		Salle.Type.COFFRE:
			if salle_courante.mimique:
				# La Mimique attaque par surprise ; vaincue, elle laisse quand même la relique.
				ennemi_courant = salle_courante.ennemi
				_preparer_renfort()
				ecran = Ecran.COMBAT
			elif not _proposer_relique():
				_salle_terminee()
	return true


## La salle qui vient d'être jouée est finie. Le combat d'un pas qui a des salles bonus mène au choix des portes ;
## sinon (ou après une salle bonus) : le combat du pas suivant, ou le boss de l'étage après le 5e pas.
func _salle_terminee() -> void:
	salles_franchies += 1
	salle_courante = null
	ennemi_courant = null
	if not en_salle_bonus and pas in Donjon.BONUS_APRES_PAS:
		ecran = Ecran.PORTES
		return
	en_salle_bonus = false
	pas += 1
	if pas > Donjon.NB_PAS:
		ennemi_courant = donjon.boss_de(etage)
		_preparer_renfort()
		ecran = Ecran.COMBAT
	else:
		_commencer_combat_du_pas()


## Lance le combat obligatoire du pas en cours (celui que le donjon a prévu pour ce pas de cet étage).
func _commencer_combat_du_pas() -> void:
	en_salle_bonus = false
	salle_courante = donjon.combat(etage, pas)
	ennemi_courant = salle_courante.ennemi
	_preparer_renfort()
	ecran = Ecran.COMBAT


## Le boss est vaincu (et sa relique prise) : étage suivant, avec le soin d'équilibrage éventuel.
func _etage_suivant() -> void:
	etage += 1
	pas = 1
	var soin := _pourcentage_des_pv_max(SOIN_APRES_BOSS_POURCENT)
	pv = mini(pv_max, pv + soin)
	_commencer_combat_du_pas()


## Prépare le combat en cours avec les PV actuels du joueur.
func creer_combat() -> Combat:
	combat_courant = Combat.new(ennemi_courant, pv, pv_max, rng, nb_rouleaux, or_total)
	combat_courant.preparer_tirages(creer_machine(), sac, modificateurs())
	combat_courant.gain_mise_or = Maledictions.multiplicateur_gain_or(maledictions)
	combat_courant.relances_de_partie = relances_de_partie
	if _ennemi_renforce:
		combat_courant.pv_max_ennemi = Maledictions.pv_ennemi_renforces(ennemi_courant.pv_max)
		combat_courant.pv_ennemi = combat_courant.pv_max_ennemi
	# Reliques qui se renouvellent à chaque combat : Jeton porte-bonheur (mise remboursée),
	# Dé pipé (relance gratuite), Cinquième as (garder un rouleau et relancer les autres).
	for relique in reliques:
		combat_courant.remboursements_de_mise += int(relique.valeur("mise_remboursee_par_combat"))
		combat_courant.relances_gratuites += int(relique.valeur("relances_gratuites"))
		combat_courant.relances_cinquieme_as += int(relique.valeur("relances_cinquieme_as"))
	# L'attaque surprise de la Mimique tombe avant le premier tirage (le journal est dans le combat).
	combat_courant.jouer_ouverture()
	return combat_courant


## La machine à sous de cette partie (5 rouleaux, 6 avec le Sixième rouleau).
func creer_machine() -> MachineASous:
	return MachineASous.new(nb_rouleaux, 1)


## Ce que les reliques possédées changent dans le calcul des tirages.
func modificateurs() -> Modificateurs:
	return Modificateurs.depuis_reliques(reliques)


# --- Reliques ----------------------------------------------------------------

func a_relique(id: StringName) -> bool:
	for relique in reliques:
		if relique.id == id:
			return true
	return false


## Ajoute une relique et applique ses effets immédiats. Renvoie faux si on l'a déjà.
## Effets immédiats : PV max (Cœur de pierre), crânes ajoutés au sac (Jackpot maudit),
## rouleaux en plus (Sixième rouleau). Les autres effets sont lus à chaque tirage ou combat.
func ajouter_relique(relique: RelicData) -> bool:
	if a_relique(relique.id):
		return false
	reliques.append(relique)

	var bonus_pv := int(relique.valeur("pv_max_bonus"))
	if bonus_pv > 0:
		pv_max += bonus_pv
		pv = mini(pv_max, pv + bonus_pv)

	var nb_cranes := int(relique.valeur("cranes_ajoutes"))
	if nb_cranes > 0:
		sac.ajouter(Sac.CRANE, nb_cranes)

	nb_rouleaux += int(relique.valeur("rouleaux_en_plus"))
	return true


## `nombre` reliques différentes que le joueur ne possède pas encore (moins s'il n'en reste pas assez).
## Tirées avec le générateur de la partie, comme les récompenses.
func proposer_reliques(nombre: int) -> Array[RelicData]:
	var candidates := _reliques_disponibles()
	# Mélange de Fisher-Yates avec notre générateur.
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = temp
	return candidates.slice(0, mini(nombre, candidates.size()))


## Les reliques que le joueur ne possède pas encore, dans l'ordre du jeu (sans toucher au hasard).
func _reliques_disponibles() -> Array[RelicData]:
	var liste: Array[RelicData] = []
	for relique in Reliques.toutes():
		if _relique_proposable(relique):
			liste.append(relique)
	return liste


## Une relique qu'on peut encore recevoir : pas déjà possédée, et débloquée dans le profil (s'il y en a un).
func _relique_proposable(relique: RelicData) -> bool:
	return not a_relique(relique.id) and (profil == null or profil.a_debloque_relique(relique.id))


## Reste-t-il au moins une relique que le joueur ne possède pas ? (sans toucher au hasard)
func peut_recevoir_relique() -> bool:
	for relique in Reliques.toutes():
		if _relique_proposable(relique):
			return true
	return false


## Le joueur choisit sa relique (coffre, Mimique vaincue ou boss) : elle est ajoutée et la salle est finie.
func choisir_relique(relique: RelicData) -> void:
	if not _est_a(Ecran.RELIQUE):
		return
	ajouter_relique(relique)
	_relique_terminee()


## Passe à l'écran des reliques s'il en reste une à offrir. Renvoie faux sinon (rien ne change).
func _proposer_relique() -> bool:
	if not peut_recevoir_relique():
		return false
	ecran = Ecran.RELIQUE
	return true


## Après le choix d'une relique : le boss de l'étage ouvre l'étage suivant, toute autre salle est finie.
func _relique_terminee() -> void:
	if est_combat_de_boss():
		_etage_suivant()
	else:
		_salle_terminee()


## Reporte le résultat d'un combat fini sur la partie : PV, or, puis la suite.
## Un combat n'est compté qu'une fois (les appels répétés sont ignorés).
## Victoire : récompense en symbole (combat normal), relique (Mimique, boss), ou victoire finale
## (boss de l'étage 3). Fuite de l'ennemi : la salle est finie, sans récompense.
func terminer_combat(combat: Combat) -> void:
	if etat != Etat.EN_COURS or combat != combat_courant or not combat.est_fini():
		return
	combat_courant = null
	pv = combat.pv_joueur
	or_total += combat.or_gagne - combat.or_vole
	relances_de_partie = combat.relances_de_partie

	if combat.etat == Combat.Etat.DEFAITE:
		etat = Etat.DEFAITE
		ecran = Ecran.FIN
		return

	if combat.etat == Combat.Etat.FUITE:
		_salle_terminee()
		return

	combats_gagnes += 1
	if combat.ennemi.est_boss:
		boss_vaincus += 1
		salles_franchies += 1
		if etage >= Donjon.NB_ETAGES:
			etat = Etat.VICTOIRE
			ecran = Ecran.FIN
		elif not _proposer_relique():
			_etage_suivant()
	elif salle_courante != null and salle_courante.mimique:
		# La Mimique vaincue laisse quand même la relique du coffre.
		if not _proposer_relique():
			_salle_terminee()
	else:
		ecran = Ecran.RECOMPENSE


## Trois symboles différents à proposer après un combat normal.
func proposer_recompenses() -> Array[SymbolData]:
	return tirer_symboles(NB_RECOMPENSES)


## Les symboles qui peuvent être proposés (récompenses, boutique) : les 4 symboles de base,
## plus ceux que le profil a débloqués (jamais le crâne).
func chemins_des_symboles_proposables() -> Array[String]:
	var chemins: Array[String] = RECOMPENSES.duplicate()
	if profil != null:
		for id in Profil.SYMBOLES_A_DEBLOQUER:
			if profil.a_debloque_symbole(id):
				chemins.append("res://data/symbols/%s.tres" % id)
	return chemins


## Tire `nombre` symboles différents parmi ceux qui sont proposables, avec le générateur de la partie.
## Sert aux récompenses et aux offres de la boutique.
func tirer_symboles(nombre: int) -> Array[SymbolData]:
	var chemins := chemins_des_symboles_proposables()
	# Mélange de Fisher-Yates avec notre générateur (Array.shuffle() utiliserait un autre hasard).
	for i in range(chemins.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := chemins[i]
		chemins[i] = chemins[j]
		chemins[j] = temp

	var symboles: Array[SymbolData] = []
	for i in mini(nombre, chemins.size()):
		symboles.append(load(chemins[i]) as SymbolData)
	return symboles


## Ajoute le symbole choisi au sac. Passer = ne rien appeler.
func choisir_recompense(symbole: SymbolData) -> void:
	sac.ajouter(symbole)


## La récompense d'un combat est réglée (symbole pris ou non) : on retourne aux portes.
func terminer_recompense() -> void:
	if _est_a(Ecran.RECOMPENSE):
		_salle_terminee()


# --- Boutique et repos -------------------------------------------------------

## Le joueur quitte la boutique : retour aux portes.
func quitter_boutique() -> void:
	if _est_a(Ecran.BOUTIQUE):
		_salle_terminee()


## Les PV qu'un repos rendrait maintenant : 30 % des PV max (arrondi au-dessus), sans dépasser le maximum.
func soin_du_repos() -> int:
	var soin := _pourcentage_des_pv_max(SOIN_REPOS_POURCENT)
	return mini(soin, pv_max - pv)


## Repos : le joueur se soigne. Renvoie les PV rendus. La salle est finie.
func repos_soigner() -> int:
	if not _est_a(Ecran.REPOS):
		return 0
	var soin := soin_du_repos()
	if soin <= 0:
		return 0
	pv += soin
	_salle_terminee()
	return soin


## Repos : le joueur part sans rien faire (seulement possible quand aucune action ne l'est : PV pleins
## et tous les symboles déjà dorés), pour ne jamais rester bloqué dans la salle.
func quitter_repos() -> bool:
	if not _est_a(Ecran.REPOS) or soin_du_repos() > 0 or peut_dorer():
		return false
	_salle_terminee()
	return true


## Y a-t-il un symbole qui peut encore être doré dans le sac ?
func peut_dorer() -> bool:
	for symbole in sac.symboles:
		if not symbole.doree:
			return true
	return false


## Repos : le symbole d'index `index` du sac devient doré, gratuitement. La salle est finie.
## Renvoie faux (et ne change rien) si ce n'est pas un repos ou si le symbole est déjà doré.
func repos_dorer(index: int) -> bool:
	if not _est_a(Ecran.REPOS) or not sac.ameliorer(index):
		return false
	_salle_terminee()
	return true


# --- Pour les tests en jeu (boutons « [test] ») -------------------------------

## Saute directement au boss de l'étage en cours.
func aller_au_boss() -> void:
	if etat != Etat.EN_COURS:
		return
	pas = Donjon.NB_PAS + 1
	en_salle_bonus = false
	salle_courante = null
	ennemi_courant = donjon.boss_de(etage)
	_preparer_renfort()
	combat_courant = null
	ecran = Ecran.COMBAT


## Saute au début de l'étage suivant (sans combattre le boss).
func sauter_etage() -> void:
	if etat != Etat.EN_COURS or etage >= Donjon.NB_ETAGES:
		return
	combat_courant = null
	_etage_suivant()
