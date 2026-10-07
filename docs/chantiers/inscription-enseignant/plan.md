# Plan d'exécution — Amélioration du parcours d'inscription des enseignants

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Specs : [`prd.md`](prd.md) · [ADR-0082](../../decisions/adr/0082-inscription-enseignant-en-deux-voies.md) · [UDR-0078](../../decisions/udr/0078-inscription-enseignant-en-deux-voies.md)

## Graphe

```
Lot 0 — SOCLE (séquentiel) : migration, entités, ports, routes ajoutées, frame DRENA paramétré
  ↓
  ├─► Lot A « s'inscrire : voie standard et lien d'invitation »   ┐
  ├─► Lot B « partager un lien d'invitation, lire la voie »       ├─ en parallèle, worktrees isolés
  └─► Lot C « rejoindre un établissement depuis l'écran d'attente »┘
  ↓
Lot D — RETRAIT de l'ancienne voie + parcours de bout en bout (séquentiel, après A, B, C)
```

Pourquoi un Lot D : retirer `/e/:code`, `/teacher-signup/without-code` et « Changer le lien » casse les vues que A, B et C réécrivent. Le retrait des routes, des contrôleurs et des use cases morts vient donc **après** eux, en une fois, avec les tests système qui traversent plusieurs lots. Ainsi l'application reste verte à chaque merge.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + fichiers partagés
- **Fichiers**     : `db/migrate/20261007100000_add_teacher_arrival_and_school_invite_tokens.rb`
                     `db/schema.rb`
                     `app/domain/entities/identity/full_name.rb`
                     `app/domain/entities/identity/arrival_channel.rb`
                     `app/domain/ports/identity/invite_link_repository_port.rb`
                     `app/domain/ports/identity/registration_repository_port.rb` *(`create_teacher(user:, pin:, material_id:, joined_via:)`)*
                     `app/infrastructure/repositories/identity/registration_repository.rb`
                     `app/domain/use_cases/identity/register_teacher.rb` *(une ligne : `joined_via: "code"`, réécrit ensuite par le Lot A)*
                     `app/domain/use_cases/identity/register_pending_teacher.rb` *(une ligne : `joined_via: "standard"`, supprimé ensuite par le Lot D)*
                     `app/views/school/drena_schools/index.html.erb` *(local `scope`, `:teacher_registration` par défaut ; partagé par A et C)*
                     `app/helpers/components_helper.rb` · `app/views/components/_subject_bubble.html.erb` *(option `link_html:` de `ui_subject_bubble`, vide par défaut)*
                     `config/routes/identity.rb` *(ajout seulement : `get "i/:token", to: "identity/teacher_registrations#invite", as: :teacher_invite_link`)*
                     `test/support/factories/identity.rb` *(`create_teacher` accepte `joined_via:`)*
                     `test/domain/use_cases/identity/register_teacher_test.rb` · `test/domain/use_cases/identity/register_pending_teacher_test.rb` *(faux dépôts : `create_teacher` accepte `joined_via:` ; ajout du 2026-10-07, découvert par l'exécutant du Lot 0)*
                     `test/infrastructure/orm/models_test.rb` · `db/seeds/development.rb` · `db/seeds/demo/saint_michel.rb` *(écritures de `teacher_profiles` : `joined_via: "standard"` ; même ajout)*
                     `test/infrastructure/repositories/identity/registration_repository_test.rb` *(`joined_via:` écrit ; même ajout)*
                     `app/infrastructure/repositories/identity/invite_link_repository.rb` · `test/infrastructure/repositories/identity/invite_link_repository_test.rb` *(déplacés du Lot A : `test/architecture/port_contracts_test.rb` exige un adaptateur pour chaque port)*
                     `test/db/add_teacher_arrival_and_school_invite_tokens_migration_test.rb`
                     `test/db/growth_migrations_test.rb` *(nouvelle migration dans `LATER`)*
                     `test/db/schema_constraints_test.rb`
                     `test/domain/entities/identity/full_name_test.rb`
                     `test/domain/entities/identity/arrival_channel_test.rb`
- **Dépend de**    : —
- **Test associé** : `test/db/add_teacher_arrival_and_school_invite_tokens_migration_test.rb` (IE-14 : reprise `colleague` / `standard` / `code`) · `test/db/schema_constraints_test.rb` (CHECK de `joined_via`, format et unicité des deux jetons) · `test/domain/entities/identity/full_name_test.rb` (IE-03, IE-05 au niveau entité)
- **Done quand**   : `bin/rails db:migrate` passe sur une base peuplée ; chaque enseignant existant a sa voie ; chaque établissement a ses deux jetons ; `bin/rails test` reste vert ; les ports `InviteLinkRepositoryPort` et `RegistrationRepositoryPort` sont gelés

**Contrats gelés par le Lot 0** (un lot qui veut les changer s'arrête, le Lot 0 rouvre) :

```ruby
# Ports::Identity::InviteLinkRepositoryPort
InviteLink = Data.define(:school_id, :school_active, :channel, :referrer_id) # channel ∈ colleague direction team
def resolve(token:) = raise NotImplementedError # → InviteLink | nil ; collègue d'abord, puis direction, puis équipe

# Ports::Identity::RegistrationRepositoryPort
def create_teacher(user:, pin:, material_id:, joined_via:) = raise NotImplementedError

# Entities::Identity::FullName.split(raw) → [last_name, first_name] | nil
# Entities::Identity::ArrivalChannel::ALL / WRITABLE
```

---

## Lot A — S'inscrire : voie standard et lien d'invitation

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/identity/register_teacher.rb` *(réécrit : absorbe la voie sans code, résout le jeton, rattache, `joined_via`)*
                     `app/domain/dtos/identity/teacher_registration_input.rb` *(`full_name`, correction, `drena_public_id`, `school_public_id`, `invite_token` ; plus de `school_code` ni de `ref`)*
                     `app/infrastructure/queries/school/school_preview_query.rb` *(nom et DRENA d'un établissement actif, par identifiant)*
                     `app/controllers/identity/teacher_registrations_controller.rb` *(`new`, `create`, `invite` ; plus de `with_code`)*
                     `app/views/identity/teacher_registrations/new.html.erb`
                     `app/views/identity/teacher_registrations/_form.html.erb`
                     `app/views/identity/teacher_registrations/_school_fields.html.erb` *(nouveau, repris de la voie sans code, sans code national)*
                     `app/views/identity/teacher_registrations/_school_preview.html.erb`
                     `app/javascript/controllers/identity/full_name_controller.js`
                     `app/javascript/controllers/identity/phone_digits_controller.js`
                     `app/javascript/controllers/identity/pin_match_controller.js`
                     `config/locales/identity/teacher_registrations.fr.yml`
                     `test/domain/use_cases/identity/register_teacher_test.rb`
                     `test/domain/dtos/identity/teacher_registration_input_test.rb`
                     `test/infrastructure/queries/school/school_preview_query_test.rb`
                     `test/controllers/identity/teacher_registrations_controller_test.rb`
                     `test/system/identity/teacher_signup_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/identity/register_teacher_test.rb` (IE-01, IE-03, IE-04, IE-05, IE-06 voie et parrainage, IE-09, IE-10, IE-11, IE-12, IE-13) · `test/controllers/identity/teacher_registrations_controller_test.rb` (IE-02 sans champ code, IE-09 en 200, IE-13 403) · `test/system/identity/teacher_signup_test.rb` (IE-01 à 390 px, IE-04 « Corriger », IE-17 concordance en direct, IE-19 numéro nettoyé en direct, et sans JavaScript)
- **Done quand**   : sur `/teacher-signup`, un visiteur choisit DRENA → établissement → matière, tape « KOUASSI Aya Marie », voit l'aperçu, voit « Les codes concordent. », colle « +225 07 01 02 03 04 » qui devient « 0701020304 », et arrive sur ses classes, rattaché, voie « standard » ; par `/i/<referral_token>`, l'établissement est affiché et la voie est « colleague » ; un jeton inconnu ouvre la page standard avec l'alerte

---

## Lot B — Partager un lien d'invitation, lire la voie d'arrivée

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/identity/referral_query.rb` *(plus de `school_code` dans la ligne)*
                     `app/infrastructure/queries/school/own_school_query.rb` *(`direction_invite_token`)*
                     `app/infrastructure/queries/school/school_detail_query.rb` *(`team_invite_token` ; `teachers` : `joined_via` et nom du parrain)*
                     `app/infrastructure/queries/school/schools_query.rb` · `test/infrastructure/queries/school/own_school_query_test.rb` · `test/infrastructure/queries/school/schools_query_test.rb` *(ajout du 2026-10-07 : l'en-tête `teams/schools/_header` est aussi rendu par trois Turbo Streams avec une `SchoolsQuery::Row`, qui doit porter `team_invite_token` ; le test fige la liste des champs de `OwnSchoolQuery::Row`)*
                     `app/views/identity/referrals/_invite.html.erb`
                     `app/views/identity/referrals/_sidebar_card.html.erb`
                     `app/views/school_admin/schools/_link.html.erb` *(sans code ni « Changer le lien »)*
                     `app/views/teams/schools/_header.html.erb`
                     `app/views/teams/schools/show.html.erb` *(ligne « Inscription : … »)*
                     `app/views/classroom/teacher_homes/_course_levels.html.erb` *(bulle « Inviter » → WhatsApp, partage compté)*
                     `config/locales/classroom/teacher_homes.fr.yml`
                     `test/controllers/classroom/teacher_homes_controller_test.rb`
                     `config/locales/identity/referrals.fr.yml`
                     `config/locales/school_admin/schools.fr.yml`
                     `config/locales/teams/schools.fr.yml`
                     `test/infrastructure/queries/identity/referral_query_test.rb`
                     `test/infrastructure/queries/school/school_detail_query_test.rb`
                     `test/controllers/identity/referrals_controller_test.rb`
                     `test/controllers/school_admin/schools_controller_test.rb`
                     `test/controllers/teams/schools_controller_test.rb`
                     `test/system/school_admin/school_link_test.rb`
                     `test/system/school_admin/school_test.rb`
                     `test/system/teams/school_code_test.rb`
                     `test/system/identity/sidebar_referral_test.rb`
                     `test/system/finitions/classroom_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/school_admin/schools_controller_test.rb` (IE-07 : lien `/i/`, ni code ni « Changer le lien ») · `test/controllers/teams/schools_controller_test.rb` (IE-08 lien de l'équipe, IE-15 voie dans la liste) · `test/controllers/identity/referrals_controller_test.rb` (IE-06 : le lien ne contient pas le code) · `test/infrastructure/queries/school/school_detail_query_test.rb` (IE-15) · `test/controllers/classroom/teacher_homes_controller_test.rb` (IE-20 : la bulle « Inviter » pointe vers wa.me avec `/i/<jeton>` et porte l'action de partage)
- **Done quand**   : la bulle « Inviter » de l'accueil enseignant ouvre WhatsApp avec le lien d'invitation ; un enseignant, la direction et l'équipe copient chacun un lien `/i/<jeton>` qui ne contient pas le code d'établissement ; la direction n'a plus « Changer le lien » ; la fiche de l'équipe montre la voie d'arrivée de chaque enseignant

---

## Lot C — Rejoindre un établissement depuis l'écran d'attente

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/school/join_school_with_code.rb` *(rattachement par `school_public_id` d'un établissement actif de la DRENA ; règle des départs inchangée ; nom de classe gardé pour limiter le diff)*
                     `app/domain/dtos/school/school_join_input.rb` *(`drena_public_id`, `school_public_id` ; plus de `school_code`)*
                     `app/controllers/identity/pending_school_joins_controller.rb`
                     `app/controllers/identity/pending_accounts_controller.rb` *(plus de préremplissage du code ; options DRENA et établissements)*
                     `app/views/identity/pending_accounts/show.html.erb`
                     `config/locales/identity/pending_accounts.fr.yml`
                     `config/locales/identity/pending_school_joins.fr.yml`
                     `test/domain/use_cases/school/join_school_with_code_test.rb`
                     `test/domain/dtos/school/school_join_input_test.rb`
                     `test/controllers/identity/pending_school_joins_controller_test.rb`
                     `test/controllers/identity/pending_accounts_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/school/join_school_with_code_test.rb` (IE-18 : rattachement, établissement qui l'a retiré refusé, inactif refusé) · `test/controllers/identity/pending_accounts_controller_test.rb` (IE-18 : aucun champ code, DRENA présente)
- **Done quand**   : un enseignant retiré, sur l'écran d'attente, choisit DRENA puis établissement et arrive sur son accueil ; choisir l'établissement qui l'a retiré renvoie l'erreur neutre ; aucun code d'établissement n'apparaît

---

## Lot D — Retrait de l'ancienne voie et parcours de bout en bout

- **Couche**       : delivery + domaine + infrastructure (suppressions) + tests système
- **Fichiers**     : `config/routes/identity.rb` *(retire `e/:code`, `teacher-signup/without-code`)*
                     `config/routes/school_admin.rb` *(retire `patch "school/link"`)*
                     `app/domain/use_cases/identity/register_pending_teacher.rb` *(supprimé)*
                     `app/domain/dtos/identity/pending_teacher_registration_input.rb` *(supprimé)*
                     `app/controllers/identity/pending_teacher_registrations_controller.rb` *(supprimé)*
                     `app/views/identity/pending_teacher_registrations/` *(supprimé : `new`, `_school_fields`)*
                     `config/locales/identity/pending_teacher_registrations.fr.yml` *(supprimé, clés encore utiles déplacées par le Lot A)*
                     `app/infrastructure/queries/school/school_code_preview_query.rb` *(supprimé)*
                     `app/controllers/school_admin/school_links_controller.rb` *(supprimé)*
                     `app/views/school_admin/school_links/update.turbo_stream.erb` *(supprimé)*
                     `config/locales/school_admin/school_links.fr.yml` *(supprimé)*
                     `test/domain/use_cases/identity/register_pending_teacher_test.rb` · `test/domain/dtos/identity/pending_teacher_registration_input_test.rb` · `test/controllers/identity/pending_teacher_registrations_controller_test.rb` · `test/controllers/school_admin/school_links_controller_test.rb` · `test/infrastructure/queries/school/school_code_preview_query_test.rb` *(supprimés)*
                     `test/routing/v1_routes_test.rb`
                     `test/system/identity/cold_start_test.rb` *(réécrit sur `/teacher-signup`)*
                     `test/system/identity/invite_colleague_test.rb`
                     `test/system/boucle_pedagogique_test.rb`
                     `test/system/finitions/public_pages_test.rb` · `test/system/finitions/narrow_screens_test.rb` · `test/system/finitions/narrow_titles_test.rb`
                     `test/views/page_titles_test.rb` · `test/integration/pin_reveal_fields_test.rb` · `test/helpers/share_helper_test.rb`
                     `test/system/school_admin/departed_teachers_test.rb` *(GD-23 : écran d'attente par DRENA → établissement ; ajout du 2026-10-07, relevé par le Lot C)*
                     `app/controllers/school/drena_schools_controller.rb` · `test/controllers/school/drena_schools_controller_test.rb` · `app/controllers/identity/pending_accounts_controller.rb` · `app/views/identity/pending_accounts/show.html.erb` *(paramètre `scope` limité à `teacher_registration` ou `school_join`, pour que l'écran d'attente reprenne `/drenas/:id/schools` — ADR-0082 §4.5 ; ajout du 2026-10-07)*
                     `test/controllers/teams/school_codes_controller_test.rb` *(CE-07 visite `/e/<code>` ; relevé par le Lot A)*
                     `test/system/teams/school_code_test.rb` *(CE-07 lit `SchoolCodePreviewQuery` ; vérifier par `find_by_school_code`)* · `app/infrastructure/queries/school/own_school_query.rb` · `test/infrastructure/queries/school/own_school_query_test.rb` *(plus de `school_code`, seul `school_links` le lisait)* · `app/views/school_admin/schools/_link.html.erb` · `app/domain/dtos/identity/teacher_registration_input.rb` *(commentaires périmés)* — *ajouts du 2026-10-07, relevés par l'exécutant du Lot D*
                     `test/routing/school_admin_routes_test.rb` *(`WRITES` sans `PATCH /school-admin/school/link` ; ajout du 2026-10-07, relevé par l'exécutant du Lot D)*
                     `script/ci/test_timings.yml` *(durée de `teacher_signup_test` à réenregistrer)*
                     `config/locales/identity/teacher_registrations.fr.yml` *(placeholder du numéro sans espaces, « 0701020304 », cohérent avec le nettoyage en direct ; après le Lot A)*
- **Dépend de**    : Lot A, Lot B, Lot C
- **Test associé** : `test/routing/v1_routes_test.rb` (IE-02 : `/e/:code` et `/teacher-signup/without-code` non routés) · `test/system/identity/invite_colleague_test.rb` (IE-06 de bout en bout : lien d'Awa → inscription → parrainage compté) · `test/system/identity/school_staff_registration_test.rb` inchangé et vert (IE-16)
- **Done quand**   : `/e/K7M-4QZ` répond 404 ; plus aucune référence à `school_code_signup`, `RegisterPendingTeacher` ni `new_pending_teacher_registration` dans `app/` (`grep` vide) ; l'inscription de la direction par le code marche toujours ; `bin/ci` est vert

---

## Lot E — Tableau des établissements de l'équipe sans code (ajout du 2026-10-07, memo Q21)

- **Couche**       : domaine (port) + infrastructure + ui
- **Fichiers**     : `app/domain/ports/school/school_repository_port.rb` · `app/infrastructure/repositories/school/school_repository.rb` *(retrait de `find_by_national_code`)*
                     `app/infrastructure/queries/school/schools_query.rb` *(recherche par nom ou sigle ; `Row` sans `school_code` si plus lu)*
                     `app/views/teams/schools/index.html.erb` · `app/views/teams/schools/_school_row.html.erb` · `app/views/teams/schools/_filters.html.erb`
                     `config/locales/teams/schools.fr.yml`
                     `test/infrastructure/repositories/school/school_repository_test.rb` · `test/infrastructure/queries/school/schools_query_test.rb` · `test/controllers/teams/schools_controller_test.rb` · `test/system/teams/schools_test.rb`
- **Dépend de**    : Lot D
- **Test associé** : `test/infrastructure/queries/school/schools_query_test.rb` (IE-21 : « 012345 » ne trouve plus l'établissement, nom et sigle oui) · `test/controllers/teams/schools_controller_test.rb` (IE-21 : pas de colonne « Code d'établissement », libellé « Nom ou sigle »)
- **Done quand**   : sur `/teams/schools`, le tableau n'a plus de colonne « Code d'établissement » et la recherche ne trouve plus un établissement par son code national ; `find_by_national_code` n'existe plus (`grep` vide)

---

## Rattachement des critères d'acceptation

| Critère | Lot(s) |
|---|---|
| IE-01 | A |
| IE-02 | A (champ absent), D (`/e/` en 404) |
| IE-03, IE-04, IE-05 | 0 (entité), A (use case, page) |
| IE-06 | A (voie, parrainage), B (lien sans code), D (bout en bout) |
| IE-07 | B |
| IE-08 | B (lien), A (voie `team` à l'inscription) |
| IE-09, IE-10, IE-11, IE-12, IE-13 | A |
| IE-14 | 0 |
| IE-15 | B |
| IE-16 | D |
| IE-17, IE-19 | A |
| IE-20 | 0 (option de la bulle), B |
| IE-21 | E |
| IE-18 | C |

Aucun critère orphelin.

---

## Dispatch

```
Vague 1 : Lot 0                    → 1 agent, séquentiel, sur feature/inscription-enseignant
Vague 2 : Lot A ‖ Lot B ‖ Lot C    → 3 agents, worktrees isolés, après merge du Lot 0
Vague 3 : Lot D                    → 1 agent, après merge de A, B et C
```

Worktrees de la vague 2, créés depuis la branche de chantier **après** le merge du Lot 0 :

```bash
git worktree add ../lnclass-inscription-enseignant-lot-a -b feature/inscription-enseignant-lot-a feature/inscription-enseignant
git worktree add ../lnclass-inscription-enseignant-lot-b -b feature/inscription-enseignant-lot-b feature/inscription-enseignant
git worktree add ../lnclass-inscription-enseignant-lot-c -b feature/inscription-enseignant-lot-c feature/inscription-enseignant
```

Consignes à chaque agent de lot :

- chemins **absolus**, `git -C <worktree absolu>` ;
- ordre intra-lot : test rouge → domaine → infrastructure → delivery → UI (UDR-0078) ;
- en-tête HITL de 3 lignes sur chaque fichier créé ou modifié dans `app/`, avec ADR-0082 et UDR-0078 ;
- **interdiction de toucher un fichier absent de son champ `Fichiers`**. S'il en a besoin, il s'arrête et remonte : le fichier appartient au Lot 0, ou le plan est faux.

---

## Vérification de collision

> Faite avant de lancer la vague 2. Deux lots **parallèles** (A, B, C) ne listent jamais le même fichier. Le Lot 0 et le Lot D sont séquentiels : un fichier qu'ils partagent avec un lot de la vague 2 est touché **avant** ou **après** lui, jamais en même temps.

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/identity.rb` | Lot 0 (ajout de `/i/:token`), puis Lot D (retraits) |
| `config/routes/school_admin.rb` | Lot D |
| `app/views/school/drena_schools/index.html.erb` | Lot 0 (local `scope`, utilisé par A et C) |
| `app/domain/use_cases/identity/register_teacher.rb` | Lot 0 (une ligne), puis Lot A |
| `app/domain/use_cases/identity/register_pending_teacher.rb` | Lot 0 (une ligne), puis Lot D (suppression) |
| `app/domain/ports/identity/registration_repository_port.rb` · `app/infrastructure/repositories/identity/registration_repository.rb` | Lot 0 |
| `test/support/factories/identity.rb` · `test/infrastructure/orm/models_test.rb` · `db/seeds/development.rb` · `db/seeds/demo/saint_michel.rb` | Lot 0 |
| `test/domain/use_cases/identity/register_teacher_test.rb` | Lot 0 (faux dépôt), puis Lot A |
| `test/domain/use_cases/identity/register_pending_teacher_test.rb` | Lot 0 (faux dépôt), puis Lot D (suppression) |
| `app/helpers/components_helper.rb` · `app/views/components/_subject_bubble.html.erb` | Lot 0 |
| `app/views/classroom/teacher_homes/_course_levels.html.erb` · `config/locales/classroom/teacher_homes.fr.yml` | Lot B |
| `config/locales/identity/teacher_registrations.fr.yml` | Lot A |
| `config/locales/identity/pending_accounts.fr.yml` · `pending_school_joins.fr.yml` | Lot C |
| `config/locales/identity/referrals.fr.yml` · `school_admin/schools.fr.yml` · `teams/schools.fr.yml` | Lot B |
| `config/locales/identity/pending_teacher_registrations.fr.yml` · `school_admin/school_links.fr.yml` | Lot D |
| `app/infrastructure/queries/school/school_detail_query.rb` · `own_school_query.rb` · `schools_query.rb` | Lot B |
| `test/system/identity/teacher_signup_test.rb` | Lot A |
| `test/system/identity/invite_colleague_test.rb` · `cold_start_test.rb` · `boucle_pedagogique_test.rb` · `finitions/*` (hors `classroom_test.rb`) | Lot D |
| `test/system/finitions/classroom_test.rb` · `sidebar_referral_test.rb` | Lot B |

Contrôle mécanique (`awk … | sort | uniq -d`, 2026-10-07) : 17 doublons, dont 14 à l'intérieur d'un même lot (fichier répété dans `Test associé`). Les trois doublons entre lots sont séquentiels et figurent dans le tableau : `register_teacher.rb` (Lot 0 → A), `register_pending_teacher.rb` (Lot 0 → D), `config/routes/identity.rb` (Lot 0 → D). **Aucun doublon entre A, B et C.**

---

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md`
- [x] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md`
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Pour ce chantier : inscription standard à 390 px et sur ordinateur, inscription par le lien d'un collègue (parrainage compté), un lien invalide (alerte, voie « standard »), un nom d'un seul mot (422), un numéro collé avec `+225`, des codes secrets différents (statut en direct, puis 422 sans JavaScript), l'écran d'attente d'un enseignant retiré, et l'inscription de la direction par le code, toujours valable.
