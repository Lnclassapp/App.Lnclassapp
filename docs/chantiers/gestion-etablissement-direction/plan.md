# Plan d'exécution — La direction gère son établissement

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Entrées : [`prd.md`](prd.md) (28 critères GD-01 à GD-28), [ADR-0071](../../decisions/adr/0071-gestes-de-la-direction-sur-son-etablissement.md), [UDR-0056](../../decisions/udr/0056-gestes-de-la-direction.md).

## Préalables au Lot 0

- [x] ADR-0071 et UDR-0056 passés de `Proposé` à `Accepté` par le porteur le 2026-10-01 ; points à confirmer de l'ADR-0071 §9 tranchés le même jour (le lien d'invitation ajouté au retour par code : GD-28, Lot D).

## Graphe

```
Lot 0 — SOCLE (séquentiel)
  migration · entité · ports gelés et leurs adaptateurs · 3 policies · routes · navigation
  page « Établissement » (lien en lecture, bloc des classes partagé) · fabriques
  ↓
  ├─► Lot A « Changer le lien »                         ┐
  ├─► Lot B « + et − sur un niveau »                    ├─ en parallèle, fichiers disjoints
  ├─► Lot C « Retirer un enseignant »                   │
  └─► Lot D « Enseignants retirés, réintégrer, rejoindre par code » ┘
```

**Règles gelées.**
1. Les lots A à D **implémentent** les contrats du Lot 0 ; aucun ne change un port, une entité, une policy, une route, la navigation ou une fabrique. Un lot qui en a besoin **s'arrête** : le Lot 0 rouvre.
2. Aucun lot vertical n'ajoute de fabrique dans `test/support/factories/` : ses aides vivent dans son fichier de test.
3. Aucun lot vertical n'écrit dans `docs/` : il remonte ses notes au porteur du chantier, qui tient `journal.md`.
4. **Leçon d'`espace-direction` (challenge 1)** : chaque méthode de port ajoutée a son adaptateur **dans le Lot 0**, sinon le test d'architecture des contrats de ports casse ; avant de toucher un `Data.define`, chercher ses appelants.

---

## Lot 0 — Socle

- **Couche**       : infrastructure (migration, `Orm::`, adaptateurs) + domaine (entité, ports, policies) + delivery + ui (page squelette, navigation)
- **Fichiers**     : db/migrate/20261001090000_create_teacher_school_departures.rb
                     db/schema.rb
                     app/infrastructure/orm/teacher_school_departure.rb
                     app/domain/entities/school/teacher_departure.rb
                     app/domain/entities/identity/audit_action.rb
                     app/domain/ports/school/teacher_departure_repository_port.rb
                     app/domain/ports/school/school_repository_port.rb
                     app/domain/ports/classroom/teaching_repository_port.rb
                     app/domain/ports/classroom/assignment_repository_port.rb
                     app/infrastructure/repositories/school/teacher_departure_repository.rb
                     app/infrastructure/repositories/school/school_repository.rb
                     app/infrastructure/repositories/classroom/teaching_repository.rb
                     app/infrastructure/repositories/classroom/assignment_repository.rb
                     app/domain/policies/school/manage_school_structure_policy.rb
                     app/domain/policies/school/manage_school_teachers_policy.rb
                     app/domain/policies/school/join_school_with_code_policy.rb
                     app/infrastructure/queries/school/own_school_query.rb
                     config/routes/school_admin.rb
                     config/routes/identity.rb
                     app/helpers/navigation_helper.rb
                     config/locales/shared/navigation.fr.yml
                     config/locales/school_admin/shared.fr.yml
                     config/locales/school_admin/schools.fr.yml
                     app/controllers/school_admin/schools_controller.rb
                     app/views/school_admin/schools/show.html.erb
                     app/views/school_admin/schools/_link.html.erb
                     app/views/shared/_level_classrooms.html.erb
                     app/views/teams/schools/_level_classrooms.html.erb (supprimé : remplacé par le partiel partagé)
                     app/views/teams/schools/show.html.erb
                     app/views/teams/schools/update.turbo_stream.erb
                     app/views/teams/schools/deactivate.turbo_stream.erb
                     app/views/teams/level_classrooms/update.turbo_stream.erb
                     test/support/factories/school.rb
