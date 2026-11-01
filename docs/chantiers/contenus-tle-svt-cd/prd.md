# PRD — Les 10 premières leçons de SVT de Terminale C et D

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
> Vague T4 du programme [`contenus-v3-tous-niveaux`](../contenus-v3-tous-niveaux/feuille-de-route.md) : ses exigences transverses s'appliquent.

## 1. Contexte

La vague rédige les 10 premières leçons de SVT de Tle C et de Tle D de la progression 2026-2027 (17 leçons distinctes, 20 fichiers) au format v3, avec « Je m'entraîne » dans chaque notion et les figures de l'inventaire (ADR-0117). Aucun code.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | Importer les fichiers en brouillon, relire, publier | Importer un fichier que l'import refuse (règles inchangées) |
| Student | Réviser une leçon publiée, s'entraîner dans la fiche, faire ses exercices | Voir une leçon en brouillon |
| Teacher | Donner les exercices, corriger les questions rédigées | Modifier la leçon |

Aucune règle d'autorisation nouvelle.

## 3. Parcours utilisateur

### Chemin nominal

1. Un rédacteur par leçon distincte écrit le fichier avec `prompt-redaction.md` (matière SVT, niveau Tle).
2. Le contrôle (`valider.rb`) et le contrôle de l'entraînement passent sans erreur ni avertissement.
3. Un relecteur distinct relit le fond ; l'auteur corrige ; les contrôles sont relancés.
4. Les 3 leçons communes sont déclinées en D ; l'équipe importe en brouillon.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Schéma sans sorte ni planche | Décrit dans l'énoncé ou en `diagram` ; listé au journal comme besoin de planche |
| Moins de 50 % de questions corrigées automatiquement | Avertissement ; le fichier n'est pas livré |
| Fait ou valeur incertain | Non écrit ou donné comme résultat d'expérience ; signalé à l'enseignant |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Les leçons de SVT de Tle C et D

  Scénario: les leçons suivent la progression nationale
    Étant donné la progression 2026-2027 de SVT en Tle C et en Tle D
    Alors leurs 10 premières leçons ont chacune un fichier version 3 au même intitulé exact dans lecons-traitees/tle-c/svt et tle-d/svt
    Et chaque fichier porte level_name "Tle", material_name "SVT" et la série de son dossier
    Et aucun fichier version 1 n'y reste

  Scénario: chaque leçon livrée passe le contrôle
    Quand on lance ruby script/contenus/valider.rb sur chacun des 20 fichiers
    Alors il sort sans erreur ni avertissement

  Scénario: chaque notion a son entraînement
    Étant donné une notion d'un des 20 fichiers
    Alors elle porte un entraînement de 1 à 6 questions conforme à NotionPractice, distinct de son exercice noté
    Et chaque leçon a au moins une question à plusieurs cases et un indice

  Scénario: une leçon commune est la même dans les deux séries
    Étant donné une leçon commune à C et D
    Alors ses deux fichiers ne diffèrent que par series_name et subtitle
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine, infrastructure, delivery, UI, script | aucun changement |
| Contenus | 10 fichiers v3 dans `tle-c/svt/`, 10 dans `tle-d/svt/` (6 v1 remplacés) ; section Tle du README des contenus |

## 6. Décisions rattachées

- ADR-0116, ADR-0117, UDR-0142, ADR-0119/0120 et UDR-0147 (« Je m'entraîne »), appliqués sans amendement.
- Aucun ADR ni UDR nouveau.
