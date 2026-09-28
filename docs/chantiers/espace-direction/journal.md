# Journal — Espace direction

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Numéros réservés : ADR-0065 à 0067, UDR-0052 et 0053. `annuaire-equipe` prendra à partir d'ADR-0068 et d'UDR-0054 | Relevé sur toutes les branches distantes (plus haut : ADR-0064, UDR-0051) ; deux chantiers V2 en parallèle | — |
| 2026-09-28 | Trois ADR au lieu d'un : matricule (0065), droits et gestes (0066), tableau de bord (0067) | Trois décisions qui vieillissent différemment : le format du matricule peut changer seul ; les définitions du tableau de bord suivent l'ADR-0062 | ADR-0065, 0066, 0067 |
| 2026-09-28 | Une policy à gestes, `School::StaffPolicy`, plutôt qu'élargir `ManageSchoolPolicy` | `ManageSchoolPolicy` autorise aussi la validation des comptes en attente (refusée par Q1), l'import et les DRENA : l'élargir aurait donné ces gestes à la direction | ADR-0066 §3 |
| 2026-09-28 | La direction a le « + » mais pas le « − » des classes | Q3 : « ajoute la classe suivante d'un niveau » ; le retrait n'a pas été demandé. Point à confirmer | ADR-0066 §9 |
| 2026-09-28 | Index unique de `classroom_students` rendu partiel (`WHERE left_at IS NULL`) | Le cas du grill « erreur de classe » est un aller-retour, que l'index de l'ADR-0040 interdisait | ADR-0066, amende ADR-0040 |
| 2026-09-28 | Obligation du matricule posée en deux migrations (0a : format, unicité, rôle ; F : obligatoire) | Poser l'obligation au Lot 0a casserait l'inscription élève jusqu'à la fusion du Lot F ; la branche doit rester verte entre les lots | ADR-0065 §6 |
| 2026-09-28 | L'anonymisation efface le matricule ; il redevient libre | Minimisation des données de mineurs (ADR-0036) ; « jamais réattribué » = jamais porté par deux comptes vivants. Point à confirmer | ADR-0065, amende ADR-0036 |
| 2026-09-28 | Une invitation de direction ne vise qu'un numéro sans compte | Rattacher un compte existant (enseignant qui devient Censeur) demande un parcours d'authentification à l'acceptation ; hors V2 | ADR-0066 (coûts) |
| 2026-09-28 | Un enseignant retiré revient par un code d'établissement depuis l'écran d'attente (`RejoinSchoolWithCode`) | Grill 7 : « peut rejoindre un autre établissement par son code » ; aucun parcours ne le permettait pour un compte existant | ADR-0066 §4.4 |
| 2026-09-28 | Cinquième destination « Établissement » (code et personnel) | Le code et le personnel n'avaient pas de place dans les quatre destinations prévues par l'UDR-0006 ; cinq est le maximum | UDR-0052, amende UDR-0006 |
| 2026-09-28 | Les listes de la direction affichent les initiales, pas la photo | Élargir `ReadUserPolicy` (ADR-0060) toucherait une policy que `annuaire-equipe` va modifier | ADR-0066 (coûts) |
| 2026-09-28 | Deux socles séquentiels (0a données et contrats, 0b accès et fichiers partagés) | Le socle dépasse une poignée de fichiers : un nouveau rôle actif et sept contrats. Chaque moitié reste démontrable | — |
| 2026-09-28 | Profil (`_information`, `ProfileQuery`) et écran d'attente attribués chacun à un seul lot (0b, C) | Deux lots les auraient touchés (profil : direction et matricule ; attente : direction et enseignant retiré) | — |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- La table `school_staffs` de l'ADR-0044 **n'existe pas** : seul le type d'invitation `school_staff` a été posé en V1. `Actor` ne porte pas la fonction ; `HomeDestination` envoie tout `school_admin` sur l'écran d'attente ; `SecondFactorPolicy` et `ResolveSession` ne connaissent que `team` (C-20 décidé, jamais codé).
- `AcceptInvitation` refuse explicitement toute invitation qui n'est pas `team` (« ne s'accepte pas par cet écran »).
- `ManageSchoolPolicy` sert à la fois l'import, les DRENA, la génération des classes, la régénération du code **et** la validation des comptes en attente : c'est pourquoi on ne l'élargit pas.
- `ManageClassroomPolicy#call(actor:)` ne reçoit pas l'établissement : impossible de borner la direction sans changer la signature ; d'où `StaffPolicy#call(actor:, school:, gesture:)`.
- L'index unique `(classroom_id, student_id)` de `classroom_students` interdit le retour d'un élève dans une classe quittée.
- Les classes de l'an dernier gardent le statut `active` tant que l'archivage de fin d'année (V3) n'existe pas : « classe active » ne suffit pas, il faut aussi « de l'année en cours » pour dire qu'un élève est pris ailleurs.
- `JoinRequestRepositoryPort` n'a aucune lecture par enseignant ; `school_join_requests.teacher_id` est unique : un enseignant approuvé puis retiré ne peut plus refaire de demande.
- L'écran d'attente affiche « Votre demande est en cours de validation » pour une demande **approuvée** d'un enseignant sans école (état jamais atteint avant ce chantier).
- `create_user(role: "school_admin")` est utilisé par une dizaine de tests de refus ; avec le second facteur exigé, ils recevraient une redirection au lieu d'un 403 : la fabrique lui donne un second facteur par défaut (Lot 0a).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Rattacher par invitation un numéro qui a déjà un compte | Parcours d'authentification à l'acceptation | À ouvrir si le porteur le demande |
| Lister et révoquer les invitations de direction en cours | Le lien s'affiche une fois ; une invitation perdue attend 72 h | Idem |
| Photos dans les listes de la direction | `ReadUserPolicy` non élargie | `annuaire-equipe` ou suivant |
| Taux de rendu par devoir (élève × devoir) | Déplier cours et fiches en exercices | `rapports-de-classe` (V3) |
| Régénérer ou fermer le code d'adhésion d'une classe par la direction | Non demandé ; ADR-0041 le prévoyait | V3, `vie-de-la-classe` |
| Retirer un élève de l'établissement (départ en cours d'année) | Hors V2 (memo) | V3, avec CL-02 |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
