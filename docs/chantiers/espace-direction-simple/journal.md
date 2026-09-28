# Journal — Espace direction, version simple

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Remplacer la conception complète de la V2 par deux pages en lecture seule | Le porteur la juge « une usine à gaz » ; apprendre d'abord des vraies directions | ADR-0065 |
| 2026-09-28 | Un seul type de compte direction, sans fonction ni second facteur | Réponses 1 et 2 du porteur | ADR-0065, amendement de l'ADR-0044 |
| 2026-09-28 | Le taux de rendu compte les paires élève × devoir rendues, et tout se lit sur les élèves présents | La page d'une classe montre « devoirs rendus / devoirs donnés » par élève : le taux de la classe doit en être la moyenne, sinon deux pages se contredisent | ADR-0065 §4 |
| 2026-09-28 | L'accueil de la direction (`HomeDestination`) appartient au Lot C, pas au Lot 0 | Le Lot 0 doit laisser l'application verte ; une redirection vers une page absente ne l'est pas | Non |
| 2026-09-28 | Numéros ADR-0065 et UDR-0052, les suivants libres dans `Develop` | Consigne du porteur ; la branche `feature/espace-direction` utilise les mêmes numéros | Non (noté en coût dans l'ADR-0065) |

## Ce qui a dérapé

- La V2 a d'abord été conçue en grand (65 critères, trois ADR, deux UDR, un Lot 0a codé) avant qu'une seule direction réelle ne l'ait vue. Leçon : pour un public qu'on ne connaît pas encore, livrer la plus petite page utile et écouter.

## Ce qu'on a appris sur la codebase

- Le rôle `school_admin`, l'invitation `school_staff` et la navigation de la direction existent depuis la V1, mais la contrainte `invitations_staff_has_school` et `Entities::Identity::Invitation` exigent une fonction : il faut les assouplir.
- `SessionPolicy` et `ResolveSession` ne gardent que `team` : une direction se connecte déjà par PIN seul, sans rien changer à la session.
- `SchoolDetailQuery#teachers` fait déjà la jointure enseignant → matière qu'il faut pour « Enseignants ».

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Retirer une direction à l'écran | Hors du périmètre simple | `annuaire-equipe` (backlog) |
| Second facteur de la direction | Décision du porteur | `espace-direction` (backlog), dès qu'une direction écrit |
| Rendu exact par exercice | Grossier mais suffisant pour une première lecture | `rapports-de-classe` (V3) |

## Clôture

| | |
|---|---|
| **Livré le** | — |
| **PR** | — |
| **ADR produits** | [0065](../../decisions/adr/0065-espace-direction-simple-en-lecture-seule.md) |
| **UDR produits** | [0052](../../decisions/udr/0052-espace-direction-simple.md) |
