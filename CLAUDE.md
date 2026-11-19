# Jackpot Donjon

Roguelike 2D où chaque combat se joue sur une machine à sous (1 ligne de 5 rouleaux, combos de 3/4/5).
Godot 4.7, GDScript. Projet perso d'Alex, fait pour le plaisir avec l'IA : Claude écrit le code, Alex teste avec F5.

## Références

- Règles du jeu, valeurs, jalons : `docs/cahier-des-charges.md` (copie locale).
  La version de référence est en ligne : https://claude.ai/artifact/7T7o7Bod8SKvpvXNtsJpef
  Lire la section concernée avant de toucher à une règle. Si une règle change, mettre à jour la copie locale et prévenir Alex de reporter le changement en ligne.

## État actuel

IMPORTANT : dès qu'une étape est terminée (ou avant qu'Alex quitte la session), mettre à jour cette section : ce qui est fait, ce qui reste à tester, la prochaine étape.

- v0.1 écrite : machine 1×5, sac de départ (15 symboles), combos 3/4/5 n'importe où sur la ligne (×1/×2/×4), écran de test `scenes/machine_test.tscn`.
- v0.1 terminée : 16 tests en ligne de commande passent et Alex a confirmé que ça marche en jeu (F5).
- Dépôt GitHub public : https://github.com/alexandrefelmy-dev/jackpot-donjon (branche `main`, qui ne reçoit que des étapes confirmées : voir « Git : une branche par étape »).
- v0.2 terminée : `Combat` (logique pure), `EnemyData` + 3 ennemis (`data/enemies/`), intentions attaque/protection, écran `scenes/combat.tscn` (main scene, sélecteur d'ennemi, Rejouer). Tests en ligne de commande : 16 (machine) + 46 (combat), tous ok, et Alex a confirmé que ça marche en jeu (F5, aucune erreur).
- Règles précisées en v0.2 (section « Précisions de règles (v0.2) » du cahier des charges) : reportées à la fois dans la copie locale et dans la version en ligne (fait le 2026-11-19, avec la ligne « Réalisé » du jalon v0.2).
- v0.3 terminée (Alex a confirmé en jeu, F5, une partie jusqu'au bout) : `Partie` (PV, or, sac, 5 rencontres d'étage 1 + boss), classe statique `GameState` (ex-autoload), écrans `combat` / `recompense` / `fin_partie`, ennemis Gobelin tricheur et boss Rat-Croupier (bloque un rouleau), rouleaux bloqués dans `MachineASous.tirer`. Tests : 20 (machine) + 66 (combat) + 51 (partie) + 18 (interface) = 155, tous ok ; 25 parties jouées à travers les vraies scènes en headless sans erreur. Règles v0.3 reportées dans le cahier des charges local ET en ligne (2026-11-19).
- Bug trouvé par Alex en jeu (v0.3) : le bouton « Continuer » sortait de la fenêtre (y 639 à 683 sur 648) donc impossible de passer au combat suivant ; corrigé en compactant l'écran de combat, avec `tests/test_interface.gd` pour que ça ne revienne pas. Après tout changement d'écran, relancer ce test.
- v0.4 terminée (Alex a confirmé en jeu, F5 : boutique, dorés, vol d'or, boutons de test ; le seul « bug » signalé était un malentendu sur les combos, qui doivent être côte à côte) : boutique après chaque combat normal (`Boutique` : acheter, retirer 10 or +5 par retrait, dorer 20 or, se soigner 10 PV pour 10 or), symboles dorés (copie du `.tres`, effet de base ×2, et ×2 par doré dans un combo : constante `MachineASous.FACTEUR_COMBO_PAR_DORE`), vol d'or du Gobelin tricheur, écran `scenes/boutique.tscn`. Ordre des écrans : combat → récompense → boutique → combat. Tests : 30 (machine) + 78 (combat) + 54 (partie) + 67 (boutique) + 53 (interface) = 282, tous ok ; 30 parties jouées à travers les vraies scènes (achats, retraits, dorures, soins) sans erreur. Règles v0.4 reportées dans le cahier des charges local ET en ligne (2026-11-19).
- Équilibrage v0.4 : attaques Rat 8, Squelette 13, Gobelin 9, boss 14 → environ 52 % de victoires pour un robot qui passe par la boutique sans réfléchir (600 parties) ; sans boutique le même robot gagne moins de 5 %. À régler dans `data/enemies/*.tres` après les essais d'Alex.
- Bug trouvé par Alex en jeu (v0.4) : « Identifier not found: GameState » (l'éditeur ouvert ne connaissait pas l'autoload). Corrigé en remplaçant l'autoload par une classe statique, qui ne dépend plus de `project.godot`.
- Bug trouvé par Alex en jeu (v0.4) : les touches de test F8 (+30 or) et F9 (aller au boss) ne marchaient pas : dans l'éditeur Godot, F8 est « Arrêter le jeu » (le jeu se fermait) et F9 gelait le jeu ; chez Claude, F9 marchait (fenêtre réelle + événements clavier réels, hors éditeur). Corrigé en les remplaçant par des boutons « [test] » visibles dans les écrans. **Ne jamais utiliser les touches de fonction F1–F12 (ni raccourcis d'éditeur) pour des fonctions de test : le jeu se joue à la souris, utiliser des boutons.**
- Les journaux du jeu (y compris celui d'un jeu lancé par Alex depuis l'éditeur) sont dans `%APPDATA%\Godot\app_userdata\jackpot donjon\logs\` ; Godot n'en garde que 5 : lancer des tests en ligne de commande les fait tourner et efface celui d'Alex. Quand Alex rapporte un bug, lire ce dossier AVANT de lancer quoi que ce soit.
- v0.5 terminée (Alex a confirmé en jeu, F5, mises, reliques et relances) : mises (`Mise` : or 5/10/20 gagnée = 3× la mise, quitte ou double à 5 PV), 9 reliques (`RelicData`, `data/relics/*.tres`, effets = paramètres du `.tres` ; `Reliques`, `Modificateurs`, `Partie.ajouter_relique`), tour en deux temps dans `Combat` (`tirer` / `relancer_tout` / `relancer_en_gardant` / `valider`, `jouer_tour(resultat, mise)` reste la fonction de règles), machine à 6 rouleaux (Sixième rouleau), relique offerte après le combat 3 (`scenes/relique.tscn`), 2 reliques en boutique. Ordre des écrans : combat → récompense → [relique après le combat 3] → boutique → combat. Tests : 30 (machine) + 78 (combat) + 54 (partie) + 67 (boutique) + 103 (reliques) + 122 (mises) + 131 (interface) = 585, tous ok ; 50 parties jouées à travers les vraies scènes (mises, relances, reliques, boutique) sans erreur ; de vrais clics de souris dans une vraie fenêtre vérifiés (mise, Cinquième as, Dé pipé, Valider). Règles v0.5 reportées dans le cahier des charges local ET en ligne (2026-11-19).
- Équilibrage v0.5 : valeurs des ennemis inchangées (rat 8, squelette 13, gobelin 9, boss 14) ; robot sans réflexion : environ 55 % de victoires sans relique, 56 à 61 % avec reliques offertes/achetées. À régler dans les `.tres` après les essais d'Alex.
- v0.6 terminée (Alex a confirmé en jeu, F5 : portes, coffres, repos, boss, nouveaux ennemis) : `Donjon` + `Salle` (3 étages de 5 pas à 2 portes, généré par étage à partir de la seule graine, contraintes contrôlées), `Partie` = avancée dans le donjon (`etage`, `pas`, `ecran` : quel écran afficher, `choisir_porte`, `terminer_recompense`, `choisir_relique`, `quitter_boutique`, `repos_soigner`, `repos_dorer`), écrans `portes` et `repos` (+ `Cartes.creer_carte` : grosse carte avec titre), coffres (relique 1 parmi 2), mimiques à l'étage 3, 12 ennemis dont 3 boss avec leurs mécaniques dans `Combat` (`EnemyData.passif` / `.ouverture` : crânes temporaires dans le sac du combat, renfort de l'Usurier, fuite du Pickpocket, charge du Golem, attaque surprise qui ne tue jamais, règles du Grand Croupier dans `ReglesMachine`). Le combat est toujours l'écran principal du projet : s'il n'est pas attendu, il redirige (`GameState.rediriger`). PV remontés de 50 % à chaque nouvel étage (`Partie.SOIN_APRES_BOSS_POURCENT`). Tests : en plus des anciens, `test_donjon` (500 graines, déterminisme) et `test_ennemis` ; simulation de 3 passes de parties entières. Équilibrage : robot « prudent » 42 %, « hasard » 16 %, « tout » 22 % de victoires (voir `outils/equilibrage.gd`, essais en JSON après `--`). Cahier des charges local et en ligne à jour (2026-11-19). Écarts au plan notés : soin de 50 % à chaque nouvel étage, Dame de Pique 1 crâne par tour, étage 3 avec 2 ennemis de combat.
- v0.7 écrite (branche `v0.7-profil`, à tester par Alex avec F5) : profil enregistré (`Profil`, `ProfilFichier` : JSON versionné, écriture atomique, `.bak`, migrations, refus d'un fichier plus récent sans l'écraser), `Comptoir` (6 achats : déblocage au hasard d'un symbole ou d'une relique, PV max, or de départ, relance gratuite par partie, Trèfle), `Maledictions` (5), `Bilan` (jetons d'âme et malédiction en fin de partie, une seule fois), `Partie.creer(graine, profil)` (sans profil = jeu de la v0.6 : tous les tests anciens restent valables), 4 nouveaux symboles (Bombe, Flèche, Aimant, Trèfle : `SymbolData.usage_unique` / `compte_id` / `effet_par_compte` / `description`), écrans `comptoir` (ouvert au lancement et après chaque partie, menu provisoire) et fin de partie avec bilan. **Le profil du joueur ne se lit et ne s'écrit que dans le jeu lui-même** : `GameState._sauvegarde_active()` est faux en mode sans fenêtre, et les outils qui ouvrent une vraie fenêtre mettent `GameState.sauvegarde_autorisee = false` (tests : fichiers dans `user://tests_profil/`). Tests en plus : `test_profil`, `test_comptoir`, `test_symboles`. Équilibrage du robot « prudent » : 42 % sans profil, 19 % profil neuf, 11 % avec 3 malédictions, 42 % tout débloqué.
- Prochaine étape après la v0.7 : v0.8 (habillage : graphismes, sons, musique, animations, menu principal). Plan à faire approuver par Alex avant de coder (voir « Plan avant chaque étape »).

## Conventions

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
- `scripts/partie/` : `Partie` (état et règles d'une partie : PV, or, sac, étage et pas, portes, récompenses, reliques, effets du profil), `Donjon` et `Salle` (disposition du donjon, fixée par la graine), `Boutique` (prix et actions de la boutique, symboles et reliques), `Reliques` (liste des 9 reliques)
- `data/relics/` : un `.tres` par relique (prix, description, paramètres des effets)
- `scripts/profil/` : `Profil` (ce qui survit d'une partie à l'autre), `ProfilFichier` (lecture et écriture sûres), `Comptoir` (achats et prix), `Maledictions`, `Bilan` (fin de partie vers le profil)
- `scripts/ui/` : `Cartes` (styles de boutons partagés par les écrans)
- `scripts/game_state.gd` : classe `GameState` à membres statiques, PAS un autoload (garde la partie, change d'écran ; aucune règle dedans)
- `scenes/` : scènes et leur script (`combat.tscn` = écran principal, puis `comptoir.tscn`, `portes.tscn`, `repos.tscn`, `recompense.tscn`, `relique.tscn`, `boutique.tscn` et `fin_partie.tscn` ; `machine_test.tscn` = test de la machine)
- `data/symbols/` : un `.tres` par symbole
- `data/enemies/` : un `.tres` par ennemi
- `tests/` : scripts de test en ligne de commande
- `docs/` : cahier des charges, CREDITS.md

## Vérifier son travail

- Tests : `godot --headless --path . -s res://tests/test_machine.gd`, `... test_combat.gd`, `... test_partie.gd`, `... test_boutique.gd`, `... test_reliques.gd`, `... test_mises.gd`, `... test_donjon.gd`, `... test_ennemis.gd`, `... test_profil.gd`, `... test_comptoir.gd`, `... test_symboles.gd` et `... test_interface.gd` (vérifie que les boutons tiennent dans la fenêtre 1152×648) (affichent ok / ÉCHEC, code de sortie 1 en cas d'échec). Les tests de règles utilisent des ennemis de test aux valeurs fixes, pas les `.tres` (qui sont réglés en jouant).
- **Outils** (`outils/`, voir `outils/README.md`) : `equilibrage.gd` (taux de victoire de robots, pour régler la difficulté), `simulation_parties.gd` (50 parties entières à travers les vraies scènes), `capture_ecrans.gd` (captures d'écran réelles de chaque écran : les ouvrir et les regarder, les tests de position ne voient pas un texte coupé ou un cadre mal dimensionné), `clics_reels.gd` (vrais clics de souris). Quand un nouvel écran ou un nouveau flux est écrit, les mettre à jour (ajouter l'écran à `capture_ecrans.gd`, le flux à `simulation_parties.gd`) plutôt que de refaire des scripts jetables.
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
1. Tous les tests de `tests/` passent (`test_machine`, `test_combat`, `test_partie`, `test_boutique`, `test_reliques`, `test_mises`, `test_donjon`, `test_ennemis`, `test_profil`, `test_comptoir`, `test_symboles`, `test_interface`) et le jeu se lance comme avec F5 (`godot --headless --path . --quit-after 60`) sans erreur.
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
