# Jackpot Donjon — Cahier des charges

> Copie du document en ligne au 18 novembre 2026. La version de référence est ici :
> https://claude.ai/artifact/7T7o7Bod8SKvpvXNtsJpef

## Présentation

Jackpot Donjon est un roguelike solo en 2D : le joueur descend un donjon, et chaque combat se joue en tirant le levier d'une machine à sous qu'il améliore au fil de la partie. C'est un projet personnel, fait pour le plaisir et développé avec l'aide de l'IA.

| Élément | Choix |
| --- | --- |
| Genre | Roguelike, combat au tour par tour piloté par une machine à sous |
| Plateforme | PC Windows |
| Moteur | Godot 4.7, GDScript |
| Joueurs | Solo |
| Durée d'une partie | 20 à 30 minutes (objectif) |
| Langue | Français |
| Inspirations | Luck be a Landlord (machine qu'on construit), Slay the Spire (intentions ennemies, étages), Balatro (reliques qui cassent les règles) |

Le cœur du plaisir : voir sa machine devenir de plus en plus « truquée » en sa faveur, et prendre des risques au bon moment.

## Boucle de jeu

Une partie traverse 3 étages ; chaque étage enchaîne 5 salles choisies entre 2 portes, puis un boss. Perdre tous ses PV dans n'importe quel combat termine la partie.

```
Nouvelle partie (40 PV, sac de 15 symboles)
  -> Choisir une porte (2 salles proposées)
  -> Jouer la salle (combat, boutique, coffre ou repos)
  -> 5 salles faites ?  non -> retour au choix de porte
                        oui -> Boss de l'étage (relique en récompense)
  -> Étage 3 ?          non -> étage suivant, retour au choix de porte
                        oui -> Victoire
PV à 0 dans un combat -> Game over -> Rejouer (nouvelle partie)
```

On n'avance que vers l'avant : la seule boucle est celle des portes, jusqu'au boss de l'étage.

| Type de salle | Ce qui s'y passe |
| --- | --- |
| Combat | Un ennemi de l'étage ; le type de salle le plus fréquent |
| Boutique | Acheter, retirer ou améliorer des symboles, acheter des reliques |
| Coffre | Une relique gratuite ; à l'étage 3, parfois une mimique |
| Repos | Soigner 30 % des PV max, ou rendre un symbole doré gratuitement |

## La machine à sous

La machine est une seule ligne de 5 rouleaux, comme une vraie machine à sous : à chaque tirage, 5 symboles sont tirés au hasard dans le « sac » du joueur. Le sac, c'est la collection de symboles que le joueur possède : l'agrandir, l'améliorer et le nettoyer est toute la stratégie.

**Règles du tirage**

- Les 5 rouleaux s'arrêtent un par un, de gauche à droite.
- Chaque symbole visible applique son effet de base.
- 3 symboles identiques ou plus, côte à côte et n'importe où sur la ligne, forment un **combo** : l'effet de combo remplace leurs effets de base.
- Le combo est multiplié selon sa longueur : 3 symboles ×1, 4 symboles ×2, 5 symboles **JACKPOT** ×4.
- Si le sac contient moins de 5 symboles, les rouleaux restants sont vides.
- Ordre de résolution : de gauche à droite, les combos en dernier.

Le tirage se fait **sans remise** : chaque symbole du sac ne peut sortir qu'une fois par tirage (d'où les rouleaux vides si le sac est trop petit). Avec le sac de départ, un tirage donne un combo (3 ou plus) environ 1 fois sur 9 (11,6 %), un combo de 4 exactement environ 1 fois sur 55 et un jackpot environ 1 fois sur 500.

**Sac de départ (15 symboles)** : 6 épées, 3 boucliers, 2 potions, 2 pièces, 2 crânes.

**Symboles de base** (valeurs de départ, à équilibrer en jouant)

| Symbole | Effet de base | Combo de 3 (×2 pour 4, ×4 pour 5) |
| --- | --- | --- |
| Épée | 3 dégâts à l'ennemi | 15 dégâts |
| Bouclier | +3 armure ce tour | +12 armure |
| Potion | Soigne 3 PV | Soigne 12 PV |
| Pièce | +2 or | +10 or |
| Crâne | L'attaque ennemie fait +1 dégât | Le joueur perd 6 PV immédiatement |

