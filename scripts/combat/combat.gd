class_name Combat
extends RefCounted
## Un combat au tour par tour entre le joueur et un ennemi.
## Pas d'interface ici : la scène donne le résultat d'un tirage à jouer_tour()
## et lit l'état (PV, armure, intention, victoire...) pour l'afficher.
##
## Déroulé d'un tour (voir « Combat » dans le cahier des charges) :
## 1. les effets du tirage s'appliquent ;
## 2. si l'ennemi est à 0 PV : victoire (même si le joueur est aussi à 0 PV) ;
## 3. si le joueur est à 0 PV : défaite ;
## 4. sinon l'ennemi exécute son intention ;
## 5. fin de tour : l'armure du joueur retombe à 0.

## FUITE : l'ennemi s'est enfui (le Pickpocket) : le combat est fini sans victoire ni défaite.
enum Etat { EN_COURS, VICTOIRE, DEFAITE, FUITE }

const PV_JOUEUR_DEPART := 40
## Au plus ce nombre de crânes temporaires ajoutés au sac du combat par les passifs des ennemis.
const MAX_CRANES_TEMPORAIRES := 10

var pv_max_joueur: int
var pv_joueur: int
var armure_joueur: int = 0

## Les données de l'ennemi (partagées, jamais modifiées).
var ennemi: EnemyData
var pv_ennemi: int
## Les PV max de CET ennemi dans CE combat (ceux du fichier, plus 20 % avec le Croupier rancunier).
var pv_max_ennemi: int
var armure_ennemi: int = 0

## Position dans la liste d'intentions de l'ennemi (jouées en boucle).
var index_intention: int = 0
var numero_tour: int = 1
var etat: Etat = Etat.EN_COURS
## Or gagné pendant ce combat : pièces tirées, puis or de la victoire.
var or_gagne: int = 0
## Rouleaux (index de cases) bloqués pour le prochain tirage du joueur.
## La scène les lit avant de tirer ; jouer_tour() les vide ensuite.
var rouleaux_bloques: Array[int] = []
## Or volé au joueur pendant ce combat (par le Gobelin tricheur, par exemple).
var or_vole: int = 0
## Combien de mises d'or perdues seront encore remboursées dans ce combat
## (Jeton porte-bonheur : 1 par combat). Rempli par Partie.creer_combat().
var remboursements_de_mise: int = 0
## Relances de tous les rouleaux encore disponibles dans ce combat (Dé pipé : 1 par combat).
var relances_gratuites: int = 0
## Relances « garder un rouleau, relancer les autres » disponibles (Cinquième as : 1 par combat).
var relances_cinquieme_as: int = 0
## La relance gratuite « de partie » (avantage du Comptoir) : utilisable une fois dans toute la partie,
## après celles des reliques. Partie la donne au combat et reprend ce qui n'a pas servi.
var relances_de_partie: int = 0
## Ce que rapporte une mise d'or gagnée : 3 fois la mise (2 avec le Mauvais œil).
var gain_mise_or: int = Mise.MULTIPLICATEUR_GAIN_OR

# --- Ce que les ennemis ajoutent (voir EnemyData.passif et .ouverture) -------
## Crânes temporaires ajoutés au sac DU COMBAT (le vrai sac du joueur n'est jamais touché).
var cranes_temporaires: int = 0
## Attaque gagnée pour de bon par l'ennemi (Usurier : à chaque tour où le joueur a misé).
var bonus_attaque_ennemi: int = 0
## La règle de machine en vigueur pour le tirage en cours (Grand Croupier), "" = aucune.
var regle_active: String = ""
## Ce qui s'est passé avant le premier tirage (attaque surprise de la Mimique), pour l'afficher.
var journal_ouverture: Array[String] = []
var _ouverture_jouee: bool = false

# --- Le tour en deux temps : tirer, (relancer), valider ---------------------
## Vrai entre tirer() et valider() : les rouleaux sont affichés, les effets pas encore appliqués.
var tirage_en_attente: bool = false
## Les symboles du tirage en cours (null = rouleau vide ou bloqué).
var grille_courante: Array[SymbolData] = []
## Le résultat calculé de ce tirage (effets, combos), appliqué par valider().
var resultat_courant: ResultatTirage
## La mise choisie pour ce tour.
var mise_en_cours: Mise
## Les rouleaux qui étaient bloqués par l'ennemi pour ce tirage (jouer_tour les libère ensuite).
var bloques_du_tirage: Array[int] = []