- **Dépend de**    : — (préalables acceptés)
- **Test associé** : test/db/schema_constraints_test.rb (`teacher_school_departures` : un départ ouvert par couple, `reinstated_*` ensemble, clés `RESTRICT`)
                     test/domain/entities/school/teacher_departure_test.rb
                     test/domain/entities/identity/audit_action_test.rb (`teacher.detached`, `teacher.reinstated`)
                     test/domain/policies/school/manage_school_structure_policy_test.rb
                     test/domain/policies/school/manage_school_teachers_policy_test.rb
                     test/domain/policies/school/join_school_with_code_policy_test.rb
                     test/infrastructure/repositories/school/teacher_departure_repository_test.rb
                     test/infrastructure/repositories/school/school_repository_test.rb (`detach_teacher` ne touche pas un autre établissement)
                     test/infrastructure/repositories/classroom/teaching_repository_test.rb (`withdraw_all_in_school`)
                     test/infrastructure/repositories/classroom/assignment_repository_test.rb (`archive_all_by_teacher_in_school` : actifs seulement, cet établissement seulement)
                     test/infrastructure/queries/school/own_school_query_test.rb
                     test/controllers/school_admin/schools_controller_test.rb (GD-01, GD-02, GD-03 : lien, copie, WhatsApp ; 403 aux autres rôles)
                     test/helpers/navigation_helper_test.rb (trois destinations)
                     test/controllers/teams/schools_controller_test.rb (la fiche rend le bloc partagé, inchangé)
                     test/system/school_admin/school_test.rb (GD-01, GD-03 en bureau et à 390 px)
                     test/architecture/port_contracts_test.rb (existant, vert)
