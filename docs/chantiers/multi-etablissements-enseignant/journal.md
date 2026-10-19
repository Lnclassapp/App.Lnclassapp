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
| 2026-10-16 | Réponse MET-4 : chaque établissement est un espace autonome ; une classe d'un autre établissement ne s'ouvre plus (Q11 renversée) ; un test de non-fuite par écran | Décision du porteur | ADR-0094 §10, UDR-0098 §3.5 |
| 2026-10-16 | Lot A : le refus `:other_school` est rendu une seule fois, par `RendersResult` (retour à l'accueil, toast), au lieu d'un traitement par contrôleur | Toutes les pages d'une classe (page, suivi, « Assigner », jours, déclaration) passent par lui | ADR-0094 §10 |
| 2026-10-16 | Lot A : plafond des annonces d'un enseignant compté par établissement (`Message#cap_school_id`) | Sans cela, publier dans A archivait une annonce de B et l'encadré du plafond nommait des annonces de B | ADR-0094 §10 (amende 0081 §4.1) |
| 2026-10-16 | Réponse MET-8 : deux liens d'invitation ; nouveau Lot E après A et B | Décision du porteur ; les fichiers d'invitation sont ceux du Lot A | ADR-0094 §11 (Lot E) |
| 2026-10-16 | Lot B : le lien `/i/<jeton>` ouvert connecté redirige vers `GET /teachers/schools/join/:token` (contrôleur authentifié, dans le shell) au lieu d'une page rendue par `TeacherRegistrationsController` | Le shell, la session et la garde de rôle viennent avec `AuthenticatedController` ; l'écran d'attente garde sa propre route | UDR-0099 §3.4 (précision) |
| 2026-10-16 | Lot B : l'écran d'attente (`PendingSchoolJoinsController`) reste réservé à l'enseignant sans établissement ; un enseignant rattaché ajoute depuis « Mes établissements » | Un même use case, deux portes ; la session ne passe sur le nouvel établissement que depuis « Mes établissements » | — |
| 2026-10-16 | Lot C : `sessions.current_school_id` en `ON DELETE SET NULL`, seule exception à « toute clé étrangère restreint » ; ajoutée à la liste fermée de `schema_constraints_test.rb` | Un établissement supprimé (sans rattachement) ne doit pas être bloqué par une session qui le désignait | ADR-0094 §4.1 |
| 2026-10-16 | Lot E : un jeton par rattachement (`teacher_schools.invite_token`) pour « Inviter un collègue de mon établissement » ; `teacher_profiles.referral_token` devient le parrainage (`source: "sponsor"`, déjà admis par la base) | Le lien suit l'établissement courant sans jeton par session ; le parrainage garde le parrain | ADR-0094 §11 |
| 2026-10-16 | Fabrique de test `create_teacher` : par défaut, l'établissement de sa première classe | Avec le cloisonnement, un enseignant rattaché à un autre établissement que ses classes ne les voyait plus ; les tests existants supposaient un seul établissement implicite | — |

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
- Lot A : l'agent précédent a été arrêté au milieu du lot (≈ 60 fichiers non commités). Repris tel quel ; seule la page d'une classe d'un autre établissement a changé de sens entre-temps (réponse MET-4) : le test ME-12 écrit pour « la page s'ouvre » a été réécrit.
- Le Lot 0 avait laissé deux tests rouges sans les voir : la liste des liens du panneau (« Mes établissements » ajouté) dans `account_panel_test.rb` et `teacher_header_test.rb`, et la règle « toute clé étrangère restreint » (`sessions.current_school_id`). Corrigés au Lot A et au Lot C.
- Lots exécutés à la suite dans un seul arbre de travail, commités ensuite lot par lot : le `bin/ci` complet n'a été joué que sur l'état final ; les commits intermédiaires ont passé le pre-commit (tests des fichiers touchés, joués sur l'arbre final), pas un `bin/ci` chacun. Les fichiers communs à deux lots sont dans le premier qui les touche, dans leur forme finale.

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
- Les annonces reçues étaient déjà bornées par `reader.school_id` : passer l'établissement courant dans l'acteur a suffi. « Mes annonces », la modification et le plafond de 3 (ADR-0081) lisaient l'auteur seul : il a fallu les borner à l'établissement.
- `referrals.source` admettait déjà `sponsor` (migration de l'ADR-0063) sans qu'aucun chemin ne l'écrive : le parrainage sans établissement s'y est posé sans migration de contrainte.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| La recherche de comptes de l'équipe (`AccountSearchQuery`) n'affiche que l'établissement principal d'un enseignant | Hors du besoin de la direction ; un changement d'écran de l'équipe demanderait une UDR de plus | `annuaire-equipe` (V2, backlog) |
| ~~Lien personnel « Inviter un collègue » limité à l'établissement principal~~ | Levée par la réponse MET-8 (Lot E) | — |
| Plafond de 3 annonces en ligne compté par établissement pour l'enseignant, par auteur pour l'équipe et la direction | L'équipe écrit des annonces nationales et par établissement ; changer son plafond est une autre décision | à décider si le besoin apparaît |
| Matières par établissement | Point d'extension posé (ligne `teacher_schools`, lectures qui reçoivent `school_id:`) | `enseignant-plusieurs-matieres` (part de cette branche) |
| Vérification sur appareil Lnclass Teacher (redirection de `/teachers/menu` après un changement d'établissement, UDR-0098 §3.2) | Pas d'appareil Android dans la session | recette par le porteur |
| Sous-agents de revue (`security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`) | Non disponibles dans la session d'exécution | à lancer sur la PR avant la fusion |
| Une matière par enseignant pour tous ses établissements | `teacher_profiles.material_id` unique ; demande du porteur traitée à part | `enseignant-plusieurs-matieres` (cadré en parallèle) |

## Revue de la PR #250 (sécurité, échecs avalés, tests) — corrigée le 2026-10-16

| Constat | Correction | Preuve |
|---|---|---|
| Principal calculé avant le verrou (`JoinSchoolWithCode`, `ReinstateTeacher`) : 500 (`RecordNotUnique`) sur deux « Rejoindre » simultanés sans établissement | `attach_teacher_within_cap` décide `primary = attached.empty?` sous le verrou et le rend ; le use case place la session d'après cette valeur ; `RecordNotUnique` → `:conflict already_attached` | `teacher_primary_concurrency_test.rb` (deux jonctions ; réintégration + jonction), `school_repository_test.rb`, `join_school_with_code_test.rb` |
| Départ compté hors verrou (`LeaveSchool`, `DetachTeacher`) ; `promote_primary` ignorait les lignes modifiées : zéro établissement ou aucun principal | Port `lock_teacher` en tête de transaction ; `LeaveSchool` rejoue sa policy sous le verrou ; `promote_primary` en `update_all` compté (`nil` si 0) | `teacher_leave_concurrency_test.rb` (deux départs ; départ + retrait ; ligne disparue), `detach_teacher_test.rb` |
| Trois contrôles hors établissement courant (§10) : résultats de session, code PIN, photo | `school_id: actor.school_id` (`teaches_student?`, `classroom_ids_for`) | `session_result_query_test.rb`, `issue_pin_recovery_code_test.rb`, `read_account_photo_test.rb` |
| `set_current_school` rendait `true` sans ligne | Rend le nombre de lignes ; `SwitchCurrentSchool` : `:not_found` à 0 | `session_repository_test.rb`, `switch_current_school_test.rb` |
| Sous filtre DRENA, « comptes enseignants » comptait un enseignant par établissement | `distinct.count(:teacher_id)` ; lignes inchangées (ME-23) ; `CACHE_VERSION` 6 | `team_dashboard_query_test.rb` |

Tests ajoutés aussi : plafond de 3 annonces par établissement (modification, publication programmée), `AuthoredMessagesQuery` par `school_id`, non-fuite d'un cours et d'un essentiel d'un niveau présent dans A et B, badge « Établissement secondaire », modale « Retirer », rôles refusés (`/i/<jeton>`, jonction, `current_schools`, `teacher_schools`), `rate_limit` de la jonction par lien, message du plafond, `joined_via` inchangé (ME-02), retour dans B après l'avoir quitté (ME-13). ADR-0094 §4.4, §4.5 et §6 mis à jour (signature du port, `lock_teacher`).

FU-47 (`test/system/finitions/catalog_and_student_test.rb`) échouait aussi sur `Develop` (2 passages sur 3) : après « Tout voir », Turbo montre l'aperçu en cache de `/courses` (3 cours, champ encore rempli) avant la page reçue, et le test lisait la valeur du champ pendant l'aperçu. Le test attend désormais la page reçue (`html[data-turbo-preview]` absent, `assert_field … with: ""`).

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-16 (PR prête vers `Develop`, fusion par le porteur) |
| **PR** | `feature/multi-etablissements-enseignant` → `Develop` |
| **Migrations** | `20261016140000_add_current_school_id_to_sessions` (Lot 0), `20261016150000_add_invite_token_to_teacher_schools` (Lot E) |
| **ADR produits** | ADR-0094 (Accepté, amendé §10 MET-4 et §11 MET-8) ; amendements des ADR-0030, 0062, 0071, 0083 |
| **UDR produits** | UDR-0098 (Accepté, §3.5 amendé, §3.6 ajouté), UDR-0099, UDR-0100 (Accepté) |