**Symboles à débloquer** (gagnés en récompense ou achetés)

| Symbole | Effet |
| --- | --- |
| Bombe | 8 dégâts, puis retirée du sac pour le reste du combat |
| Flèche | 1 dégât par flèche visible dans la grille |
| Poison | Empoisonne l'ennemi : 1 dégât par tour, cumulable |
| Joker | Copie l'effet du symbole à sa gauche ; compte comme n'importe quel symbole pour les combos |
| Trèfle | Transforme un crâne voisin en pièce |
| Aimant | +1 or par pièce visible |
| Sablier | L'ennemi saute sa prochaine action (rare) |

**Version dorée** : tout symbole peut être amélioré en boutique ; sa version dorée double son effet de base, et chaque symbole doré dans un combo double l'effet du combo.

## Combat

Un combat oppose le joueur à un seul ennemi, au tour par tour : un tirage du joueur, puis une action de l'ennemi. Le joueur commence la partie avec 40 PV maximum ; ses PV ne remontent pas entre les combats, sauf soins.

**Déroulé d'un tour**

1. L'ennemi affiche son **intention** pour ce tour (ex. « attaque 7 », « se protège », « sabote la machine »).
2. Le joueur choisit sa mise (facultatif, voir section suivante).
3. Le joueur tire le levier : les rouleaux s'arrêtent un par un.
4. Les effets des symboles s'appliquent, puis ceux des combos.
5. Si l'ennemi est encore en vie, il exécute son intention. L'armure du joueur absorbe les dégâts en premier.
6. Fin du tour : l'armure retombe à 0, le poison agit, on repart à l'étape 1.

**Précisions de règles (v0.2)**

- Les effets du tirage s'appliquent dans l'ordre : dégâts à l'ennemi (son armure absorbe d'abord), armure, soin (jamais au-dessus des PV max), or, puis les crânes. Le malus d'un crâne (+1 à l'attaque ennemie) ne dure que le tour du tirage.
- La perte de PV d'un combo de crânes est immédiate : l'armure ne la bloque pas.
- L'armure de l'ennemi (intention « Protection ») gagnée à son action protège contre le tirage du tour suivant, puis retombe quand il agit à nouveau.
- Si l'ennemi et le joueur tombent à 0 PV dans le même tirage, c'est la victoire. Si l'ennemi est vaincu, il n'agit pas ; si le joueur tombe à 0 PV avant son action, il n'agit pas non plus.
- Les intentions d'un ennemi sont une liste jouée en boucle, une par tour (définie dans son fichier de données).

**Précisions de règles (v0.3)**

- Une partie v0.3 = 5 combats contre des ennemis de l'étage 1 (tirés au hasard, jamais le même deux fois de suite), puis le boss de l'étage. Boss vaincu = victoire (un seul étage pour l'instant ; les 3 étages arrivent en v0.6).
- Entre deux combats, les PV ne remontent pas (sauf soins), l'armure retombe, l'or gagné et le sac sont conservés. L'or se dépense à la boutique (v0.4).
- Après chaque combat normal, 3 symboles différents sont proposés parmi épée, bouclier, potion et pièce (jamais le crâne) : on en prend 1 pour l'ajouter au sac, ou on passe. Pas de récompense après le boss (une relique est prévue en v0.5).
- Intention « Blocage » : à son action du tour N, l'ennemi bloque un rouleau tiré au hasard, qui reste vide au tirage du tour N+1 (un rouleau vide casse les combos). Le joueur voit « bloque un rouleau » dans l'intention dès le tour N.
- Gobelin tricheur : alterne attaque et vol d'or (v0.4 ; en v0.3 il alternait attaque et protection, faute de boutique). Rat-Croupier : 60 PV, alterne attaque et blocage.
- À 0 PV dans un combat : game over. Rejouer lance une nouvelle partie (nouveau sac, PV pleins, nouvelle graine).
- Attaques de départ (réglées en v0.4 avec la boutique) : Rat d'égout 8, Squelette 13 (après sa protection de 5), Gobelin tricheur 9 (puis vol de 3 or), Rat-Croupier 14. Réglées avec 600 parties jouées par un robot qui passe par la boutique mais ne réfléchit pas : environ 52 % de victoires, donc plus facile pour un joueur qui choisit bien ses symboles. Sans la boutique, le même robot gagne moins de 5 % des parties : la boutique est indispensable.

**Fin du combat**

- Ennemi à 0 PV : victoire. Le joueur gagne de l'or et choisit **1 symbole parmi 3** à ajouter à son sac (ou passe).
- Joueur à 0 PV : game over, la partie est perdue et tout recommence à zéro.

**Types d'intentions ennemies**

| Intention | Effet |
| --- | --- |
| Attaque | Inflige X dégâts |
| Protection | Gagne X armure |
| Renforcement | Ses attaques font +X dégâts pour le reste du combat |
| Sabotage | Ajoute un crâne temporaire dans le sac du joueur, ou bloque un rouleau au prochain tirage |

## Mise et prise de risque

Avant chaque tirage, le joueur peut miser pour amplifier le résultat : c'est le côté « gambling » du jeu. Ne pas miser reste toujours possible.

| Mise | Ce qu'on risque | Si ça passe | Si ça rate |
| --- | --- | --- | --- |
| Mise d'or | 5, 10 ou 20 or | Au moins un combo (hors crânes) : l'or misé revient ×3 | L'or misé est perdu |
| Quitte ou double | 5 PV | Aucun crâne visible : tous les effets positifs du tirage sont doublés | Au moins un crâne : les 5 PV sont perdus |

Une seule mise par tour. Certaines reliques modifient les mises (gains plus forts, mise gratuite une fois par combat).

Toute la monnaie du jeu est fictive : aucun achat ni argent réel.

## Progression

Le joueur progresse pendant une partie seulement : or, symboles et reliques sont perdus au game over. L'or vient des pièces, des victoires (5 à 15 or selon l'ennemi) et des mises gagnées.

**Boutique** (prix de départ)

| Action | Prix |
| --- | --- |
| Acheter un symbole (3 au choix) | 8 à 15 or |
| Retirer un symbole du sac | 10 or, +5 à chaque retrait |
| Rendre un symbole doré | 20 or |
| Acheter une relique (2 au choix) | 25 à 40 or |
| Se soigner de 10 PV | 10 or |

**Précisions de règles (v0.4)**

- Déroulé : combat → récompense (1 symbole parmi 3, ou passer) → boutique → combat suivant. Pas de boutique après le boss. Les salles au choix entre 2 portes remplaceront cette suite en v0.6.
- Acheter un symbole : 3 symboles différents sont proposés parmi épée, bouclier, potion et pièce (jamais le crâne), chacun à son prix (épée 10, bouclier 8, potion 10, pièce 12). Une offre achetée disparaît de l'étal.
- Retirer un symbole du sac : 10 or, puis 5 de plus à chaque retrait de la partie (10, 15, 20…). On garde toujours au moins 1 symbole dans le sac.
- Rendre un symbole doré : 20 or. Un symbole déjà doré ne peut pas l'être deux fois.
- Se soigner de 10 PV : 10 or, autant de fois qu'on veut tant que les PV ne sont pas au maximum (le soin ne dépasse jamais les PV max).
- Un achat sans assez d'or est refusé et ne change rien.
- Symbole doré : même identité que l'original (un doré et un normal forment un combo ensemble). Son effet de base est doublé. Dans un combo, chaque symbole doré double l'effet du combo, en plus du multiplicateur de longueur (3 épées dont 1 dorée : 30 dégâts ; dont 2 dorées : 60 ; 3 dorées : 120). On peut dorer un crâne : ses effets comptent doublés aussi (à éviter).
- Vol d'or : le Gobelin tricheur prend 3 or au joueur, jamais plus que l'or qu'il a (son or d'avant le combat plus les pièces tirées pendant le combat). Un voleur vaincu ne vole pas.
- L'or peut maintenant baisser (vol, achats) ; il ne devient jamais négatif.

**Reliques** : objets passifs qui changent les règles, obtenus en boutique, dans les coffres et sur les boss.

