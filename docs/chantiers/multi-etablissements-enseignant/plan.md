# Plan d'exécution — Un enseignant dans plusieurs établissements

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Contextes : `school` porte la règle (rattachement, plafond, établissement courant) ; `identity` porte la session et l'acteur ; `classroom` et `catalog` ne font que recevoir l'établissement courant. Une migration (`sessions.current_school_id`). Un commit par lot, documentation du lot comprise (CLAUDE.md, sobriété de tokens).
>
> **Préalable au Lot 0** : les questions 1 à 8, 10 et 11 du [memo](memo.md#ce-que-le-grill-a-révélé) répondues par le porteur (la 9 relève de `enseignant-plusieurs-matieres`), l'ADR-0094 et les UDR-0098 à 0100 passées à « Accepté » (amendées si une réponse diffère). Si la question 7 (« Quitter ») est refusée, le Lot B perd `LeaveSchool` ; si la question 10 est refusée, le Lot D disparaît.

## Graphe

```
Lot 0 — SOCLE (séquentiel) : migration, acteur = établissement courant, ports et repository, query des établissements,
        routes, entrée « Mes établissements » du panneau, locale de navigation, amendements des ADR 0030, 0071, 0083
  ↓
  ├─► Lot A  Établissement courant (UDR-0098)              ┐
  ├─► Lot B  Rejoindre et quitter (UDR-0099)               │
  ├─► Lot C  Chaque direction ne voit que sa part (UDR-0100) ├─ en parallèle
  ├─► Lot D  Pilotage de l'équipe par rattachement          │
  └─► Lot E  Deux liens d'invitation (MET-8)                ┘  (après A : mêmes fichiers d'invitation)
```

> **Amendement du 2026-10-16 (réponses MET-4 et MET-8).** Le Lot A s'étend à tout l'espace enseignant (policies d'une classe, annonces, collègues en attente, test de non-fuite par écran, ADR-0094 §10). Le lien « Inviter un collègue » vers le principal est remplacé par deux liens : c'est le Lot E, qui suit A. Les lots sont exécutés à la suite par un seul agent, sur la branche du chantier (journal).

Vagues de dispatch :

```
Vague 1 : Lot 0              → 1 agent, séquentiel
Vague 2 : Lot A ‖ B ‖ C ‖ D  → 4 agents, worktrees isolés (feature/multi-etablissements-enseignant-lot-a … -lot-d)
```

Quatre lots, plus le socle.

---

## Lot 0 — Socle

- **Couche**       : infrastructure (migration, repositories, query) + domaine (contrats) + delivery (routes) + ui (navigation partagée)
- **Fichiers**     : `db/migrate/2026101…_add_current_school_id_to_sessions.rb` · `db/schema.rb`
                     `app/domain/entities/school/teacher_schools.rb` *(nouveau, `MAX = 3`)*
                     `app/domain/entities/identity/session_state.rb` *(+ `current_school_id`)*
                     `app/domain/entities/identity/audit_action.rb` *(+ `teacher.left`)*
                     `app/domain/ports/school/school_repository_port.rb` *(+ `attach_teacher_within_cap`, `school_ids_for`, `promote_primary`)*
                     `app/domain/ports/identity/session_repository_port.rb` *(+ `set_current_school`)*
                     `app/domain/ports/identity/user_repository_port.rb` *(`actor_for(user_id:, current_school_id: nil)`)*
                     `app/infrastructure/repositories/school/school_repository.rb`
                     `app/infrastructure/repositories/identity/session_repository.rb`
                     `app/infrastructure/repositories/identity/user_repository.rb`
                     `app/domain/use_cases/identity/resolve_session.rb` *(passe `session.current_school_id`)*
                     `app/infrastructure/queries/school/teacher_schools_query.rb` *(nouvelle)*
                     `config/routes/school.rb` *(`PATCH teachers/current-school`, `GET/POST teachers/schools`, `DELETE teachers/schools/:public_id`)*
                     `app/helpers/navigation_helper.rb` *(entrée « Mes établissements » du panneau enseignant)*
                     `config/locales/shared/navigation.fr.yml` *(entrée et rubrique « Établissement » du panneau)*
                     `docs/decisions/adr/0030-…`, `0071-…`, `0083-…` *(sections « Amendement » renvoyant à l'ADR-0094)*
- **Dépend de**    : — *(et les réponses du porteur)*
- **Test associé** : `test/infrastructure/repositories/identity/user_repository_test.rb` *(courant rattaché → courant ; courant quitté → principal ; aucun → nil ; direction inchangée)*
                     `test/infrastructure/repositories/school/school_repository_test.rb` *(plafond, déjà rattaché, `promote_primary` choisit le plus ancien)*
                     `test/infrastructure/repositories/school/teacher_cap_concurrency_test.rb` *(nouveau, motif de `staff_cap_concurrency_test.rb` : deux threads ne dépassent pas 3)*
                     `test/infrastructure/repositories/identity/session_repository_test.rb`
                     `test/domain/use_cases/identity/resolve_session_test.rb`
                     `test/infrastructure/queries/school/teacher_schools_query_test.rb`
- **Done quand**   : un acteur enseignant suit l'établissement courant de sa session et retombe sur le principal sans lui ; le plafond tient sous concurrence ; `SELECT COUNT(*) FROM teacher_schools WHERE NOT "primary"` en production est consigné au journal (attendu : 0) ; les routes existent ; le panneau rend l'entrée « Mes établissements » pour un enseignant et rien de nouveau pour les autres rôles

Contrats gelés : les signatures de l'ADR-0094 §4.5 ; `TeacherSchoolsQuery::Row(public_id, name, sigle, drena_name, primary, current)` ; noms de routes `teacher_current_school`, `teacher_schools`, `teacher_school` ; clés `shared.navigation.account_panel.schools.*`.

---

## Lot A — Établissement courant (UDR-0098)

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/policies/school/switch_current_school_policy.rb` *(nouvelle)*
                     `app/domain/use_cases/school/switch_current_school.rb` *(nouveau)*
                     `app/controllers/school/current_schools_controller.rb` *(nouveau)*
                     `app/views/shared/navigation/_account_panel.html.erb` *(rubrique « Établissement »)*
                     `app/infrastructure/queries/identity/shell_user_query.rb` · `app/infrastructure/queries/identity/profile_query.rb`
                     `app/infrastructure/queries/classroom/teacher_home_query.rb` · `app/infrastructure/queries/classroom/teacher_follow_ups_query.rb`
                     `app/infrastructure/queries/classroom/catalog_assignment_targets_query.rb` · `app/infrastructure/queries/catalog/teacher_audience_query.rb`
                     `app/controllers/classroom/teacher_homes_controller.rb` · `app/controllers/catalog/courses_controller.rb`
                     `app/controllers/catalog/essentials_controller.rb` · `app/controllers/assessment/exercises_controller.rb`
                     `app/views/classroom/teacher_homes/show.html.erb` · `app/views/classroom/teaching_selections/index.html.erb`
                     `app/domain/policies/identity/invite_colleague_policy.rb` · `app/domain/use_cases/identity/record_referral_share.rb` *(le principal, plus `actor.school_id`)*
                     `app/controllers/concerns/colleague_invitation.rb` · `app/infrastructure/queries/identity/referral_query.rb`
                     `app/views/identity/referrals/_invite.html.erb`
                     `config/locales/classroom/teacher_homes.fr.yml` · `config/locales/classroom/teaching_selections.fr.yml`
                     `config/locales/identity/referrals.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/policies/school/switch_current_school_policy_test.rb`
                     `test/domain/use_cases/school/switch_current_school_test.rb`
                     `test/infrastructure/queries/classroom/teacher_home_query_test.rb` *(deux « 6ème 1 », une par établissement)*
                     `test/domain/policies/identity/invite_colleague_policy_test.rb` · `test/domain/use_cases/identity/record_referral_share_test.rb` *(dans B, le lien reste celui de A principal)*
                     `test/system/school/current_school_test.rb` *(ME-07 à ME-12, panneau sur le site et `/teachers/menu`)*
- **Done quand**   : un enseignant de deux établissements passe de l'un à l'autre par le panneau, ne voit sur l'accueil, le catalogue et « Assigner » que l'établissement courant, et un enseignant d'un seul établissement ne voit rien de nouveau ; captures à 390 px et sur ordinateur (panneau ouvert, accueil), et dans Lnclass Teacher

---

## Lot B — Rejoindre et quitter (UDR-0099)

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/policies/school/join_school_with_code_policy.rb` *(amendée : `schools_count`)*
                     `app/domain/policies/school/leave_school_policy.rb` *(nouvelle)*
                     `app/domain/use_cases/school/join_school_with_code.rb` *(amendé : secondaire, plafond, jeton)*
                     `app/domain/use_cases/school/leave_school.rb` *(nouveau)*
                     `app/domain/dtos/school/school_invite_join_input.rb` *(nouveau)*
                     `app/controllers/school/teacher_schools_controller.rb` *(nouveau)*
                     `app/controllers/identity/teacher_registrations_controller.rb` *(`#invite` pour un enseignant connecté)*
                     `app/views/school/teacher_schools/index.html.erb` · `app/views/school/teacher_schools/_join_fields.html.erb`
                     `app/views/identity/pending_accounts/show.html.erb` *(rend `_join_fields`)*
                     `app/views/identity/teacher_registrations/join.html.erb`
                     `config/locales/school/teacher_schools.fr.yml` *(nouveau)* · `config/locales/identity/teacher_registrations.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/policies/school/join_school_with_code_policy_test.rb` · `test/domain/policies/school/leave_school_policy_test.rb`
                     `test/domain/use_cases/school/join_school_with_code_test.rb` *(0, 1, 2, 3 établissements ; départ ouvert ; déjà rattaché ; aucune demande écrite)*
                     `test/domain/use_cases/school/leave_school_test.rb` *(devoirs de cet établissement seulement, promotion du principal, pas de départ)*
                     `test/system/school/teacher_schools_test.rb` *(ME-02, ME-04, ME-13 à ME-15)*
                     `test/system/identity/invite_link_signed_in_test.rb` *(ME-01, ME-03, ME-05, ME-16)*
                     `test/system/identity/teacher_signup_test.rb` *(écran d'attente inchangé)*
- **Done quand**   : un enseignant connecté rejoint un second établissement par le lien de sa direction ou par « Mes établissements », jamais celui qui l'a retiré ni un quatrième, et quitte un établissement qui n'est pas son dernier ; l'écran d'attente se comporte comme avant ; captures de la page (un, deux, trois établissements), de la modale « Quitter » et de la carte « Rejoindre ? » à 390 px et sur ordinateur

---

## Lot C — Chaque direction ne voit que sa part (UDR-0100)

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/school/detach_teacher.rb` *(+ `promote_primary`)*
                     `app/domain/use_cases/school/reinstate_teacher.rb` *(secondaire, plafond)*
                     `app/infrastructure/queries/school/departed_teachers_query.rb` *(sans `WITHOUT_SCHOOL`)*
                     `app/controllers/school_admin/teacher_reinstatements_controller.rb` *(toast du plafond)*
                     `app/views/school_admin/schools/_link.html.erb` *(phrase d'aide)*
                     `config/locales/school_admin/schools.fr.yml` · `config/locales/school_admin/teacher_reinstatements.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/school/detach_teacher_test.rb` *(retrait du principal : B devient principal)*
                     `test/domain/use_cases/school/reinstate_teacher_test.rb` *(secondaire ; plafond → `:conflict`)*
                     `test/infrastructure/queries/school/departed_teachers_query_test.rb`
                     `test/system/school_admin/shared_teacher_test.rb` *(ME-17 à ME-22 : deux directions, un enseignant partagé, test de refus par écran)*
- **Done quand**   : pour un enseignant de A et B, la direction de A ne trouve ni le nom, ni les classes, ni les devoirs de B sur aucun de ses écrans ; retirer A laisse l'enseignant dans B ; « Réintégrer » fonctionne pour un enseignant parti ailleurs ; captures de « Établissement » et « Enseignants retirés » à 390 px et sur ordinateur

---

## Lot D — Pilotage de l'équipe par rattachement

- **Couche**       : infrastructure + docs
- **Fichiers**     : `app/infrastructure/queries/school/drena_schools_query.rb`
                     `app/infrastructure/queries/school/team_dashboard_query.rb`
                     `docs/decisions/adr/0062-indicateurs-de-pilotage-lus-en-direct.md` *(amendement : « DRENA d'un enseignant »)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/school/drena_schools_query_test.rb` *(la DRENA reste la somme de ses établissements, RE-08)*
                     `test/infrastructure/queries/school/team_dashboard_query_test.rb` *(national compté une fois)*
                     `test/performance/school/heavy_screens_budget_test.rb` *(`PERF=1`, budget de l'ADR-0067 tenu)*
- **Done quand**   : ME-23 et ME-24 passent, le nombre de requêtes du pilotage ne change pas et le budget `PERF=1` est vert

---

## Lot E — Deux liens d'invitation (MET-8)

- **Couche**       : infrastructure (migration `teacher_schools.invite_token`, repositories, query) + domaine + delivery + ui
- **Fichiers**     : `db/migrate/2026101…_add_invite_token_to_teacher_schools.rb` · `db/schema.rb`
                     `app/domain/ports/identity/invite_link_repository_port.rb` *(InviteLink + `sponsor`)* · `app/infrastructure/repositories/identity/invite_link_repository.rb`
                     `app/domain/use_cases/identity/register_teacher.rb` *(lien de parrainage : établissement choisi, parrainage noté)*
                     `app/domain/policies/identity/invite_colleague_policy.rb` · `app/domain/use_cases/identity/record_referral_share.rb` · `app/controllers/concerns/colleague_invitation.rb`
                     `app/infrastructure/queries/identity/referral_query.rb` · `app/views/identity/referrals/*` · `app/views/classroom/teacher_homes/_course_levels.html.erb`
                     `app/controllers/identity/teacher_registrations_controller.rb` · `app/views/identity/teacher_registrations/*`
                     `config/locales/identity/referrals.fr.yml` · `config/locales/identity/teacher_registrations.fr.yml`
- **Dépend de**    : Lot A (mêmes fichiers d'invitation), Lot B (lien ouvert connecté)
- **Test associé** : `test/infrastructure/repositories/identity/invite_link_repository_test.rb` · `test/domain/use_cases/identity/register_teacher_test.rb`
                     `test/domain/policies/identity/invite_colleague_policy_test.rb` · `test/infrastructure/queries/identity/referral_query_test.rb`
                     `test/controllers/identity/referrals_controller_test.rb` · `test/system/identity/two_invite_links_test.rb` *(ME-26 à ME-29)*
- **Done quand**   : la page « Inviter un collègue » montre deux liens, celui de l'établissement courant (le collègue arrive dans cet établissement) et celui de parrainage (le collègue choisit son établissement, le parrainage est compté) ; captures à 390 px et sur ordinateur

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `db/migrate/…`, `db/schema.rb` | Lot 0 |
| `config/routes/school.rb` | Lot 0 |
| `app/helpers/navigation_helper.rb`, `config/locales/shared/navigation.fr.yml` | Lot 0 |
| Ports `school_repository_port.rb`, `session_repository_port.rb`, `user_repository_port.rb` et leurs repositories | Lot 0 |
| `app/domain/use_cases/identity/resolve_session.rb` | Lot 0 |
| `app/infrastructure/queries/school/teacher_schools_query.rb` | Lot 0 |
| ADR-0030, 0071, 0083 (amendements) | Lot 0 |
| `app/views/shared/navigation/_account_panel.html.erb` | Lot A |
| Queries de l'enseignant (`teacher_home`, `teacher_follow_ups`, `catalog_assignment_targets`, `teacher_audience`, `shell_user`, `profile`, `referral`) | Lot A |
| `InviteColleaguePolicy`, `RecordReferralShare`, `ColleagueInvitation` | Lot A |
| `join_school_with_code.rb` et sa policy, `leave_school.rb`, `identity/pending_accounts/show.html.erb`, `identity/teacher_registrations_controller.rb` | Lot B |
| `detach_teacher.rb`, `reinstate_teacher.rb`, `departed_teachers_query.rb`, `school_admin/schools/_link.html.erb` | Lot C |
| `drena_schools_query.rb`, `team_dashboard_query.rb`, ADR-0062 | Lot D |

Aucun fichier n'est listé par deux lots parallèles. `SchoolRepository` (Lot 0) est appelé par B et C, jamais modifié par eux.

## Portes de sortie

- [x] Réponses du porteur consignées au memo ; ADR-0094 et UDR-0098 à 0100 « Accepté »
- [x] Tous les lots sont `Done` (0, A, B, C, D, E ; un commit chacun)
- [ ] Un rôle distinct de l'auteur a **exécuté** le résultat : deux directions et un enseignant partagé, parcours ME-01 à ME-22 refaits dans l'application, sur le site et dans Lnclass Teacher
- [x] `bin/ci-quiet` vert, verdict écrit dans la PR (CI GitHub coupée, ADR-0069) ; pureté du domaine, rubocop, tests, parcours système, brakeman
- [ ] Sous-agents de revue (`security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`) une fois, sur le diff final : policies, use cases et routes sont touchés
- [x] Captures envoyées au porteur (jamais commitées) : chaque écran modifié à 390 px et sur ordinateur, panneau et menus ouverts
- [x] Index ADR et UDR régénérés par `script/docs/build_index` au commit de clôture ; ligne du chantier dans `docs/chantiers/README.md` et §6 de la feuille de route (ID-27, Q7) mis à jour à la clôture (ID-09 et SC-23 restent à `espace-direction`)
- [x] `journal.md` complété
