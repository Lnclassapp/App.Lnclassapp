# Memo — Accueil de la direction : établissement, niveaux, annonces, activité

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-04 |
| **Branche** | `feature/accueil-direction` |
| **Programme** | — |

---

## Le problème

Une direction connectée arrive sur « Travail des élèves » : un tableau d'une ligne par classe (élèves, devoirs donnés, taux de rendu, moyenne). Il répond à une seule question, « nos élèves font-ils leurs devoirs ? », et il la pose à plat : toutes les classes de l'établissement, de la 6ème à la Terminale, dans une seule liste qui défile.

Rien n'y dit à la direction ce qui demande son attention (une classe sans enseignant, une classe vide, des enseignants en attente), rien ne lui permet d'aller droit à un niveau, et elle ne reçoit aucune information de l'équipe Lnclass ni ne voit ce qui s'est passé récemment dans son établissement.

Le porteur demande (2026-10-04) que la page principale de la direction s'organise en quatre sections :

1. **Établissement** : une carte qui réunit les alertes et les informations sur les classes ;
2. **Niveaux** : tous les niveaux de l'établissement, chacun avec son icône et son nom, sur le même principe que la section « Cours » de l'accueil enseignant (une bulle par niveau) : un niveau mène aux seules classes de ce niveau ;
3. **Annonces** ;
4. **Activité récente**.

## Pour qui

- **La direction (SchoolStaff)**, à chaque connexion, souvent au téléphone : c'est sa page d'arrivée.
- *(à confirmer au grill)* l'équipe, les enseignants, les élèves, les parents.

## Pourquoi maintenant

*(à confirmer au grill)* L'espace direction simple est en production depuis la V2 : les premières directions s'en servent, et le porteur juge que le tableau seul ne suffit pas comme page d'arrivée.

## Hors périmètre

*(à compléter au grill)*

- Toute écriture par la direction qui n'est pas explicitement décidée ici (l'espace direction reste en lecture seule par défaut, ADR-0065).
- La page « Enseignants » : inchangée.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1. Les annonces n'existent pas sur `Develop` : ce chantier les construit-il ? | **Non** : un chantier `annonces` est en cours sur sa propre branche (porteur, 2026-10-04). | Ce chantier **ne construit rien** des annonces : il les **affiche** sur l'accueil de la direction, en lisant ce que le chantier `annonces` fournit. **Dépendance** : la section ne peut se coder qu'après le merge d'`annonces` dans `Develop`. Écart à trancher : `annonces` a décidé que le carrousel reste propre à l'accueil élève et que la direction lit ses annonces sur une page « Annonces » de sa navigation ; une section sur l'accueil de la direction est un **ajout** à l'UDR-0071, pas une contradiction. Fichier partagé probable : `navigation_helper` (le Lot D d'`annonces` y ajoute « Annonces »). |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …
