extends Control
## Écran du choix des salles bonus : après les combats 2 et 4 de chaque étage, 2 portes au choix. Chaque porte
## montre le type de salle (boutique, coffre ou repos). Le combat, lui, n'est jamais au choix.
## Ensuite la partie dit quel écran afficher (boutique, relique, repos, ou le combat d'une mimique).

const COULEUR_FOND := Color("1b1a24")
const TAILLE_PORTE := Vector2(330, 340)
const COULEUR_BOSS := Color("ff9a5c")

## Couleur de chaque type de salle (en attendant les vrais graphismes).
const COULEURS: Dictionary = {
	Salle.Type.BOUTIQUE: Color("9c7424"),
	Salle.Type.COFFRE: Color("3b6f9c"),
	Salle.Type.REPOS: Color("3f7d4f"),
}

var partie: Partie
var portes: Array[Salle] = []
var boutons_portes: Array[Button] = []
## Le texte de chaque porte (titre et description), pour les tests et l'info-bulle.
var textes_portes: Array[String] = []


func _ready() -> void:
	partie = GameState.partie
	if partie.ecran != Partie.Ecran.PORTES:
		GameState.rediriger()
		return
	GameState.demarrer()
	Musique.jouer_pour(partie)
	portes = partie.portes()
	_construire_interface()


## Le joueur franchit la porte `index` : la partie décide de l'écran suivant.
func _choisir(index: int) -> void:
	for bouton in boutons_portes:
		bouton.disabled = true
	if partie.choisir_porte(index):
		Son.jouer(&"clic")
		GameState.aller_a_suivant()


## Ce que le joueur sait d'une porte : ce qu'on y fait, jamais ce qui s'y cache.
func _description(salle: Salle) -> String:
	match salle.type:
		Salle.Type.BOUTIQUE:
			return tr("Achète, retire ou dore des symboles, achète des reliques, soigne-toi.")
		Salle.Type.COFFRE:
			var texte := tr("Une relique gratuite : tu en choisis 1 parmi 2.")
			if partie.etage == Donjon.ETAGE_DES_MIMIQUES:
				texte += "\n\n" + tr("Méfie-toi : à cet étage, certains coffres sont des mimiques.")
			return texte
		Salle.Type.REPOS:
			return tr("Soigne %d %% de tes PV max (%d PV maintenant), ou rends un symbole doré gratuitement.") % [
				Partie.SOIN_REPOS_POURCENT, partie.soin_du_repos()]
	return ""


func _construire_interface() -> void:
	Cartes.ajouter_fond(self, COULEUR_FOND, true)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 14)
	centre.add_child(colonne)

	var titre := Label.new()
	titre.text = tr("Étage %d — %s") % [partie.etage, partie.nom_etage()]
	titre.add_theme_font_size_override("font_size", 34)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Habillage.titre(titre)
	colonne.add_child(titre)

	var avancee := Label.new()
	avancee.text = tr("Combat %d / %d gagné — choisis une salle bonus") % [partie.pas, Donjon.NB_PAS]
	avancee.add_theme_font_size_override("font_size", 22)
	avancee.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(avancee)

	colonne.add_child(_creer_progression())

	var infos := Label.new()
	infos.text = tr("PV : %d / %d     Or : %d     Sac : %d symboles     Reliques : %d") % [
		partie.pv, partie.pv_max, partie.or_total, partie.sac.taille(), partie.reliques.size()]
	infos.add_theme_font_size_override("font_size", 18)
	infos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(infos)

	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 40)
	rangee.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_child(rangee)
	for i in portes.size():
		var porte := _creer_porte(portes[i], i)
		rangee.add_child(porte)
		boutons_portes.append(porte)


## Une rangée de jetons : les combats gagnés (verts), le prochain combat (doré), ceux à venir, puis le boss.
func _creer_progression() -> Control:
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 10)
	rangee.alignment = BoxContainer.ALIGNMENT_CENTER
	for numero in range(1, Donjon.NB_PAS + 1):
		# Un jeton rond par salle : vert pour les salles faites, doré pour celle à choisir, sombre pour les suivantes.
		var case_pas := Panel.new()
		case_pas.custom_minimum_size = Vector2(26, 26)
		case_pas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var jeton := StyleBoxFlat.new()
		jeton.set_corner_radius_all(13)
		jeton.set_border_width_all(3)
		jeton.border_color = Habillage.COULEUR_OR_SOMBRE
		if numero <= partie.pas:
			jeton.bg_color = Color("3fae5c")
		elif numero == partie.pas + 1:
			jeton.bg_color = Cartes.COULEUR_SURVOL
			jeton.border_color = Color.WHITE
		else:
			jeton.bg_color = Color("2a1f3a")
		case_pas.add_theme_stylebox_override("panel", jeton)
		rangee.add_child(case_pas)
	var boss := Label.new()
	boss.text = tr("BOSS")
	boss.add_theme_color_override("font_color", COULEUR_BOSS)
	boss.add_theme_font_size_override("font_size", 16)
	rangee.add_child(boss)
	return rangee


## L'image de chaque type de salle (pack 0x72).
const ICONES: Dictionary = {
	Salle.Type.BOUTIQUE: "coin_anim_f0",
	Salle.Type.COFFRE: "chest_full_open_anim_f0",
	Salle.Type.REPOS: "flask_big_green",
}


## Une porte = une grosse carte colorée : le type de salle en grand, puis ce qu'on y fait.
func _creer_porte(salle: Salle, index: int) -> Button:
	var description := _description(salle)
	var porte := Cartes.creer_carte(COULEURS[salle.type], salle.nom_type().to_upper(), description, TAILLE_PORTE,
			40, 19, Images.icone(ICONES[salle.type], 64), true)
	textes_portes.append(Cartes.texte_carte(porte))
	Cartes.neon(porte.get_meta("titre") as Label)
	porte.tooltip_text = tr("Franchir cette porte : %s") % salle.nom_type()
	porte.pressed.connect(_choisir.bind(index))
	return porte
