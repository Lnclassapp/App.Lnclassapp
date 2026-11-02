# PRD — Les 11 leçons de Français de Première (A, C, D)

> Les specs sont figées ici. Vague P8 du programme [`contenus-v3-tous-niveaux`](../contenus-v3-tous-niveaux/feuille-de-route.md) : ses exigences transverses s'appliquent.

## 1. Contexte

La vague rédige les 11 leçons distinctes de Français de 1ère de la progression 2026-2027 au format v3, avec « Je m'entraîne » dans chaque notion, et les décline en 40 fichiers (10 en A1, 10 en A2, 10 en C, 10 en D). Aucun code.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | Importer les fichiers en brouillon, relire, publier | Importer un fichier que l'import refuse |
| Student | Réviser une leçon publiée, s'entraîner dans la fiche | Voir une leçon en brouillon |
| Teacher | Donner les exercices, corriger les questions rédigées | Modifier la leçon |

Aucune règle d'autorisation nouvelle.

## 3. Parcours utilisateur

1. Un rédacteur par leçon écrit le fichier avec `prompt-redaction.md` (Français, 1ère).
2. `valider.rb` et le contrôle de l'entraînement passent sans erreur ni avertissement.
3. Un relecteur distinct (Opus) relit le fond ; les défauts sont corrigés ; les contrôles sont relancés.
4. Chaque leçon est déclinée par série (`series_name` et rang du `subtitle`).

| Situation | Comportement attendu |
|---|---|
| Moins de 50 % de questions corrigées automatiquement | Avertissement ; le fichier n'est pas livré |
| Fait d'œuvre ou règle d'épreuve incertain | Non écrit ; signalé à l'enseignant |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Les leçons de Français de 1ère

  Scénario: les leçons suivent la progression nationale
    Étant donné la progression 2026-2027 de Français en 1ère A, C et D
    Alors chacune de ses leçons a un fichier version 3 au même intitulé exact dans lecons-traitees/1ere-<série>/francais
    Et chaque fichier porte level_name "1ère", material_name "Français", la série de son dossier et le rang de sa progression
    Et aucun fichier version 1 n'y reste

  Scénario: chaque leçon livrée passe le contrôle
    Quand on lance ruby script/contenus/valider.rb sur chaque fichier
    Alors il sort sans erreur ni avertissement

  Scénario: chaque notion a son entraînement
    Étant donné une notion d'un fichier
    Alors elle porte un entraînement de 1 à 6 questions conforme à NotionPractice, distinct de son exercice noté
    Et chaque leçon a au moins une question à plusieurs cases et un indice

  Scénario: une leçon est la même dans toutes les séries
    Étant donné une leçon de 1ère A (ou C pour les valeurs des temps verbaux)
    Alors ses fichiers des autres séries ne diffèrent que par series_name et le rang du subtitle
```

## 5. Modélisation préliminaire

Aucun changement de domaine, d'infrastructure, de delivery ni d'UI. Contenus : fichiers v3 dans `1ere-{a,c,d}/francais/` ; section 1ère du README des contenus.

## 6. Décisions rattachées

ADR-0116, ADR-0119/0120 et UDR-0147 (« Je m'entraîne »), appliqués sans amendement. Aucun ADR ni UDR nouveau.
