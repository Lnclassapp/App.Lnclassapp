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

- **Construire les annonces** (rédiger, publier, lire, masquer, retirer) : chantier `annonces`, en cours sur sa branche. Ce chantier ne fait qu'afficher son carrousel.
- **Changer qui rédige et qui masque les annonces** (D-A1) : décidé par le porteur, mis en œuvre par le chantier `annonces` (ADR-0078, UDR-0071 amendés là-bas).
- Toute rédaction d'annonce par la direction : seule l'équipe rédige (D-A1).
- Le tableau « Travail des élèves » sous sa forme actuelle : remplacé par les cartes de classe de chaque niveau (Q4).
- Toute écriture par la direction qui n'est pas explicitement décidée ici.
- La page « Enseignants » : inchangée.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1. Les annonces n'existent pas sur `Develop` : ce chantier les construit-il ? | **Non** : un chantier `annonces` est en cours sur sa propre branche (porteur, 2026-10-04). | Ce chantier **ne construit rien** des annonces : il les **affiche** sur l'accueil de la direction, en lisant ce que le chantier `annonces` fournit. **Dépendance** : la section ne peut se coder qu'après le merge d'`annonces` dans `Develop`. Écart à trancher : `annonces` a décidé que le carrousel reste propre à l'accueil élève et que la direction lit ses annonces sur une page « Annonces » de sa navigation ; une section sur l'accueil de la direction est un **ajout** à l'UDR-0071, pas une contradiction. Fichier partagé probable : `navigation_helper` (le Lot D d'`annonces` y ajoute « Annonces »). |
| Q2. Que montre la section « Annonces » de l'accueil de la direction ? (A aperçu des reçues · B aperçu + « Rédiger » · C ses annonces en ligne · D le carrousel de l'élève) | **D : le carrousel de l'élève, à l'identique** (porteur, 2026-10-04). | On réutilise le carrousel du chantier `annonces` (5 cartes au plus, ordre direction → enseignants → Lnclass, lien « Toutes les annonces » vers la page « Annonces »), alimenté par la même règle de lecture : la direction y voit les annonces nationales et celles de son établissement destinées à « tous » ou « aux directions ». Pas de bouton « Rédiger » sur l'accueil : on rédige depuis la page « Annonces ». Le gabarit du carrousel porte aujourd'hui des identifiants propres à l'accueil élève : il faudra le paramétrer (fichier du chantier `annonces`, donc **après son merge**). Point dur : « masquer » est réservé à l'élève par le chantier `annonces` (voir Q3). |
| Q3. Dans son carrousel, la direction peut-elle masquer une annonce ? (le chantier `annonces` réserve le masquage à l'élève) | **Non** (porteur, 2026-10-04). | Le carrousel de la direction s'affiche **sans aucune croix** ; la règle de masquage du chantier `annonces` (ADR-0078 §4.2) ne change pas. Une annonce de l'équipe reste dans le carrousel jusqu'à sa date de fin. Un test vérifie l'absence de croix, et le serveur refuse déjà un masquage forgé par une direction (403). Le carrousel doit donc accepter « jamais masquable » comme paramètre, en plus de la règle « officielle ». **Revu par la décision D-A1 ci-dessous : toute annonce devient masquable, la croix revient.** |
| D-A1. *(décision du porteur, hors question, 2026-10-04)* « Nous allons alléger tout. Seule l'équipe peut créer les annonces. Toutes les annonces peuvent être masquées. » | **L'équipe seule rédige** ; ni la direction ni l'enseignant ne publient. **Toute annonce est masquable**, par tout lecteur. | Cette décision appartient au chantier **`annonces`**, pas à celui-ci : elle y défait l'auteur « direction » et l'auteur « enseignant » (ciblage par classes, Lot A déjà mergé sur sa branche), la notion d'annonce « officielle » et le retrait par la direction (Lot C). Elle amende l'ADR-0078 et l'UDR-0071, et se reporte dans le memo d'`annonces`. **Pour ce chantier** : le carrousel de la direction ne montre que des annonces de l'équipe (nationales ou pour son établissement) ; **chaque carte a sa croix** et le toast « Annuler », comme chez l'élève. Dépendance : la règle de masquage d'`annonces` doit accepter la direction comme lecteur qui masque. |
| Q4. Quand la direction touche la bulle d'un niveau, qu'est-ce qui s'ouvre ? (A le tableau filtré · B des cartes de classe · C tableau complet en plus) | **B, avec une icône par classe**, et **un signal** : une pastille posée sur le rond de la classe, comme une notification, **rouge, jaune ou verte**, pour comparer les classes (porteur, 2026-10-04). | Le tableau « Travail des élèves » quitte la page : la page d'un niveau montre ses classes en ronds à icône, chacun avec sa pastille, puis mène à la page de la classe (inchangée). **Écarts à trancher dans l'UDR** : la charte (§5) réserve l'ambre à l'urgence et interdit le rouge pour juger un résultat ; l'UDR-0052 interdit qu'une information ne passe que par la couleur — la pastille doit donc avoir un équivalent texte (lecteur d'écran et légende). À trancher au grill : ce que mesure la couleur, ses seuils, l'icône d'une classe. |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …
