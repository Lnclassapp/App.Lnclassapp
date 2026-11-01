# PRD — Les 7 leçons de SVT de Terminale A1 et A2

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
> Vague T5 du programme [`contenus-v3-tous-niveaux`](../contenus-v3-tous-niveaux/feuille-de-route.md) : ses exigences transverses s'appliquent.

## 1. Contexte

La vague rédige les 7 leçons de SVT de Tle A1 et A2 de la progression 2026-2027 (7 leçons distinctes, 14 fichiers) au format v3, avec « Je m'entraîne » dans chaque notion et les figures de l'inventaire (ADR-0117). Aucun code.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | Importer les fichiers en brouillon, relire, publier | Importer un fichier que l'import refuse (règles inchangées) |
| Student | Réviser une leçon publiée, s'entraîner dans la fiche, faire ses exercices | Voir une leçon en brouillon |
| Teacher | Donner les exercices, corriger les questions rédigées | Modifier la leçon |

Aucune règle d'autorisation nouvelle.

## 3. Parcours utilisateur

### Chemin nominal

1. Un rédacteur par leçon écrit le fichier de `tle-a1/svt/` avec `prompt-redaction.md` (SVT, Tle, série A).
2. `valider.rb` et le contrôle de l'entraînement passent sans erreur ni avertissement.
3. Un relecteur distinct relit le fond ; les défauts sont corrigés ; les contrôles sont relancés.
4. Chaque leçon est déclinée dans `tle-a2/svt/` (seule `series_name` change) ; l'équipe importe en brouillon.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Schéma sans sorte ni planche | Décrit dans l'énoncé ou en `diagram` ; listé au journal comme besoin de planche |
| Moins de 50 % de questions corrigées automatiquement | Avertissement ; le fichier n'est pas livré |
| Fait ou valeur incertain | Non écrit ou donné comme résultat d'expérience ; signalé à l'enseignant |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Les leçons de SVT de Tle A1 et A2

  Scénario: les leçons suivent la progression nationale
    Étant donné la progression 2026-2027 de SVT en Tle A1 et en Tle A2
    Alors ses 7 leçons ont chacune un fichier version 3 au même intitulé exact dans lecons-traitees/tle-a1/svt et tle-a2/svt
    Et chaque fichier porte level_name "Tle", material_name "SVT" et la série de son dossier
    Et aucun fichier version 1 n'y reste

  Scénario: chaque leçon livrée passe le contrôle
    Quand on lance ruby script/contenus/valider.rb sur chacun des 14 fichiers
    Alors il sort sans erreur ni avertissement

  Scénario: chaque notion a son entraînement
    Étant donné une notion d'un des 14 fichiers
    Alors elle porte un entraînement de 1 à 6 questions conforme à NotionPractice, distinct de son exercice noté
    Et chaque leçon a au moins une question à plusieurs cases et un indice

  Scénario: une leçon est la même dans les deux séries
    Étant donné une leçon de Tle A1
    Alors son fichier de Tle A2 ne diffère que par series_name
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine, infrastructure, delivery, UI, script | aucun changement |
| Contenus | 7 fichiers v3 dans `tle-a1/svt/`, 7 dans `tle-a2/svt/` (6 v1 remplacés) ; section Tle du README des contenus |

## 6. Décisions rattachées

- ADR-0116, ADR-0117, UDR-0142, ADR-0119/0120 et UDR-0147 (« Je m'entraîne »), appliqués sans amendement.
- Aucun ADR ni UDR nouveau.
