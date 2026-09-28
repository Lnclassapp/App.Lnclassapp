# Plan d'exécution — Espace direction

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Entrées : [`prd.md`](prd.md) (56 critères ED-01 à ED-56), [ADR-0065](../../decisions/adr/0065-matricule-de-l-eleve.md), [ADR-0066](../../decisions/adr/0066-espace-direction-droits-et-gestes.md), [ADR-0067](../../decisions/adr/0067-tableau-de-bord-de-l-etablissement.md), [UDR-0052](../../decisions/udr/0052-espace-direction.md), [UDR-0053](../../decisions/udr/0053-matricule-de-l-eleve.md).

## Préalables au Lot 0 (programme, [`programme.md` §2](../../workflows/programme.md#2-décider--prdmd-cadre--adrudr-de-fondation))

- [ ] ADR-0065, 0066, 0067 et UDR-0052, 0053 passés de `Proposé` à `Accepté` par le porteur.
- [ ] **Format du matricule MENA confirmé** sur un vrai matricule (ADR-0065 §9) ; sinon le `CHECK` et `StudentNumber::FORMAT` sont corrigés **avant** le Lot 0a.
- [ ] Juste avant la mise en production : **aucun élève en base de production** (sinon la migration du Lot F échoue, voulu).

## Graphe

```
Lot 0a — SCHÉMA ET CONTRATS (séquentiel)
  migrations · entités · ports gelés · StaffPolicy · StaffRepository · fabriques
  ↓
Lot 0b — GARDE D'ACCÈS ET FICHIERS PARTAGÉS (séquentiel)
  second facteur de la direction · acteur · routes · navigation · shell · profil · page Établissement
  ↓
  ├─► Lot A « Inviter la direction et le personnel »       ┐
  ├─► Lot B « Personnel : voir et retirer »                │
  ├─► Lot C « Enseignants : liste, retrait, retour par code »│
  ├─► Lot D « Classes et tableau de bord »                 ├─ en parallèle, fichiers disjoints
  ├─► Lot E « Élèves : liste et rattachement par matricule »│
  ├─► Lot F « Matricule : inscription et correction équipe »│
  └─► Lot G « Code d'établissement »                        ┘
```

**Pourquoi deux lots socles.** Le socle de ce chantier est plus gros qu'une poignée de fichiers : il porte un nouveau rôle actif (second facteur, acteur, garde) et sept contrats consommés par sept lots. Le couper en 0a (données et contrats, sans écran) puis 0b (accès et fichiers partagés) garde chaque socle court et démontrable seul. **Aucun lot parallèle ne démarre avant la fusion de 0b** dans `feature/espace-direction`.

**Règles gelées.**
1. Les lots A à G **implémentent** les ports gelés par 0a ; aucun ne les redéfinit. Un lot qui a besoin de changer un port, une entité du Lot 0a, une route, une locale partagée ou une fabrique **s'arrête** : le Lot 0 rouvre.
2. Aucun lot vertical n'ajoute de fabrique dans `test/support/factories/` : il écrit ses aides dans son fichier de test.
3. Aucun lot vertical n'écrit dans `docs/` : il remonte ses notes au porteur du chantier, qui tient `journal.md`.

---

## Lot 0a — Schéma et contrats

- **Couche**       : infrastructure (migrations, `Orm::`, repositories) + domaine (entités, ports, policy)
- **Fichiers**     : db/migrate/20260929090000_add_student_number_to_users.rb
                     db/migrate/20260929090100_create_school_staffs.rb
                     db/migrate/20260929090200_partial_unique_classroom_students.rb
                     db/schema.rb
                     app/infrastructure/orm/school_staff.rb
                     app/infrastructure/orm/user.rb
                     app/domain/entities/identity/student_number.rb
                     app/domain/entities/identity/actor.rb
                     app/domain/entities/identity/user.rb
                     app/domain/entities/identity/session_state.rb
                     app/domain/entities/identity/audit_action.rb
                     app/domain/entities/classroom/membership.rb
                     app/domain/entities/school/staff_member.rb
                     app/domain/entities/school/staff_position.rb
                     app/domain/ports/school/staff_repository_port.rb
                     app/domain/ports/school/school_repository_port.rb
                     app/domain/ports/school/join_request_repository_port.rb
                     app/domain/ports/identity/user_repository_port.rb
                     app/domain/ports/identity/registration_repository_port.rb
                     app/domain/ports/classroom/membership_repository_port.rb
                     app/domain/ports/classroom/classroom_repository_port.rb
                     app/domain/ports/classroom/teaching_repository_port.rb
                     app/domain/policies/school/staff_policy.rb
                     app/infrastructure/repositories/school/staff_repository.rb
                     app/infrastructure/repositories/identity/user_repository.rb
                     app/infrastructure/repositories/classroom/membership_repository.rb
                     config/initializers/filter_parameter_logging.rb
                     db/seeds/development.rb
                     test/support/factories/identity.rb
