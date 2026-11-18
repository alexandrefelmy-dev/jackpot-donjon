---
name: fin-de-session
description: Clôture une session de travail sur Jackpot Donjon. Lance les tests, met à jour l'état actuel dans CLAUDE.md (et le cahier des charges si une règle a changé), fait le commit git et résume la session pour Alex. Lancé par Alex avec /fin-de-session, suivi éventuellement d'une note.
disable-model-invocation: true
---

# Fin de session

Alex arrête de travailler pour aujourd'hui. Fais les étapes ci-dessous dans l'ordre, sans en sauter.
Note éventuelle d'Alex à prendre en compte : $ARGUMENTS

## 1. Faire le point

- Lance `git status --short` et `git diff --stat` pour voir ce qui a changé pendant la session.
- Si le dossier n'est pas encore un dépôt git, propose à Alex de lancer `git init` et attends sa réponse avant de continuer à l'étape 5.
- Relis la conversation : qu'est-ce qui a été fait, qu'est-ce qui reste en cours, quels problèmes sont connus ?

## 2. Lancer les tests

- Lance les tests indiqués dans la section « Vérifier son travail » de CLAUDE.md.
- Si un test échoue, ne le corrige pas maintenant : note-le dans l'état actuel (étape 3) et signale-le à Alex.
- Si Godot est introuvable, dis-le et passe à la suite.

## 3. Mettre à jour l'état actuel dans CLAUDE.md

Remplace le contenu de la section « État actuel » (garde la ligne IMPORTANT en tête). N'ajoute pas l'historique à la suite : la section décrit seulement la situation d'aujourd'hui, en 10 lignes au maximum :

- **Fait** : ce qui marche maintenant (version, fonctionnalités).
- **À tester par Alex en jeu** : ce qui n'a pas encore été vérifié avec F5, et comment le tester.
- **Problèmes connus** : tests en échec, bugs repérés, points à équilibrer.
- **Prochaine étape** : la tâche suivante, d'après les jalons du cahier des charges.

## 4. Mettre à jour le cahier des charges si besoin

Si une règle du jeu, une valeur ou un jalon a changé pendant la session :
- mets à jour `docs/cahier-des-charges.md` ;
- garde la liste exacte des changements pour le résumé final (Alex devra les reporter dans la version en ligne).

## 5. Commit git

- Vérifie qu'aucun fichier sensible (mot de passe, clé, fichier `.env`) ne part dans le commit.
- `git add -A`, puis un commit avec un message court en français qui dit ce qui a été fait, par exemple `v0.2 : premier combat contre un ennemi`.
- Ne pousse pas sur GitHub sauf si Alex le demande.

## 6. Résumé pour Alex

Termine par un message court (6 lignes au maximum) :

1. Ce qui a été fait pendant la session.
2. Ce qu'Alex doit tester en jeu, et comment.
3. Les changements à reporter dans le cahier des charges en ligne (s'il y en a).
4. La prochaine étape.
5. Comment reprendre : propose un nom de session et rappelle les commandes `/rename <nom>` maintenant, puis `claude --resume <nom>` (ou `claude --continue`) la prochaine fois.
