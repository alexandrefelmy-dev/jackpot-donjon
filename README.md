# Jackpot Donjon

Un roguelike solo en 2D : on descend un donjon, et chaque combat se joue en tirant le levier d'une machine à sous qu'on améliore au fil de la partie.

Une ligne de 5 rouleaux, tirés au hasard dans le « sac » de symboles du joueur. Trois symboles identiques côte à côte forment un combo (×1), quatre ×2, cinq un jackpot ×4. Le plaisir : voir sa machine devenir de plus en plus truquée en sa faveur.

Une partie traverse 3 étages : 5 combats obligatoires chacun, avec le choix entre 2 salles bonus (coffre, boutique ou repos) après les combats 2 et 4, puis un boss. Entre deux parties, le Comptoir du Croupier permet de dépenser les jetons d'âme gagnés pour débloquer des symboles, des reliques et des avantages.

Inspirations : Luck be a Landlord, Slay the Spire, Balatro.

**Statut : version 1.0** (jeu complet, export Windows en un seul .exe) ; prochaine étape possible : v1.1, la version anglaise. Projet personnel, développé avec l'aide de l'IA.

## Jouer

### Avec le .exe (Windows 10 ou 11, 64 bits)

Le jeu s'exporte en **un seul fichier**, `jackpot-donjon.exe`, qui n'a besoin ni de Godot ni d'installation : un double-clic suffit. Ce fichier n'est pas stocké dans le dépôt Git (il est trop gros) : on le fabrique avec la commande ci-dessous. Il sort dans le dossier `build/` :

- `build/windows/jackpot-donjon.exe` : le jeu ;
- `build/jackpot-donjon-1.0-windows.zip` : le jeu, un `LISEZMOI.txt` et les crédits, prêts à envoyer à quelqu'un.

```
python outils/exporter.py
```

Au premier lancement, Windows peut afficher un avertissement (le jeu n'est pas signé) : « Informations complémentaires », puis « Exécuter quand même ».

Pour fabriquer l'exe, il faut : Godot 4.7.2 avec ses **modèles d'export** installés (Éditeur, « Gérer les modèles d'export », version 4.7.2 ; ils vont dans `%APPDATA%\Godot\export_templates\4.7.2.stable\`), et, pour y écrire l'icône et le nom du jeu, l'outil gratuit [rcedit](https://github.com/electron/rcedit) indiqué dans les paramètres de l'éditeur (`export/windows/rcedit`). Les détails sont dans `outils/README.md` et dans le fichier `export_presets.cfg`.

### Commandes

- **Souris** : tout se joue à la souris.
- **Espace** (ou **Entrée**) : tirer le levier, valider un tirage, passer l'animation des rouleaux.
- **Échap** : retour dans les menus.
- **Alt + Entrée**, ou le bouton ⛶ en haut à droite : plein écran.

### Vos données

Le profil (jetons d'âme, déblocages, records) et les options sont enregistrés dans `%APPDATA%\Godot\app_userdata\jackpot donjon\`. Supprimer ce dossier fait repartir de zéro.

### Depuis l'éditeur Godot (pour développer)

1. Installer [Godot 4.7](https://godotengine.org/download) (version standard, GDScript).
2. Ouvrir le dossier du projet dans Godot (`project.godot`).
3. Appuyer sur F5 : le jeu s'ouvre sur le menu principal (avec le son !). Des boutons « [test] » n'apparaissent que dans ce mode : aller directement au boss, recevoir une relique en combat, +30 or en boutique. L'écran de test de la machine est `scenes/machine_test.tscn`.

Le plein écran est refusé dans la fenêtre intégrée de l'éditeur (Godot ne l'accepte pas) : pour l'essayer, désactiver « Embed Game on Next Play » dans l'onglet Jeu, ou lancer le `.exe`.

## Lancer les tests

```
godot --headless --path . --import
godot --headless --path . -s res://tests/test_machine.gd
godot --headless --path . -s res://tests/test_combat.gd
godot --headless --path . -s res://tests/test_partie.gd
godot --headless --path . -s res://tests/test_boutique.gd
godot --headless --path . -s res://tests/test_reliques.gd
godot --headless --path . -s res://tests/test_mises.gd
godot --headless --path . -s res://tests/test_donjon.gd
godot --headless --path . -s res://tests/test_ennemis.gd
godot --headless --path . -s res://tests/test_profil.gd
godot --headless --path . -s res://tests/test_comptoir.gd
godot --headless --path . -s res://tests/test_symboles.gd
godot --headless --path . -s res://tests/test_options.gd
godot --headless --path . -s res://tests/test_audio.gd
godot --headless --path . -s res://tests/test_impacts.gd
godot --headless --path . -s res://tests/test_images.gd
godot --headless --path . -s res://tests/test_stats.gd
godot --headless --path . -s res://tests/test_interface.gd
```

Sous Windows, utiliser l'exécutable `..._console.exe` de Godot. Le script affiche `ok` ou `ÉCHEC` pour chaque test et se termine avec le code 1 en cas d'échec.

D'autres outils de vérification (équilibrage par des « robots », parties entières simulées, captures d'écran, vrais clics, temps par image) sont décrits dans [`outils/README.md`](outils/README.md).

## Documentation

Les règles, les valeurs et les jalons (v0.1 à v1.1) sont dans [`docs/cahier-des-charges.md`](docs/cahier-des-charges.md). Les images, sons et musiques viennent de ressources libres (CC0) : voir [`docs/CREDITS.md`](docs/CREDITS.md).

## Organisation

| Dossier | Contenu |
| --- | --- |
| `scenes/` | scènes et leur script (menu, options, Comptoir, portes, combat, récompense, relique, boutique, repos, fin de partie, test de la machine) |
| `scripts/` | logique : sac, tirage, combos, effets, combat, mises, partie, statistiques, boutique, reliques, profil, interface |
| `data/` | symboles, ennemis et reliques, un fichier `.tres` chacun ; tables des sons et des musiques |
| `assets/` | images (pack 0x72), sons, musiques, shaders, icône du jeu, manifeste des licences |
| `tests/` | tests en ligne de commande |
| `outils/` | outils : équilibrage, parties simulées, captures d'écran, vrais clics, mesure des performances, export Windows |
| `docs/` | cahier des charges, crédits et licences (`CREDITS.md`), `LISEZMOI.txt` livré avec le jeu |
| `build/` | le jeu exporté (`.exe` et `.zip`), fabriqué par `outils/exporter.py` et ignoré par Git |