var _machine: MachineASous
var _sac: Sac
var _modificateurs: Modificateurs
## Les symboles tels que tirés du sac, avant le Trèfle (pour garder un rouleau à la relance).
var _origine: Array[SymbolData] = []
var _notes_relances: Array[String] = []

var _hasard: RandomNumberGenerator
var _nb_rouleaux: int
## L'or que le joueur avait en entrant dans le combat.
var _or_depart: int


## `hasard` sert à choisir les rouleaux bloqués : on passe le générateur de la partie
## pour garder un seul hasard rejouable. `nb_rouleaux` = nombre de cases de la machine.
## `or_joueur` = l'or que le joueur possède, pour savoir combien un voleur peut lui prendre.
func _init(donnees: EnemyData, pv_depart: int = PV_JOUEUR_DEPART, pv_max: int = PV_JOUEUR_DEPART,
		hasard: RandomNumberGenerator = null, nb_rouleaux: int = 5, or_joueur: int = 0) -> void:
	ennemi = donnees
	pv_ennemi = donnees.pv_max
	pv_max_ennemi = donnees.pv_max
	pv_joueur = pv_depart
	pv_max_joueur = pv_max
	_hasard = hasard if hasard != null else RandomNumberGenerator.new()
	_nb_rouleaux = nb_rouleaux
	_or_depart = or_joueur
	if bool(donnees.passif.get("regle_par_tour", false)):
		regle_active = _tirer_regle("")


## Donne au combat de quoi tirer lui-même (tour en deux temps) : la machine, le sac du joueur
## et ce que ses reliques changent. Sans cet appel, tirer() ne fait rien (jouer_tour() marche toujours).
func preparer_tirages(machine: MachineASous, sac: Sac, modificateurs: Modificateurs) -> void:
	_machine = machine
	# Le combat tire dans SA copie du sac : les crânes temporaires des ennemis n'y survivent pas.
	_sac = sac.copie()
	_modificateurs = modificateurs if modificateurs != null else Modificateurs.new()


## Premier temps du tour : tire les rouleaux (ceux que l'ennemi a bloqués restent vides, le Trèfle
## transforme des crânes en pièces) et calcule le résultat, sans l'appliquer. `mise` est la mise du tour.
## Renvoie faux si on ne peut pas tirer (combat fini, tirage déjà en attente, combat non préparé).
func tirer(mise: Mise = null) -> bool:
	if _machine == null or est_fini() or tirage_en_attente:
		return false
	mise_en_cours = mise
	bloques_du_tirage = rouleaux_bloques.duplicate()
	_notes_relances = []
	_nouveau_tirage(-1)
	tirage_en_attente = true
	return true


## Une relance est-elle possible maintenant ? (tirage affiché et une relique de relance disponible)
func peut_relancer() -> bool:
	return tirage_en_attente and (relances_toutes_les_cases() > 0 or relances_cinquieme_as > 0)


## Combien de relances de tous les rouleaux sont encore possibles (reliques, puis relance de partie).
func relances_toutes_les_cases() -> int:
	return relances_gratuites + relances_de_partie


## Dé pipé : relance tous les rouleaux (les rouleaux bloqués restent bloqués). Une fois par combat.
func relancer_tout() -> bool:
	if not tirage_en_attente or relances_toutes_les_cases() <= 0:
		return false
	if relances_gratuites > 0:
		relances_gratuites -= 1
	else:
		relances_de_partie -= 1
	_nouveau_tirage(-1)
	_notes_relances.append(tr("Dé pipé : tous les rouleaux sont relancés"))
	return true


## Cinquième as : garde le rouleau `index` (0 = celui de gauche) et relance les autres.
## Un rouleau vide ou bloqué ne peut pas être gardé. Une fois par combat.
func relancer_en_gardant(index: int) -> bool:
	if not tirage_en_attente or relances_cinquieme_as <= 0:
		return false
	if index < 0 or index >= grille_courante.size() or grille_courante[index] == null:
		return false
	relances_cinquieme_as -= 1
	_nouveau_tirage(index)
	_notes_relances.append(tr("Cinquième as : le rouleau %d est gardé, les autres sont relancés") % (index + 1))
	return true


## Second temps du tour : applique le tirage affiché et la mise, puis l'ennemi agit.
## Renvoie le détail du tour (relances comprises), ligne par ligne.
func valider() -> Array[String]:
	var journal: Array[String] = []
	if not tirage_en_attente:
		return journal
	tirage_en_attente = false
	var mise := mise_en_cours
	mise_en_cours = null
	journal.append_array(_notes_relances)
	journal.append_array(jouer_tour(resultat_courant, mise))
	_retirer_symboles_a_usage_unique(journal)
	return journal


