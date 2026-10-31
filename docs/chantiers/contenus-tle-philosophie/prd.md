# PRD — Les 10 premières leçons de Philosophie de Tle

> Vague T6 du programme [`contenus-v3-tous-niveaux`](../contenus-v3-tous-niveaux/feuille-de-route.md) ; critères transverses du programme et de la vague [`contenus-3e-francais`](../contenus-3e-francais/prd.md).

## 1. Contexte

Rédiger les 10 premières leçons de la progression 2026-2027 de Philosophie de Tle en fichiers v3, une fois chacune, déclinées en un fichier par série (A1, A2, C, D).

## 2. Acteurs et permissions

Aucune règle nouvelle : Team importe en brouillon et publie ; Student révise une leçon publiée ; Teacher donne et corrige les exercices.

## 3. Parcours

Rédaction → `script/contenus/valider.rb` → relecture IA indépendante → corrections → contrôle → déclinaison par série → rangement.

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Les leçons de Philosophie de Tle

  Scénario: les leçons suivent la progression nationale
    Étant donné la progression 2026-2027 de Philosophie de Tle pour A1, A2, C et D
    Alors chacune de ses 10 premières leçons (9 en C et D) a un fichier version 3 au même intitulé exact
    Et le sous-titre porte le rang de la série, series_name la série
    Et aucun fichier version 1 n'y reste

  Scénario: chaque fichier passe le contrôle
    Quand on lance ruby script/contenus/valider.rb sur chacun des 38 fichiers
    Alors il sort sans erreur ni avertissement

  Scénario: une leçon est la même d'une série à l'autre
    Étant donné les fichiers d'une même leçon dans deux séries
    Alors ils ne diffèrent que par series_name et le rang du sous-titre
```

## 5. Modélisation

Aucun changement de code. Contenus : `docs/contenus/lecons-traitees/tle-{a1,a2,c,d}/philosophie/*.json` ; consigne : `prompt-redaction.md` (ligne Philosophie).

## 6. Décisions rattachées

Aucun ADR ni UDR : aucun port, table, contrat ou vue.
