# PRD — Les 10 premières leçons d'Histoire-Géographie de Tle

> Vague T8 du programme [`contenus-v3-tous-niveaux`](../contenus-v3-tous-niveaux/feuille-de-route.md) ; critères transverses de la vague [`contenus-3e-histoire-geographie`](../contenus-3e-histoire-geographie/prd.md).

## 1. Contexte

Rédiger les 10 premières leçons de la progression 2026-2027 d'Histoire-Géographie de Tle en fichiers v3, une fois chacune, sans série.

## 2. Acteurs et permissions

Aucune règle nouvelle : Team importe en brouillon et publie ; Student révise une leçon publiée ; Teacher donne et corrige les exercices.

## 3. Parcours

Rédaction → `script/contenus/valider.rb` → test « Je m'entraîne » → relecture IA indépendante → corrections → contrôles → rangement.

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Les leçons d'Histoire-Géographie de Tle

  Scénario: les leçons suivent la progression nationale
    Étant donné la progression 2026-2027 d'Histoire-Géographie de Tle
    Alors chacune de ses 10 premières leçons a un fichier version 3 au même intitulé exact dans lecons-traitees/tle/histoire-geographie/
    Et aucun fichier n'a de series_name
    Et aucun fichier version 1 d'HG ne reste dans tle-a1, tle-a2, tle-c, tle-d

  Scénario: chaque fichier passe le contrôle
    Quand on lance ruby script/contenus/valider.rb sur chacun des 10 fichiers
    Alors il sort sans erreur ni avertissement

  Scénario: chaque notion a son entraînement
    Quand on lance test/integration/contenus/tle_histoire_geographie_je_m_entraine_test.rb
    Alors chaque notion porte un practice de 1 à 6 questions bien formées, distinctes de l'exercice noté

  Scénario: la démo Saint-Michel trouve l'HG sans série
    Étant donné db/seeds/demo/saint_michel.rb
    Alors il lit lecons-traitees/tle/ et cherche un cours sans série sans série
```

## 5. Modélisation

Aucun port, table, contrat ni vue. Contenus : `docs/contenus/lecons-traitees/tle/histoire-geographie/*.json` ; test d'intégration du contenu ; démo `db/seeds/demo/saint_michel.rb` (rangement).

## 6. Décisions rattachées

Aucun ADR ni UDR.