## Les symboles à usage unique (Bombe) visibles sur ce tirage quittent le sac DU COMBAT.
## Le vrai sac du joueur n'est jamais touché : ils reviennent au combat suivant.
func _retirer_symboles_a_usage_unique(journal: Array[String]) -> void:
	if _sac == null:
		return
	for symbole in grille_courante:
		if symbole != null and symbole.usage_unique and _sac.symboles.has(symbole):
			_sac.symboles.erase(symbole)
			journal.append(tr("%s : retiré du sac pour ce combat") % symbole.nom_affiche())


## Tire (ou retire) les rouleaux. `garde` = index d'un rouleau à conserver (-1 = aucun) : il reste
## tel quel et son symbole est retiré du sac pour les autres, qui sont tirés sans remise.
func _nouveau_tirage(garde: int) -> void:
	var nb := _machine.nb_cases()
	var reste := _sac.copie()
	if garde >= 0:
		reste.symboles.erase(_origine[garde])
	var tires := reste.tirer(nb - (1 if garde >= 0 else 0), _hasard)

	var origine: Array[SymbolData] = []
	var k := 0
	for i in nb:
		if i == garde:
			origine.append(_origine[garde])
		else:
			origine.append(tires[k])
			k += 1
	for index in bloques_du_tirage:
		if index >= 0 and index < nb and index != garde:
			origine[index] = null

	var grille := _machine.transformer_craniens(origine, _modificateurs.chance_crane_en_piece, _hasard)
	# Le symbole Trèfle change un crâne voisin en pièce (sans hasard, avant les combos).
	grille = _machine.transformer_voisins(grille)
	if garde >= 0:
		grille[garde] = grille_courante[garde]
	_origine = origine
	grille_courante = grille
	resultat_courant = _machine.resoudre(grille_courante,
			_modificateurs if regle_active.is_empty() else _modificateurs.avec_regle(regle_active))


## L'or que le joueur possède en ce moment : celui d'avant le combat, plus les pièces
## tirées, moins ce qu'on lui a volé.
func or_du_joueur() -> int:
	return _or_depart + or_gagne - or_vole


func est_fini() -> bool:
	return etat != Etat.EN_COURS


## L'intention de l'ennemi pour ce tour ({} si l'ennemi n'a aucune intention).
func intention_actuelle() -> Dictionary:
	if ennemi.intentions.is_empty():
		return {}
	return ennemi.intentions[index_intention % ennemi.intentions.size()]


## L'intention telle que le joueur la voit : l'attaque comprend la force gagnée par l'ennemi
## (Usurier). Les crânes du tirage, eux, s'ajoutent au tirage (ils ne sont pas connus d'avance).
func intention_affichee() -> Dictionary:
	var intention := intention_actuelle().duplicate()
	if intention.get("type", "") == Intentions.ATTAQUE:
		intention["valeur"] = int(intention.get("valeur", 0)) + bonus_attaque_ennemi
	return intention


## Joue l'ouverture de l'ennemi (attaque surprise de la Mimique) avant le premier tirage.
## À appeler une fois, quand le combat commence ; les appels suivants ne font rien.
## L'ouverture n'achève jamais le joueur : elle lui laisse au moins 1 PV (c'est une surprise, pas
## une exécution). Renvoie les lignes du journal (aussi gardées dans journal_ouverture).
func jouer_ouverture() -> Array[String]:
	var journal: Array[String] = []
	if _ouverture_jouee or ennemi.ouverture.is_empty() or est_fini():
		return journal
	_ouverture_jouee = true
	if ennemi.ouverture.get("type", "") == Intentions.ATTAQUE:
		var degats := mini(int(ennemi.ouverture.get("valeur", 0)), pv_joueur - 1)
		pv_joueur -= degats
		journal.append(tr("%s attaque par surprise : %d dégâts") % [tr(ennemi.nom), degats])
	journal_ouverture = journal
	return journal


## Le joueur peut-il faire cette mise maintenant ?
## Mise d'or : un montant autorisé et assez d'or. Quitte ou double : plus de 5 PV
## (pour ne jamais se tuer soi-même en misant). Pas de mise : toujours.
func peut_miser(mise: Mise) -> bool:
	if mise == null:
		return true
	match mise.type:
		Mise.Type.OR:
			return mise.montant in Mise.MONTANTS_OR and or_du_joueur() >= mise.montant
		Mise.Type.QUITTE_OU_DOUBLE:
			return pv_joueur > Mise.PV_QUITTE_OU_DOUBLE
	return true


