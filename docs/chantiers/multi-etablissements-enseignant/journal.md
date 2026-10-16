# Journal — Un enseignant dans plusieurs établissements

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-16 | Chantier relancé (reporté par le porteur le 2026-09-28), cadrage seul : memo, PRD, ADR, UDR et plan, validés par le porteur avant le code | Relance des vagues V2 à V6 par le porteur | — |
| 2026-10-16 | Q7 de la feuille de route reformulée (question 1 du memo) : « avec le code » n'existe plus côté enseignant depuis l'ADR-0083 | Le code d'établissement ne sert plus qu'à la direction (ADR-0077) | ADR-0094 (Proposé) |
| 2026-10-16 | Recommandation : l'enseignant rejoint lui-même ; la direction ne rattache pas par numéro (ID-09, SC-23 réinterprétés) | Pas de rattachement sans accord, pas de recherche d'un compte par numéro ; lève la dépendance à l'espace direction complet (V2, backlog) | ADR-0094 §3, option E (Proposé) |
| 2026-10-16 | Recommandation : établissement courant par session (`sessions.current_school_id`), principal stable | Aucune policy à réécrire ; le lien personnel « Inviter un collègue » reste résolu vers le principal sans dériver | ADR-0094 §3, option C (Proposé) |
| 2026-10-16 | Pilotage : un enseignant compte dans chaque établissement où il est rattaché, la DRENA reste la somme de ses établissements | Le critère RE-08 de l'ADR-0062 (somme des établissements = ligne de la DRENA) l'impose dès qu'on compte par établissement | ADR-0094 §4.6, amende 0062 (Proposé) |
| 2026-10-16 | Réponses du porteur : recommandations acceptées ; ADR-0094 et UDR-0098 à 0100 passées à « Accepté » au Lot 0 | Décision du porteur (memo, « Réponses du porteur ») | ADR-0094 §9 |
| 2026-10-16 | Q9 : la matière n'est pas touchée ; point d'extension = la ligne `teacher_schools` (rattachement enseignant-établissement), où `enseignant-plusieurs-matieres` rangera les matières par établissement | Le porteur veut les matières choisies par établissement, dans le chantier suivant | ADR-0094 §9 |
| 2026-10-16 | Lot 0 : un seul agent exécute les lots A à D à la suite, sur la branche de chantier (pas de worktrees de lot) | Les lots restent disjoints (tableau de collision) ; un commit par lot | — |
| 2026-10-16 | `SessionState#current_school_id` a la valeur par défaut `nil` (constructeur de `Data`) | Les doubles de session des tests existants ne changent pas ; une session sans établissement courant vaut « le principal » | — |

## Vérification en production (Lot 0) — à lancer par le porteur

Aucun chemin n'a jamais écrit de ligne `teacher_schools` secondaire ; il ne devrait y en avoir aucune. Le porteur lance, **avant la mise en production** de ce chantier, sur la base de production (lecture seule) :

```sql
-- 1. Nombre de rattachements secondaires (attendu : 0)
SELECT COUNT(*) FROM teacher_schools WHERE NOT "primary";

-- 2. S'il y en a : lesquels, et l'enseignant a-t-il un principal ?
SELECT ts.teacher_id, ts.school_id, ts.created_at,
       EXISTS (SELECT 1 FROM teacher_schools p WHERE p.teacher_id = ts.teacher_id AND p."primary") AS has_primary
FROM teacher_schools ts
WHERE NOT ts."primary"
ORDER BY ts.teacher_id, ts.created_at;

-- 3. Aucun enseignant ne dépasse le plafond de 3 (attendu : aucune ligne)
SELECT teacher_id, COUNT(*) FROM teacher_schools GROUP BY teacher_id HAVING COUNT(*) > 3;
```

| Requête | Résultat en production | Date |
|---|---|---|
| 1 | *à remplir par le porteur* | |
| 3 | *à remplir par le porteur* | |

Si la requête 1 rend autre chose que 0 : ces lignes deviennent des établissements secondaires visibles par l'enseignant dès la mise en production (rubrique « Établissement » du panneau). Les noter ici avec leur origine avant de déployer.

## Ce qui a dérapé

- Rien au Lot 0.

## Ce qu'on a appris sur la codebase

- `teacher_schools` porte déjà tout le modèle (n-n, drapeau `primary`, index « un principal ») ; **aucun chemin n'écrit de ligne secondaire** : `RegisterTeacher`, `JoinSchoolWithCode` et `ReinstateTeacher` écrivent tous `primary: true`. Pas de reprise de l'ancienne base (ADR-0034) : il ne devrait y avoir aucune ligne secondaire en production (à vérifier au Lot 0).
- `schools.first` est un défaut de l'**ancienne** application ; il n'existe plus dans ce dépôt. Son successeur est le drapeau `primary`.
- `Actor#school_id` d'un enseignant est le principal (`UserRepository#school_id_of`) : c'est le point unique par lequel toutes les policies de l'enseignant supposent un seul établissement.
- `TeachPolicy`, `ReadClassroomPolicy` et `AssignPolicy` autorisent par la liaison `teacher_classrooms`, pas par l'établissement : elles valent déjà pour plusieurs établissements.
- Quatre lectures de l'enseignant ne filtrent pas par établissement (`TeacherHomeQuery`, `TeacherFollowUpsQuery`, `CatalogAssignmentTargetsQuery`, `TeacherAudienceQuery`) ; elles mélangeraient des classes homonymes.
- `DetachTeacher` supprime la ligne principale sans en promouvoir une autre ; `ReinstateTeacher` et `DepartedTeachersQuery` excluent un enseignant qui a un établissement ailleurs (ADR-0071, écrit pour un établissement).
- La fiche d'établissement de l'équipe a déjà un badge « Établissement secondaire » (`teams/schools/show`), jamais affiché faute de ligne secondaire.
- Les comptes d'enseignants du pilotage sont incohérents entre eux : `DrenaSchoolsQuery` et `TeamDashboardQuery` (DRENA) comptent le principal, `TeamDashboardQuery` (par établissement) et `SchoolsQuery` comptent toutes les lignes.
- Les sessions sont en base (`sessions`, jeton haché) : l'établissement courant s'y range sans cookie supplémentaire.
- La page d'une classe nomme déjà son établissement (`classroom/classrooms/_header`).

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| La recherche de comptes de l'équipe (`AccountSearchQuery`) n'affiche que l'établissement principal d'un enseignant | Hors du besoin de la direction ; un changement d'écran de l'équipe demanderait une UDR de plus | `annuaire-equipe` (V2, backlog) |
| Lien personnel « Inviter un collègue » limité à l'établissement principal | Un jeton par enseignant (ADR-0063) ; un lien par établissement est un autre modèle | à décider si le besoin apparaît |
| Une matière par enseignant pour tous ses établissements | `teacher_profiles.material_id` unique ; demande du porteur traitée à part | `enseignant-plusieurs-matieres` (cadré en parallèle) |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | ADR-0094 (Proposé) |
| **UDR produits** | UDR-0098, UDR-0099, UDR-0100 (Proposé) |
