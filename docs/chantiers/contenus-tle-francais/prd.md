# PRD — Les 7 leçons de Français de Terminale (A1, A2, C, D)

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
> Vague T7 du programme [`contenus-v3-tous-niveaux`](../contenus-v3-tous-niveaux/feuille-de-route.md) : ses exigences transverses s'appliquent.

## 1. Contexte

La vague rédige les 7 leçons distinctes de Français de Tle de la progression 2026-2027 au format v3, avec « Je m'entraîne » dans chaque notion, et les décline en 26 fichiers (7 en A1, 7 en A2, 6 en C, 6 en D). Aucun code.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | Importer les fichiers en brouillon, relire, publier | Importer un fichier que l'import refuse (règles inchangées) |
| Student | Réviser une leçon publiée, s'entraîner dans la fiche, faire ses exercices | Voir une leçon en brouillon |
| Teacher | Donner les exercices, corriger les questions rédigées | Modifier la leçon |

Aucune règle d'autorisation nouvelle.

## 3. Parcours utilisateur

### Chemin nominal

1. Un rédacteur par leçon écrit le fichier de `tle-a1/francais/` avec `prompt-redaction.md` (Français, Tle).
2. `valider.rb` et le contrôle de l'entraînement passent sans erreur ni avertissement.
3. Un relecteur distinct relit le fond ; les défauts sont corrigés ; les contrôles sont relancés.
4. Chaque leçon est déclinée dans les autres séries (`series_name` et rang du `subtitle`) ; l'équipe importe en brouillon.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Moins de 50 % de questions corrigées automatiquement | Avertissement ; le fichier n'est pas livré |
| Fait d'œuvre ou règle d'épreuve incertain | Non écrit ; signalé à l'enseignant |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Les leçons de Français de Tle

  Scénario: les leçons suivent la progression nationale
    Étant donné la progression 2026-2027 de Français en Tle A1, A2, C et D
    Alors chacune de ses leçons a un fichier version 3 au même intitulé exact dans lecons-traitees/tle-<série>/francais
    Et chaque fichier porte level_name "Tle", material_name "Français", la série de son dossier et le rang de sa progression
    Et aucun fichier version 1 n'y reste

  Scénario: chaque leçon livrée passe le contrôle
    Quand on lance ruby script/contenus/valider.rb sur chacun des 26 fichiers
    Alors il sort sans erreur ni avertissement

  Scénario: chaque notion a son entraînement
    Étant donné une notion d'un des 26 fichiers
    Alors elle porte un entraînement de 1 à 6 questions conforme à NotionPractice, distinct de son exercice noté
    Et chaque leçon a au moins une question à plusieurs cases et un indice

  Scénario: une leçon est la même dans toutes les séries
    Étant donné une leçon de Tle A1
    Alors ses fichiers des autres séries ne diffèrent que par series_name et le rang du subtitle
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine, infrastructure, delivery, UI, script | aucun changement |
| Contenus | 26 fichiers v3 dans `tle-a1/`, `tle-a2/`, `tle-c/`, `tle-d/` `francais/` (12 v1 remplacés) ; section Tle du README des contenus |

## 6. Décisions rattachées

- ADR-0116, ADR-0119/0120 et UDR-0147 (« Je m'entraîne »), appliqués sans amendement.
- Aucun ADR ni UDR nouveau.