- **Dépend de**    : — (préalables ci-dessus acceptés)
- **Test associé** : test/db/schema_constraints_test.rb (ED-50 ; `school_staffs` ; `classroom_students` : deux lignes closes acceptées, deux ouvertes refusées)
                     test/domain/entities/identity/student_number_test.rb
                     test/domain/entities/identity/actor_test.rb
                     test/domain/entities/school/staff_position_test.rb
                     test/domain/policies/school/staff_policy_test.rb (table §4.3 cellule par cellule, refus inter-établissements pour chaque geste)
                     test/infrastructure/repositories/school/staff_repository_test.rb
                     test/infrastructure/repositories/identity/user_repository_test.rb (`actor_for` avec fonction, établissement inactif → `nil` ; `find_student_by_number` ; `update_student_number`)
                     test/infrastructure/repositories/classroom/membership_repository_test.rb (`school_id`, `school_year`)
                     test/domain/use_cases/school/review_join_request_test.rb et test/domain/use_cases/school/vouch_for_teacher_test.rb (ED-23 : un `school_admin` refusé)
- **Done quand**   : `bin/rails db:migrate` puis `db:rollback` puis `db:migrate` passent ; `bin/rails runner "puts Policies::School::StaffPolicy.name, Ports::School::StaffRepositoryPort.name, Entities::Identity::StudentNumber.name"` charge les constantes ; les fabriques créent un élève avec matricule et un membre de la direction avec second facteur (`create_school_admin(school:, position:)`) ; `create_user(role: "school_admin")` reçoit un second facteur par défaut, et tous les tests existants qui l'utilisent restent verts ; `bin/ci` au vert

Détail des contrats : ADR-0066 §4.5 (ports), §4.3 (table), ADR-0065 §4 (colonne). Le seed de développement ajoute un Proviseur (`0700000002`, second facteur à activer) rattaché à l'établissement du seed, et un matricule à l'élève du seed.

---

## Lot 0b — Garde d'accès et fichiers partagés

- **Couche**       : domaine + infrastructure + delivery + ui (socle)
- **Fichiers**     : app/domain/entities/identity/home_destination.rb
                     app/domain/policies/identity/second_factor_policy.rb
                     app/domain/use_cases/identity/resolve_session.rb
                     app/infrastructure/queries/identity/shell_user_query.rb
                     app/infrastructure/queries/identity/profile_query.rb
                     app/infrastructure/queries/school/direction_school_query.rb
                     config/routes.rb
                     config/routes/school_admin.rb
                     config/routes/teams.rb
                     config/routes/identity.rb
                     app/controllers/concerns/authentication.rb
                     app/controllers/school_admin/base_controller.rb
                     app/controllers/school_admin/schools_controller.rb
                     app/helpers/navigation_helper.rb
                     app/views/school_admin/schools/show.html.erb
                     app/views/identity/profiles/_information.html.erb
                     app/views/teams/schools/show.html.erb
                     config/locales/shared/navigation.fr.yml
                     config/locales/identity/profiles.fr.yml
                     config/locales/school_admin/shared.fr.yml
                     config/locales/school_admin/schools.fr.yml
