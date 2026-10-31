# PRD — Les 10 premières leçons de Mathématiques de Tle C et de Tle D

> Vague T1 du programme [`contenus-v3-tous-niveaux`](../contenus-v3-tous-niveaux/feuille-de-route.md). Modèle : [`refonte-contenus-maths`](../refonte-contenus-maths/) (ADR-0116, UDR-0141), figures ADR-0117, entraînement [`je-m-entraine-dans-la-fiche`](../je-m-entraine-dans-la-fiche/memo.md).

## 1. Contexte

14 leçons distinctes, 20 fichiers `lnclass.course-tree` v3 prêts à importer, rangés dans `docs/contenus/lecons-traitees/tle-c/mathematiques/` et `tle-d/mathematiques/`.

| Leçon | C | D |
|---|---:|---:|
| Barycentre et lignes de niveaux | 1 | — |
| Limites et continuité | 2 | 1 |
| Divisibilité dans ℤ | 3 | — |
| Dérivabilité et étude de fonctions | 4 | 3 |
| Géométrie analytique de l'espace | 5 | — |
| Primitives | 6 | 4 |
| Fonctions logarithmes | 7 | 5 |
| Coniques | 8 | — |
| Fonctions exponentielles et fonctions puissances (C) / et puissances (D) | 9 | 6 |
| Nombres complexes | 10 | 8 |
| Probabilité conditionnelle et variable aléatoire | — | 2 |
| Suites numériques | — | 7 |
| Calcul intégral | — | 9 |
| Nombres complexes et géométrie du plan | — | 10 |

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | Importer en brouillon, relire, publier | Importer un fichier qui ne passe pas le contrôle |
| Student | Réviser une leçon publiée, s'entraîner dans la fiche | Voir une leçon en brouillon |
| Teacher | Donner les exercices de la leçon | Modifier la leçon |

Aucune règle d'autorisation nouvelle.

## 3. Critères d'acceptation

```gherkin
Fonctionnalité: Les leçons de Mathématiques de Tle C et D

  Scénario: les leçons suivent les progressions
    Alors les rangs 1 à 10 de Tle C et de Tle D ont chacun un fichier version 3 à l'intitulé exact de la progression
    Et chaque fichier porte level_name "Tle", material_name "Mathématiques" et la series_name de sa série
    Et aucun fichier version 1 ne reste dans lecons-traitees/tle-c/mathematiques ni tle-d/mathematiques

  Scénario: chaque fichier passe le contrôle
    Quand on lance ruby script/contenus/valider.rb sur chacun des 20 fichiers
    Alors il sort sans erreur ni avertissement

  Scénario: chaque notion a son entraînement
    Alors chaque notion porte un practice de 1 à 6 questions accepté par NotionPractice
    Et chaque leçon a au moins une question à plusieurs cases et un indice
    Et aucune question d'entraînement n'est celle de l'exercice noté de la notion

  Scénario: les calculs sont justes
    Étant donné chaque valeur d'un exemple, d'une question ou d'une correction
    Quand une relecture indépendante (un autre agent que l'auteur) la refait
    Alors elle trouve la même valeur, et la proposition marquée correcte est la bonne

  Scénario: une leçon commune est adaptée à sa série
    Étant donné une leçon commune à C et D
    Alors ses deux fichiers ont les mêmes notions
    Et les problèmes de niveau devoir et bac du fichier D sont écrits au niveau de la série D
```

## 4. Modélisation préliminaire

Aucun changement de code : figures des sortes existantes (`geometry`, `coordinate_plane`, `number_line`, `stat_chart`, `diagram`).

## 5. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Leçons v3 de Maths en Tle C | 0 | 10 | |
| Leçons v3 de Maths en Tle D | 0 | 10 | |
