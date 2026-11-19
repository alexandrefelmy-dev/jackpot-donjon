extends Control
## Écran de combat de la v0.2 : un ennemi avec son intention, la machine à sous,
## les PV et l'armure du joueur. Victoire et défaite arrêtent le combat ; on peut rejouer.
## L'interface est construite en code (comme machine_test), les vrais décors viendront en v0.8.

## Les ennemis proposés dans le sélecteur (pour tester victoire et défaite).
const ENNEMIS: Array[String] = [
	"res://data/enemies/rat_egout.tres",
	"res://data/enemies/squelette.tres",
	"res://data/enemies/golem_jetons.tres",
]

const TAILLE_CASE := Vector2(120, 130)
const COULEUR_FOND := Color("1b1a24")
const COULEUR_CASE_VIDE := Color("2c2a38")
const COULEUR_COMBO := Color("ffd34d")
const COULEUR_VICTOIRE := Color("7ddc7d")
const COULEUR_DEFAITE := Color("ff6b6b")

var machine := MachineASous.new(5, 1)
var sac: Sac
var combat: Combat
var rng := RandomNumberGenerator.new()
var ennemis: Array[EnemyData] = []

var cases: Array[PanelContainer] = []
var etiquettes: Array[Label] = []

var selecteur: OptionButton
var panneau_ennemi: PanelContainer
var etiquettes_ennemi: Array[Label] = []
var texte_nom_ennemi: Label
var barre_pv_ennemi: ProgressBar
var texte_pv_ennemi: Label
var texte_intention: Label
var barre_pv_joueur: ProgressBar
var texte_pv_joueur: Label
var texte_or: Label
var texte_fin: Label
var bouton_levier: Button
var bouton_rejouer: Button
var texte_journal: RichTextLabel
var texte_graine: Label


func _ready() -> void:
	for chemin in ENNEMIS:
		ennemis.append(load(chemin) as EnemyData)
	_construire_interface()
	_nouveau_combat()


func _unhandled_input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche and touche.pressed and not touche.echo and touche.keycode == KEY_SPACE:
		_tirer()


## Prépare un combat tout neuf contre l'ennemi choisi dans le sélecteur.
func _nouveau_combat() -> void:
	rng.randomize()
	sac = Sac.creer_sac_de_depart()
	combat = Combat.new(ennemis[selecteur.selected])
	texte_graine.text = tr("Graine : %d") % rng.seed
	texte_journal.text = tr("Tire le levier pour lancer la machine.")

	for i in machine.nb_cases():
		_dessiner_case(i, null, false)

	var fond := StyleBoxFlat.new()
	fond.set_corner_radius_all(10)
	fond.bg_color = combat.ennemi.couleur
	panneau_ennemi.add_theme_stylebox_override("panel", fond)
	var couleur_texte := _couleur_texte(combat.ennemi.couleur)
	for etiquette in etiquettes_ennemi:
		etiquette.add_theme_color_override("font_color", couleur_texte)

	barre_pv_ennemi.max_value = combat.ennemi.pv_max
	barre_pv_joueur.max_value = combat.pv_max_joueur
	_rafraichir()


func _tirer() -> void:
	if combat.est_fini():
		return
	var numero_tour := combat.numero_tour
	var grille := machine.tirer(sac, rng)
	var resultat := machine.resoudre(grille)
	for i in grille.size():
		_dessiner_case(i, grille[i], i in resultat.cases_en_combo)
	var journal_combat := combat.jouer_tour(resultat)
	_afficher_tour(numero_tour, resultat, journal_combat)
	_rafraichir()


func _on_ennemi_choisi(_index: int) -> void:
	_nouveau_combat()


# --- Affichage -------------------------------------------------------------

func _couleur_texte(fond: Color) -> Color:
	return Color.BLACK if fond.get_luminance() > 0.5 else Color.WHITE


## Met à jour tout ce qui dépend de l'état du combat.
func _rafraichir() -> void:
	texte_nom_ennemi.text = tr(combat.ennemi.nom)
	barre_pv_ennemi.value = combat.pv_ennemi
	texte_pv_ennemi.text = tr("PV %d / %d   Armure %d") % [
		combat.pv_ennemi, combat.ennemi.pv_max, combat.armure_ennemi]

	if combat.est_fini():
		texte_intention.text = ""
	else:
		texte_intention.text = tr("Intention : %s") % Intentions.decrire(combat.intention_actuelle())

	barre_pv_joueur.value = combat.pv_joueur
	texte_pv_joueur.text = tr("Toi : PV %d / %d   Armure %d") % [
		combat.pv_joueur, combat.pv_max_joueur, combat.armure_joueur]
	texte_or.text = tr("Or gagné : %d") % combat.or_gagne

	match combat.etat:
		Combat.Etat.VICTOIRE:
			texte_fin.text = tr("VICTOIRE ! +%d or") % combat.ennemi.or_victoire
			texte_fin.add_theme_color_override("font_color", COULEUR_VICTOIRE)
		Combat.Etat.DEFAITE:
			texte_fin.text = tr("DÉFAITE... tu n'as plus de PV.")
			texte_fin.add_theme_color_override("font_color", COULEUR_DEFAITE)
		_:
			texte_fin.text = ""
	bouton_levier.disabled = combat.est_fini()
	bouton_rejouer.visible = combat.est_fini()


func _dessiner_case(index: int, symbole: SymbolData, en_combo: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	var etiquette := etiquettes[index]

	if symbole == null:
		style.bg_color = COULEUR_CASE_VIDE
		etiquette.text = tr("vide")
		etiquette.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
		cases[index].tooltip_text = ""
	else:
		style.bg_color = symbole.couleur
		etiquette.text = tr(symbole.nom)
		etiquette.add_theme_color_override("font_color", _couleur_texte(symbole.couleur))
		cases[index].tooltip_text = "%s\n%s\n%s" % [
			tr(symbole.nom),
			Effets.decrire(symbole.effet_base),
			tr("Combo de 3 : %s") % Effets.decrire(symbole.effet_combo),
		]

	if en_combo:
		style.set_border_width_all(6)
		style.border_color = COULEUR_COMBO

	cases[index].add_theme_stylebox_override("panel", style)


## Écrit ce qui s'est passé pendant le tour : combos, effets du tirage, puis le combat.
func _afficher_tour(numero_tour: int, resultat: ResultatTirage, journal_combat: Array[String]) -> void:
	var texte := PackedStringArray()
	texte.append("[b]%s[/b]" % (tr("Tour %d") % numero_tour))

	for combo in resultat.combos:
		var titre := tr("JACKPOT !!!") if combo.est_jackpot() else tr("COMBO !")
		texte.append("[color=#ffd34d][b]%s[/b] %s[/color]" % [
			titre, tr("%d × %s, effet ×%d") % [
				combo.longueur, tr(combo.symbole.nom), combo.multiplicateur]])

	texte.append("")
	texte.append("[b]%s[/b]" % tr("Tirage"))
	if resultat.totaux.is_empty():
		texte.append(tr("aucun effet"))
	else:
		texte.append(Effets.decrire(resultat.totaux, "\n"))

	texte.append("")
	texte.append("[b]%s[/b]" % tr("Combat"))
	for ligne in journal_combat:
		texte.append(ligne)

	texte_journal.text = "\n".join(texte)


# --- Construction de l'interface (en code, pour la v0.2) --------------------

func _construire_interface() -> void:
	var fond := ColorRect.new()
	fond.color = COULEUR_FOND
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)

	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for cote in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marge.add_theme_constant_override(cote, 24)
	add_child(marge)

	var ecran := HBoxContainer.new()
	ecran.add_theme_constant_override("separation", 40)
	marge.add_child(ecran)

	_construire_colonne_combat(ecran)
	_construire_colonne_journal(ecran)


