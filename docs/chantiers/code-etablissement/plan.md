# Plan d'exécution — Code d'établissement pour l'inscription des enseignants

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot 0 — SOCLE : migration, entité SchoolCode, port SchoolRepositoryPort, repository, import, fabriques et seeds
  ↓
  ├─► Lot A « l'enseignant s'inscrit par le code ou le lien »   ┐ fichiers disjoints ;
  └─► Lot B « l'équipe lit, copie et régénère le code »          ┘ routes et locales partagées au Lot 0
```

Exécuté par un seul agent, dans l'ordre 0 → A → B : les lots A et B sont parallélisables, mais tiennent chacun en quelques fichiers.

---

## Lot 0 — Socle : tout établissement a un code unique

- **Couche**       : domaine + infrastructure
- **Fichiers**     : `db/migrate/20260928110000_add_school_codes.rb` · `db/schema.rb`
                     `app/domain/entities/school/school_code.rb` · `app/domain/entities/school/school.rb`
                     `app/domain/ports/school/school_repository_port.rb`
                     `app/infrastructure/repositories/school/school_repository.rb`
                     `app/domain/use_cases/school/import_schools.rb`
                     `db/seeds/school.rb` · `test/support/factories/school.rb`
                     `config/routes/identity.rb` · `config/routes/teams.rb`
                     `config/locales/identity/teacher_registrations.fr.yml` · `config/locales/teams/schools.fr.yml`
                     `docs/guide/glossaire.md`
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/school/school_code_test.rb` · `test/db/add_school_codes_migration_test.rb`
                     `test/db/schema_constraints_test.rb` · `test/infrastructure/repositories/school/school_repository_test.rb`
                     `test/domain/use_cases/school/import_schools_test.rb` · `test/routing/v1_routes_test.rb`
- **Done quand**   : chaque établissement, existant ou importé, a un code valide et unique ; la base refuse l'absence, le doublon et le mauvais format (CE-09, CE-10)

## Lot A — L'enseignant s'inscrit par le code d'établissement ou par le lien

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/dtos/identity/teacher_registration_input.rb` · `app/domain/use_cases/identity/register_teacher.rb`
                     `app/infrastructure/queries/school/school_code_preview_query.rb`
                     `app/controllers/identity/teacher_registrations_controller.rb`
                     `app/views/identity/teacher_registrations/{new,_form,_school_preview}.html.erb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/dtos/identity/teacher_registration_input_test.rb` · `test/domain/use_cases/identity/register_teacher_test.rb`
                     `test/infrastructure/queries/school/school_code_preview_query_test.rb`
                     `test/controllers/identity/teacher_registrations_controller_test.rb`
                     `test/system/identity/teacher_signup_test.rb` · `test/system/boucle_pedagogique_test.rb`
- **Done quand**   : un visiteur s'inscrit avec le code saisi ou le lien `/e/<code>` ; tout code refusé reçoit le même message ; `/e/` est limité en débit (CE-01 à CE-05)

## Lot B — L'équipe lit, copie et régénère le code

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/school/regenerate_school_code.rb`
                     `app/infrastructure/queries/school/{school_detail_query,schools_query}.rb`
                     `app/controllers/teams/school_codes_controller.rb`
                     `app/views/teams/schools/_header.html.erb` · `app/views/teams/school_codes/update.turbo_stream.erb`
                     `app/javascript/controllers/classroom/join_code_copy_controller.js` *(en-tête seulement)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/school/regenerate_school_code_test.rb`
                     `test/controllers/teams/school_codes_controller_test.rb` · `test/controllers/teams/schools_controller_test.rb`
                     `test/system/teams/school_code_test.rb`
- **Done quand**   : la fiche montre le code, le copie avec son lien, et le régénère depuis le menu ⋮ après confirmation ; un non-membre reçoit 403 (CE-06 à CE-08)

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/identity.rb`, `config/routes/teams.rb` | Lot 0 |
| `config/locales/identity/teacher_registrations.fr.yml`, `config/locales/teams/schools.fr.yml` | Lot 0 |
| `app/domain/ports/school/school_repository_port.rb`, `app/infrastructure/repositories/school/school_repository.rb` | Lot 0 |
| `db/schema.rb`, fabriques, seeds | Lot 0 |

Aucun fichier listé par deux lots.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR-0057 écrit et indexé ; amendement ADR-0030
- [x] UDR-0044 écrite et indexée ; amendements UDR-0024 et UDR-0036
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur *(à faire par le challenger, sur la PR)*
- [x] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop` *(ouverte par le coordinateur)*
- [x] `journal.md` complété
