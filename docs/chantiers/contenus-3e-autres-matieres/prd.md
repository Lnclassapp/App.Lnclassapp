# PRD cadre — Leçons de 3ème en SVT, Physique-Chimie, Histoire-Géographie, Français et EDHC, et leurs figures

> PRD cadre du programme : ses critères valent pour toutes les vagues ; chaque vague les reprend dans le PRD de son chantier, pour les sortes et la matière qu'elle livre.
>
> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

En 3ème, seules les maths ont des leçons au format v3 ; les 10 premières leçons de la progression nationale en SVT, PC, HG, Français et EDHC sont vides. Le chantier ajoute six sortes de figures (frise, carte, schéma fléché, tracé optique, planche légendée, molécule) et une courbe, puis rédige les 50 leçons et les livre en fichiers prêts à importer. Programme en 5 vagues, une matière par vague, chacune avec sa PR et sa mise en production : Français, Histoire-Géographie, SVT, Physique-Chimie, EDHC.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | Importer les fichiers en brouillon, relire, publier (écran Imports existant) | Importer une leçon dont une figure est d'une sorte inconnue ou mal formée |
| Student | Lire la fiche de révision et faire les exercices d'une leçon publiée, figures comprises | Voir une leçon en brouillon |
| Teacher | Donner les exercices de la leçon à sa classe ; corriger les questions rédigées | Modifier la leçon |
| Parent, SchoolStaff | Rien de nouveau | — |

Aucune règle d'autorisation nouvelle : celles de l'import et de la lecture des leçons s'appliquent (ADR-0116).

## 3. Parcours utilisateur

### Chemin nominal

1. À la fin de chaque vague, le porteur reçoit les 10 fichiers de la matière ; les figures dont ils ont besoin sont déjà en production.
2. L'équipe importe un fichier depuis **Imports → Fiches de cours complètes** ; la leçon est créée en brouillon.
3. L'équipe ouvre la fiche de révision : chaque notion a ses quatre blocs, chaque figure se dessine, les curseurs la font varier.
4. L'équipe publie ; l'élève de 3ème révise la leçon et fait ses exercices.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Fichier avec une figure d'une sorte nouvelle importé avant la mise en production de son code | Refus `figure_invalid` (sorte inconnue) ; rien n'est créé |
| Carte qui cite un lieu ou une aire absents du fond ; planche qui cite une partie absente | Refus `figure_invalid` à l'import et au script, avec le chemin du paramètre |
| Frise dont un événement sort des bornes ; schéma `tree` avec deux racines ; molécule dont un carbone a 5 liaisons | Refus `figure_invalid` |
| Module de figure qui ne charge pas, ou JavaScript absent | La description de la figure reste affichée ; l'exercice reste faisable |
| Leçon de Français, HG ou EDHC dont moins de la moitié des questions sont corrigées automatiquement | Avertissement du script ; le lot ne livre pas le fichier tant qu'il reste |
| Question rédigée sans corrigé modèle | Refus existant (`blank`) |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Sortes de figures des matières de 3ème

  Scénario: chaque sorte nouvelle bien formée est acceptée
    Étant donné une figure de chacune des sortes timeline, map, diagram, optics, plate et molecule, bien formée
    Et une figure stat_chart de type line
    Quand le fichier est contrôlé par l'import et par le script
    Alors aucune erreur n'est rendue

  Scénario: une incohérence de figure est refusée de la même façon des deux côtés
    Étant donné une frise dont un événement est avant le début
    Ou une carte dont un lieu n'existe pas dans son fond
    Ou une planche dont une partie n'existe pas
    Ou un schéma en arbre à deux racines
    Ou une molécule dont un carbone a cinq liaisons
    Ou un tracé optique en mode lentille sans distance focale
    Quand le fichier est contrôlé par l'import et par le script
    Alors les deux rendent figure_invalid sur le même chemin

  Scénario: les listes fermées sont les mêmes dans le domaine et dans le navigateur
    Étant donné les planches, leurs parties et les identifiants de chaque fond de carte
    Quand on compare la liste du domaine et celle des modules de rendu
    Alors elles sont identiques

  Scénario: chaque sorte se dessine dans la fiche de révision
    Étant donné une leçon dont la fiche a une figure de chaque sorte nouvelle
    Quand un élève ouvre la fiche
    Alors chaque figure est dans l'état ready
    Et sa description n'est plus visible que des lecteurs d'écran

  Scénario: un curseur redessine la figure
    Étant donné un tracé optique avec un curseur sur la distance de l'objet
    Quand l'élève déplace le curseur
    Alors la position de l'image et le grandissement affichés changent
    Et la nouvelle mesure est annoncée

  Scénario: un identifiant inconnu côté navigateur ne dessine rien
    Étant donné une figure plate dont la planche est inconnue du module
    Quand la fiche s'affiche
    Alors la figure est dans l'état error et sa description reste visible

  Scénario: les modules de figures restent sûrs et légers
    Quand on inspecte app/javascript/lib/figures et ses fonds de carte
    Alors aucun module n'écrit de balisage, ne charge de ressource ni ne porte de couleur en dur
    Et chaque fond de carte pèse 150 Ko au plus

Fonctionnalité: Les 50 leçons

  Scénario: chaque leçon livrée passe le contrôle
    Étant donné un fichier de docs/contenus/lecons-traitees/3eme/<matière>/
    Quand on lance ruby script/contenus/valider.rb sur ce fichier
    Alors il sort sans erreur ni avertissement

  Scénario: les leçons suivent la progression nationale
    Étant donné la progression 2026-2027 d'une matière en 3ème
    Alors ses 10 premières leçons ont chacune un fichier version 3 au même intitulé exact

  Scénario: la moitié des questions au moins est corrigée automatiquement
    Étant donné une leçon de Français, d'Histoire-Géographie ou d'EDHC
    Quand le script la contrôle
    Alors il avertit si moins de la moitié de ses questions sont corrigées automatiquement
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `FigureKinds` étendu (6 sortes, `chart: line`) ; listes fermées des planches et des fonds ; cohérence par sorte dans `Figure` |
| Infrastructure | aucune migration ; l'import valide par le domaine, sans changement de port |
| Delivery | aucune route, aucun contrôleur |
| UI | 6 modules `lib/figures/<kind>.js`, 3 fonds `lib/figures/maps/<fond>.js`, `stat_chart.js` (courbe), `figure_controller.js` (liste blanche) |
| Contenus | `prompt-redaction.md` généralisé par matière ; `valider.rb` (avertissement de part corrigée automatiquement) ; script de fabrication des fonds ; 50 fichiers v3 |

## 6. Décisions rattachées

- ADR-0117 — six sortes de figures et une courbe ; amende ADR-0116 §4.2.
- UDR-0142 — dessin des six sortes ; complète UDR-0141 §3.3. Aucune vue nouvelle.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Leçons v3 de 3ème hors maths | 0 | 50 | |
| Sortes de figures | 5 | 11 | |
| Poids max d'un fond de carte | — | ≤ 150 Ko | |