- **Done quand**   : `bin/rails db:migrate`, `db:rollback`, `db:migrate` passent ; une direction connectée voit trois entrées de navigation, ouvre « Établissement » et lit son lien, le copie et l'ouvre dans WhatsApp ; le bloc « Classes par niveau » s'affiche (ses boutons répondent par une erreur de routage tant que le Lot B n'est pas fusionné) ; la fiche d'un établissement côté équipe est inchangée ; `bin/ci` au vert

Le partiel `shared/_level_classrooms` est l'ancien `teams/schools/_level_classrooms` déplacé à l'identique, avec `add_url:` et `remove_url:` (UDR-0056 §3.2) : comportement de l'équipe inchangé, ses tests existants doivent passer sans modification. `school_admin/shared.fr.yml` porte les refus communs (`forbidden`, `not_found`). La fabrique `create_teacher_departure(teacher:, school:, detached_by:, reinstated: false)` sert à C et D.

---

## Lot A — Changer le lien

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : app/domain/use_cases/school/regenerate_school_code.rb
                     app/controllers/teams/school_codes_controller.rb
                     app/controllers/school_admin/school_links_controller.rb
                     app/views/school_admin/schools/_link.html.erb
                     app/views/school_admin/school_links/update.turbo_stream.erb
                     config/locales/school_admin/school_links.fr.yml
- **Dépend de**    : Lot 0
- **Test associé** : test/domain/use_cases/school/regenerate_school_code_test.rb (GD-04, GD-06 : direction de A sur A acceptée, sur B refusée ; inactif refusé ; équipe inchangée)
                     test/controllers/school_admin/school_links_controller_test.rb (GD-04, GD-07 : 403 sur établissement inactif ; 403 aux autres rôles)
                     test/controllers/teams/school_codes_controller_test.rb (GD-05)
                     test/system/school_admin/school_link_test.rb (GD-04 : changement confirmé, ancien `/e/` refusé, à 390 px)
- **Done quand**   : la direction change le lien après confirmation, le nouveau s'affiche sans rechargement et l'ancien lien affiche « Code d'établissement invalide » ; une direction d'établissement inactif ne voit pas le bouton ; l'équipe régénère toujours depuis la fiche

`_link.html.erb` passe du Lot 0 (lecture) au Lot A (modale « Changer le lien ») : jamais en parallèle.

---

## Lot B — « + » et « − » sur un niveau

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : app/domain/use_cases/classroom/add_level_classroom.rb
                     app/domain/use_cases/classroom/remove_level_classroom.rb
                     app/controllers/teams/level_classrooms_controller.rb
                     app/controllers/school_admin/level_classrooms_controller.rb
                     app/views/school_admin/level_classrooms/update.turbo_stream.erb
- **Dépend de**    : Lot 0
- **Test associé** : test/domain/use_cases/classroom/add_level_classroom_test.rb (GD-08, GD-11, GD-12)
                     test/domain/use_cases/classroom/remove_level_classroom_test.rb (GD-09, GD-10, GD-11)
                     test/controllers/school_admin/level_classrooms_controller_test.rb (GD-08 à GD-12 : streams, motifs, 403 inactif, 404 classe de B)
                     test/controllers/teams/level_classrooms_controller_test.rb (GD-13)
                     test/system/school_admin/level_classrooms_test.rb (GD-08, GD-09 à 390 px)
- **Done quand**   : la direction ajoute « 6ème 5 » par le « + » et la retire par le « − » sans rechargement ; une classe qui a servi est refusée avec le motif ; l'équipe garde ses deux gestes sur la fiche

---

## Lot C — Retirer un enseignant

- **Couche**       : domaine + infrastructure (query) + delivery + ui
- **Fichiers**     : app/domain/use_cases/school/detach_teacher.rb
                     app/infrastructure/queries/school/school_teachers_query.rb
                     app/controllers/school_admin/teachers_controller.rb
                     app/views/school_admin/teachers/index.html.erb
                     app/views/school_admin/teachers/destroy.turbo_stream.erb
                     config/locales/school_admin/teachers.fr.yml
- **Dépend de**    : Lot 0
- **Test associé** : test/domain/use_cases/school/detach_teacher_test.rb (GD-14, GD-15, GD-16, GD-17, GD-18)
                     test/infrastructure/queries/school/school_teachers_query_test.rb (`public_id` par ligne, nombre de requêtes inchangé)
                     test/controllers/school_admin/teachers_controller_test.rb (GD-14, GD-16 : 404 enseignant de B ; GD-17 : 403 inactif, menu absent, 403 équipe ; GD-18)
                     test/system/school_admin/teachers_test.rb (GD-14 : retrait confirmé, ligne retirée sans rechargement, à 390 px)
- **Done quand**   : la direction retire un enseignant après confirmation ; sa ligne disparaît, le toast dit combien de devoirs ont été archivés ; à sa requête suivante, l'enseignant arrive sur l'écran d'attente ; ses classes, élèves et résultats sont intacts

Le bouton « Enseignants retirés » de l'en-tête (UDR-0056 §3.3) mène à la route du Lot D : erreur de routage tant que D n'est pas fusionné. Le test `teachers_controller_test` existant (DS-06, DS-10, DS-11) change : `tr#teacher_<index>` devient `tr#teacher_<public_id>`.

---

## Lot D — Enseignants retirés, réintégrer, rejoindre par code

- **Couche**       : domaine + infrastructure (query) + delivery + ui
- **Fichiers**     : app/domain/use_cases/school/reinstate_teacher.rb
                     app/domain/use_cases/school/join_school_with_code.rb
                     app/domain/dtos/school/school_join_input.rb
                     app/infrastructure/queries/school/departed_teachers_query.rb
                     app/controllers/school_admin/departed_teachers_controller.rb
                     app/controllers/school_admin/teacher_reinstatements_controller.rb
                     app/controllers/identity/pending_school_joins_controller.rb
                     app/controllers/identity/pending_accounts_controller.rb
                     app/controllers/identity/teacher_registrations_controller.rb
                     app/views/school_admin/departed_teachers/index.html.erb
                     app/views/school_admin/teacher_reinstatements/create.turbo_stream.erb
                     app/views/identity/pending_accounts/show.html.erb
                     config/locales/school_admin/departed_teachers.fr.yml
                     config/locales/school_admin/teacher_reinstatements.fr.yml
                     config/locales/identity/pending_accounts.fr.yml
                     config/locales/identity/pending_school_joins.fr.yml
- **Dépend de**    : Lot 0
- **Test associé** : test/domain/use_cases/school/reinstate_teacher_test.rb (GD-19, GD-20)
                     test/domain/use_cases/school/join_school_with_code_test.rb (GD-23, GD-24, GD-26, GD-27)
                     test/domain/dtos/school/school_join_input_test.rb (normalisation du code)
                     test/infrastructure/queries/school/departed_teachers_query_test.rb (GD-21 ; nombre de requêtes fixe)
                     test/controllers/school_admin/departed_teachers_controller_test.rb (GD-21 : liste, état vide, 403 aux autres rôles)
                     test/controllers/school_admin/teacher_reinstatements_controller_test.rb (GD-19, GD-20 : 404 enseignant de B, 403 inactif)
                     test/controllers/identity/pending_school_joins_controller_test.rb (GD-23, GD-24, GD-25 : 429, GD-26 : 403)
                     test/controllers/identity/pending_accounts_controller_test.rb (GD-22 : formulaire pour l'enseignant sans établissement ; absent pour une demande en attente ; GD-28 : code pré-rempli)
                     test/controllers/identity/teacher_registrations_controller_test.rb (GD-28 : `/e/<code>` ouvert par un enseignant connecté sans établissement → écran d'attente pré-rempli ; autres comptes connectés → leur accueil, inchangé)
                     test/system/school_admin/departed_teachers_test.rb (GD-19 puis GD-23, à 390 px ; les départs sont créés par la fabrique du Lot 0)
- **Done quand**   : la direction voit ses enseignants retirés et en réintègre un ; un enseignant retiré saisit le code d'un autre établissement depuis l'écran d'attente et arrive sur le choix de ses classes ; le code de l'établissement qui l'a retiré est refusé avec le message d'un code invalide

D ne dépend pas de C dans les fichiers : ses tests créent les départs par la fabrique `create_teacher_departure` (Lot 0). La démonstration complète (retirer → réintégrer) suit la fusion de C.

---

## Rattachement des critères aux lots

| Lot | Critères |
|---|---|
| 0 | GD-01, GD-02, GD-03 |
| A | GD-04, GD-05, GD-06, GD-07 |
| B | GD-08, GD-09, GD-10, GD-11, GD-12, GD-13 |
| C | GD-14, GD-15, GD-16, GD-17, GD-18 |
| D | GD-19, GD-20, GD-21, GD-22, GD-23, GD-24, GD-25, GD-26, GD-27, GD-28 |

Aucun critère orphelin : GD-01 à GD-28, chacun rattaché à un lot et à au moins un fichier de test.

---

## Vérification de collision

> Contrôle mécanique, avant de lancer les lots parallèles :
> `awk '/^## Vérification de collision/{exit} 1' docs/chantiers/gestion-etablissement-direction/plan.md | grep -oE '(app|test|config|db|lib)/[A-Za-z0-9_/.-]+\.(rb|erb|yml|js)' | sort | uniq -d`
> Sortie attendue : **`app/views/school_admin/schools/_link.html.erb` seulement** (Lot 0 puis Lot A, jamais en parallèle). Toute autre ligne est une collision.

| Fichier ou répertoire partagé | Lot propriétaire | Pourquoi |
|---|---|---|
| `db/migrate/*`, `db/schema.rb` | Lot 0 | Seule migration du chantier |
| Ports, entité, adaptateurs des nouvelles méthodes | Lot 0 | Contrats gelés, `port_contracts_test` vert dès le socle |
| Les trois policies | Lot 0 | `ManageSchoolStructurePolicy` lue par A et B ; `ManageSchoolTeachersPolicy` par C et D ; `JoinSchoolWithCodePolicy` par D |
| `config/routes/school_admin.rb`, `config/routes/identity.rb` | Lot 0 | Toutes les routes de l'UDR-0056 §3.0 |
| `app/helpers/navigation_helper.rb`, `config/locales/shared/navigation.fr.yml` | Lot 0 | Troisième destination |
| `config/locales/school_admin/shared.fr.yml` | Lot 0 | Refus communs |
| `app/views/school_admin/schools/show.html.erb`, `shared/_level_classrooms.html.erb`, vues `teams/schools/*` et `teams/level_classrooms/*` | Lot 0 | La page est commune à A et B ; le partiel est partagé avec l'équipe |
| `app/views/school_admin/schools/_link.html.erb` | Lot 0, puis Lot A | Lecture au socle, modale « Changer le lien » en A |
| `app/infrastructure/repositories/school/school_repository.rb` | Lot 0 | Lu par A (`replace_school_code`) et D (`attach_teacher`), modifié au socle seulement |
| `test/support/factories/school.rb` | Lot 0 | `create_teacher_departure` |
| `config/locales/teams/level_classrooms.fr.yml` | aucun | Clés lues par le partiel partagé, inchangées |
| `app/views/identity/pending_accounts/show.html.erb`, `app/controllers/identity/pending_accounts_controller.rb`, `config/locales/identity/pending_accounts.fr.yml` | Lot D | Seul lot qui change l'écran d'attente |
| `app/views/layouts/*` | aucun | Le shell n'est pas modifié |
| `docs/chantiers/gestion-etablissement-direction/*` | porteur du chantier | Les lots n'écrivent pas dans `docs/` |

---

## Dispatch

```
Vague 1 : Lot 0                   → 1 agent, séquentiel
Vague 2 : Lot A ‖ B ‖ C ‖ D       → 4 agents, worktrees isolés (après fusion du Lot 0)
```

Chaque lot parallèle part de la branche de chantier, Lot 0 fusionné :

```bash
git worktree add ../lnclass-gestion-etablissement-direction-lot-a -b feature/gestion-etablissement-direction-lot-a feature/gestion-etablissement-direction
```

Brief de chaque agent : chemin **absolu** du worktree (`git -C <worktree>`), son lot recopié en entier (4 champs), les liens vers `prd.md`, l'ADR-0071 et l'UDR-0056, l'ordre intra-lot (test rouge → domaine → infrastructure → delivery → UI), l'**interdiction de toucher un fichier hors de son champ `Fichiers`**. Fusion dans `feature/gestion-etablissement-direction` au fur et à mesure ; **une seule PR** vers `Develop`.

Ordre de fusion conseillé (démonstration, pas fichiers) : A et B, puis C, puis D.

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

- [x] ADR-0071 et UDR-0056 `Accepté` (préalables, 2026-10-01)
- [ ] Chaque geste a son test de refus inter-établissements et son refus sur établissement inactif (PRD §4)
- [ ] Les tests existants de la fiche de l'équipe (« + », « − », code) passent sans modification après le déplacement du partiel

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Pour ce chantier, il rejoue au minimum, à 390 px : la direction partage puis change le lien, et l'ancien lien est refusé ; « + » puis « − » ; le retrait d'un enseignant (devoirs archivés, écran d'attente) puis son essai avec le code de l'établissement qui l'a retiré (refusé), puis le code d'un autre (accepté) ; une réintégration ; **un refus inter-établissements forgé à la main** (DELETE d'un enseignant de B depuis un compte de A) ; un geste forgé sur un établissement inactif.
