# Plan d'exécution — Espace direction, version simple

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Décisions : [ADR-0065](../../decisions/adr/0065-espace-direction-simple-en-lecture-seule.md), [UDR-0052](../../decisions/udr/0052-espace-direction-simple.md). Critères : [PRD §4](prd.md#4-critères-dacceptation).

## Graphe

```
Lot 0 — SOCLE : table, rattachement, acteur, routes, navigation, garde
  ↓
  ├─► Lot A « l'équipe invite, la direction crée son compte »   ┐
  ├─► Lot B « Enseignants »                                     ├─ en parallèle
  └─► Lot C « Travail des élèves » (accueil de la direction)    ┘
```

Vague 1 : Lot 0 → 1 agent. Vague 2 : Lot A ‖ Lot B ‖ Lot C → 3 agents, worktrees isolés (`git worktree add ../lnclass-espace-direction-simple-lot-a -b feature/espace-direction-simple-lot-a feature/espace-direction-simple`).

Deux règles : le Lot 0 gèle les contrats (un lot qui doit changer un port s'arrête, le Lot 0 rouvre) ; aucun lot parallèle ne démarre avant la fusion du Lot 0 dans `feature/espace-direction-simple`.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + delivery (garde, routes) + ui (navigation)
- **Fichiers**     : db/migrate/20260929100000_create_school_staffs.rb
                     db/schema.rb
                     app/infrastructure/orm/school_staff.rb
                     app/infrastructure/orm/user.rb
                     app/domain/entities/identity/invitation.rb
                     app/domain/ports/school/staff_repository_port.rb
                     app/domain/policies/school/read_own_school_policy.rb
                     app/infrastructure/repositories/identity/user_repository.rb
                     app/controllers/school_admin/base_controller.rb
                     app/helpers/navigation_helper.rb
                     config/routes.rb · config/routes/school_admin.rb · config/routes/teams.rb
                     config/locales/shared/navigation.fr.yml
                     test/support/factories/identity.rb
                     test/system/role_homes_test.rb
- **Dépend de**    : —
- **Test associé** : test/db/schema_constraints_test.rb
                     test/domain/entities/identity/invitation_test.rb
                     test/domain/policies/school/read_own_school_policy_test.rb
                     test/infrastructure/repositories/identity/user_repository_test.rb
                     test/helpers/navigation_helper_test.rb
                     test/routing/school_admin_routes_test.rb (DS-11, GET seulement)
- **Done quand**   : `bin/rails db:migrate` crée `school_staffs` ; une direction créée par `create_school_admin(school:)` se connecte par PIN et son acteur porte l'établissement ; `/school-admin/classrooms`, `/school-admin/classrooms/:public_id`, `/school-admin/teachers` et `/teams/schools/:school_public_id/staff-invitations` sont dessinées ; la navigation de la direction a deux entrées ; `bin/rails test` au vert

Contrats gelés : `StaffRepositoryPort#attach(user_id:, school_id:, invited_by_id:, at:)` ; `ReadOwnSchoolPolicy#call(actor:)` ; `Actor#school_id` d'un `school_admin` = son établissement ; noms de route `school_admin_classrooms`, `school_admin_classroom`, `school_admin_teachers`, `school_staff_invitations`, `new_school_staff_invitation`. Le cas `school_admin` de `role_homes_test.rb` est retiré ici : son parcours passe au test système du Lot C.

---

## Lot A — L'équipe invite, la direction crée son compte

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : app/domain/use_cases/identity/invite_school_staff.rb
                     app/domain/policies/identity/invite_school_staff_policy.rb
                     app/domain/dtos/identity/school_staff_invitation_input.rb
                     app/domain/use_cases/identity/accept_invitation.rb
                     app/infrastructure/repositories/school/staff_repository.rb
                     app/infrastructure/repositories/identity/invitation_repository.rb
                     app/infrastructure/queries/identity/profile_query.rb
                     app/infrastructure/queries/identity/shell_user_query.rb
                     app/controllers/teams/staff_invitations_controller.rb
                     app/controllers/identity/invitations_controller.rb
                     app/views/teams/staff_invitations/ (new, _created, created, create.turbo_stream)
                     app/views/teams/schools/_header.html.erb
                     app/views/identity/invitations/show.html.erb
                     app/views/identity/profiles/_information.html.erb
                     config/locales/teams/staff_invitations.fr.yml · config/locales/teams/schools.fr.yml
                     config/locales/identity/invitations.fr.yml · config/locales/identity/profiles.fr.yml
- **Dépend de**    : Lot 0
- **Test associé** : test/domain/use_cases/identity/invite_school_staff_test.rb (DS-01, DS-02)
                     test/domain/policies/identity/invite_school_staff_policy_test.rb (DS-04)
                     test/domain/use_cases/identity/accept_invitation_test.rb (DS-03)
                     test/infrastructure/repositories/school/staff_repository_test.rb
                     test/controllers/teams/staff_invitations_controller_test.rb (DS-02, DS-04)
                     test/system/teams/staff_invitation_test.rb (DS-01, DS-03)
- **Done quand**   : depuis la fiche d'un établissement actif, l'équipe obtient un lien ; ce lien crée un compte de direction qui se connecte par PIN sans second facteur et dont le profil nomme l'établissement

---

## Lot B — Enseignants

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : app/infrastructure/queries/school/school_teachers_query.rb
                     app/controllers/school_admin/teachers_controller.rb
                     app/views/school_admin/teachers/index.html.erb
                     config/locales/school_admin/teachers.fr.yml
- **Dépend de**    : Lot 0
- **Test associé** : test/infrastructure/queries/school/school_teachers_query_test.rb (DS-06, DS-10)
                     test/controllers/school_admin/teachers_controller_test.rb (DS-10, DS-11)
- **Done quand**   : une direction ouvre « Enseignants » et voit les enseignants de son établissement, leur matière et leurs classes, sans aucun enseignant d'un autre établissement

---

## Lot C — Travail des élèves

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : app/domain/entities/identity/home_destination.rb
                     app/controllers/concerns/authentication.rb
                     app/infrastructure/queries/school/student_work_query.rb
                     app/controllers/school_admin/classrooms_controller.rb
                     app/views/school_admin/classrooms/index.html.erb
                     app/views/school_admin/classrooms/show.html.erb
                     config/locales/school_admin/classrooms.fr.yml
- **Dépend de**    : Lot 0
- **Test associé** : test/domain/entities/identity/home_destination_test.rb (DS-05)
                     test/infrastructure/queries/school/student_work_query_test.rb (DS-07, DS-08, DS-09, DS-10)
                     test/controllers/school_admin/classrooms_controller_test.rb (DS-10, DS-11)
                     test/system/school_admin/student_work_test.rb (DS-05, DS-09)
- **Done quand**   : une direction se connecte, arrive sur « Travail des élèves », ouvre une classe et voit chaque élève avec ses devoirs rendus et son score moyen ; la classe d'un autre établissement donne 404

---

## Vérification de collision

Doublons cherchés par la commande de la skill `plan-lots` (sortie vide), puis relus à la main pour les répertoires.

| Fichier | Lot propriétaire |
|---|---|
| `config/routes.rb`, `config/routes/school_admin.rb`, `config/routes/teams.rb` | Lot 0 |
| `config/locales/shared/navigation.fr.yml` | Lot 0 |
| `app/helpers/navigation_helper.rb` | Lot 0 |
| `db/schema.rb`, `db/migrate/` | Lot 0 |
| `test/support/factories/identity.rb` | Lot 0 |
| `test/system/role_homes_test.rb` | Lot 0 |
| `app/controllers/school_admin/base_controller.rb` | Lot 0 |
| `app/infrastructure/repositories/identity/user_repository.rb` | Lot 0 |
| `app/domain/entities/identity/home_destination.rb`, `app/controllers/concerns/authentication.rb` | Lot C (seul lot qui a une page d'accueil à donner) |
| `app/views/identity/profiles/_information.html.erb`, `app/infrastructure/queries/identity/shell_user_query.rb` | Lot A |
| `config/locales/school_admin/teachers.fr.yml` / `classrooms.fr.yml` | Lot B / Lot C (fichiers distincts) |
| `config/locales/teams/*.fr.yml`, `config/locales/identity/*.fr.yml` | Lot A |

Aucun layout n'est modifié. Le shell lit la navigation dans `NavigationHelper` (Lot 0) et le détail sous le nom dans `ShellUserQuery` (Lot A).

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md`
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md`
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Ici : il invite une direction depuis la fiche d'un établissement, crée le compte par le lien, se connecte par PIN, recalcule à la main les chiffres d'une classe (DS-07), puis demande une classe d'un autre établissement (404) et une page de la direction avec un compte enseignant (403).
