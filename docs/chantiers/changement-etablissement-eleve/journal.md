# Journal — Un élève change de classe ou d'établissement

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Chantier reporté (porteur) | Priorité à la V2 simple | — |
| 2026-10-16 | Chantier relancé avec les vagues V2 à V6 ; cadrage seul (memo, PRD, ADR, UDR, plan), code après validation du porteur | Demande du porteur | — |
| 2026-10-16 | Recommandation : l'élève déclenche lui-même, sans validation ; départ = `left_at` sans retrait ; résultats sur l'élève ; aucune migration | Inventaire du code : tout existe sauf le geste ; moteur « aucune étape ne dépend d'un absent » de l'ADR-0085 | ADR-0095 (Proposé) |
| 2026-10-16 | Changement dans le même établissement inclus (même use case) | Les erreurs de classe à l'inscription en libre-service sont le cas le plus fréquent | ADR-0095 §4, à confirmer (question 5) |
| 2026-10-16 | Porteur : recommandations acceptées, l'élève seul change de classe ; ADR-0095 et UDR-0101 à 0103 acceptées | Réponses du porteur | ADR-0095 (Accepté) |
| 2026-10-16 | Lot 0 : la classe d'arrivée est verrouillée **avant** la lecture de la classe actuelle | Deux envois simultanés vers la même classe : le second lit la nouvelle classe et reçoit `same_classroom` au lieu de rouvrir la ligne et d'écrire une seconde trace | ADR-0095 §4.1 (note d'exécution) |
| 2026-10-16 | Lot 0 : trace `classroom.student_moved` avec les identifiants internes (`from_classroom_id`, `to_classroom_id`, `to_school_id`, `via`) | Les identifiants publics de la classe quittée demandaient une lecture que le port des adhésions ne donne pas ; aucun port changé | ADR-0095 §4.1 (note d'exécution) |
| 2026-10-16 | Lot 0 : `ClassroomDesignation#designate` reprend « lien ou cascade » et le refus du lien mort ou archivé | Partagé par `JoinAsStudent` et `ChangeClassroom`, sans copie | — |
| 2026-10-16 | Lot 0 : la cascade accepte le scope `student_classroom_change` (`DrenaSchoolsController::PICKER_SCOPES`) | Les listes de la cascade nomment leurs champs d'après la page | — |

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
