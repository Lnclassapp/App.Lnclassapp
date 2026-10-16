# Plan d'exécution — Un enseignant qui enseigne plusieurs matières

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
>
> **Préalable au Lot 0** : les questions 1 à 11 du [memo](memo.md#ce-que-le-grill-a-révélé) répondues par le porteur ; l'ADR-0103 et les UDR-0125 à 0127 passées à « Accepté » (amendées si une réponse diffère) ; le nombre de `teacher_profiles` en production relevé ; l'ordre avec `multi-etablissements-enseignant` fixé (§ Articulation).
>
> **Préalable rempli le 2026-10-16.** Réponses du porteur : recommandations acceptées sauf Q1 et Q7 — les matières sont attachées au **rattachement enseignant-établissement**. ADR-0103 et UDR-0125 à 0127 amendés et acceptés au Lot 0. Ordre : ce chantier part de la branche `feature/multi-etablissements-enseignant` (PR #250) et fusionne après elle. Requête de comptage pour la production : [journal](journal.md).

## Amendement du Lot 0 (réponses du porteur)

Ce qui change dans les lots ci-dessous, sans changer leur découpage :

| Prévu | Livré |
|---|---|
| Table `teacher_materials(teacher_id, material_id)`, `Orm::TeacherMaterial` | Table `teacher_school_materials(teacher_id, school_id, material_id)`, `Orm::TeacherSchoolMaterial` : une liste par rattachement, sans FK vers `teacher_schools` (la liste survit à un retrait) |
| `TeacherProfileRepositoryPort#replace_materials`, `TeacherProfile#material_ids` | Port **nouveau** `Ports::Identity::TeacherMaterialRepositoryPort` (`material_ids_for`, `replace`, `inherit`) et `Repositories::Identity::TeacherMaterialRepository` ; l'entité du profil perd `material_id` au Lot Z |
| `RegistrationRepositoryPort#create_teacher(material_ids:)` | `create_teacher` garde `material_id` (écriture double) jusqu'au Lot Z, qui le retire ; `RegisterTeacher` écrit la liste après le rattachement |
| — | Lot 0 : `JoinSchoolWithCode`, `ReinstateTeacher`, `ReviewJoinRequest`, `VouchForTeacher` donnent une liste au nouveau rattachement (`inherit`) ; `SchoolRepository#delete_if_unreferenced` efface les listes d'un établissement supprimé |
| `TeacherMaterialsQuery.tags_for(teacher_ids:)` | `TeacherMaterialsQuery#tags_for(teacher_ids:, school_id:)` et `#for_pairs` ; `TeacherMaterialsQuery.label` (nom ou noms courts) |
| `ManageOwnMaterialsPolicy` : un enseignant | un enseignant **avec un établissement courant** ; la liste modifiée est celle de `actor.school_id` |
| Lots en parallèle (A, B, C, D) | Exécutés à la suite par un seul agent, un commit par lot, dans l'ordre 0, A, B, C, D, Z |

## Graphe

```
Lot 0 — SOCLE (séquentiel)
  migration + copie · Orm::TeacherMaterial · entité TeacherMaterials · ports gelés
  écriture double · RegisterTeacher (seconde matière) · TeacherMaterialsQuery · ui_subject_badges · route
  ↓
  ├─► Lot A  Inscription et profil (UDR-0125)              ┐
  ├─► Lot B  Catalogue et accueil (UDR-0126)               │ en parallèle,
  ├─► Lot C  Page de classe (UDR-0127 §3.1-3.3)            │ fichiers disjoints
  └─► Lot D  Signature, direction, équipe (UDR-0127 §3.4-3.6) ┘
  ↓
Lot Z — CONTRACTION (séquentiel) : retrait de teacher_profiles.material_id
```

Chaque lot est un commit (documentation du lot comprise). Une PR pour le chantier, vers `Develop`.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + fichiers partagés
- **Fichiers**     : `db/migrate/2026101…_create_teacher_materials.rb` *(nouveau : table + copie, ADR-0103 §6)* · `db/schema.rb`
                     `app/infrastructure/orm/teacher_material.rb` *(nouveau)* · `app/infrastructure/orm/teacher_profile.rb` · `app/infrastructure/orm/user.rb` *(`has_many :teacher_materials`)* · `app/infrastructure/orm/material.rb` *(`has_many :teacher_materials, dependent: :restrict_with_error`)*
                     `app/domain/entities/identity/teacher_materials.rb` *(nouveau, `MIN = 1`, `MAX = 3`)* · `app/domain/entities/identity/teacher_profile.rb` *(`material_ids`)* · `app/domain/entities/identity/audit_action.rb` *(+ `profile.materials_changed`)*
                     `app/domain/ports/identity/teacher_profile_repository_port.rb` *(+ `replace_materials`)* · `app/domain/ports/identity/registration_repository_port.rb` *(`material_ids:`)*
                     `app/infrastructure/repositories/identity/teacher_profile_repository.rb` · `app/infrastructure/repositories/identity/registration_repository.rb` *(écriture double : `teacher_materials` + `material_id` = première)*
                     `app/domain/dtos/identity/teacher_registration_input.rb` *(+ `second_material_slug`)* · `app/domain/use_cases/identity/register_teacher.rb` *(résout 1 ou 2 slugs, `TeacherMaterials.build`)*
                     `app/infrastructure/repositories/catalog/taxonomy_repository.rb` *(`delete_material` refuse aussi si `teacher_materials`)*
                     `app/infrastructure/queries/identity/teacher_materials_query.rb` *(nouveau : `tags_for(teacher_ids:)` → `{ id => [MaterialTag] }`, une requête)*
                     `app/helpers/components_helper.rb` *(+ `ui_subject_badges(tags, size:)` : un `ui_subject_badge` par matière dans `div.flex.flex-wrap.gap-1.5`)*
                     `config/routes/identity.rb` *(`resource :materials, only: %i[edit update], controller: :profile_materials` sous `resource :profile`)*
                     `test/support/factories/identity.rb` · `db/seeds/development.rb` · `db/seeds/demo/saint_michel.rb` *(une ligne `teacher_materials` par enseignant créé)*
- **Dépend de**    : — (préalable ci-dessus)
- **Test associé** : `test/domain/entities/identity/teacher_materials_test.rb` · `test/infrastructure/repositories/identity/teacher_profile_repository_test.rb` (`replace_materials` : ordre gardé, ajout, retrait, écriture double) · `test/infrastructure/repositories/identity/registration_repository_test.rb` · `test/domain/use_cases/identity/register_teacher_test.rb` (seconde matière, doublon, slug inconnu) · `test/infrastructure/queries/identity/teacher_materials_query_test.rb` (une requête pour N enseignants) · `test/infrastructure/repositories/catalog/taxonomy_repository_test.rb` · `test/db/schema_constraints_test.rb` (unicité, FK) · test de migration : autant de lignes que de profils
- **Done quand**   : la migration jouée sur une copie de la base de démo donne une ligne `teacher_materials` par profil ; toutes les pages existantes restent identiques (suite complète verte, sans toucher une lecture) ; les contrats ci-dessus sont gelés

## Lot A — Inscription et profil (UDR-0125)

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : `app/domain/policies/identity/manage_own_materials_policy.rb` *(nouveau)*
                     `app/domain/use_cases/identity/update_teacher_materials.rb` *(nouveau, ADR-0103 §4.4)*
                     `app/domain/dtos/identity/teacher_materials_input.rb` *(nouveau, `material_slugs`)*
                     `app/controllers/identity/profile_materials_controller.rb` *(nouveau)*
                     `app/views/identity/profile_materials/edit.html.erb` · `app/views/identity/profile_materials/update.turbo_stream.erb` *(nouveaux)*
                     `app/views/identity/profiles/_information.html.erb` *(ligne « Matières »)*
                     `app/infrastructure/queries/identity/profile_query.rb` *(`materials`)* · `app/infrastructure/queries/identity/shell_user_query.rb` *(nom ou noms courts)*
                     `app/controllers/identity/teacher_registrations_controller.rb` *(permet `second_material_slug`)* · `app/views/identity/teacher_registrations/_form.html.erb`
                     `config/locales/identity/profile_materials.fr.yml` *(nouveau)* · `config/locales/identity/profiles.fr.yml` · `config/locales/identity/teacher_registrations.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/policies/identity/manage_own_materials_policy_test.rb` (élève, direction, équipe refusés) · `test/domain/use_cases/identity/update_teacher_materials_test.rb` · `test/controllers/identity/profile_materials_controller_test.rb` (refus par rôle, 422, Turbo Stream, repli HTML) · `test/controllers/identity/teacher_registrations_controller_test.rb` · `test/infrastructure/queries/identity/profile_query_test.rb` · `test/infrastructure/queries/identity/shell_user_query_test.rb` · `test/system/teacher_materials_test.rb` (inscription avec deux matières, ajout d'une troisième au profil)
- **Done quand**   : un enseignant s'inscrit avec PC et SVT, ajoute Maths dans « Mon profil », voit « PC, SVT, Maths · Lycée X » dans l'en-tête ; un élève reçoit un refus sur `/profile/materials/edit` ; captures 390 px et ordinateur du formulaire, du profil et de la modale (avec et sans erreur)

## Lot B — Catalogue et accueil (UDR-0126)

- **Couche**       : infrastructure (queries) + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/catalog/teacher_audience_query.rb` *(`material_ids`)* · `app/infrastructure/queries/catalog/course_catalog_query.rb` *(`material_ids:`, `group_by_material:`)*
                     `app/controllers/catalog/courses_controller.rb`
                     `app/views/catalog/courses/index.html.erb` *(sous-titre, filtre « Matière »)* · `app/views/catalog/courses/_page.html.erb` *(groupes)*
                     `app/infrastructure/queries/classroom/teacher_home_query.rb` *(`materials`, score moyen)* · `app/infrastructure/queries/classroom/teacher_follow_ups_query.rb` *(`material_ids`, matière par ligne)*
                     `app/views/classroom/teacher_homes/show.html.erb` *(badges)* · `app/views/classroom/teacher_homes/_course_levels.html.erb` · `app/views/classroom/teacher_homes/_follow_ups.html.erb`
                     `config/locales/catalog/courses.fr.yml` · `config/locales/classroom/teacher_homes.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/catalog/teacher_audience_query_test.rb` · `test/infrastructure/queries/catalog/course_catalog_query_test.rb` (deux matières, `material=` hors portée) · `test/infrastructure/queries/classroom/teacher_home_query_test.rb` (score moyen sur deux matières ; une matière inchangée) · `test/infrastructure/queries/classroom/teacher_follow_ups_query_test.rb` · `test/controllers/catalog/courses_controller_test.rb` · `test/controllers/classroom/teacher_homes_controller_test.rb`
- **Done quand**   : l'enseignant de PC et SVT voit ses deux matières groupées dans le catalogue, le filtre limité à elles sur ordinateur, deux badges sur l'accueil, des bulles génériques vers ses deux matières ; l'enseignant d'une matière voit exactement l'écran d'avant ; captures 390 px et ordinateur (catalogue, accueil), pour une et pour deux matières

## Lot C — Page de classe (UDR-0127 §3.1 à §3.3)

- **Couche**       : infrastructure (query) + ui
- **Fichiers**     : `app/infrastructure/queries/classroom/classroom_overview_query.rb` *(`#courses` : `material_ids`, rang de la matière, `material_slug`)*
                     `app/views/classroom/classrooms/_courses.html.erb` *(une bande par matière)*
                     `app/views/classroom/classrooms/_gaps.html.erb` *(badge de matière ; seulement si `remediation-ciblee` l'a livré, sinon reporté à ce chantier-là)*
                     `config/locales/classroom/classrooms.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/classroom/classroom_overview_query_test.rb` (deux matières, deux enseignants d'une classe, équipe toutes matières) · `test/controllers/classroom/classrooms_controller_test.rb` · `test/infrastructure/queries/assessment/classroom_gaps_query_test.rb` (cas « seconde matière de l'enseignant », s'il existe)
- **Done quand**   : sur la page de sa 3ème 2, l'enseignant de PC et SVT voit deux bandes et assigne un exercice de SVT ; l'enseignant de Maths de la même classe ne voit que la bande Maths et voit l'assignation SVT dans « Exercices assignés » ; captures 390 px et ordinateur

## Lot D — Signature, direction, équipe (UDR-0127 §3.4 à §3.6)

- **Couche**       : infrastructure (queries) + ui
- **Fichiers**     : `app/infrastructure/queries/communication/inbox_query.rb` · `app/helpers/communication/messages_helper.rb`
                     `app/infrastructure/queries/school/school_teachers_query.rb` · `app/infrastructure/queries/school/departed_teachers_query.rb` · `app/infrastructure/queries/school/join_requests_query.rb` · `app/infrastructure/queries/school/school_detail_query.rb`
                     `app/infrastructure/queries/catalog/materials_query.rb` *(compte par `teacher_materials`)*
                     `app/views/school_admin/teachers/index.html.erb` · `app/views/school_admin/departed_teachers/index.html.erb` · `app/views/teams/schools/show.html.erb` · `app/views/teams/schools/_join_requests.html.erb` · `app/views/classroom/teacher_homes/_pending_colleagues.html.erb`
                     `config/locales/school_admin/teachers.fr.yml` *(« Matières »)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/communication/inbox_query_test.rb` · `test/helpers/communication/messages_helper_test.rb` (une, deux matières, anonymisé) · `test/infrastructure/queries/school/school_teachers_query_test.rb` (`assert_queries_count` constant à 1 et 30) · `departed_teachers_query_test.rb` · `join_requests_query_test.rb` · `school_detail_query_test.rb` · `test/infrastructure/queries/catalog/materials_query_test.rb`
- **Done quand**   : « M. Kouassi · PC, SVT » sur l'annonce lue par un élève ; la direction voit deux badges dans « Enseignants » ; l'équipe compte l'enseignant dans les deux matières ; captures 390 px et ordinateur de « Enseignants » et d'une annonce

## Lot Z — Contraction (ADR-0103 §4.6, temps 2)

- **Couche**       : infrastructure
- **Fichiers**     : `db/migrate/2026101…_remove_material_id_from_teacher_profiles.rb` *(réversible : `down` rajoute la colonne nullable, remplie avec la première matière)* · `db/schema.rb`
                     `app/infrastructure/orm/teacher_profile.rb` · `app/infrastructure/orm/material.rb` *(retire `teacher_profiles`)*
                     `app/infrastructure/repositories/identity/teacher_profile_repository.rb` · `app/infrastructure/repositories/identity/registration_repository.rb` *(fin de l'écriture double)*
                     `app/infrastructure/repositories/catalog/taxonomy_repository.rb` *(ne lit plus `TeacherProfile.material_id`)*
                     `test/db/schema_constraints_test.rb` · `test/infrastructure/orm/models_test.rb` · `test/support/factories/identity.rb` · `db/seeds/development.rb` · `db/seeds/demo/saint_michel.rb`
- **Dépend de**    : Lots A, B, C, D
- **Test associé** : suite complète ; la commande de l'ADR-0103 §7 (`grep` sans résultat)
- **Done quand**   : `teacher_profiles` n'a plus `material_id` ; aucune lecture ni écriture ne la cite ; `bin/rails db:rollback` puis `db:migrate` repasse proprement

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/identity.rb` | Lot 0 |
| `app/helpers/components_helper.rb` | Lot 0 |
| `app/infrastructure/queries/identity/teacher_materials_query.rb` | Lot 0 |
| `app/domain/use_cases/identity/register_teacher.rb` · `teacher_registration_input.rb` | Lot 0 |
| `app/infrastructure/repositories/catalog/taxonomy_repository.rb` | Lot 0 (puis Lot Z, séquentiel) |
| `app/infrastructure/repositories/identity/*` · `app/infrastructure/orm/*` · `db/schema.rb` · seeds · factories | Lot 0 (puis Lot Z, séquentiel) |
| `config/locales/identity/*.fr.yml` · `profile_query.rb` · `shell_user_query.rb` · vues `identity/` | Lot A |
| `config/locales/catalog/courses.fr.yml` · `config/locales/classroom/teacher_homes.fr.yml` · `teacher_homes/show`, `_course_levels`, `_follow_ups` | Lot B |
| `app/views/classroom/teacher_homes/_pending_colleagues.html.erb` | Lot D (n'utilise aucune clé nouvelle de `teacher_homes.fr.yml`) |
| `config/locales/classroom/classrooms.fr.yml` · `classroom_overview_query.rb` · `classrooms/_courses`, `_gaps` | Lot C |
| `config/locales/school_admin/teachers.fr.yml` · queries `school/*` · `inbox_query.rb` · `materials_query.rb` | Lot D |

Aucun fichier n'est listé par deux lots parallèles (A, B, C, D).

## Articulation avec `multi-etablissements-enseignant`

Les deux chantiers réécrivent les mêmes lectures de l'enseignant. **Leurs lots ne tournent jamais en même temps sur ces fichiers** :

| Fichier | `multi-etablissements-enseignant` | ce chantier |
|---|---|---|
| `teacher_home_query.rb` · `teacher_follow_ups_query.rb` · `teacher_audience_query.rb` · `catalog/courses_controller.rb` · `teacher_homes/show.html.erb` · `config/locales/classroom/teacher_homes.fr.yml` | Lot A | Lot B |
| `shell_user_query.rb` · `profile_query.rb` | Lot A | Lot A |
| `departed_teachers_query.rb` | Lot C | Lot D |
| `identity/teacher_registrations_controller.rb` · `config/locales/identity/teacher_registrations.fr.yml` | Lot B | Lot A |

Règle : le chantier lancé en premier termine ces lots et fusionne ; l'autre rebase sa branche avant de lancer les siens. Les autres lots des deux chantiers (Lot 0, Lots C et D chez eux, Lots C et Z ici) sont disjoints et peuvent tourner en même temps. **Recommandation** : lancer d'abord le chantier dont le porteur répond en premier aux questions ; à réponses égales, `multi-etablissements-enseignant` (son Lot A introduit l'établissement courant, que ce chantier n'a pas à connaître).

## Portes de sortie

- [ ] Tous les lots sont `Done`, Lot Z compris
- [ ] Le nombre de lignes `teacher_materials` après migration égale celui de `teacher_profiles` (relevé avant le Lot 0)
- [ ] Un rôle distinct de l'auteur a **exécuté** le résultat : inscription avec deux matières, ajout au profil, catalogue, page de classe, annonce, « Enseignants » ; et un enseignant d'une seule matière ne voit **aucun** changement
- [ ] Captures 390 px et ordinateur de chaque écran modifié envoyées au porteur (jamais commitées)
- [ ] Pureté du domaine, rubocop, tests, parcours système : au vert ; `bin/ci-quiet` écrit dans la PR
- [ ] Sous-agents de revue (`security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`) sur le diff final : une policy, un use case et une route sont touchés
- [ ] ADR-0103 et UDR-0125 à 0127 à « Accepté », index régénérés par `script/docs/build_index` au commit de clôture ; amendements reportés dans les ADR et UDR amendés (ADR-0083, ADR-0101 §4.4, UDR-0026, 0027, 0041, 0052, 0062, 0069, 0071, 0077, 0079, 0100, 0121)
- [ ] `journal.md` complété