## Joue un tour complet à partir du résultat du tirage et de la mise (aucune si null).
## Renvoie le détail du tour, ligne par ligne. Ne fait rien si le combat est fini.
func jouer_tour(resultat: ResultatTirage, mise: Mise = null) -> Array[String]:
	var journal: Array[String] = []
	if est_fini():
		return journal

	# Les rouleaux bloqués ont servi pour ce tirage : ils sont libres à nouveau.
	rouleaux_bloques = []

	# La mise est réglée d'abord (même si le tirage tue l'ennemi).
	if mise != null and mise.type != Mise.Type.AUCUNE:
		if peut_miser(mise):
			_regler_mise(mise, resultat, journal)
			var renfort := int(ennemi.passif.get("attaque_par_mise", 0))
			if renfort > 0:
				bonus_attaque_ennemi += renfort
				journal.append(tr("%s se renforce : +%d attaque pour le reste du combat") % [tr(ennemi.nom), renfort])
		else:
			journal.append(tr("Mise impossible : elle est annulée."))

	# 1. Effets du tirage, dans l'ordre de Effets.ORDRE.
	# (Règle du Grand Croupier : des épées soignent l'ennemi, avant que les dégâts ne tombent.)
	var soin_ennemi := mini(resultat.total("soin_ennemi"), pv_max_ennemi - pv_ennemi)
	if soin_ennemi > 0:
		pv_ennemi += soin_ennemi
		journal.append(tr("%s se soigne de %d PV") % [tr(ennemi.nom), soin_ennemi])

	var degats := resultat.total("degats")
	if degats > 0:
		var absorbes := mini(armure_ennemi, degats)
		armure_ennemi -= absorbes
		pv_ennemi = maxi(0, pv_ennemi - (degats - absorbes))
		journal.append(tr("Tu infliges %d dégâts") % degats)
		if absorbes > 0:
			journal.append(tr("Son armure absorbe %d") % absorbes)

	var armure := resultat.total("armure")
	if armure > 0:
		armure_joueur += armure
		journal.append(tr("Tu gagnes %d armure") % armure)

	var soin := mini(resultat.total("soin"), pv_max_joueur - pv_joueur)
	if soin > 0:
		pv_joueur += soin
		journal.append(tr("Tu te soignes de %d PV") % soin)

	var or_tire := resultat.total("or")
	if or_tire > 0:
		or_gagne += or_tire
		journal.append(tr("Tu gagnes %d or") % or_tire)

	var perte := resultat.total("perte_pv")
	if perte > 0:
		# Les crânes font mal « immédiatement » : l'armure ne protège pas.
		pv_joueur = maxi(0, pv_joueur - perte)
		journal.append(tr("Les crânes te font perdre %d PV") % perte)

	# 2. Victoire ou défaite avant l'action de l'ennemi.
	if pv_ennemi <= 0:
		etat = Etat.VICTOIRE
		or_gagne += ennemi.or_victoire
		journal.append(tr("%s est vaincu !") % tr(ennemi.nom))
		return journal
	if pv_joueur <= 0:
		etat = Etat.DEFAITE
		journal.append(tr("Tu es à terre..."))
		return journal

	# 3. Action de l'ennemi.
	_jouer_intention(resultat.total("malus_ennemi"), journal)
	if pv_joueur <= 0:
		etat = Etat.DEFAITE
		journal.append(tr("Tu es à terre..."))
		return journal

	if etat == Etat.FUITE:
		return journal

	# 4. Fin de tour : l'armure retombe, les passifs de l'ennemi agissent.
	armure_joueur = 0
	index_intention += 1
	numero_tour += 1
	_jouer_passif(journal)
	return journal