- **Dépend de**    : Lot 0a
- **Test associé** : test/integration/school_admin_access_test.rb (ED-01, ED-02, ED-03 : paramétré sur toutes les routes du module `school_admin` dont le contrôleur est chargé ; voir la porte de sortie)
                     test/domain/use_cases/identity/resolve_session_test.rb
                     test/domain/policies/identity/second_factor_policy_test.rb
                     test/domain/entities/identity/home_destination_test.rb
                     test/infrastructure/queries/identity/shell_user_query_test.rb
                     test/infrastructure/queries/identity/profile_query_test.rb
                     test/infrastructure/queries/school/direction_school_query_test.rb
                     test/controllers/school_admin/schools_controller_test.rb (ED-04)
                     test/controllers/identity/profiles_controller_test.rb (ED-05, ED-52)
                     test/helpers/navigation_helper_test.rb
                     test/routing/school_admin_routes_test.rb (les 17 routes de l'UDR-0052 §3.0 et les routes équipe et identité ajoutées)
                     test/system/school_admin/shell_test.rb (ED-04 en bureau et à 390 px)
- **Done quand**   : un Proviseur du seed se connecte, active son second facteur, voit les cinq entrées actives de sa navigation, ouvre « Établissement » (en-tête, deux frames qui répondent 404 tant que les lots G et B ne sont pas fusionnés) et « Mon profil » (fonction et établissement) ; un Proviseur retiré atterrit sur l'écran d'attente ; `bin/ci` au vert

Toutes les routes de l'UDR-0052 §3.0 et de l'UDR-0053 §3.3 sont dessinées ici, y compris celles dont le contrôleur arrive avec un lot vertical (une route non appelée ne casse rien). `teams/schools/show` reçoit seulement le frame différé `school_staff` (UDR-0052 §3.10). `school_admin/shared.fr.yml` porte les libellés des fonctions et les messages de refus communs (UDR-0052 §3.0).

---

## Lot A — Inviter la direction et le personnel

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : app/domain/dtos/school/staff_invitation_input.rb
                     app/domain/use_cases/school/invite_staff_member.rb
                     app/domain/use_cases/identity/accept_invitation.rb
                     app/controllers/school_admin/staff_invitations_controller.rb
                     app/controllers/teams/school_staff_invitations_controller.rb
                     app/controllers/identity/invitations_controller.rb
                     app/views/shared/staff_invitations/_form.html.erb
                     app/views/shared/staff_invitations/_created.html.erb
                     app/views/school_admin/staff_invitations/new.html.erb
                     app/views/school_admin/staff_invitations/create.turbo_stream.erb
                     app/views/school_admin/staff_invitations/created.html.erb
                     app/views/teams/school_staff_invitations/new.html.erb
                     app/views/teams/school_staff_invitations/create.turbo_stream.erb
                     app/views/teams/school_staff_invitations/created.html.erb
                     app/views/identity/invitations/show.html.erb
                     config/locales/school_admin/staff_invitations.fr.yml
                     config/locales/teams/school_staff_invitations.fr.yml
                     config/locales/identity/invitations.fr.yml
- **Dépend de**    : Lot 0b
- **Test associé** : test/domain/use_cases/school/invite_staff_member_test.rb (ED-07, ED-08, ED-09, ED-10, ED-11)
                     test/domain/use_cases/identity/accept_invitation_test.rb (ED-12, ED-13)
                     test/controllers/school_admin/staff_invitations_controller_test.rb (ED-08 : 403 Éducateur et Secrétaire ; ED-11)
                     test/controllers/teams/school_staff_invitations_controller_test.rb (ED-06)
                     test/controllers/identity/invitations_controller_test.rb (ED-12, ED-13)
                     test/system/school_admin/staff_invitation_test.rb (ED-06 puis ED-12 de bout en bout, à 390 px)
- **Done quand**   : l'équipe invite un Proviseur depuis la fiche, la personne ouvre le lien, crée son compte, active son second facteur et arrive sur `school_admin_home_path` ; ce Proviseur invite une Secrétaire depuis « Établissement » ; une Secrétaire qui force l'invitation reçoit 403

---

## Lot B — Personnel : voir et retirer

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : app/domain/use_cases/school/detach_staff_member.rb
                     app/infrastructure/queries/school/staff_members_query.rb
                     app/controllers/school_admin/staff_members_controller.rb
                     app/controllers/teams/school_staff_members_controller.rb
                     app/views/shared/staff_members/_member.html.erb
                     app/views/school_admin/staff_members/index.html.erb
                     app/views/school_admin/staff_members/destroy.turbo_stream.erb
                     app/views/teams/school_staff_members/index.html.erb
                     app/views/teams/school_staff_members/destroy.turbo_stream.erb
                     config/locales/school_admin/staff_members.fr.yml
                     config/locales/teams/school_staff_members.fr.yml
- **Dépend de**    : Lot 0b
- **Test associé** : test/domain/use_cases/school/detach_staff_member_test.rb (ED-15, ED-16, ED-17, ED-18)
                     test/infrastructure/queries/school/staff_members_query_test.rb (ED-14)
                     test/controllers/school_admin/staff_members_controller_test.rb (ED-08 : bouton « Inviter » masqué ; ED-14, ED-16, ED-18)
                     test/controllers/teams/school_staff_members_controller_test.rb (ED-17 : l'équipe retire le Proviseur)
                     test/system/school_admin/staff_test.rb (ED-15 : sessions fermées, renvoi vers `pending_account_path`, à 390 px)
- **Done quand**   : sur « Établissement », la Secrétaire voit le personnel sans « Inviter » ni « Retirer » ; le Proviseur retire un Éducateur après confirmation, la liste se met à jour sans rechargement et l'Éducateur est déconnecté ; l'équipe voit la section « Direction » de la fiche et retire le Proviseur

Le bouton « Inviter un membre » mène à la route du Lot A : il répond 404 tant que A n'est pas fusionné (démo complète après A).

---

## Lot C — Enseignants : liste, retrait, retour par code

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : app/domain/use_cases/school/detach_teacher.rb
                     app/domain/use_cases/school/rejoin_school_with_code.rb
                     app/domain/dtos/school/school_rejoin_input.rb
                     app/infrastructure/repositories/school/school_repository.rb
                     app/infrastructure/repositories/school/join_request_repository.rb
                     app/infrastructure/repositories/classroom/teaching_repository.rb
                     app/infrastructure/queries/school/school_teachers_query.rb
                     app/controllers/school_admin/teachers_controller.rb
                     app/controllers/identity/school_rejoins_controller.rb
                     app/controllers/identity/pending_accounts_controller.rb
                     app/views/school_admin/teachers/index.html.erb
                     app/views/school_admin/teachers/_list.html.erb
                     app/views/school_admin/teachers/destroy.turbo_stream.erb
                     app/views/identity/pending_accounts/show.html.erb
                     config/locales/school_admin/teachers.fr.yml
                     config/locales/identity/pending_accounts.fr.yml
                     config/locales/identity/school_rejoins.fr.yml
- **Dépend de**    : Lot 0b
- **Test associé** : test/domain/use_cases/school/detach_teacher_test.rb (ED-34, ED-37, ED-38)
                     test/domain/use_cases/school/rejoin_school_with_code_test.rb (ED-35, ED-36)
                     test/infrastructure/repositories/school/school_repository_test.rb (`detach_teacher`)
                     test/infrastructure/repositories/school/join_request_repository_test.rb (`pending_for`)
                     test/infrastructure/repositories/classroom/teaching_repository_test.rb (`withdraw_all_in_school` ne touche pas un autre établissement)
                     test/infrastructure/queries/school/school_teachers_query_test.rb (ED-33)
                     test/controllers/school_admin/teachers_controller_test.rb (ED-33, ED-37, ED-38)
                     test/controllers/identity/school_rejoins_controller_test.rb (ED-36 : message, 429)
                     test/controllers/identity/pending_accounts_controller_test.rb (ED-35 : variantes direction et enseignant retiré ; demande approuvée puis retirée)
                     test/system/school_admin/teachers_test.rb (ED-34 puis ED-35 de bout en bout, à 390 px)
- **Done quand**   : le Censeur filtre les enseignants par classe, en retire un après confirmation ; l'enseignant retiré voit l'écran d'attente avec le champ de code, saisit le code d'un autre établissement actif et arrive sur son accueil ; ses anciennes classes, devoirs et sessions sont intacts

---

## Lot D — Classes et tableau de bord

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : app/domain/use_cases/classroom/add_level_classroom.rb
                     app/controllers/teams/level_classrooms_controller.rb
                     app/infrastructure/queries/school/school_dashboard_query.rb
                     app/infrastructure/queries/school/direction_classrooms_query.rb
                     app/controllers/school_admin/homes_controller.rb
                     app/controllers/school_admin/classrooms_controller.rb
                     app/controllers/school_admin/level_classrooms_controller.rb
                     app/views/school_admin/homes/show.html.erb
                     app/views/school_admin/classrooms/index.html.erb
                     app/views/school_admin/classrooms/_level_row.html.erb
                     app/views/school_admin/classrooms/show.html.erb
                     app/views/school_admin/level_classrooms/create.turbo_stream.erb
                     config/locales/school_admin/homes.fr.yml
                     config/locales/school_admin/classrooms.fr.yml
                     config/locales/school_admin/level_classrooms.fr.yml
- **Dépend de**    : Lot 0b
- **Test associé** : test/domain/use_cases/classroom/add_level_classroom_test.rb (ED-24, ED-26 : `StaffPolicy`, établissement B refusé)
                     test/domain/use_cases/classroom/create_classroom_test.rb et test/domain/use_cases/classroom/remove_level_classroom_test.rb (ED-25 : `school_admin` toujours refusé)
                     test/controllers/teams/level_classrooms_controller_test.rb (l'équipe garde « + » et « − »)
                     test/infrastructure/queries/school/school_dashboard_query_test.rb (ED-28, ED-29, ED-31, ED-32 ; une définition par test, nombre de requêtes constant)
                     test/infrastructure/queries/school/direction_classrooms_query_test.rb
                     test/controllers/school_admin/homes_controller_test.rb (ED-30, ED-32)
                     test/controllers/school_admin/classrooms_controller_test.rb (ED-25, ED-26 : 404, ED-27, ED-30)
                     test/system/school_admin/classrooms_test.rb (ED-24 à 390 px)
                     test/system/role_homes_test.rb (un Proviseur rattaché arrive sur son tableau de bord)
- **Done quand**   : un Proviseur rattaché arrive sur son tableau de bord (trois chiffres, une ligne par classe, aucune note d'élève) ; la Secrétaire ajoute « 6ème 5 » par le « + » sans rechargement ; la page de la classe montre ses chiffres, son code d'adhésion et ses enseignants ; la page d'une classe d'un autre établissement répond 404

---

## Lot E — Élèves : liste et rattachement par matricule

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : app/domain/entities/school/student_placement.rb
                     app/domain/dtos/school/student_lookup_input.rb
                     app/domain/dtos/school/student_placement_input.rb
                     app/domain/use_cases/school/find_student_for_placement.rb
                     app/domain/use_cases/school/place_student.rb
                     app/infrastructure/repositories/classroom/classroom_repository.rb
                     app/infrastructure/queries/school/school_students_query.rb
                     app/controllers/school_admin/students_controller.rb
                     app/controllers/school_admin/student_placements_controller.rb
                     app/views/school_admin/students/index.html.erb
                     app/views/school_admin/students/_list.html.erb
                     app/views/school_admin/student_placements/new.html.erb
                     app/views/school_admin/student_placements/_lookup_form.html.erb
                     app/views/school_admin/student_placements/_placement_form.html.erb
                     app/views/school_admin/student_placements/_rate_limited.html.erb
                     app/views/school_admin/student_placements/create.turbo_stream.erb
                     config/locales/school_admin/students.fr.yml
                     config/locales/school_admin/student_placements.fr.yml
- **Dépend de**    : Lot 0b
- **Test associé** : test/domain/entities/school/student_placement_test.rb (règle « rattachable », ADR-0066 §4.4)
                     test/domain/use_cases/school/find_student_for_placement_test.rb (ED-40, ED-41, ED-42)
                     test/domain/use_cases/school/place_student_test.rb (ED-44, ED-45, ED-46, ED-47)
                     test/infrastructure/repositories/classroom/classroom_repository_test.rb (`lock_by_public_id`)
                     test/infrastructure/queries/school/school_students_query_test.rb (ED-39)
                     test/controllers/school_admin/students_controller_test.rb (ED-39, ED-30 : ni numéro ni note)
                     test/controllers/school_admin/student_placements_controller_test.rb (ED-41 : corps identiques, ED-42, ED-43, ED-47, ED-56)
                     test/system/school_admin/student_placement_test.rb (ED-44, ED-45 à 390 px)
- **Done quand**   : l'Éducateur saisit un matricule avec espaces et minuscule, lit le nom de l'élève, choisit une classe et le voit dans la liste sans rechargement ; un matricule inconnu et un élève d'un autre établissement donnent la même réponse ; la 11ᵉ recherche de la minute répond 429 ; un aller-retour de classe fonctionne

---

## Lot F — Matricule : inscription et correction par l'équipe

- **Couche**       : infrastructure (migration) + domaine + delivery + ui
- **Fichiers**     : db/migrate/20260929091000_require_student_number.rb
                     db/schema.rb (régénéré après la migration ; seul lot vertical à toucher `db/`)
                     app/domain/dtos/classroom/join_with_code_input.rb
                     app/domain/use_cases/classroom/join_with_code.rb
                     app/infrastructure/repositories/identity/registration_repository.rb
                     app/domain/dtos/identity/student_number_input.rb
                     app/domain/use_cases/identity/change_student_number.rb
                     app/domain/policies/identity/change_student_number_policy.rb
                     app/domain/policies/identity/reset_second_factor_policy.rb
                     app/infrastructure/queries/identity/account_lookup_query.rb
                     app/controllers/classroom/joins_controller.rb
                     app/controllers/teams/account_lookups_controller.rb
                     app/controllers/teams/student_numbers_controller.rb
                     app/controllers/teams/second_factor_resets_controller.rb
                     app/views/classroom/joins/_signup_form.html.erb
                     app/views/teams/account_lookups/show.html.erb
                     app/views/teams/account_lookups/_result.html.erb
                     app/views/teams/student_numbers/edit.html.erb
                     app/views/teams/student_numbers/update.turbo_stream.erb
                     config/locales/classroom/joins.fr.yml
                     config/locales/teams/account_lookups.fr.yml
                     config/locales/teams/student_numbers.fr.yml
- **Dépend de**    : Lot 0b
- **Test associé** : test/db/student_number_required_test.rb (ED-51)
                     test/domain/dtos/classroom/join_with_code_input_test.rb (ED-48, ED-49 : normalisation, vide, format)
                     test/domain/use_cases/classroom/join_with_code_test.rb (ED-49 : pris, aucun compte)
                     test/infrastructure/repositories/identity/registration_repository_test.rb (conflit `student_number` ou `contact`)
                     test/domain/use_cases/identity/change_student_number_test.rb (ED-53, ED-54)
                     test/domain/policies/identity/reset_second_factor_policy_test.rb (ED-55)
                     test/infrastructure/queries/identity/account_lookup_query_test.rb (numéro ou matricule)
                     test/controllers/classroom/joins_controller_test.rb (ED-48, ED-49)
                     test/controllers/teams/account_lookups_controller_test.rb (paramètre `q`, `contact` encore lu)
                     test/controllers/teams/student_numbers_controller_test.rb (ED-53, ED-54 : 403 hors équipe)
                     test/controllers/teams/second_factor_resets_controller_test.rb (ED-55)
                     test/system/classroom/join_test.rb (ED-48 à 390 px)
                     test/system/boucle_pedagogique_test.rb, test/system/error_paths_test.rb, test/system/identity/pin_reveal_test.rb, test/integration/pin_reveal_fields_test.rb (parcours d'inscription existants : champ matricule rempli)
- **Done quand**   : un visiteur ne peut plus s'inscrire sans matricule, s'inscrit avec « 1234 5678 a » et le retrouve en « 12345678A » sur son profil ; un matricule pris est refusé sans nom ; l'équipe retrouve un élève par son matricule dans « Débloquer un compte » et le corrige ; elle réinitialise le second facteur d'un Censeur ; la contrainte `users_student_number_required` est en base

---

## Lot G — Code d'établissement

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : app/domain/use_cases/school/regenerate_school_code.rb
                     app/controllers/teams/school_codes_controller.rb
                     app/controllers/school_admin/school_codes_controller.rb
                     app/views/school_admin/school_codes/show.html.erb
                     app/views/school_admin/school_codes/update.turbo_stream.erb
                     config/locales/school_admin/school_codes.fr.yml
- **Dépend de**    : Lot 0b
- **Test associé** : test/domain/use_cases/school/regenerate_school_code_test.rb (ED-21, ED-22 : `StaffPolicy`, établissement B refusé)
                     test/controllers/school_admin/school_codes_controller_test.rb (ED-19, ED-20, ED-21)
                     test/controllers/teams/school_codes_controller_test.rb (l'équipe régénère toujours)
                     test/system/school_admin/school_code_test.rb (ED-20 : régénération confirmée, ancien lien `/e/` en 404, à 390 px)
- **Done quand**   : sur « Établissement », la Secrétaire lit et copie le code sans bouton « Régénérer » ; le Censeur le régénère après confirmation, le nouveau code s'affiche sans rechargement et l'ancien `/e/<code>` répond 404

---

## Rattachement des critères aux lots

| Lot | Critères |
|---|---|
| 0a | ED-23, ED-50 |
| 0b | ED-01, ED-02, ED-03, ED-04, ED-05, ED-52 |
| A | ED-06, ED-07, ED-08 (403), ED-09, ED-10, ED-11, ED-12, ED-13 |
| B | ED-08 (bouton masqué), ED-14, ED-15, ED-16, ED-17, ED-18 |
| C | ED-33, ED-34, ED-35, ED-36, ED-37, ED-38 |
| D | ED-24, ED-25, ED-26, ED-27, ED-28, ED-29, ED-30 (tableau de bord, classe), ED-31, ED-32 |
| E | ED-30 (liste des élèves), ED-39, ED-40, ED-41, ED-42, ED-43, ED-44, ED-45, ED-46, ED-47, ED-56 |
| F | ED-48, ED-49, ED-51, ED-53, ED-54, ED-55 |
| G | ED-19, ED-20, ED-21, ED-22 |

Aucun critère orphelin : ED-01 à ED-56, 56 critères, chacun rattaché à au moins un lot et un fichier de test.

---

## Vérification de collision

> Construite avant de lancer les lots parallèles. Deux lots parallèles (A à G) ne listent jamais le même fichier. Contrôle mécanique :
> `awk '/^## Vérification de collision/{exit} 1' docs/chantiers/espace-direction/plan.md | grep -oE '(app|test|config|db|lib)/[A-Za-z0-9_/.-]+\.(rb|erb|yml|js)' | sort | uniq -d`
> Sortie attendue : **`db/schema.rb` seulement** — listé par le Lot 0a et par le Lot F, qui ne sont **jamais** en parallèle (F part après 0b) ; aucun autre lot vertical ne touche `db/`.

| Fichier ou répertoire partagé | Lot propriétaire | Pourquoi |
|---|---|---|
| `db/migrate/*`, `db/schema.rb` | Lot 0a ; puis Lot F (une migration, `schema.rb` régénéré) | Seul F ajoute une migration parmi les lots verticaux (contrainte d'obligation du matricule posée avec le champ d'inscription, ADR-0065 §6) |
| `db/seeds/development.rb` | Lot 0a | Seed du Proviseur et du matricule |
| `test/support/factories/identity.rb` | Lot 0a | Fabriques partagées ; les lots n'en ajoutent pas |
| `test/db/schema_constraints_test.rb` | Lot 0a | F teste l'obligation dans son propre fichier `test/db/student_number_required_test.rb` |
| Ports et entités (`app/domain/ports/**`, entités du §4.5 de l'ADR-0066) | Lot 0a | Contrats gelés |
| `app/domain/policies/school/staff_policy.rb` | Lot 0a | Consommée par A, B, C, D, E, G |
| `app/infrastructure/repositories/identity/user_repository.rb` | Lot 0a | Lue par E (recherche) et F (correction) : implémentée une fois |
| `app/infrastructure/repositories/school/staff_repository.rb` | Lot 0a | Utilisée par A (acceptation) et B (retrait) |
| `app/infrastructure/repositories/classroom/membership_repository.rb` | Lot 0a | Nouveaux champs de `Membership` |
| `config/routes.rb`, `config/routes/school_admin.rb`, `config/routes/teams.rb`, `config/routes/identity.rb` | Lot 0b | Toutes les routes de l'UDR-0052 §3.0 et de l'UDR-0053 §3.3 |
| `config/locales/shared/navigation.fr.yml`, `config/locales/school_admin/shared.fr.yml` | Lot 0b | Navigation, fonctions, refus communs |
| `config/locales/identity/profiles.fr.yml`, `app/views/identity/profiles/_information.html.erb`, `app/infrastructure/queries/identity/profile_query.rb` | Lot 0b | Profil de la direction **et** matricule de l'élève : deux lots l'auraient touché |
| `app/helpers/navigation_helper.rb`, `app/controllers/concerns/authentication.rb` | Lot 0b | Shell et routes d'accueil |
| `app/views/teams/schools/show.html.erb` | Lot 0b | Seulement le frame `school_staff` ; B remplit le frame |
| `app/views/school_admin/schools/show.html.erb` | Lot 0b | Page « Établissement » : frames `school_code` (G) et `school_staff` (B) |
| `app/views/identity/pending_accounts/show.html.erb`, `config/locales/identity/pending_accounts.fr.yml` | Lot C | Variantes direction **et** enseignant retiré, dans un seul lot |
| `config/locales/identity/invitations.fr.yml` | Lot A | — |
| `config/locales/classroom/joins.fr.yml` | Lot F | — |
| `app/domain/use_cases/classroom/add_level_classroom.rb`, `app/controllers/teams/level_classrooms_controller.rb` | Lot D | Changement de policy du « + » (équipe comprise) |
| `app/domain/use_cases/school/regenerate_school_code.rb`, `app/controllers/teams/school_codes_controller.rb` | Lot G | Changement de policy (équipe comprise) |
| `app/infrastructure/repositories/classroom/classroom_repository.rb` | Lot E | `lock_by_public_id` ; D **lit** le repository sans le modifier |
| `app/infrastructure/repositories/school/school_repository.rb`, `join_request_repository.rb`, `app/infrastructure/repositories/classroom/teaching_repository.rb` | Lot C | — |
| `app/infrastructure/repositories/identity/registration_repository.rb` | Lot F | — |
| `app/views/shared/staff_invitations/*` | Lot A | Partagé équipe / direction, dans un seul lot |
| `app/views/shared/staff_members/*` | Lot B | Idem |
| `app/views/layouts/*` | aucun | Le shell n'est pas modifié ; seules les données de navigation changent (Lot 0b) |
| `test/system/role_homes_test.rb` | Lot D | Seul l'accueil de la direction y change |
| `test/integration/school_admin_access_test.rb` | Lot 0b | Paramétré : couvre chaque route dès que son contrôleur est fusionné |
| `docs/chantiers/espace-direction/*` | porteur du chantier | Les lots n'écrivent pas dans `docs/` |

---

## Ce qui touche `annuaire-equipe` (second chantier de la V2)

`annuaire-equipe` (ID-18, ID-21, ID-22, ID-23, TR-20 à TR-22) peut démarrer **dès la fusion du Lot 0b** (feuille de route, V2), à ces conditions :

| Fichier ou contrat | Ici | Dans `annuaire-equipe` | Règle |
|---|---|---|---|
| `Ports::Identity::UserRepositoryPort`, `Repositories::Identity::UserRepository`, `Entities::Identity::User` | Lot 0a (matricule, `actor_for`, `school_admin?`) | anonymisation, modification d'un compte | **Après** le Lot 0a : ses ajouts partent de nos contrats gelés ; jamais en parallèle du Lot 0a |
| `test/support/factories/identity.rb` | Lot 0a | nouvelles fabriques | Après le Lot 0a |
| `config/routes/teams.rb`, `config/locales/teams/*` | Lot 0b (routes) ; A, B, F (leurs fichiers de locale) | routes et locales de l'annuaire | Routes : son Lot 0 après notre Lot 0b. Locales : fichiers distincts par contrôleur, aucun fichier commun |
| `Identity::AnonymizeUser` | — | le crée | **Doit** mettre `student_number` à `NULL` et terminer le rattachement `school_staffs` (ADR-0036 amendé, PRD §8) |
| « Débloquer un compte » : `Queries::Identity::AccountLookupQuery`, `teams/account_lookups/*`, `Teams::StudentNumbersController` | Lot F | l'annuaire peut remplacer la recherche par la fiche d'un compte | **Après** la fusion du Lot F ; la fiche reprend « Corriger le matricule » sans nouveau geste (UDR-0053 §4) |
| `Policies::Identity::ReadUserPolicy` | inchangée | élargie probablement (fiche, liste) | Aucun conflit ici ; si l'annuaire l'élargit à la direction, les photos des listes de la direction pourront suivre (dette) |
| Navigation `team` (5 destinations, maximum de l'UDR-0006) | inchangée | une entrée « Comptes » demanderait une nouvelle UDR | À trancher dans l'UDR de l'annuaire |
| Ordre de mise en production | — | — | Les deux chantiers en production **avant l'ouverture aux élèves** (matricule usurpé → anonymisation, ADR-0065) |

---

## Dispatch

```
Vague 1 : Lot 0a                                   → 1 agent, séquentiel
Vague 2 : Lot 0b                                   → 1 agent, séquentiel (après fusion de 0a)
Vague 3 : Lot A ‖ B ‖ C ‖ D ‖ E ‖ F ‖ G            → 7 agents, worktrees isolés (après fusion de 0b)
```

Chaque lot parallèle part de la branche de chantier, **Lot 0b fusionné** :

```bash
git worktree add ../lnclass-espace-direction-lot-a -b feature/espace-direction-lot-a feature/espace-direction
```

(tiret, pas slash : `feature/espace-direction-lot-a`). Brief de chaque agent : chemin absolu du worktree, son lot recopié en entier (4 champs), les liens vers `prd.md`, l'ADR et l'UDR qui le gouvernent, l'ordre intra-lot (test rouge → domaine → infrastructure → delivery → UI), l'interdiction de toucher un fichier hors de son champ `Fichiers`, `git -C <worktree>` et chemins absolus. Fusion dans `feature/espace-direction` au fur et à mesure ; **une seule PR** vers `Develop`.

Ordre de fusion conseillé dans la vague 3 (aucune dépendance de fichier, seulement de démonstration) : G et B d'abord (la page « Établissement » se remplit), A ensuite (le bouton « Inviter » de B mène quelque part), puis C, D, E, F dans l'ordre d'arrivée.

---

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

Portes propres à ce chantier :

- [ ] ADR-0065, 0066, 0067 et UDR-0052, 0053 `Accepté` ; format du matricule confirmé (préalables)
- [ ] `test/integration/school_admin_access_test.rb` couvre **les 17 routes** du module `school_admin` (compte vérifié à la fin de la vague 3 : aucune route dont le contrôleur manque)
- [ ] Chaque cas d'usage a son test de refus inter-établissements ; chaque geste sensible son refus Éducateur et Secrétaire (PRD §4, en-tête)
- [ ] Aucun élève en production avant la migration du Lot F
- [ ] C-31 marquée fermée dans le registre des contradictions de la feuille de route, à l'acceptation de l'UDR-0052

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Pour ce chantier, il rejoue au minimum : l'invitation du Proviseur par l'équipe jusqu'au tableau de bord ; le rattachement d'un élève par matricule par une Secrétaire ; le retrait d'un enseignant puis son retour par code ; **un refus inter-établissements forgé à la main** (URL d'une classe, d'un enseignant ou d'un membre de B depuis un compte de A) ; **un geste de gestion forgé par un Éducateur** ; la 11ᵉ recherche de matricule de la minute ; tout cela à 390 px sur un téléphone ou un émulateur. Il mesure le tableau de bord (§7 du PRD).
