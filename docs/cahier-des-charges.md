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

**Précisions de règles (v0.6)**

- Structure : 3 étages (Les Cryptes, La Salle de jeu maudite, Le Coffre-fort) ; un étage = 5 salles, chacune choisie entre 2 portes, puis le boss de l'étage. Boss de l'étage 3 vaincu = victoire. On n'avance que vers l'avant.
- Les portes montrent le type de salle (combat, boutique, coffre, repos), pas l'ennemi. Chaque porte tire son type avec ces poids : combat 50, coffre 20, boutique 15, repos 15. Contraintes du générateur (l'étage est retiré sinon) : les 2 portes d'un pas ne sont jamais identiques (deux combats sont permis contre des ennemis différents) ; la 1re salle d'un étage propose 2 combats ; un étage contient au moins un coffre, une boutique et un repos.
- Après un combat normal gagné : récompense (1 symbole parmi 3, ou passer), puis les portes suivantes. Il n'y a plus de boutique automatique ni de relique offerte après le combat 3 : la boutique est une salle au choix, les coffres et les boss donnent les reliques.
- Coffre : écran « Choisis 1 relique parmi 2 ». À l'étage 3, 1 coffre sur 3 est une Mimique (invisible sur la porte, mais l'écran des portes de l'étage 3 prévient que certains coffres sont des mimiques) : elle attaque par surprise avant le premier tirage (10 dégâts, jamais mortels : il reste au moins 1 PV) ; si on la bat, la relique est donnée quand même. La Mimique n'apparaît que dans les coffres.
- Repos : soigner 30 % des PV max (arrondi au-dessus, sans dépasser le maximum), ou rendre un symbole doré gratuitement (choisi dans le sac). Une seule action, puis les portes.
- Boss : vaincu, il donne une relique (1 parmi 2) ; à l'étage 3, c'est la victoire. À l'arrivée d'un nouvel étage, les PV remontent de 50 % des PV max (constante `SOIN_APRES_BOSS_POURCENT`, ajoutée au cahier de départ : sans elle, un robot sans réflexion perdait presque toujours à l'étage 2).
- Hasard : le donjon (portes, ennemis, mimiques) ne dépend que de la graine de la partie : un générateur par étage, séparé de celui du jeu (tirages, récompenses, blocages). Même graine = même donjon, quoi que le joueur ait fait avant.
- Nouvelles intentions : « Se prépare à frapper » (le Golem ne fait rien ce tour-là, puis frappe fort) et « Va s'enfuir » (le Pickpocket quitte le combat : ni or de victoire ni récompense). Le Pickpocket : vole 4 or, attaque 9, vole 4 or, puis fuit.
- Crânes temporaires (Fantôme de joueur et Dame de Pique : 1 par tour chacun ; le cahier de départ prévoyait 2 pour la Dame, trop dur) : ajoutés au sac du combat seulement (le vrai sac n'est jamais touché), 10 au maximum par combat ; leur nombre s'affiche sous l'intention.
- Usurier : +2 d'attaque pour le reste du combat à chaque tour où le joueur a misé (une mise annulée ne compte pas) ; l'intention affichée montre l'attaque renforcée.
- Grand Croupier : à chaque tour une règle de la machine change, annoncée avant le tirage et valable pour ce tirage, jamais deux fois de suite la même : les épées soignent l'ennemi au lieu de le blesser ; les boucliers ne donnent pas d'armure ; les potions ne soignent pas ; les crânes comptent double.
- Le joueur voit toujours à l'avance ce qui l'attend : intention, passif et règle du tour s'affichent avant le tirage.

| Ennemi | PV | Intentions (jouées en boucle) | Or de victoire |
| --- | --- | --- | --- |
| Rat d'égout | 12 | attaque 8 | 8 |
| Squelette | 22 | protection 5, attaque 13 | 13 |
| Gobelin tricheur | 18 | attaque 9, vol 3 | 13 |
| Rat-Croupier (boss) | 48 | attaque 10, blocage d'un rouleau | 40 |
| Fantôme de joueur | 26 | attaque 7, protection 6 ; +1 crâne temporaire par tour | 16 |
| Golem de jetons | 36 | se prépare, attaque 16 | 24 |
| Pickpocket | 24 | vol 4, attaque 9, vol 4, fuite | 16 |
| Dame de Pique (boss) | 54 | attaque 7, attaque 10 ; +1 crâne temporaire par tour | 64 |
| Garde du coffre | 45 | protection 14, attaque 13 | 24 |
| Mimique | 35 | surprise 10 au début, puis attaque 11 | 19 |
| Usurier | 38 | attaque 10 (+2 par tour de mise) | 24 |
| Grand Croupier (boss) | 63 | attaque 7, attaque 9 ; une règle de machine change à chaque tour | 60 |

- Équilibrage : trois robots sans réflexion traversent le donjon (400 parties chacun). Le « prudent » (repos s'il est blessé, boutique s'il a de l'or, sinon coffre puis combat, achète les reliques) gagne 42 % de ses parties ; le « hasard » (portes au hasard, aucun achat de relique) 16 % ; le « tout » (comme le prudent, mais mise 5 or dès qu'il a 25 or) 22 %. Le boss de l'étage 1 est atteint dans 96 à 97 % des parties. Un vrai joueur fait mieux. Valeurs à régler dans les `.tres` après les essais d'Alex.

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
| Bombe | 8 dégâts, puis retirée du sac pour le reste du combat (v0.7) |
| Flèche | 1 dégât par flèche visible dans la grille (v0.7) |
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

- Une partie v0.3 = 5 combats contre des ennemis de l'étage 1 (tirés au hasard, jamais le même deux fois de suite), puis le boss de l'étage. Boss vaincu = victoire (depuis la v0.6, la partie traverse 3 étages : voir « Boucle de jeu »).
- Entre deux combats, les PV ne remontent pas (sauf soins), l'armure retombe, l'or gagné et le sac sont conservés. L'or se dépense à la boutique (v0.4).
- Après chaque combat normal, 3 symboles différents sont proposés parmi épée, bouclier, potion et pièce (jamais le crâne) : on en prend 1 pour l'ajouter au sac, ou on passe. Pas de récompense en symbole après un boss : il donne une relique (v0.6).
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

**Précisions de règles (v0.5)**

- Mises : une seule par tour, choisie avant le tirage (boutons « Pas de mise », 5, 10, 20 or, « Quitte ou double »), remise à « Pas de mise » après chaque tour. Une mise impossible (pas assez d'or ; 5 PV ou moins pour le quitte ou double) est grisée. Elle se règle même si le tirage tue l'ennemi.
- Mise d'or : si le tirage contient au moins un combo qui n'est pas un combo de crânes, l'or misé « revient ×3 » : on reçoit 3 fois la mise (gain net : 2 fois la mise). Sinon la mise est perdue.
- Quitte ou double : aucun crâne visible → les effets positifs du tirage (dégâts, armure, soin, or) sont doublés, pas le malus des crânes. Au moins un crâne visible → on perd 5 PV (l'armure ne les bloque pas).
- Tour en deux temps : le levier affiche les rouleaux. Sans relance possible, le tour se joue aussitôt. Avec le Dé pipé ou le Cinquième as, on peut relancer, puis « Valider » (la touche Espace valide aussi). La mise est fixée au premier tirage ; les rouleaux bloqués par un ennemi restent bloqués.
- Reliques (chacune une seule fois par partie ; prix en boutique) : Cœur de pierre (30 or) : +10 PV max et +10 PV tout de suite. Tirelire (30) : +2 or à chaque tour sans combo (un combo de crânes compte comme un combo). Lame aimantée (35) : chaque pièce visible inflige aussi 1 dégât (pièces dans un combo comprises). Trèfle à quatre feuilles (30) : chaque crâne tiré a 1 chance sur 2 de devenir une pièce, avant le calcul des combos. Jackpot maudit (40) : l'effet de tous les combos est ×2, et 2 crânes sont ajoutés au sac tout de suite. Jeton porte-bonheur (25) : la première mise d'or perdue de chaque combat est remboursée. Sixième rouleau (40) : 6 rouleaux (combo de 6 : ×8). Dé pipé (30) : une relance gratuite de tous les rouleaux par combat. Cinquième as (35) : une fois par combat, on garde 1 rouleau (clic dessus) et on relance les autres.
- Obtention : la boutique propose 2 reliques non possédées. Depuis la v0.6, les coffres et les boss offrent aussi « Choisis 1 relique parmi 2 » (sans « passer ») ; la relique offerte après le combat 3 de la v0.5 a disparu.
- Équilibrage : les valeurs des ennemis de la v0.4 sont inchangées. Un robot qui ne réfléchit pas gagne environ 55 % des parties sans relique et 56 à 61 % avec les reliques offertes et achetées.

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

- Déroulé (jusqu'à la v0.5) : combat → récompense → boutique → combat suivant. Depuis la v0.6, la boutique est une salle au choix parmi les 2 portes (voir « Boucle de jeu »).
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

**Précisions de règles (v0.7)**

- Jetons d'âme : calculés une seule fois en fin de partie (1 par salle franchie, 5 par boss battu, 10 pour une victoire). Une partie abandonnée (jeu fermé) ne rapporte rien.
- Déroulé : le jeu s'ouvre sur le Comptoir du Croupier (depuis la v0.8, il s'ouvre sur le menu principal et le Comptoir est un de ses boutons) ; « Jouer » lance une partie ; l'écran de fin affiche les jetons gagnés et la malédiction reçue ou effacée, puis mène au Comptoir ou relance une partie.
- Déblocages : un déblocage tire au hasard un élément encore verrouillé. Au départ sont débloqués les symboles épée, bouclier, potion et pièce, et les reliques Cœur de pierre, Tirelire, Lame aimantée et Dé pipé. Restent à débloquer les symboles Bombe, Flèche, Aimant et Trèfle, et les reliques Trèfle à quatre feuilles, Jackpot maudit, Jeton porte-bonheur, Sixième rouleau et Cinquième as. Les récompenses, la boutique, les coffres et les boss ne proposent que ce qui est débloqué. Une carte du Comptoir est grisée quand on ne peut plus l'acheter (pas assez de jetons, tout débloqué, niveau maximum, déjà acheté).
- Avantages : PV max +5 par niveau (3 niveaux au maximum, PV de départ compris) ; or de départ +10 par niveau (3 niveaux) ; une relance gratuite par partie = une relance de tous les rouleaux, utilisable dans n'importe quel combat, une seule fois, après celles des reliques ; un Trèfle dans le sac de départ.
- Malédictions : fixées au lancement de la partie. À chaque défaite, une malédiction tirée au hasard s'ajoute (3 au maximum, toutes différentes). Chaque boss battu pendant la partie en efface une (la plus ancienne) avant l'ajout, et celle qui vient d'être effacée ne revient pas aussitôt ; une victoire les efface toutes et n'en ajoute pas.
- Effets des malédictions : Sac lesté, +1 crâne dans le sac de départ. Bourse trouée, tous les prix de la boutique +20 % (arrondi au-dessus). Fatigue, −5 PV max (et PV de départ). Croupier rancunier, l'ennemi du premier combat de chaque étage a +20 % de PV (arrondi au-dessus). Mauvais œil, une mise d'or gagnée rapporte ×2 au lieu de ×3.
- Nouveaux symboles : Bombe, 8 dégâts (combo de 3 : 40), retirée du sac du combat après le tirage où elle est visible (elle revient au combat suivant). Flèche, chaque flèche visible inflige autant de dégâts que de flèches visibles (2 flèches : 4 dégâts ; combo de 3 : 12). Aimant, chaque aimant rapporte autant d'or que de pièces visibles (combo de 3 : 8 or). Trèfle, transforme un crâne voisin en pièce avant le calcul des combos (combo de 3 : 6 or). Les versions dorées doublent aussi ces effets. Poison, Joker et Sablier sont reportés à une version ultérieure.
- Sans profil (tests et outils), le jeu se joue comme en v0.6 : 4 symboles de base, 9 reliques, aucun avantage ni malédiction.
- Profil : fichier JSON `user://profil.save` avec un numéro de version, écrit dans un fichier temporaire puis renommé (l'ancien fichier est gardé en `.bak`). Fichier abîmé : le `.bak` est rechargé, sinon profil neuf, avec un message au Comptoir. Fichier d'une version plus récente que le jeu : ignoré et jamais écrasé. Contenu : jetons, symboles et reliques débloqués, niveaux, avantages achetés, malédictions, nombre de parties et de victoires. Les tests et les outils n'écrivent jamais dans le vrai profil du joueur.
- Équilibrage : le robot « prudent » (voir v0.6) gagne 42 % de ses parties sans profil, 19 % avec un profil neuf (seulement 4 reliques et 4 symboles possibles), 11 % avec 3 malédictions (Fatigue, Rancunier, Bourse trouée) et 42 % avec tous les avantages et tout débloqué. Valeurs à régler après les essais d'Alex.

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
| Golem de jetons | 2 | 36 | Lent, très grosses attaques |
| Pickpocket | 2 | 24 | Vole de l'or, fuit au bout de 4 tours si pas tué |
| Garde du coffre | 3 | 45 | Armure élevée |
| Mimique | 3 | 35 | Se fait passer pour un coffre, attaque surprise |
| Usurier | 3 | 38 | Se renforce à chaque tour où le joueur a misé |

**Boss**

| Boss | PV | Mécanique spéciale |
| --- | --- | --- |
| Le Rat-Croupier | 48 | Bloque un rouleau tous les 2 tours |
| La Dame de Pique | 54 | Ajoute 1 crâne temporaire dans le sac à chaque tour |
| Le Grand Croupier | 63 | Change une règle de la machine à chaque tour (ex. les épées soignent l'ennemi) |

**Précisions de règles (v0.8)**

- Menu principal : le jeu s'ouvre dessus. Jouer (lance une partie avec le profil), Comptoir du Croupier, Options, Quitter. Un bouton « Menu » ramène du Comptoir et de l'écran de fin au menu ; Échap revient en arrière dans les menus.
- Options : volume Musique (60 % au départ) et volume Effets (80 %), plein écran, « Réduire les tremblements d'écran » (coupe aussi les arrêts sur image), « Réduire les flashs » (coupe aussi le pulsement des néons), et un écran de crédits. Elles sont enregistrées dans `user://options.save` (JSON versionné, même écriture sûre que le profil : fichier temporaire, `.bak`, version plus récente refusée sans être écrasée). Les tests et les outils n'écrivent jamais dans le vrai fichier d'options.
- Touches : Espace, Entrée, Entrée du pavé numérique ou bouton A de la manette tirent le levier ; Échap ou bouton B reviennent en arrière. Les actions sont créées par le code au lancement (le fichier `project.godot` n'est pas modifié). Le jeu reste jouable à la souris seule.
- Son : deux bus, Musique et Effets, créés au lancement ; un curseur règle le gain par le carré de sa valeur et coupe à 0. Aucun son ne joue directement sur le bus principal. Chaque effet répété a un petit décalage de hauteur (± 6 %). Sons : rouleaux, clic d'arrêt de chaque rouleau (un peu plus aigu à chaque rouleau), ding de combo, fanfare de jackpot, coup donné, coup reçu, bouclier, soin, pièces, bombe, achat, relique, clic, victoire, défaite.
- Musique : une boucle par étage (1, 2, 3) et une pour les boss ; le menu et le Comptoir reprennent celle de l'étage 1. Changement par fondu enchaîné d'environ 1,5 s ; la musique continue d'un écran à l'autre d'un même étage.
- Rouleaux : ils s'arrêtent un par un de gauche à droite (environ 0,12 s d'écart, avec un petit rebond). Le tirage est calculé d'un coup (les règles ne changent pas), seul l'affichage est étalé ; on ne peut pas valider avant la fin, et Espace pendant l'animation l'accélère.
- Effets de jeu : chiffres qui s'envolent (dégâts, coup reçu, armure, soin, or, 12 au plus à l'écran), tremblement d'écran proportionnel aux gros dégâts (secousse au carré qui retombe en un peu moins d'une seconde), arrêt sur image de 0,06 s au plus sur les gros impacts, flash, pluie de pièces et bannière sur un jackpot. Jamais plus de 3 flashs par seconde.
- Néons : un shader à halo pulsant (période de 2 s) sur les titres du menu, des portes, du Comptoir et de l'écran de fin, et sur la bannière de jackpot.
- Graphismes : le pack DungeonTileset II de 0x72 (CC0), agrandi d'un facteur entier sans lissage. Chaque ennemi a dans son `.tres` le nom de ses images (`images`), chaque symbole le nom de son icône (`icone`) ; le chevalier est le joueur. Le bouclier, l'aimant et le trèfle, absents du pack, sont dessinés par un script du projet (16×16). Le pack n'a pas d'images d'attaque ni de mort : les coups passent par les effets. Plusieurs ennemis n'ont pas d'image exacte (le Rat d'égout est une limace, le Rat-Croupier un ogre, le Pickpocket un diablotin…) : correspondance réglable dans les `.tres`.
- Crédits : `docs/CREDITS.md` liste chaque ressource externe (auteur, source, licence), et `assets/manifeste.json` le fait fichier par fichier ; un test vérifie que chaque image est déclarée.
- Équilibrage : aucune valeur de jeu n'a changé.

## Interface et contrôles

Le jeu se joue entièrement à la souris, avec la barre Espace comme raccourci pour tirer le levier. Résolution de base 1280 × 720, mise à l'échelle automatique en plein écran.

| Écran | Contenu |
| --- | --- |
| Menu principal | Jouer, Comptoir du Croupier, Options, Quitter |
| Options | Volume Musique et Effets, plein écran, réduire les tremblements et les flashs, crédits |
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

Style visé : pixel art sombre de donjon, avec des touches de néons dorés et rouges façon casino. Le développement a commencé avec des formes colorées et du texte à la place des images ; les vrais graphismes sont arrivés avec la v0.8.

- **Graphismes** : le pack 16x16 DungeonTileset II de 0x72 (CC0), complété au besoin par ses extensions dans le même style.
- **Sons** : rouleaux qui tournent, clic d'arrêt de chaque rouleau, « ding » de combo, fanfare de jackpot, coups, pièces.
- **Musique** : une boucle d'ambiance par étage, une musique de boss.
- **Effets de jeu** (le « juice ») : rouleaux qui s'arrêtent l'un après l'autre, tremblement d'écran sur gros dégâts, pluie de pièces sur un jackpot, chiffres de dégâts qui s'envolent.

Toute ressource externe doit avoir une licence qui autorise son usage ; sa source est notée dans un fichier CREDITS.md.

## Contraintes techniques

Le projet utilise Godot 4.7 et GDScript, dans le dossier `jackpot-donjon` déjà créé. Le contenu (symboles, ennemis, reliques) est décrit dans des fichiers de données, pour en ajouter sans toucher au code.

- **Langage** : GDScript avec typage statique (`var pv: int = 40`), pour attraper les erreurs plus tôt.
- **Données** : une ressource Godot (`.tres`) par symbole, ennemi et relique, basée sur des classes `SymbolData`, `EnemyData`, `RelicData`. Ces fichiers sont partagés : l'état qui change en jeu (PV restants d'un ennemi, symbole doré) vit dans une copie (`duplicate_deep()`) ou dans `GameState`, jamais dans le `.tres` lui-même.
- **État de la partie** : une classe `GameState` (membres statiques, sans autoload : un autoload est déclaré dans `project.godot`, que l'éditeur Godot ouvert peut réécrire sans lui) garde la partie en cours (PV, or, sac, reliques, étage et salle en cours).
- **Sauvegarde du profil** : jetons d'âme, avantages débloqués et malédictions sont enregistrés dans un fichier `user://profil.save`. Le fichier porte un numéro de version (pour migrer les anciens profils après une mise à jour) et s'écrit dans un fichier temporaire renommé ensuite, pour ne pas être corrompu par un plantage en pleine écriture.
- **Tests** : la logique (tirage, combos, effets, combat) est testée sans interface avec `godot --headless`, dans `tests/` ; le script de test se termine avec un code d'erreur s'il échoue.
- **Hasard** : une graine affichée en debug, pour pouvoir rejouer exactement une partie qui a bugué. Un générateur pour le jeu (tirages, récompenses, blocages) et, séparés, un par étage du donjon (portes, ennemis, mimiques), tous dérivés de la graine : même graine = même donjon, quoi que le joueur ait fait avant.
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
   - Fini quand : on peut miser avant un tirage et jouer avec des reliques qui changent les règles.
   - Réalisé : mises d'or et quitte ou double ; les 9 reliques ; tour en deux temps pour les relances (Dé pipé, Cinquième as) ; machine à 6 rouleaux (Sixième rouleau) ; une relique offerte après le combat 3 (1 parmi 2) ; 2 reliques en boutique.
6. **v0.6 – Le donjon** : 3 étages, choix entre 2 portes, coffres et repos, tous les ennemis et boss.
   - Fini quand : on traverse les 3 étages et on peut gagner la partie en battant le Grand Croupier.
   - Réalisé : 3 étages de 5 salles au choix entre 2 portes (combat, boutique, coffre, repos) puis un boss ; donjon généré à partir de la graine ; coffres (1 relique parmi 2) et mimiques à l'étage 3 ; repos (soin ou dorure) ; 9 ennemis, la Mimique et 3 boss avec leurs mécaniques (crânes temporaires, Usurier, fuite du Pickpocket, charge du Golem, attaque surprise, règles du Grand Croupier) ; relique offerte par chaque boss ; PV remontés de 50 % à chaque nouvel étage.
7. **v0.7 – Entre les parties** : jetons d'âme, Comptoir du Croupier, malédictions, sauvegarde du profil.
   - Fini quand : on gagne des jetons en jouant, on les dépense au Comptoir, et tout survit à la fermeture du jeu.
   - Réalisé : profil enregistré (écriture sûre, sauvegarde `.bak`, versions) ; Comptoir du Croupier au lancement et après chaque partie ; 6 achats (déblocage au hasard d'un symbole ou d'une relique, PV max, or de départ, relance gratuite, Trèfle) ; 5 malédictions ; bilan de fin de partie ; 4 nouveaux symboles (Bombe, Flèche, Aimant, Trèfle).
8. **v0.8 – Habillage** : graphismes, sons, musique, animations, menu principal.
   - Fini quand : le jeu a ses images, ses sons et sa musique, un menu principal et des options, et chaque tirage s'anime.
   - Réalisé : menu principal et options (volumes, plein écran, réduire les tremblements et les flashs, crédits, enregistrées) ; sons et musiques CC0 (Kenney, OpenGameArt) complétés par des sons générés ; bus Musique et Effets ; rouleaux qui s'arrêtent un par un, chiffres qui s'envolent, tremblement, arrêt sur image, pluie de pièces, flash, néons ; images du pack 0x72 pour les ennemis, le chevalier, les symboles et les portes, avec trois icônes dessinées ; Espace, Entrée et manette pour le levier, Échap pour revenir. Écarts : les néons ne sont pas sur les boutons de mise ; pas d'animations d'attaque ni de mort (le pack n'en a pas) ; sons manquants générés par script.
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
