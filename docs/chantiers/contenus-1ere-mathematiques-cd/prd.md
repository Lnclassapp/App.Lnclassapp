# PRD — Les 10 premières leçons de Mathématiques de 1ère C et de 1ère D

> Vague P1 du programme [`contenus-v3-tous-niveaux`](../contenus-v3-tous-niveaux/feuille-de-route.md). Modèle : [`contenus-tle-mathematiques-cd`](../contenus-tle-mathematiques-cd/prd.md).

## 1. Contexte

13 leçons distinctes, 20 fichiers `lnclass.course-tree` v3, rangés dans `docs/contenus/lecons-traitees/1ere-c/mathematiques/` et `1ere-d/mathematiques/`.

| Leçon | C | D |
|---|---:|---:|
| Équations et inéquations dans ℝ | 1 | — |
| Équations et inéquations du second degré dans ℝ | — | 1 |
| Angles orientés et trigonométrie | 2 | 2 |
| Généralités sur les fonctions | 3 | 3 |
| Barycentre | 4 | 8 |
| Limites et continuité | 5 | 4 |
| Dénombrement | 6 | 5 |
| Extension de la notion de limite | 7 | 7 |
| Composées de transformations du plan | 8 | — |
| Dérivation | 9 | 6 |
| Orthogonalité de l'espace | 10 | — |
| Étude et représentation graphique d'une fonction | — | 9 |
| Probabilité | — | 10 |

## 2. Acteurs et permissions

Team importe en brouillon et publie ; Student révise une leçon publiée ; Teacher donne les exercices. Aucune règle d'autorisation nouvelle.

## 3. Critères d'acceptation

```gherkin
Fonctionnalité: Les leçons de Mathématiques de 1ère C et D

  Scénario: les leçons suivent les progressions
    Alors les rangs 1 à 10 de 1ère C et de 1ère D ont chacun un fichier version 3 à l'intitulé exact de la progression
    Et chaque fichier porte level_name "1ère", material_name "Mathématiques" et la series_name de sa série
    Et aucun fichier version 1 ne reste dans lecons-traitees/1ere-c/mathematiques ni 1ere-d/mathematiques

  Scénario: chaque fichier passe le contrôle
    Quand on lance ruby script/contenus/valider.rb sur chacun des 20 fichiers
    Alors il sort sans erreur ni avertissement

  Scénario: chaque notion a son entraînement
    Alors chaque notion porte un practice de 1 à 6 questions accepté par NotionPractice
    Et chaque leçon a au moins une question à plusieurs cases et un indice
    Et aucune question d'entraînement n'est celle de l'exercice noté de la notion

  Scénario: les calculs sont justes
    Quand un relecteur Opus distinct de l'auteur refait chaque valeur d'un exemple, d'une question ou d'une correction
    Alors il trouve la même valeur, et la proposition marquée correcte est la bonne

  Scénario: une leçon commune est adaptée à sa série
    Alors ses deux fichiers ont les mêmes notions
    Et les problèmes 3 et 4 du fichier D sont écrits au niveau de la série D

  Scénario: les rangs respectent la progression
    Alors aucune leçon ne traite une notion d'une leçon qui la suit dans sa progression
```

## 4. Modélisation préliminaire

Aucun changement de code : figures des sortes existantes.

## 5. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Leçons v3 de Maths en 1ère C | 0 | 10 | |
| Leçons v3 de Maths en 1ère D | 0 | 10 | |
