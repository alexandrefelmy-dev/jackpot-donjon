extends Control
## Scène de test de la v0.1 : 5 rouleaux, on tire le levier et on voit le résultat.
## Pas encore d'ennemi ni de PV : on vérifie juste que la machine calcule juste.

const TAILLE_CASE := Vector2(120, 160)
const COULEUR_FOND := Color("1b1a24")
const COULEUR_CASE_VIDE := Color("2c2a38")
const COULEUR_COMBO := Color("ffd34d")

var machine := MachineASous.new(5, 1)
var sac: Sac
var rng := RandomNumberGenerator.new()

var cases: Array[PanelContainer] = []
var etiquettes: Array[Label] = []
var texte_resultat: RichTextLabel
var texte_graine: Label


func _ready() -> void:
	rng.randomize()
	sac = Sac.creer_sac_de_depart()
	_construire_interface()
	texte_graine.text = tr("Graine : %d") % rng.seed


func _unhandled_input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche and touche.pressed and not touche.echo and touche.keycode == KEY_SPACE:
		_tirer()


func _tirer() -> void:
	var grille := machine.tirer(sac, rng)
	var resultat := machine.resoudre(grille)
	for i in grille.size():
		_dessiner_case(i, grille[i], i in resultat.cases_en_combo)
	_afficher_resultat(resultat)


# --- Affichage -------------------------------------------------------------

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
		var couleur_texte := Color.BLACK if symbole.couleur.get_luminance() > 0.5 else Color.WHITE
		etiquette.add_theme_color_override("font_color", couleur_texte)
		cases[index].tooltip_text = "%s\n%s\n%s" % [
			tr(symbole.nom),
			symbole.decrire_base(),
			tr("Combo de 3 : %s") % symbole.decrire_combo(),
		]

	if en_combo:
		style.set_border_width_all(6)
		style.border_color = COULEUR_COMBO

	cases[index].add_theme_stylebox_override("panel", style)


func _afficher_resultat(resultat: ResultatTirage) -> void:
	var texte := PackedStringArray()

	if resultat.combos.is_empty():
		texte.append(tr("Pas de combo."))
	else:
		for combo in resultat.combos:
			var titre := tr("JACKPOT !!!") if combo.est_jackpot() else tr("COMBO !")
			texte.append("[color=#ffd34d][b]%s[/b] %s[/color]" % [
				titre, tr("%d × %s, effet ×%d") % [
					combo.longueur, tr(combo.symbole.nom), combo.multiplicateur]])

	texte.append("")
	texte.append("[b]%s[/b]" % tr("Total du tirage"))
	if resultat.totaux.is_empty():
		texte.append(tr("aucun effet"))
	else:
		texte.append(Effets.decrire(resultat.totaux, "\n"))

	texte.append("")
	texte.append("[b]%s[/b]" % tr("Détail"))
	for ligne_journal in resultat.journal:
		texte.append(ligne_journal)

	texte_resultat.text = "\n".join(texte)


# --- Construction de l'interface (en code, pour la v0.1) -------------------

func _construire_interface() -> void:
	var fond := ColorRect.new()
	fond.color = COULEUR_FOND
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)

	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for cote in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marge.add_theme_constant_override(cote, 32)
	add_child(marge)

	var ecran := HBoxContainer.new()
	ecran.add_theme_constant_override("separation", 48)
	marge.add_child(ecran)

	_construire_colonne_machine(ecran)
	_construire_colonne_resultat(ecran)


func _construire_colonne_machine(parent: Control) -> void:
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 16)
	parent.add_child(colonne)

	var titre := Label.new()
	titre.text = tr("Jackpot Donjon — test de la machine")
	titre.add_theme_font_size_override("font_size", 26)
	colonne.add_child(titre)

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
		_dessiner_case(i, null, false)

	var bouton := Button.new()
	bouton.text = tr("Tirer le levier (Espace)")
	bouton.custom_minimum_size = Vector2(0, 56)
	bouton.focus_mode = Control.FOCUS_NONE  # sinon Espace déclencherait 2 tirages
	bouton.pressed.connect(_tirer)
	colonne.add_child(bouton)

	var infos_sac := Label.new()
	infos_sac.text = tr("Sac : %d symboles") % sac.taille()
	infos_sac.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	colonne.add_child(infos_sac)


func _construire_colonne_resultat(parent: Control) -> void:
	var colonne := VBoxContainer.new()
	colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.add_theme_constant_override("separation", 12)
	parent.add_child(colonne)

	var titre := Label.new()
	titre.text = tr("Résultat du tirage")
	titre.add_theme_font_size_override("font_size", 22)
	colonne.add_child(titre)

	texte_resultat = RichTextLabel.new()
	texte_resultat.bbcode_enabled = true
	texte_resultat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texte_resultat.add_theme_font_size_override("normal_font_size", 18)
	texte_resultat.add_theme_font_size_override("bold_font_size", 18)
	texte_resultat.text = tr("Tire le levier pour lancer la machine.")
	colonne.add_child(texte_resultat)

	texte_graine = Label.new()
	texte_graine.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	colonne.add_child(texte_graine)
