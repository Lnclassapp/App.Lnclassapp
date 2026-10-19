# Journal — Un élève change de classe ou d'établissement

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Chantier reporté (porteur) | Priorité à la V2 simple | — |
| 2026-10-16 | Chantier relancé avec les vagues V2 à V6 ; cadrage seul (memo, PRD, ADR, UDR, plan), code après validation du porteur | Demande du porteur | — |
| 2026-10-16 | Recommandation : l'élève déclenche lui-même, sans validation ; départ = `left_at` sans retrait ; résultats sur l'élève ; aucune migration | Inventaire du code : tout existe sauf le geste ; moteur « aucune étape ne dépend d'un absent » de l'ADR-0085 | ADR-0095 (Proposé) |
| 2026-10-16 | Changement dans le même établissement inclus (même use case) | Les erreurs de classe à l'inscription en libre-service sont le cas le plus fréquent | ADR-0095 §4, à confirmer (question 5) |

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- Le changement d'établissement était **déjà possible** en deux temps : retrait par l'ancienne classe (`RemoveStudent`), puis choix par l'élève (`JoinAsStudent`), qui accepte toute classe sauf celle du retrait. Le blocage ne tient qu'au refus `already_enrolled` de `JoinAsStudent`.
- `MembershipRepository#add_primary` rouvre la ligne existante d'une classe déjà quittée (et efface le retrait) : revenir dans une ancienne classe ne crée jamais de doublon.
- Toutes les lectures « présents » filtrent `left_at IS NULL` (une trentaine de requêtes) : un départ disparaît partout sans changer une seule lecture.
- `Membership#classroom_active?` ignore `school_year` : à la rentrée 2027, les élèves d'une classe 2026-2027 non archivée seront « déjà inscrits » et la cascade ne leur proposera que 2027-2028. Signalé au memo (question 9), hors périmètre.
- `exercise_sessions` porte `student_id` et `classroom_assignment_id`, jamais l'adhésion : les résultats suivent l'élève sans rien faire.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Prévenir l'ancien enseignant et la direction d'un départ | Aucun canal | `notifications-push` |
| Écran d'équipe des changements de classe | La trace d'audit suffit au démarrage | — |
| `classroom_active?` sans l'année scolaire | Relève de l'archivage de fin d'année | `vie-de-la-classe` (Q8 de la feuille de route) |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | ADR-0095 |
| **UDR produits** | UDR-0101, UDR-0102, UDR-0103 |