| Relique | Effet |
| --- | --- |
| Dé pipé | Une relance gratuite par combat |
| Trèfle à quatre feuilles | Chaque crâne a 1 chance sur 2 de devenir une pièce |
| Lame aimantée | Chaque pièce inflige aussi 1 dégât |
| Sixième rouleau | Ajoute un 6e rouleau à la machine |
| Tirelire | +2 or à chaque tirage sans combo |
| Cœur de pierre | +10 PV maximum |
| Jackpot maudit | Effets de combo ×2, mais 2 crânes de plus dans le sac |
| Jeton porte-bonheur | La première mise de chaque combat est remboursée si elle rate |
| Cinquième as | Le joueur peut bloquer un rouleau et relancer les autres, une fois par combat |

## Progression entre les parties

Chaque partie, gagnée ou perdue, rapporte des avantages permanents ; chaque mort ajoute en plus une malédiction à la partie suivante. Valeurs de départ, à équilibrer.

**Jetons d'âme** : gagnés en fin de partie (1 par salle franchie, 5 par boss battu, 10 pour une victoire), dépensés au **Comptoir du Croupier**, un écran entre deux parties.

| Avantage permanent | Prix |
| --- | --- |
| Débloquer un nouveau symbole (il peut ensuite apparaître en récompense et en boutique) | 10 jetons |
| Débloquer une nouvelle relique | 15 jetons |
| +5 PV max au départ (3 fois au maximum) | 20 jetons |
| +10 or au départ (3 fois au maximum) | 15 jetons |
| Une relance gratuite par partie | 30 jetons |
| Commencer avec un trèfle dans le sac | 25 jetons |

**Malédictions** : à chaque game over, une malédiction tirée au hasard s'ajoute à la partie suivante. Elles se cumulent jusqu'à 3 ; battre un boss en efface une, une victoire les efface toutes.

| Malédiction | Effet |
| --- | --- |
| Sac lesté | +1 crâne dans le sac de départ |
| Bourse trouée | Prix de la boutique +20 % |
| Fatigue | -5 PV max |
| Croupier rancunier | Le premier ennemi de chaque étage a +20 % de PV |
| Mauvais œil | Les mises d'or gagnées rapportent ×2 au lieu de ×3 |

## Contenu

La version 1.0 compte 3 étages, 9 ennemis normaux et 3 boss, dans un univers de donjon mélangé à un casino maudit.

**Étages**

| Étage | Nom | Ambiance | Boss |
| --- | --- | --- | --- |
| 1 | Les Cryptes | Souterrains humides, ennemis simples | Le Rat-Croupier |
| 2 | La Salle de jeu maudite | Casino abandonné et hanté | La Dame de Pique |
| 3 | Le Coffre-fort | Salle des trésors gardée | Le Grand Croupier |

**Ennemis** (PV de départ, à équilibrer)

| Ennemi | Étage | PV | Comportement |
| --- | --- | --- | --- |
| Rat d'égout | 1 | 12 | Attaques faibles et régulières |
| Gobelin tricheur | 1 | 18 | Alterne attaque et vol de 3 or |
| Squelette | 1 | 22 | Se protège un tour sur deux |
| Fantôme de joueur | 2 | 26 | Ajoute des crânes temporaires dans le sac |
| Golem de jetons | 2 | 40 | Lent, très grosses attaques |
| Pickpocket | 2 | 24 | Vole de l'or, fuit au bout de 4 tours si pas tué |
| Garde du coffre | 3 | 45 | Armure élevée |
| Mimique | 3 | 35 | Se fait passer pour un coffre, attaque surprise |
| Usurier | 3 | 38 | Se renforce à chaque tour où le joueur a misé |

**Boss**