## Règle une mise d'après le tirage (voir « Mise et prise de risque » du cahier des charges).
## Mise d'or : un combo qui n'est pas un combo de crânes => on reçoit 3 fois la mise ;
## sinon la mise est perdue (le Jeton porte-bonheur la rembourse une fois par combat).
## Quitte ou double : aucun crâne visible => effets positifs doublés ; sinon -5 PV.
func _regler_mise(mise: Mise, resultat: ResultatTirage, journal: Array[String]) -> void:
	match mise.type:
		Mise.Type.OR:
			if resultat.a_combo_hors_cranes():
				var gain := mise.montant * (gain_mise_or - 1)
				or_gagne += gain
				journal.append(tr("Mise de %d or gagnée : tu reçois %d or (+%d)") % [
					mise.montant, mise.montant * gain_mise_or, gain])
			else:
				or_gagne -= mise.montant
				journal.append(tr("Mise de %d or perdue") % mise.montant)
				if remboursements_de_mise > 0:
					remboursements_de_mise -= 1
					or_gagne += mise.montant
					journal.append(tr("Jeton porte-bonheur : ta mise est remboursée"))
		Mise.Type.QUITTE_OU_DOUBLE:
			if resultat.nb_cranes() == 0:
				resultat.doubler_effets_positifs()
				journal.append(tr("Quitte ou double gagné : effets positifs doublés !"))
			else:
				# Comme les crânes, la perte est immédiate : l'armure ne protège pas.
				pv_joueur = maxi(0, pv_joueur - Mise.PV_QUITTE_OU_DOUBLE)
				journal.append(tr("Quitte ou double perdu : tu perds %d PV") % Mise.PV_QUITTE_OU_DOUBLE)


## L'ennemi exécute son intention. `bonus_attaque` vient des crânes du tirage.
func _jouer_intention(bonus_attaque: int, journal: Array[String]) -> void:
	# L'armure de l'ennemi a protégé pendant le tirage : elle retombe maintenant.
	armure_ennemi = 0

	var intention := intention_actuelle()
	var valeur := int(intention.get("valeur", 0))
	match intention.get("type", ""):
		Intentions.ATTAQUE:
			var total := valeur + bonus_attaque_ennemi + bonus_attaque
			var absorbes := mini(armure_joueur, total)
			armure_joueur -= absorbes
			pv_joueur = maxi(0, pv_joueur - (total - absorbes))
			journal.append(tr("%s attaque : %d dégâts") % [tr(ennemi.nom), total])
			if absorbes > 0:
				journal.append(tr("Ton armure absorbe %d") % absorbes)
		Intentions.PROTECTION:
			armure_ennemi += valeur
			journal.append(tr("%s se protège (+%d armure)") % [tr(ennemi.nom), valeur])
		Intentions.BLOCAGE:
			# Des rouleaux différents, tirés au hasard, restent vides au prochain tirage.
			var libres: Array[int] = []
			for i in _nb_rouleaux:
				libres.append(i)
			for k in mini(valeur, libres.size()):
				var choisi := _hasard.randi_range(0, libres.size() - 1)
				rouleaux_bloques.append(libres[choisi])
				libres.remove_at(choisi)
			journal.append(tr("%s bloque %d rouleau au prochain tirage") % [tr(ennemi.nom), valeur])
		Intentions.CHARGE:
			journal.append(tr("%s se prépare à frapper") % tr(ennemi.nom))
		Intentions.FUITE:
			etat = Etat.FUITE
			journal.append(tr("%s s'enfuit !") % tr(ennemi.nom))
		Intentions.VOL:
			# Il ne peut pas voler plus que ce que le joueur possède.
			var vole := mini(valeur, maxi(0, or_du_joueur()))
			or_vole += vole
			if vole > 0:
				journal.append(tr("%s te vole %d or") % [tr(ennemi.nom), vole])
			else:
				journal.append(tr("%s tente de te voler mais tu n'as pas d'or") % tr(ennemi.nom))


## Les passifs de l'ennemi, en fin de tour : crânes temporaires dans le sac du combat, nouvelle règle.
func _jouer_passif(journal: Array[String]) -> void:
	var cranes := int(ennemi.passif.get("cranes_par_tour", 0))
	if cranes > 0 and _sac != null:
		var ajoutes := mini(cranes, MAX_CRANES_TEMPORAIRES - cranes_temporaires)
		if ajoutes > 0:
			_sac.ajouter(Sac.CRANE, ajoutes)
			cranes_temporaires += ajoutes
			journal.append(tr("%s glisse %d crâne(s) dans ta machine pour ce combat") % [tr(ennemi.nom), ajoutes])
	if bool(ennemi.passif.get("regle_par_tour", false)):
		regle_active = _tirer_regle(regle_active)
		journal.append(tr("Nouvelle règle : %s") % ReglesMachine.decrire(regle_active))


## Une règle de machine au hasard (avec le hasard du jeu), jamais la même deux tours de suite.
func _tirer_regle(precedente: String) -> String:
	var candidates: Array[String] = []
	for regle in ReglesMachine.TOUTES:
		if regle != precedente:
			candidates.append(regle)
	return candidates[_hasard.randi_range(0, candidates.size() - 1)]
