# PRD — Les 8 premières leçons de Philosophie de 1ère

> Vague P7 du programme [`contenus-v3-tous-niveaux`](../contenus-v3-tous-niveaux/feuille-de-route.md).

## 1. Contexte

Rédiger les 8 leçons de la progression 2026-2027 de Philosophie de 1ère en fichiers v3, une fois chacune, déclinées en un fichier par série (A1, A2, C, D).

## 2. Acteurs et permissions

Aucune règle nouvelle : Team importe en brouillon et publie ; Student révise une leçon publiée ; Teacher donne et corrige les exercices.

## 3. Parcours

Rédaction → `script/contenus/valider.rb` → relecture Opus indépendante → corrections → contrôle → déclinaison par série → rangement.

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Les leçons de Philosophie de 1ère

  Scénario: les leçons suivent la progression nationale
    Étant donné la progression 2026-2027 de Philosophie de 1ère
    Alors chacune de ses 8 leçons a un fichier version 3 au même intitulé exact dans 1ere-a1, 1ere-a2, 1ere-c et 1ere-d
    Et series_name porte la série et aucun fichier version 1 n'y reste

  Scénario: chaque fichier passe le contrôle
    Quand on lance ruby script/contenus/valider.rb sur chacun des 32 fichiers
    Alors il sort sans erreur ni avertissement

  Scénario: une leçon est la même d'une série à l'autre
    Étant donné les fichiers d'une même leçon dans deux séries
    Alors ils ne diffèrent que par series_name
```

## 5. Modélisation

Aucun changement de code. Contenus : `docs/contenus/lecons-traitees/1ere-{a1,a2,c,d}/philosophie/*.json`.