func _construire_colonne_combat(parent: Control) -> void:
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 12)
	parent.add_child(colonne)

	# Titre et choix de l'ennemi.
	var ligne_titre := HBoxContainer.new()
	ligne_titre.add_theme_constant_override("separation", 16)
	colonne.add_child(ligne_titre)
	var titre := Label.new()
	titre.text = tr("Jackpot Donjon")
	titre.add_theme_font_size_override("font_size", 26)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne_titre.add_child(titre)
	selecteur = OptionButton.new()
	selecteur.focus_mode = Control.FOCUS_NONE  # sinon Espace ouvrirait la liste
	for donnees in ennemis:
		selecteur.add_item(tr(donnees.nom))
	selecteur.item_selected.connect(_on_ennemi_choisi)
	ligne_titre.add_child(selecteur)

	# L'ennemi : nom, PV, armure, intention.
	panneau_ennemi = PanelContainer.new()
	colonne.add_child(panneau_ennemi)
	var marge_ennemi := MarginContainer.new()
	for cote in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marge_ennemi.add_theme_constant_override(cote, 12)
	panneau_ennemi.add_child(marge_ennemi)
	var boite_ennemi := VBoxContainer.new()
	boite_ennemi.add_theme_constant_override("separation", 6)
	marge_ennemi.add_child(boite_ennemi)

	texte_nom_ennemi = _etiquette_ennemi(boite_ennemi, 24)
	barre_pv_ennemi = _creer_barre()
	boite_ennemi.add_child(barre_pv_ennemi)
	texte_pv_ennemi = _etiquette_ennemi(boite_ennemi, 18)
	texte_intention = _etiquette_ennemi(boite_ennemi, 22)

	# Les 5 rouleaux.
	var grille := GridContainer.new()
	grille.columns = machine.colonnes
	grille.add_theme_constant_override("h_separation", 10)
	grille.add_theme_constant_override("v_separation", 10)
	colonne.add_child(grille)
	for i in machine.nb_cases():
		var case_grille := PanelContainer.new()
		case_grille.custom_minimum_size = TAILLE_CASE
		var etiquette := Label.new()
		etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		etiquette.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		etiquette.add_theme_font_size_override("font_size", 20)
		case_grille.add_child(etiquette)
		grille.add_child(case_grille)
		cases.append(case_grille)
		etiquettes.append(etiquette)

	bouton_levier = Button.new()
	bouton_levier.text = tr("Tirer le levier (Espace)")
	bouton_levier.custom_minimum_size = Vector2(0, 52)
	bouton_levier.focus_mode = Control.FOCUS_NONE  # sinon Espace déclencherait 2 tirages
	bouton_levier.pressed.connect(_tirer)
	colonne.add_child(bouton_levier)

	# Le joueur : PV, armure, or.
	barre_pv_joueur = _creer_barre()
	colonne.add_child(barre_pv_joueur)
	texte_pv_joueur = Label.new()
	texte_pv_joueur.add_theme_font_size_override("font_size", 20)
	colonne.add_child(texte_pv_joueur)
	texte_or = Label.new()
	texte_or.add_theme_font_size_override("font_size", 18)
	colonne.add_child(texte_or)

	# Fin du combat.
	texte_fin = Label.new()
	texte_fin.add_theme_font_size_override("font_size", 26)
	colonne.add_child(texte_fin)
	bouton_rejouer = Button.new()
	bouton_rejouer.text = tr("Rejouer")
	bouton_rejouer.custom_minimum_size = Vector2(0, 44)
	bouton_rejouer.focus_mode = Control.FOCUS_NONE
	bouton_rejouer.pressed.connect(_nouveau_combat)
	colonne.add_child(bouton_rejouer)


func _construire_colonne_journal(parent: Control) -> void:
	var colonne := VBoxContainer.new()
	colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.add_theme_constant_override("separation", 12)
	parent.add_child(colonne)

	var titre := Label.new()
	titre.text = tr("Dernier tour")
	titre.add_theme_font_size_override("font_size", 22)
	colonne.add_child(titre)

	texte_journal = RichTextLabel.new()
	texte_journal.bbcode_enabled = true
	texte_journal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texte_journal.add_theme_font_size_override("normal_font_size", 18)
	texte_journal.add_theme_font_size_override("bold_font_size", 18)
	colonne.add_child(texte_journal)

	texte_graine = Label.new()
	texte_graine.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	colonne.add_child(texte_graine)


func _creer_barre() -> ProgressBar:
	var barre := ProgressBar.new()
	barre.show_percentage = false
	barre.custom_minimum_size = Vector2(0, 20)
	return barre


## Crée une étiquette du panneau de l'ennemi (sa couleur de texte suit celle de l'ennemi).
func _etiquette_ennemi(parent: Control, taille: int) -> Label:
	var etiquette := Label.new()
	etiquette.add_theme_font_size_override("font_size", taille)
	parent.add_child(etiquette)
	etiquettes_ennemi.append(etiquette)
	return etiquette
