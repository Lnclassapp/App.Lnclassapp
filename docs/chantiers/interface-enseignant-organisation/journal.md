# Journal — Organisation des écrans enseignant

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-05 | La bascule d'assignation a une forme compacte (`compact: true`) qui porte toute la ligne de la classe ; le mode voyage avec la requête (`compact=1`), modale des jours comprise | Le stream doit remplacer l'échéance avec le badge : elle change à l'assignation. Un identifiant différent aurait dupliqué les trois réponses | Non (UDR-0077 §3.3) |
| 2026-10-05 | La page d'un exercice prend la même ligne compacte que la fiche | Même liste, même défaut à 375 px ; une seule forme à maintenir | Non (UDR-0077 §3.3) |
| 2026-10-05 | Les cartes du catalogue de l'enseignant perdent le badge de matière | R6 : sa matière unique est déjà dite par le sous-titre | Non (UDR-0077 §3.2) |
| 2026-10-05 | Le carrousel d'annonces de l'enseignant garde l'identifiant de section `student_home_announcements` | Partial partagé avec l'élève et la direction ; sans croix, aucune réponse de masquage ne le cible | Non |
| 2026-10-05 | Sur téléphone, le score de la liste des élèves est limité à 6 rem | Capture à 390 px : « Aucune session terminée » écrasait le nom (« Ay… ») et cassait le numéro | Non |

## Ce qui a dérapé

- La copie locale de `Develop` était en retard de plusieurs chantiers (annonces, catalogue par série) : la première exploration a conclu à tort que les annonces n'existaient pas. Même piège que `interface-eleve-organisation` : `git pull` avant d'explorer.
- Les tests de requête ont buté sur la contrainte `classroom_assignments_due_on_within_a_week` (échéance 1 à 7 jours après l'assignation) : un test d'échéance passée doit dater l'assignation.
- Le menu ⋮ des élèves a d'abord été vérifié par un test système trop strict (haut du ⋮ sous le bas du nom) ; la capture montrait une ligne juste, c'est l'assertion qui comparait les mauvais bords.

## Ce qu'on a appris sur la codebase

- `ui_card` reçoit `class:` ; une bande dans une case de grille demande `min-w-0` sur la carte, sinon la page défile en largeur.
- Le contrôleur `reveal` laisse les lignes `hidden` sans JavaScript (UDR-0057 R3) : « Voir plus » n'a pas de repli.
- `AssignmentFollowUpQuery.counts` est par classe ; l'accueil enseignant a besoin d'un agrégat multi-classes (jointure sur `classroom_students` de la classe de l'assignation) pour rester à un nombre fixe de requêtes.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Fenêtre des « Exercices à suivre » (7 jours avant, 14 après), catalogue vide sans classe, jours de séance sous l'en-tête | Décisions de l'auteur, à confirmer par le porteur | — |
| Un enseignant ouvre encore par URL un cours d'une autre matière ou d'un autre niveau | Hors périmètre : la restriction est une lecture du catalogue, pas une règle d'accès | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-05 |
| **PR** | |
| **ADR produits** | — |
| **UDR produits** | UDR-0077 |
