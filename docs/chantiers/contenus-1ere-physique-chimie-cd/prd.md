# PRD — Les leçons de Physique-Chimie de 1ère C et D au format v3

> Vague P3 du programme [`contenus-v3-tous-niveaux`](../contenus-v3-tous-niveaux/feuille-de-route.md). Modèle : [`contenus-tle-physique-chimie`](../contenus-tle-physique-chimie/prd.md), sans code.

## 1. Contexte

Rédiger les 10 premières leçons de Physique-Chimie de 1ère C et de 1ère D (12 contenus, 13 intitulés) en fichiers `lnclass.course-tree` v3 prêts à importer en brouillon, selon [`prompt-redaction.md`](../../contenus/prompt-redaction.md) et [`prompt-redaction-lot.md`](../../contenus/prompt-redaction-lot.md).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | Importer en brouillon, relire, publier | Importer un fichier refusé par `valider.rb` |
| Student | Réviser une leçon publiée, s'entraîner dans la fiche | Voir une leçon en brouillon |
| Teacher | Donner les exercices | Modifier la leçon |

Aucune règle d'autorisation nouvelle.

## 3. Parcours utilisateur

1. L'équipe importe une leçon de 1ère C ou D en brouillon ; ses figures sont acceptées.
2. La fiche montre, par notion, les 4 blocs, la figure, « Je m'entraîne ».
3. Un enseignant relit les points listés au journal du programme ; l'équipe publie.

| Situation | Comportement attendu |
|---|---|
| Fichier avec erreur ou avertissement de `valider.rb` | Non livré |
| Notion douteuse au regard du programme | « À compléter » et point à valider au journal |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Leçons de Physique-Chimie de 1ère C et D

  Scénario: chaque leçon de la progression a son fichier v3
    Étant donné les 10 premières leçons de Physique-Chimie de 1ère C et de 1ère D
    Alors chacune a un fichier v3 dans lecons-traitees/1ere-c ou 1ere-d/physique-chimie
    Et son name, son level_name "1ère", son material_name "Physique-Chimie" et son series_name sont exacts

  Scénario: chaque fichier passe le contrôle
    Quand on lance ruby script/contenus/valider.rb sur les 20 fichiers
    Alors aucun n'a d'erreur ni d'avertissement

  Scénario: chaque notion a sa fiche, son exercice et son entraînement
    Alors chaque notion a les 4 blocs, un exercice de 5 questions au moins et un entraînement de 1 à 6 questions
    Et chaque leçon a 4 problèmes, au moins une question à plusieurs cases et un indice dans ses entraînements

  Scénario: une leçon commune à C et D est la même
    Alors les deux fichiers ne diffèrent que par series_name, le rang du subtitle et, pour la leçon 1, l'intitulé
```
