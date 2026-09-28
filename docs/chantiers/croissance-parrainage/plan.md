# Plan d'exécution — Croissance par parrainage, démarrage à froid et mesure du k-factor

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot 0 — SOCLE : migrations, entités, ports, Orm, routes, locales partagées
  ↓
  Lot 1 « attribution du parrainage » (jeton, filleul, partage compté)
  ↓
  ├─► Lot 2 « inviter un collègue »      (bloc, page, compteur)          ┐
  ├─► Lot 3 « partager sa classe »       (WhatsApp du lien de classe)    ├ fichiers disjoints
  └─► Lot 4 « code national et démarrage à froid » (import, fiche, attente, validation, garant)
        ↓
        Lot 5 « leviers sans argent » (badge, classement)
        ↓
        Lot 6 « mesure » (GrowthMetricsQuery, /teams/growth)
```

Exécuté par un seul agent, dans l'ordre demandé (1 → 6) ; le Lot 0 est livré avec le Lot 1 (un commit), puisque ses contrats servent d'abord à l'attribution. Les lots 2, 3 et 4 sont parallélisables ; 5 et 6 lisent les tables de 1 et 4.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats)
- **Fichiers**     : `db/migrate/20260928150000_create_referrals.rb` · `db/migrate/20260928150100_add_national_code_to_schools.rb`
                     `db/migrate/20260928150200_create_school_join_requests.rb` · `db/schema.rb`
                     `app/infrastructure/orm/{referral,referral_share,school_join_request}.rb`
                     `app/domain/ports/identity/referral_repository_port.rb` · `app/domain/ports/school/join_request_repository_port.rb`
                     `app/domain/ports/school/school_repository_port.rb` (national_code, find_by_id)
                     `config/routes/{identity,classroom,teams}.rb` · `config/locales/identity/referrals.fr.yml` · `config/locales/teams/growth.fr.yml`
                     `test/support/factories/growth.rb` · `test/support/factories/identity.rb` (enseignant sans école)
- **Dépend de**    : —
- **Test associé** : `test/db/schema_constraints_test.rb` · `test/db/growth_migrations_test.rb` · `test/routing/v1_routes_test.rb`
- **Done quand**   : les tables et contraintes existent, les données existantes sont intactes, chaque profil enseignant a un jeton distinct

## Lot 1 — Attribution du parrainage

- **Couche**       : domaine + infrastructure + delivery
- **Fichiers**     : `app/domain/entities/identity/{referral_token,share_channel}.rb`
                     `app/domain/policies/identity/invite_colleague_policy.rb`
                     `app/domain/use_cases/identity/{register_teacher,record_referral_share}.rb` · `app/domain/dtos/identity/teacher_registration_input.rb`
                     `app/infrastructure/repositories/identity/referral_repository.rb`
                     `app/controllers/identity/{teacher_registrations,referral_shares}_controller.rb` · `app/views/identity/teacher_registrations/_form.html.erb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/entities/identity/referral_token_test.rb` · `test/domain/use_cases/identity/register_teacher_test.rb`
                     `test/domain/use_cases/identity/record_referral_share_test.rb` · `test/domain/policies/identity/invite_colleague_policy_test.rb`
                     `test/infrastructure/repositories/identity/referral_repository_test.rb`
                     `test/controllers/identity/{teacher_registrations,referral_shares}_controller_test.rb`
- **Done quand**   : une inscription par `/e/<code>?ref=<jeton>` enregistre le parrain ; un jeton étranger est ignoré ; un partage est compté (CP-01 à CP-04)

## Lot 2 — Inviter un collègue

- **Couche**       : delivery + ui
- **Fichiers**     : `app/infrastructure/queries/identity/referral_query.rb` · `app/controllers/identity/referrals_controller.rb`
                     `app/controllers/classroom/teacher_homes_controller.rb` · `app/views/classroom/teacher_homes/show.html.erb`
                     `app/views/identity/referrals/{show,_invite}.html.erb` · `app/views/classroom/teaching_selections/index.html.erb`
                     `app/javascript/controllers/identity/share_controller.js`
- **Dépend de**    : Lot 1
- **Test associé** : `test/infrastructure/queries/identity/referral_query_test.rb` · `test/controllers/identity/referrals_controller_test.rb`
                     `test/controllers/classroom/teacher_homes_controller_test.rb` · `test/system/identity/invite_colleague_test.rb`
- **Done quand**   : l'accueil montre le bloc, WhatsApp / SMS / copier / natif, le compteur ; un établissement non actif n'a pas de bloc (CP-05 à CP-07)

## Lot 3 — Partager sa classe

- **Couche**       : ui
- **Fichiers**     : `app/views/classroom/classrooms/_header.html.erb` · `config/locales/classroom/classrooms.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/classroom/classrooms_controller_test.rb` · `test/system/classroom/classroom_page_test.rb`
- **Done quand**   : la page d'une classe partage `/c/<code>` sur WhatsApp avec un message sans donnée d'élève (CP-08)

## Lot 4 — Code national et démarrage à froid

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/entities/school/{national_code,join_request}.rb` · `app/domain/entities/school/school.rb`
                     `app/domain/dtos/{school/school_input,identity/pending_teacher_registration_input}.rb`
                     `app/domain/use_cases/identity/register_pending_teacher.rb` · `app/domain/use_cases/school/{review_join_request,vouch_for_teacher,update_school,import_schools}.rb`
                     `app/domain/policies/school/vouch_policy.rb`
                     `app/infrastructure/repositories/school/{school_repository,join_request_repository}.rb`
                     `app/infrastructure/queries/school/{join_requests_query,schools_query,school_detail_query}.rb` · `config/schemas/lnclass.schools.v1.json`
                     `app/controllers/concerns/authentication.rb` · `app/controllers/authenticated_controller.rb`
                     `app/controllers/identity/{pending_teacher_registrations,pending_accounts}_controller.rb`
                     `app/controllers/school/join_request_vouches_controller.rb` · `app/controllers/teams/{join_requests,schools}_controller.rb`
                     `app/views/identity/pending_teacher_registrations/new.html.erb` · `app/views/identity/pending_accounts/show.html.erb`
                     `app/views/classroom/teacher_homes/_pending_colleagues.html.erb` · `app/views/teams/schools/{_header,_form,_join_requests,show}.html.erb`
                     `app/views/teams/imports/kinds/_schools.html.erb`
- **Dépend de**    : Lot 1
- **Test associé** : `test/domain/entities/school/national_code_test.rb` · `test/domain/use_cases/identity/register_pending_teacher_test.rb`
                     `test/domain/use_cases/school/{review_join_request,vouch_for_teacher,import_schools,update_school}_test.rb`
                     `test/infrastructure/repositories/school/join_request_repository_test.rb`
                     `test/controllers/identity/pending_teacher_registrations_controller_test.rb` · `test/controllers/teams/join_requests_controller_test.rb`
                     `test/controllers/school/join_request_vouches_controller_test.rb` · `test/system/identity/cold_start_test.rb`
- **Done quand**   : inscription par code national → attente → validation par l'équipe ou par un garant ; import et fiche portent le code national (CP-09 à CP-14)

## Lot 5 — Leviers sans argent

- **Couche**       : domaine + ui
- **Fichiers**     : `app/domain/entities/identity/ambassador.rb` · `app/controllers/identity/profiles_controller.rb` · `app/views/identity/profiles/show.html.erb`
- **Dépend de**    : Lot 2
- **Test associé** : `test/domain/entities/identity/ambassador_test.rb` · `test/controllers/identity/profiles_controller_test.rb`
- **Done quand**   : badge à 3 filleuls sur le profil (CP-15) ; le classement est livré au Lot 6 (CP-16)

## Lot 6 — Mesure

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/entities/identity/viral_coefficient.rb` · `app/domain/policies/identity/read_growth_policy.rb`
                     `app/infrastructure/queries/identity/growth_metrics_query.rb`
                     `app/controllers/teams/growth_controller.rb` · `app/views/teams/growth/show.html.erb` · `app/views/teams/homes/_shortcuts.html.erb`
- **Dépend de**    : Lots 1 et 4
- **Test associé** : `test/domain/entities/identity/viral_coefficient_test.rb` · `test/infrastructure/queries/identity/growth_metrics_query_test.rb`
                     `test/controllers/teams/growth_controller_test.rb` · `test/system/teams/growth_test.rb`
- **Done quand**   : `/teams/growth` affiche k, i, c, cycle, parrains, classement, attente ; 403 aux autres rôles (CP-16 à CP-18)

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/*.rb`, locales partagées, `db/schema.rb`, fabriques | Lot 0 |
| `app/domain/ports/**` | Lot 0 |
| `app/views/classroom/teacher_homes/show.html.erb` | Lot 2 (le Lot 4 n'ajoute qu'un partiel, rendu par le Lot 2) |
| `app/views/identity/teacher_registrations/_form.html.erb` | Lot 1 (le lien « sans code » du Lot 4 y est posé au Lot 1) |

Aucun fichier listé par deux lots parallèles.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md` (ADR-0063)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md` (UDR-0050)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur *(challenger, sur la PR)*
- [x] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR *(ouverte par le coordinateur, après la PR #49)*
- [x] `journal.md` clos (dérapages, dette, chantiers de suivi)
