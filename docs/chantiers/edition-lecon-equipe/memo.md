# Memo — Édition d'une leçon par l'équipe

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-11-14 |
| **Branche** | `fix/edition-lecon-equipe` |
| **Programme** | — |

## Symptôme

Constat du porteur en production, compte équipe, fiche d'une leçon publiée :

1. « La modification n'affiche pas les contenus à modifier » : la modale « Modifier la fiche de cours » montre un éditeur « Contenu » vide.
2. « Les exercices n'ont pas d'options » : aucun menu ⋮ sur un exercice (ni publier, ni archiver), ni sur une notion.

## Reproduction

Jeu standard (`bin/jeu-standard`), compte équipe, leçon `histoire-l-essor-du-capitalisme-et-ses-consequences` :

1. Menu ⋮ de la leçon → « Modifier » : nom, sous-titre, niveau, série, matière remplis ; « Contenu » vide (74 leçons sur 75 du jeu ont un contenu Action Text vide).
2. « Prépare interros » → feuille 1 : chaque exercice n'a ni statut publié ni menu ; la fiche de révision : chaque notion n'a ni statut ni menu.

Reproduit à la main le 2026-11-14 (captures `avant-*` envoyées au porteur).

## Portée

- Depuis ADR-0113 (la notion perd sa page, et avec elle son menu, UDR-0015) et ADR-0121 (l'exercice se lit dans la feuille ; sa page, qui portait son menu, UDR-0021, n'est plus liée depuis la leçon).
- Acteurs : l'équipe seulement. Élève, enseignant, direction : rien ne change.
- Données : aucune donnée fausse, rien à réparer.

## Verdict par point

| Point | Défaut ou choix ? | Source |
|---|---|---|
| 1. Modale vide | **Choix documenté**, mal signalé. Le formulaire recharge bien tout ce que la leçon enregistre (test `the edit form reloads the saved course, content included`). Ce que la page montre (fiche de révision, notions, exercices) vient de l'import, pas de ce formulaire : ADR-0110, ADR-0113 §4.6. Correctif : la modale le dit et mène à l'import. | ADR-0110, 0113 §4.6, UDR-0014 |
| 2. Pas de menu ⋮ | **Défaut** (régression). Chaque contenu garde son cycle de vie et ses transitions (ADR-0035, UDR-0042) ; les routes `teams/essentials|exercises/:id/publish|archive` existent mais plus aucun écran n'y mène depuis la leçon. | ADR-0035, UDR-0015, 0021, 0042 |
| 3. Corriger le texte d'une notion ou d'un exercice à l'écran | **Hors bugfix** : contredit ADR-0113 §4.6. Écrit dans `## À trancher` du journal. | ADR-0113 §4.6 |

## Hors périmètre

- Édition à l'écran du texte des notions et des exercices (ADR à rouvrir, voir journal).
- Suppression d'une leçon, d'une notion ou d'un exercice (autre session).
- Le champ « Contenu » Action Text, que plus aucune page ne montre (journal, dette).

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [x] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [x] Test au vert · suite du contexte borné au vert
- [x] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [x] Données déjà corrompues : aucune
- [x] Challenger a rejoué les étapes de reproduction dans l'application
- [x] Commit `fix(catalog): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés
