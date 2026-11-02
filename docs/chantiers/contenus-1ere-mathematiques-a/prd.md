# PRD — Les 7 leçons de Mathématiques de 1ère A

> Vague P2 du programme [`contenus-v3-tous-niveaux`](../contenus-v3-tous-niveaux/feuille-de-route.md). Modèles : [`contenus-1ere-mathematiques-cd`](../contenus-1ere-mathematiques-cd/), [`contenus-tle-mathematiques-a`](../contenus-tle-mathematiques-a/).

## 1. Contexte

7 fichiers `lnclass.course-tree` v3 dans `docs/contenus/lecons-traitees/1ere-a/mathematiques/`.

| Rang | Leçon |
|---:|---|
| 1 | Équations et inéquations |
| 2 | Dénombrement |
| 3 | Généralités sur les fonctions |
| 4 | Dérivabilité et étude de fonctions |
| 5 | Suites numériques |
| 6 | Statistique |
| 7 | Systèmes d'équations dans ℝ × ℝ |

## 2. Acteurs et permissions

Inchangés : Team importe en brouillon et publie, Student révise et s'entraîne, Teacher donne les exercices. Aucune règle d'autorisation nouvelle.

## 3. Critères d'acceptation

```gherkin
Fonctionnalité: Les leçons de Mathématiques de 1ère A

  Scénario: les leçons suivent la progression
    Alors les rangs 1 à 7 ont chacun un fichier version 3 à l'intitulé exact de la progression
    Et chaque fichier porte level_name "1ère", material_name "Mathématiques" et series_name "A"
    Et aucun fichier v1 de ces intitulés ne reste dans 1ere-a1/ ni 1ere-a2/

  Scénario: chaque fichier passe le contrôle
    Quand on lance valider.rb et controle-entrainement.rb sur chacun des 7 fichiers
    Alors ils sortent sans erreur ni avertissement

  Scénario: les calculs sont justes
    Quand un relecteur distinct de l'auteur refait chaque calcul
    Alors il trouve les mêmes valeurs et chaque proposition marquée correcte l'est

  Scénario: une leçon ne sort pas de son rang
    Alors chaque leçon ne s'appuie que sur les leçons de rang inférieur et ne traite aucune notion d'une leçon suivante
```

## 4. Modélisation préliminaire

Aucun changement de code : figures des sortes existantes.

## 5. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Leçons v3 de Maths en 1ère A | 0 | 7 | 7 |