| Boss | PV | Mécanique spéciale |
| --- | --- | --- |
| Le Rat-Croupier | 60 | Bloque un rouleau tous les 2 tours |
| La Dame de Pique | 90 | Ajoute 2 crânes temporaires dans le sac à chaque tour |
| Le Grand Croupier | 140 | Change une règle de la machine à chaque tour (ex. les épées soignent l'ennemi) |

## Interface et contrôles

Le jeu se joue entièrement à la souris, avec la barre Espace comme raccourci pour tirer le levier. Résolution de base 1280 × 720, mise à l'échelle automatique en plein écran.

| Écran | Contenu |
| --- | --- |
| Menu principal | Jouer, Options (volume, plein écran), Quitter |
| Comptoir du Croupier | Entre deux parties : jetons d'âme, avantages à débloquer, malédictions actives |
| Choix de salle | 2 portes avec l'icône du type de salle, étage et salle en cours |
| Combat | Ennemi et son intention, machine à sous, levier, mises, PV, armure, or, reliques |
| Récompense | 3 symboles au choix + bouton Passer, or gagné |
| Boutique | Symboles, reliques, retrait, amélioration, soin, or restant |
| Sac | Liste de tous les symboles possédés, consultable à tout moment |
| Fin de partie | Victoire ou game over, statistiques (étage atteint, dégâts, plus gros jackpot), jetons gagnés, malédiction reçue, Rejouer |

En combat, survoler un symbole ou une relique affiche une bulle d'aide avec son effet exact.

Le volume se règle par bus audio séparés (Musique, Effets), avec des curseurs en décibels. L'information n'est jamais donnée par la couleur seule (dégâts, soins et or ont aussi une icône ou un signe), et les textes restent lisibles à 1280 × 720.

## Direction artistique et son

Style visé : pixel art sombre de donjon, avec des touches de néons dorés et rouges façon casino. Le développement commence avec des formes colorées et du texte à la place des images ; les vrais graphismes arrivent une fois le jeu amusant.

- **Graphismes** : le pack 16x16 DungeonTileset II de 0x72 (CC0), complété au besoin par ses extensions dans le même style.
- **Sons** : rouleaux qui tournent, clic d'arrêt de chaque rouleau, « ding » de combo, fanfare de jackpot, coups, pièces.
- **Musique** : une boucle d'ambiance par étage, une musique de boss.
- **Effets de jeu** (le « juice ») : rouleaux qui s'arrêtent l'un après l'autre, tremblement d'écran sur gros dégâts, pluie de pièces sur un jackpot, chiffres de dégâts qui s'envolent.

Toute ressource externe doit avoir une licence qui autorise son usage ; sa source est notée dans un fichier CREDITS.md.

## Contraintes techniques

Le projet utilise Godot 4.7 et GDScript, dans le dossier `jackpot-donjon` déjà créé. Le contenu (symboles, ennemis, reliques) est décrit dans des fichiers de données, pour en ajouter sans toucher au code.

- **Langage** : GDScript avec typage statique (`var pv: int = 40`), pour attraper les erreurs plus tôt.
- **Données** : une ressource Godot (`.tres`) par symbole, ennemi et relique, basée sur des classes `SymbolData`, `EnemyData`, `RelicData`. Ces fichiers sont partagés : l'état qui change en jeu (PV restants d'un ennemi, symbole doré) vit dans une copie (`duplicate_deep()`) ou dans `GameState`, jamais dans le `.tres` lui-même.
- **État de la partie** : un autoload `GameState` garde PV, or, sac, reliques, étage et salle en cours.
- **Sauvegarde du profil** : jetons d'âme, avantages débloqués et malédictions sont enregistrés dans un fichier `user://profil.save`. Le fichier porte un numéro de version (pour migrer les anciens profils après une mise à jour) et s'écrit dans un fichier temporaire renommé ensuite, pour ne pas être corrompu par un plantage en pleine écriture.
- **Tests** : la logique (tirage, combos, effets, combat) est testée sans interface avec `godot --headless`, dans `tests/` ; le script de test se termine avec un code d'erreur s'il échoue.
- **Hasard** : un seul générateur aléatoire avec une graine affichée en debug, pour pouvoir rejouer exactement une partie qui a bugué.
- **Textes** : tout texte affiché passe par la traduction de Godot (`tr()` et un fichier CSV), pour ajouter l'anglais à la fin sans tout reprendre.
- **Taille de la grille** : nombre de rouleaux et de lignes en paramètres, jamais écrits en dur dans le code.
- **Rendu** : le projet est en Forward+ ; on le garde tant qu'il n'y a pas de souci, le mode Compatibility suffirait pour de la 2D.
- **Versionnage** : dépôt Git sur GitHub, un commit par fonctionnalité qui marche.

**Organisation des dossiers**

```
res://
├── scenes/        menu, choix de salle, combat, boutique, récompense, fin
├── scripts/       logique (machine, combat, effets, GameState)
├── data/
│   ├── symbols/   un .tres par symbole
│   ├── enemies/   un .tres par ennemi
│   └── relics/    un .tres par relique
├── assets/        images, sons, polices
├── tests/         tests de la logique, lancés en ligne de commande
└── docs/          cahier des charges, CREDITS.md
```

**Méthode de travail** : Claude écrit et modifie les fichiers directement dans le dossier du projet ; Alex lance le jeu avec F5 et rapporte ce qu'il voit et les erreurs de la console. Chaque étape doit laisser un jeu qui se lance.

## Périmètre et jalons

Le jeu se construit par versions jouables : la version 0.3 est le MVP, une partie complète mais minimale. Chaque version n'est commencée que quand la précédente est « finie ».

1. **v0.1 – La machine** : une scène, un bouton Tirer, une ligne de 5 rouleaux remplie depuis le sac de départ, combos de 3, 4 et 5, les effets affichés en texte.
   - Fini quand : on tire et le résultat calculé est juste.
2. **v0.2 – Premier combat** : un ennemi avec PV et intention, PV et armure du joueur, victoire et défaite.
   - Fini quand : on peut gagner ou perdre un combat.
   - Réalisé : intentions « Attaque » et « Protection » ; 3 ennemis au choix pour tester (Rat d'égout, Squelette, Golem de jetons) ; bouton Rejouer. L'or n'est que compté et affiché (pas encore conservé : v0.3).
3. **v0.3 – MVP** : 5 combats à la suite puis un boss, récompense « 1 symbole parmi 3 », écran de fin et Rejouer.
   - Fini quand : une partie entière se joue du début à la fin.
   - Réalisé : 5 combats d'étage 1 (Rat d'égout, Squelette, Gobelin tricheur simplifié) puis le boss Rat-Croupier qui bloque un rouleau ; PV, or et sac conservés d'un combat à l'autre ; écran de récompense (1 symbole parmi 3, ou passer) ; écran de victoire / game over avec Rejouer.
4. **v0.4 – Économie** : or, boutique, retrait et amélioration de symboles.
   - Fini quand : on peut dépenser son or en boutique pour changer son sac et se soigner.
   - Réalisé : boutique après chaque combat normal (acheter, retirer, rendre doré, se soigner) ; symboles dorés qui doublent leur effet et celui des combos ; vol d'or du Gobelin tricheur ; équilibrage des ennemis refait avec la boutique.
5. **v0.5 – Gambling** : mises, reliques.
6. **v0.6 – Le donjon** : 3 étages, choix entre 2 portes, coffres et repos, tous les ennemis et boss.
7. **v0.7 – Entre les parties** : jetons d'âme, Comptoir du Croupier, malédictions, sauvegarde du profil.
8. **v0.8 – Habillage** : graphismes, sons, musique, animations, menu principal.
9. **v1.0 – Sortie** : équilibrage, statistiques de fin de partie, export en .exe Windows.
10. **v1.1 – Version anglaise** : traduction de tous les textes, choix de la langue dans les options.

## Hors périmètre et décisions

**Hors périmètre de la v1.0** : multijoueur, version mobile, 3D, sauvegarde en cours de partie, plusieurs personnages jouables, scénario et dialogues, argent réel ou achats en jeu (jamais).

**Questions ouvertes** : aucune pour l'instant.

**Décisions prises**

| Question | Décision |
| --- | --- |
| Taille de la grille | 1 ligne de 5 rouleaux, combos de 3, 4 ou 5 symboles identiques n'importe où sur la ligne ; un 6e rouleau possible grâce à une relique |
| Pack graphique | [16x16 DungeonTileset II](https://0x72.itch.io/dungeontileset-ii) de 0x72 (CC0) |
| Progression entre les parties | Oui : avantages permanents gagnés à chaque partie, malédiction à chaque mort |
| Nom | « Jackpot Donjon », provisoire |
| Version anglaise | Oui, en toute fin de projet (v1.1) |
