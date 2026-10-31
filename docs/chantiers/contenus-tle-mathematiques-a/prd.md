# PRD — Les leçons de Mathématiques de Tle A1 et de Tle A2

> Vague T2 du programme [`contenus-v3-tous-niveaux`](../contenus-v3-tous-niveaux/feuille-de-route.md). Modèle : [`contenus-tle-mathematiques-cd`](../contenus-tle-mathematiques-cd/) (vague T1), [`refonte-contenus-maths`](../refonte-contenus-maths/) (ADR-0116, UDR-0141), figures ADR-0117, entraînement [`je-m-entraine-dans-la-fiche`](../je-m-entraine-dans-la-fiche/memo.md).

## 1. Contexte

9 leçons distinctes, 15 fichiers `lnclass.course-tree` v3 prêts à importer, rangés dans `docs/contenus/lecons-traitees/tle-a1/mathematiques/` et `tle-a2/mathematiques/`.

| Leçon | A1 | A2 |
|---|---:|---:|
| Étude de fonctions polynômes et de fonctions rationnelles | 1 | 1 |
| Probabilité et variable aléatoire | 2 | — |
| Probabilité | — | 2 |
| Primitives et calcul intégral | 3 | — |
| Fonction logarithme népérien | 4 | 3 |
| Fonction exponentielle népérienne | 5 | 4 |
| Statistique à deux variables | 6 | 5 |
| Suites numériques | 7 | 6 |
| Systèmes d'équations linéaires dans ℝ × ℝ | 8 | 7 |

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | Importer en brouillon, relire, publier | Importer un fichier qui ne passe pas le contrôle |
| Student | Réviser une leçon publiée, s'entraîner dans la fiche | Voir une leçon en brouillon |
| Teacher | Donner les exercices de la leçon | Modifier la leçon |

Aucune règle d'autorisation nouvelle.

## 3. Critères d'acceptation

```gherkin
Fonctionnalité: Les leçons de Mathématiques de Tle A1 et A2

  Scénario: les leçons suivent les progressions
    Alors les rangs 1 à 8 de Tle A1 et 1 à 7 de Tle A2 ont chacun un fichier version 3 à l'intitulé exact de la progression
    Et chaque fichier porte level_name "Tle", material_name "Mathématiques" et la series_name de sa série
    Et aucun fichier version 1 ne reste dans lecons-traitees/tle-a1/mathematiques ni tle-a2/mathematiques

  Scénario: chaque fichier passe le contrôle
    Quand on lance ruby script/contenus/valider.rb sur chacun des 15 fichiers
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
    Étant donné une leçon commune à A1 et A2
    Alors ses deux fichiers ont les mêmes notions
    Et le fichier A2 ne s'appuie sur aucune leçon absente de la progression A2 (primitives, intégrale, variable aléatoire)
```

## 4. Modélisation préliminaire

Aucun changement de code : figures des sortes existantes (`coordinate_plane`, `number_line`, `stat_chart`, `diagram`).

## 5. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Leçons v3 de Maths en Tle A1 | 0 | 8 | |
| Leçons v3 de Maths en Tle A2 | 0 | 7 | |
