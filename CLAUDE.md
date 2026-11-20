# Jackpot Donjon

Roguelike 2D où chaque combat se joue sur une machine à sous (1 ligne de 5 rouleaux, combos de 3/4/5).
Godot 4.7, GDScript. Projet perso d'Alex, fait pour le plaisir avec l'IA : Claude écrit le code, Alex teste avec F5.

## Références

- Règles du jeu, valeurs, jalons : `docs/cahier-des-charges.md` (copie locale).
  La version de référence est en ligne : https://claude.ai/artifact/7T7o7Bod8SKvpvXNtsJpef
  Lire la section concernée avant de toucher à une règle. Si une règle change, mettre à jour la copie locale et prévenir Alex de reporter le changement en ligne.

## État actuel

IMPORTANT : dès qu'une étape est terminée (ou avant qu'Alex quitte la session), mettre à jour cette section : ce qui est fait, ce qui reste à tester, la prochaine étape. Elle décrit seulement la situation d'aujourd'hui (10 lignes au plus), pas l'historique (il est dans git et dans le cahier des charges).

- **Fait** : v0.1 à v1.0 confirmées par Alex, fusionnées dans `main`, poussées sur GitHub (https://github.com/alexandrefelmy-dev/jackpot-donjon, étiquettes `v0.1` à `v1.0`) : machine à sous aux rouleaux qui défilent, donjon de 3 étages à combats obligatoires (5 par étage, 2 salles bonus au choix après les combats 2 et 4), boutique, mises, reliques, profil et records, Comptoir, malédictions, habillage casino, plein écran, statistiques de fin de partie, export Windows en un seul .exe (`python outils/exporter.py` : `build/windows/jackpot-donjon.exe` et `build/jackpot-donjon-1.0-windows.zip`, icône écrite par `rcedit`).
- **À reporter par Alex** : le cahier des charges EN LIGNE n'a pas les changements de la v0.8 ni de la v1.0 (plein écran, écran de combat, décor, nouvelle structure du donjon, ennemis normaux ×0,9, statistiques, records, export) : le texte est dans `docs/cahier-des-charges.md` (« Boucle de jeu », « Précisions de règles » v0.6, v0.8 et v1.0, jalon 9).
- **Équilibrage actuel** (400 parties par robot, `outils/equilibrage.gd`) : prudent 48 %, hasard 14 %, « tout » 18 %, prudent avec profil neuf 19 %, avec 3 malédictions 10 %, avec tous les avantages 31 %. À régler selon les retours d'Alex.
- **Problèmes connus** : aucun test en échec. Le .exe n'est pas signé (Windows peut avertir au premier lancement). Message « resources still in use at exit » à la fermeture avec de la musique (sans conséquence). Pistes de nettoyage écartées pour plus tard : état d'animation explicite dans `combat.gd`, son de clic global, icônes de salle en `.tres`, chargement asynchrone des musiques, politique du plein écran regroupée dans `GameState`, thème posé sur la racine plutôt que par `ajouter_fond`.
- **Prochaine étape** : v1.1 (version anglaise : traduction de tous les textes, choix de la langue dans les options) : plan à faire approuver par Alex avant de coder. Partir de `main` à jour (`git switch main`, puis `git switch -c v1.1-anglais`) et changer `Version.NUMERO`.

## Conventions

- **Jamais de touches F1 à F12 ni de raccourcis d'éditeur pour des fonctions de test** (dans l'éditeur Godot, F8 arrête le jeu et F9 le gèle) : le jeu se joue à la souris, utiliser des boutons « [test] ».
- **Le profil et les options du joueur ne s'écrivent que dans le jeu lui-même** : `GameState` n'écrit qu'après avoir chargé le vrai fichier, et jamais en mode sans fenêtre ; un test ou un outil n'écrit donc jamais dans le vrai fichier (tests du fichier : `user://tests_profil/`).
- **Exporter le jeu** : `python outils/exporter.py` (résultat dans `build/`, ignoré par git). Il faut les modèles d'export de Godot dans `%APPDATA%\Godot\export_templates\4.7.2.stable\` (installés sur le PC d'Alex) ; le préréglage est `export_presets.cfg`. Ne JAMAIS changer `config/name` dans `project.godot` : il fixe le dossier `user://` où vivent le profil et les options des joueurs (ils les perdraient). L'icône, le nom et la version sont écrits dans le .exe par `rcedit` (installé dans `C:\Toolscedit\`, indiqué dans les paramètres de l'éditeur Godot : `export/windows/rcedit`, avec `application/modify_resources=true` dans le préréglage). Fermer l'éditeur Godot avant de modifier `export_presets.cfg` ou `project.godot`.
- Les journaux du jeu lancé par Alex sont dans `%APPDATA%\Godot\app_userdata\jackpot donjon\logs\` (Godot n'en garde que 5 : lancer des tests les fait tourner). Quand Alex rapporte un bug, lire ce dossier AVANT de lancer quoi que ce soit.
- L'animation des rouleaux n'existe que dans une vraie fenêtre ; en mode sans fenêtre elle est sautée (sauf `forcer_animation`). Un script qui joue dans une vraie fenêtre appelle `ecran._terminer_animation()` après `_tirer()`.
- Après tout changement d'écran, relancer `test_interface` (les boutons doivent tenir dans 1152×648).
- GDScript typé statiquement. Noms de variables, fonctions et commentaires en français.
- Tout texte affiché au joueur passe par `tr()` (traduction anglaise prévue en v1.1).
- Le contenu du jeu (symboles, ennemis, reliques) vit dans des ressources `.tres` sous `data/`, jamais en dur dans le code.
- La taille de la machine est un paramètre : `MachineASous.new(colonnes, lignes)`.
- Les valeurs chiffrées sont des valeurs de départ, réglables dans les `.tres`.

## Structure

- `scripts/data/` : classes de données (`SymbolData`…)
- `scripts/machine/` : sac, tirage, détection des combos, résultat
- `scripts/combat/` : `Combat` (tour par tour en deux temps, PV, armure, victoire/défaite, rouleaux bloqués, mises, relances), `Intentions`, `Mise`
- `scripts/machine/modificateurs.gd` : `Modificateurs` (ce que les reliques changent dans le calcul d'un tirage)
- `scripts/partie/` : `Partie` (état et règles d'une partie : PV, or, sac, étage et pas, combat obligatoire de chaque pas, portes bonus, récompenses, reliques, effets du profil), `Donjon` et `Salle` (disposition du donjon : 5 combats et 2 choix de salles bonus par étage, fixée par la graine), `Boutique` (prix et actions de la boutique, symboles et reliques), `Reliques` (liste des 9 reliques)
- `data/relics/` : un `.tres` par relique (prix, description, paramètres des effets)
- `scripts/profil/` : `Profil` (ce qui survit d'une partie à l'autre), `ProfilFichier` (lecture et écriture sûres), `Comptoir` (achats et prix), `Maledictions`, `Bilan` (fin de partie vers le profil)
- `scripts/options/` : `Options`, `OptionsFichier`, `Entrees` ; `scripts/audio/` : `Son`, `Musique`, `TableSons` ; `scripts/ui/` : `Cartes` (styles de boutons, fond, néon), `Decor` et `Habillage` (décor et thème communs), `CadreAmpoules` et `OrnementCarte` (portes et cartes), `MeubleMachine`, `Ampoules`, `LevierMachine` (la machine à sous du combat), `ChronologieRouleaux` (minutage des arrêts), `PleinEcran`, `Impacts` et `Secousse` (effets de jeu), `Images` et `ImageAnimee` (pack 0x72), `RetourTour` (quels sons pour un tour)
- `assets/` : `images/` (pack 0x72 + 3 icônes dessinées), `sons/`, `musiques/`, `shaders/`, `manifeste.json` (source et licence de chaque fichier)
- `scripts/game_state.gd` : classe `GameState` à membres statiques, PAS un autoload (garde la partie, change d'écran ; aucune règle dedans)
- `scenes/` : scènes et leur script (`combat.tscn` = écran principal, puis `comptoir.tscn`, `portes.tscn`, `repos.tscn`, `recompense.tscn`, `relique.tscn`, `boutique.tscn` et `fin_partie.tscn` ; `machine_test.tscn` = test de la machine)
- `data/symbols/` : un `.tres` par symbole
- `data/enemies/` : un `.tres` par ennemi
- `tests/` : scripts de test en ligne de commande
- `docs/` : cahier des charges, CREDITS.md

## Vérifier son travail

- Tests : `godot --headless --path . -s res://tests/test_machine.gd`, `... test_combat.gd`, `... test_partie.gd`, `... test_boutique.gd`, `... test_reliques.gd`, `... test_mises.gd`, `... test_donjon.gd`, `... test_ennemis.gd`, `... test_profil.gd`, `... test_comptoir.gd`, `... test_symboles.gd`, `... test_options.gd`, `... test_audio.gd`, `... test_impacts.gd`, `... test_images.gd`, `... test_stats.gd` et `... test_interface.gd` (vérifie que les boutons tiennent dans la fenêtre 1152×648) (affichent ok / ÉCHEC, code de sortie 1 en cas d'échec). Les tests de règles utilisent des ennemis de test aux valeurs fixes, pas les `.tres` (qui sont réglés en jouant).
- **Outils** (`outils/`, voir `outils/README.md`) : `equilibrage.gd` (taux de victoire de robots, pour régler la difficulté), `simulation_parties.gd` (50 parties entières à travers les vraies scènes), `capture_ecrans.gd` (captures d'écran réelles de chaque écran : les ouvrir et les regarder, les tests de position ne voient pas un texte coupé ou un cadre mal dimensionné), `clics_reels.gd` (vrais clics de souris), `mesure_images.gd` (temps par image, budget 16,6 ms), `dessiner_icone.gd` (icône du jeu), `exporter.py` (export Windows et .zip). Quand un nouvel écran ou un nouveau flux est écrit, les mettre à jour (ajouter l'écran à `capture_ecrans.gd`, le flux à `simulation_parties.gd`) plutôt que de refaire des scripts jetables.
- Toujours lancer Godot en ligne de commande avec `timeout` et la sortie redirigée vers un fichier : un script en erreur peut bloquer Godot headless sans jamais rendre la main.
- Script jetable qui instancie une scène : attendre `await process_frame` avant de lire ses nœuds (sinon `_ready` n'a pas tourné). Les ressources chargées par `load()` sont déchargées quand plus rien ne les référence : garder une référence si on les modifie en mémoire.
- Éviter de modifier `project.godot` à la main : si Alex a l'éditeur Godot ouvert, celui-ci le réécrit depuis sa mémoire et efface la modification (c'est arrivé avec un autoload, et le jeu d'Alex plantait avec « Identifier not found: GameState » en v0.4). C'est pourquoi `GameState` est une classe statique et non un autoload. Si une modification de `project.godot` est vraiment nécessaire, demander à Alex de fermer et rouvrir l'éditeur avant de tester.
- Sous Windows, utiliser l'exécutable console de Godot (`Godot_v4.7.2-stable_win64_console.exe`). Il n'est pas dans le PATH ; chemin sur le PC d'Alex : `C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe` (version 4.7.2). S'il a changé, demander le nouveau chemin à Alex.
- Après avoir créé un fichier avec `class_name`, lancer d'abord `godot --headless --path . --import` pour mettre à jour le cache des classes.
- Chaque nouvelle règle de calcul a son test dans `tests/`.

## Travailler avec Alex

- Alex est étudiant en informatique (bases en Python et Ada) : expliquer en quelques lignes ce qui a changé et comment le tester.
- Une version jouable à la fois : ne pas commencer la suivante tant que la précédente ne marche pas en jeu.
- Faire un commit git après chaque étape qui marche.

## Plan avant chaque étape

Avant de coder une étape de jeu (une version du cahier des charges, ex. v0.6), toujours passer par un plan, approuvé par Alex. Rien n'est modifié pendant la planification : le plan se fait avant de créer la branche.

1. Relire la section concernée du cahier des charges et le code que l'étape touche, et choisir les skills à utiliser (voir « Skills à utiliser »).
2. Poser à Alex les choix qui dépendent de lui (règles que le cahier des charges ne fixe pas, périmètre, contenu) : une question à la fois par sujet, avec une recommandation.
3. Rédiger le plan : contexte, règles précisées (à reporter ensuite dans le cahier des charges local ET en ligne), architecture, fichiers à créer et à modifier, tests, étapes dans l'ordre (chacune laisse un jeu qui se lance), vérification, risques, et une ligne « Skills utilisés » (ceux qui ont été chargés et ce qu'ils ont apporté).
4. Présenter le plan à Alex et attendre son accord. Le jeu n'est codé qu'ensuite.
5. Si, en codant, il faut s'écarter du plan, le dire à Alex et le noter dans le résumé de fin d'étape.

Pas de plan pour les petites corrections (un bug, un texte coupé, une valeur à régler) ni pour l'outillage et la documentation : les expliquer en quelques lignes, puis les faire.

## Skills à utiliser

Décision d'Alex : utiliser les skills disponibles au maximum, pour tout le projet. Ils apportent des pratiques éprouvées (Godot, genres de jeu, UI, audio, sauvegarde…) que je ne dois pas refaire de mémoire.

- **Quand** : au moment du plan (pour concevoir) puis avant de coder la partie concernée (pour écrire). Les charger avec l'outil `Skill` AVANT de s'en servir, pas après coup. En cas de doute sur lesquels prendre, commencer par `router:router`.
- **Lesquels** : tous ceux qui touchent à l'étape (tableau ci-dessous), mais pas ceux qui n'ont rien à y voir (ne pas charger pour cocher : cela coûte du contexte).
- **Conflits** : les conventions du projet gagnent toujours sur un skill (noms en français, texte via `tr()`, contenu dans des `.tres`, tests en ligne de commande, GDScript typé, souris + Espace). Si un skill propose autre chose, adapter.
- **Trace** : le plan et le résumé de fin d'étape disent quels skills ont été utilisés et ce qu'ils ont changé (ou « aucun apport »).
- **À chaque étape** : `godot:godot-gdscript` (typage, pièges de syntaxe) et `godot:godot-gdscript-headless-testing` (tests en ligne de commande) pour tout code ; `godot:godot-nodes-scenes`, `godot:godot-ui-control` et `disciplines:game-ui-ux` pour tout écran ; `godot:godot-signals-groups` dès qu'il y a des événements entre objets ; `godot:godot-resources` pour les données `.tres` ; `/code-review` avant la fusion puis `/simplify` (nettoyage du code modifié, sans changer le comportement).

| Étape | Skills à charger en plus |
| --- | --- |
| v0.6 – Le donjon | `genres:roguelike` (structure d'une partie, étages, portes), `disciplines:procedural-gen` (tirage des salles et des ennemis), `disciplines:game-ai` et `disciplines:ai-behavior-trees-utility-ai` (nouveaux ennemis et mécaniques de boss), `genres:rpg` (chiffres de combat, objets) |
| v0.7 – Entre les parties | `disciplines:save-systems` (profil, version du fichier, écriture sûre), `genres:roguelike` (progression entre les parties) |
| v0.8 – Habillage | `disciplines:create-game-assets` (pack 0x72, licences, CREDITS), `godot:godot-animation`, `godot:godot-shaders` et `disciplines:shader-programming` (néons), `disciplines:game-feel` (tremblements, chiffres qui s'envolent, pluie de pièces), `disciplines:audio-design` et `godot:godot-audio` (bus Musique/Effets en décibels), `disciplines:camera-systems` (tremblement d'écran), `disciplines:input-systems` (souris, Espace) |
| v1.0 – Sortie | `godot:godot-export` (.exe Windows), `disciplines:performance-optimization`, `/security-review`, `disciplines:game-ui-ux` (accessibilité) |
| v1.1 – Version anglaise | `godot:godot-ui-control` (textes plus longs qui débordent), `godot:godot-resources` |
| Documents (cahier des charges en ligne) | `anthropic-skills:docs` avant tout appel au connecteur Claude Docs |

## Git : une branche par étape

`main` ne contient que des versions confirmées en jeu par Alex : il doit toujours marcher.

- **Début d'étape** : une fois le plan approuvé (voir « Plan avant chaque étape »), partir de `main` à jour (`git switch main`, puis `git switch -c <branche>`). Nom de la branche : la version et un sujet court (`v0.6-donjon`) ; pour une correction hors étape : `fix/<sujet>` ; pour de la documentation ou de l'outillage : `chore/<sujet>`. Ne jamais coder directement sur `main`. Pour une étape de jeu : changer `Version.NUMERO` (`scripts/version.gd`) tout de suite.
- **Pendant l'étape** : des commits sur la branche, tests verts avant chaque commit (messages courts, en français, avec la ligne `Co-Authored-By`). Alex teste avec F5 sur la branche (le dossier de travail est celui de la branche).
- **Avant la fusion** : lancer `/code-review` sur la branche (niveau `medium`) et corriger les problèmes confirmés, puis `/simplify` ; relancer les tests.
- **Fin d'étape**, seulement quand Alex a confirmé que ça marche en jeu : mettre à jour l'« État actuel » de `CLAUDE.md` et le `README` sur la branche (commit « vX confirmée »), puis `git switch main`, `git merge --no-ff <branche>` (le commit de fusion garde l'étape visible dans l'historique), poser l'étiquette de version (`git tag -a vX.Y -m "vX.Y : <sujet>"`), `git push --follow-tags`, et supprimer la branche (`git branch -d <branche>`). Les étiquettes `v0.1` à `v0.5` existent déjà.

## Checklist de fin d'étape

À parcourir dans l'ordre avant de dire « l'étape est finie » à Alex (cocher mentalement, ne rien sauter) :

0. Ce qui a été codé correspond au plan approuvé par Alex ; les écarts lui ont été signalés.
1. Tous les tests de `tests/` passent (`test_machine`, `test_combat`, `test_partie`, `test_boutique`, `test_reliques`, `test_mises`, `test_donjon`, `test_ennemis`, `test_profil`, `test_comptoir`, `test_symboles`, `test_options`, `test_audio`, `test_impacts`, `test_images`, `test_stats`, `test_interface`) et le jeu se lance comme avec F5 (`godot --headless --path . --quit-after 60`) sans erreur.
2. `outils/simulation_parties.gd` : aucune erreur ; `outils/equilibrage.gd` relancé si des valeurs ont changé (cible 50 à 60 %).
3. `outils/capture_ecrans.gd` : chaque écran nouveau ou modifié a été regardé en vrai (texte coupé, débordement, lisibilité) ; `outils/clics_reels.gd` si des boutons ont changé.
4. Chaque nouvelle règle de calcul a son test.
5. `docs/cahier-des-charges.md` mis à jour (bloc « Précisions de règles », jalon « Réalisé », phrases devenues fausses) ET la version en ligne mise à jour en même temps, avec le même texte.
6. `Version.NUMERO` à jour ; `README` et « État actuel » de `CLAUDE.md` à jour.
7. `/code-review` puis `/simplify` passés sur la branche ; les skills prévus au plan (« Skills à utiliser ») ont bien été chargés avant de coder.
8. Résumé pour Alex : ce qui a changé, comment tester avec F5, les boutons « [test] » utiles, les skills utilisés.
9. Alex a confirmé en jeu → fusion, étiquette, push (voir « Git : une branche par étape »).
- Les branches d'étape ne sont pas poussées sur GitHub : seul `main` l'est. Si Alex quitte avant la confirmation, la branche reste en local et l'état de `CLAUDE.md` le dit (« branche `x` en cours »).
- Ne pas fusionner une étape non confirmée, ne pas réécrire l'historique de `main`.
