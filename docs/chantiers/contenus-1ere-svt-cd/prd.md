# PRD — Les 10 premières leçons de SVT de 1ère C et D

> Vague P5 du programme [`contenus-v3-tous-niveaux`](../contenus-v3-tous-niveaux/feuille-de-route.md) : ses exigences transverses s'appliquent. Modèle : [`contenus-tle-svt-cd`](../contenus-tle-svt-cd/prd.md).

## 1. Contexte

Rédiger les 10 premières leçons de SVT de 1ère C et de 1ère D (progression 2026-2027 ; 16 leçons distinctes, 20 fichiers) au format v3, avec « Je m'entraîne » dans chaque notion et les figures de l'inventaire (ADR-0117). Aucun code.

## 2. Acteurs et permissions

Team (importe en brouillon, relit, publie), Student (révise, s'entraîne), Teacher (donne les exercices). Aucune règle d'autorisation nouvelle.

## 3. Parcours

Un rédacteur par leçon écrit le fichier avec `prompt-redaction.md` ; `valider.rb` et le contrôle de l'entraînement passent ; un relecteur distinct (Opus) relit le fond ; l'auteur corrige ; les leçons communes sont déclinées en D.

| Situation | Comportement attendu |
|---|---|
| Schéma sans sorte ni planche | Décrit dans l'énoncé ou en `diagram` ; listé au journal comme besoin |
| Moins de 50 % de questions corrigées automatiquement | Avertissement ; fichier non livré |
| Fait ou valeur incertain | Non écrit ou donné comme résultat d'expérience ; signalé à l'enseignant |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Les leçons de SVT de 1ère C et D

  Scénario: les leçons suivent la progression nationale
    Étant donné la progression 2026-2027 de SVT en 1ère C et en 1ère D
    Alors leurs 10 premières leçons ont chacune un fichier version 3 au même intitulé exact dans lecons-traitees/1ere-c/svt et 1ere-d/svt
    Et chaque fichier porte level_name "1ère", material_name "SVT" et la série de son dossier
    Et aucun fichier version 1 n'y reste

  Scénario: chaque leçon livrée passe le contrôle
    Quand on lance ruby script/contenus/valider.rb sur chacun des 20 fichiers
    Alors il sort sans erreur ni avertissement

  Scénario: chaque notion a son entraînement
    Étant donné une notion d'un des 20 fichiers
    Alors elle porte un entraînement de 1 à 6 questions conforme à NotionPractice, distinct de son exercice noté

  Scénario: une leçon commune est la même dans les deux séries
    Étant donné une leçon commune à C et D
    Alors ses deux fichiers ne diffèrent que par series_name et subtitle
```

## 5. Modélisation et décisions

Contenus seulement : 10 fichiers dans `1ere-c/svt/`, 10 dans `1ere-d/svt/`, section 1ère du README des contenus. ADR-0116/0117, UDR-0142/0147 appliqués sans amendement ; aucun ADR ni UDR nouveau.
