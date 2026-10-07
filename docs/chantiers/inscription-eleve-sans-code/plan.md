# Plan d'exécution — Inscription des élèves sans code de classe

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Specs : [`prd.md`](prd.md) · [ADR-0083](../../decisions/adr/0083-inscription-eleve-sans-code-de-classe.md) · [UDR-0079](../../decisions/udr/0079-inscription-eleve-sans-code-de-classe.md)

> ⚠️ **Préalable avant le Lot 0.** Les lots de `inscription-enseignant` qui livrent `Entities::Identity::FullName` et les contrôleurs Stimulus `identity--full-name`, `identity--phone-digits`, `identity--pin-match` sont fusionnés dans la branche de base : ce chantier les réutilise.

## Graphe

```
Lot 0 — SOCLE (séquentiel) : migration, voie d'arrivée, ports et adaptateurs, policy de gestion, routes et textes partagés
  ↓
  ├─► Lot A « s'inscrire : voie standard et lien de classe »   ┐
  ├─► Lot C « partager et changer le lien de la classe »       ├─ en parallèle, worktrees isolés
  └─► Lot D « voir les nouveaux arrivés, retirer un élève »    ┘
  ↓
  ├─► Lot B « élève sans classe : choisir sa classe »   (après A : il réutilise la cascade)   ┐ en parallèle
  └─► Lot E « la direction gère une classe »            (après C et D : il réutilise leurs blocs) ┘
  ↓
Lot F — RETRAIT du code de classe + parcours de bout en bout (séquentiel, après tous)
```

Pourquoi un Lot F : supprimer `/join`, `Entities::Classroom::JoinCode` et la colonne `join_code` casse les vues et les lectures que A à E réécrivent. Le retrait vient donc après eux, en une fois, avec les tests système qui prouvent le parcours entier. Jusqu'au Lot F, le code et le lien coexistent : l'application reste utilisable à chaque fusion.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + fichiers partagés
- **Fichiers**     : `db/migrate/20261007110000_add_classroom_link_tokens_and_student_removal.rb`
                     `db/schema.rb`
                     `app/domain/entities/classroom/student_arrival_channel.rb`
                     `app/domain/entities/classroom/classroom.rb` *(attribut `link_token`)*
                     `app/domain/entities/classroom/membership.rb` *(attributs `joined_via`, `removed_at`)*
                     `app/domain/ports/classroom/classroom_repository_port.rb` *(ajout : `lock_by_public_id`, `lock_by_link_token`, `rotate_link_token` ; `lock_by_join_code` reste jusqu'au Lot F)*
                     `app/domain/ports/classroom/membership_repository_port.rb` *(`add_primary(…, via:)`, `remove`, `removed_from?`)*
                     `app/infrastructure/repositories/classroom/classroom_repository.rb`
                     `app/infrastructure/repositories/classroom/membership_repository.rb`
                     `app/infrastructure/orm/classroom_student.rb` *(association `removed_by`)*
                     `app/domain/policies/classroom/manage_classroom_members_policy.rb` *(partagée par C, D et E)*
                     `app/domain/use_cases/classroom/join_with_code.rb` · `app/domain/use_cases/classroom/join_as_student.rb` *(une ligne chacun : `via: "code"` ; réécrits par A et B)*
                     `config/routes/classroom.rb` · `config/routes/school.rb` *(ajout seulement : `/student-signup`, `/students/classroom/new` et son `POST /students/classroom`, les deux adresses de la cascade — `school_picker_levels_path`, `school_picker_classrooms_path` —, `PATCH /classrooms/:public_id/link`, `DELETE /classrooms/:classroom_public_id/students/:student_public_id`)*
                     `config/locales/classroom/classrooms.fr.yml` *(clés du lien, des pastilles et du retrait : partagées par C et D)*
                     `test/support/factories/identity.rb` *(`create_student` accepte `joined_via:` et `joined_at:`)*
                     `db/seeds/development.rb` · `db/seeds/demo/saint_michel.rb` · les 20 fichiers de `test/` qui écrivent une adhésion par `Orm::ClassroomStudent.create!` *(`joined_via: "standard"` : la colonne n'a pas de défaut ; ajout du 2026-10-07, découvert par l'exécutant du Lot 0)*
                     `test/integration/classroom/join_capacity_test.rb` *(faux dépôt : `add_primary` accepte `via:` ; même ajout)*
                     `test/routing/v1_routes_test.rb` *(les routes ajoutées ; même ajout)*
                     `test/db/add_classroom_link_tokens_and_student_removal_migration_test.rb`
                     `test/db/schema_constraints_test.rb`
                     `test/domain/entities/classroom/student_arrival_channel_test.rb`
                     `test/domain/policies/classroom/manage_classroom_members_policy_test.rb`
                     `test/infrastructure/repositories/classroom/classroom_repository_test.rb`
                     `test/infrastructure/repositories/classroom/membership_repository_test.rb`
                     `test/domain/use_cases/classroom/join_with_code_test.rb` · `test/domain/use_cases/classroom/join_as_student_test.rb` *(faux dépôts : `add_primary` accepte `via:`)*
- **Dépend de**    : —
- **Test associé** : `test/db/add_classroom_link_tokens_and_student_removal_migration_test.rb` (IL-22 : voie `code` reprise, un lien par classe) · `test/db/schema_constraints_test.rb` (format et unicité de `link_token`, `CHECK` de `joined_via`, `removed_at` sans `left_at` refusé) · `test/domain/policies/classroom/manage_classroom_members_policy_test.rb` (IL-12, chaque refus) · `test/infrastructure/repositories/classroom/membership_repository_test.rb` (retrait, retour par réouverture de l'adhésion, IL-21)
- **Done quand**   : `bin/rails db:migrate` passe sur une base peuplée ; chaque classe a son jeton ; chaque adhésion existante a la voie `code` ; `bin/rails test` reste vert ; l'inscription par code marche encore ; les ports et la policy sont gelés

**Contrats gelés par le Lot 0** (un lot qui veut les changer s'arrête, le Lot 0 rouvre) :

```ruby
# Ports::Classroom::ClassroomRepositoryPort
def lock_by_public_id(public_id:) = raise NotImplementedError   # → Classroom | nil, sous verrou, avec active_students_count
def lock_by_link_token(token:)    = raise NotImplementedError   # → Classroom | nil, idem
def rotate_link_token(id:)        = raise NotImplementedError   # → String, le nouveau jeton

# Ports::Classroom::MembershipRepositoryPort
def add_primary(classroom_id:, student_id:, via:, at:)             = raise NotImplementedError # rouvre l'adhésion d'un élève retiré
def remove(classroom_id:, student_id:, removed_by_id:, at:)        = raise NotImplementedError # → true si close, false si déjà parti
def removed_from?(classroom_id:, student_id:)                      = raise NotImplementedError # → Boolean

# Policies::Classroom::ManageClassroomMembersPolicy#call(actor:, classroom:)   # classroom : avec teacher_ids et school_id
#   → success | failure(:not_found) pour un enseignant ou une direction hors périmètre | failure(:forbidden) pour un élève ou un visiteur
# Entities::Classroom::StudentArrivalChannel::ALL = %w[standard link code] / WRITABLE = %w[standard link]
```

---

## Lot A — S'inscrire : voie standard et lien de classe

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/classroom/register_student.rb` *(remplace `join_with_code.rb`, qui reste jusqu'au Lot F)*
                     `app/domain/dtos/classroom/student_registration_input.rb`
                     `app/domain/policies/classroom/join_policy.rb` *(`via_link:`, `removed:` ; le code n'est plus vérifié que pour l'ancien chemin)*
                     `app/infrastructure/queries/school/school_levels_query.rb`
                     `app/infrastructure/queries/classroom/level_classrooms_query.rb`
                     `app/infrastructure/queries/classroom/join_preview_query.rb` *(lecture par jeton, à côté du code)*
                     `app/controllers/classroom/student_registrations_controller.rb`
                     `app/controllers/school/school_levels_controller.rb`
                     `app/controllers/school/level_classrooms_controller.rb`
                     `app/controllers/classroom/joins_controller.rb` *(jeton de 12 caractères : nouveau chemin ; code de 5 : ancien chemin, inchangé)*
                     `app/views/classroom/student_registrations/new.html.erb`
                     `app/views/classroom/student_registrations/_form.html.erb`
                     `app/views/classroom/student_registrations/_class_picker.html.erb`
                     `app/views/school/school_levels/index.html.erb`
                     `app/views/school/level_classrooms/index.html.erb`
                     `app/views/classroom/joins/new.html.erb`
                     `app/javascript/controllers/classroom/class_picker_controller.js`
                     `config/locales/classroom/student_registrations.fr.yml`
                     `config/locales/classroom/joins.fr.yml` *(raison `removed_from_classroom`, à côté de `classroom_full`)*
                     `test/domain/use_cases/classroom/register_student_test.rb`
                     `test/domain/dtos/classroom/student_registration_input_test.rb`
                     `test/domain/policies/classroom/join_policy_test.rb`
                     `test/infrastructure/queries/school/school_levels_query_test.rb`
                     `test/infrastructure/queries/classroom/level_classrooms_query_test.rb`
                     `test/infrastructure/queries/classroom/join_preview_query_test.rb`
                     `test/controllers/classroom/student_registrations_controller_test.rb`
                     `test/controllers/school/school_levels_controller_test.rb`
                     `test/controllers/school/level_classrooms_controller_test.rb`
                     `test/controllers/classroom/joins_controller_test.rb`
                     `test/integration/classroom/join_capacity_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/classroom/register_student_test.rb` (IL-01, IL-03, IL-08, IL-10, IL-19) · `test/controllers/classroom/student_registrations_controller_test.rb` (IL-02 pour la page, IL-05, IL-06, IL-07, IL-20, IL-23) · `test/infrastructure/queries/classroom/level_classrooms_query_test.rb` (IL-04) · `test/controllers/classroom/joins_controller_test.rb` (IL-08, IL-09 pour un jeton inconnu ou d'une classe archivée) · `test/integration/classroom/join_capacity_test.rb` (IL-05 sous concurrence)
- **Done quand**   : un visiteur ouvre `/student-signup`, choisit DRENA, établissement, niveau et classe, crée son compte et arrive sur son accueil dans cette classe ; un autre ouvre `/c/<jeton>` et s'inscrit dans la classe affichée ; une classe complète ou introuvable se dit dans la liste

---

## Lot C — Partager et changer le lien de la classe

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/classroom/change_classroom_link.rb`
                     `app/infrastructure/queries/classroom/classroom_header_query.rb` *(jeton du lien, droit de gestion)*
                     `app/infrastructure/queries/school/school_detail_query.rb` *(jeton du lien de chaque classe)*
                     `app/controllers/classroom/classroom_links_controller.rb`
                     `app/views/classroom/classrooms/_link.html.erb`
                     `app/views/classroom/classrooms/_header.html.erb` *(le bloc du lien à côté du code, qui reste jusqu'au Lot F)*
                     `app/views/classroom/classroom_links/update.turbo_stream.erb`
                     `app/views/teams/schools/_classroom_group.html.erb` *(« Copier le lien »)*
                     `test/domain/use_cases/classroom/change_classroom_link_test.rb`
                     `test/infrastructure/queries/classroom/classroom_header_query_test.rb`
                     `test/controllers/classroom/classroom_links_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/classroom/change_classroom_link_test.rb` (IL-11) · `test/controllers/classroom/classroom_links_controller_test.rb` (IL-11, IL-12 pour le lien : enseignant de la classe et équipe accordés, autre enseignant 404, élève 403)
- **Done quand**   : un enseignant copie le lien de sa classe et le partage sur WhatsApp ; il change le lien, le bloc en montre un nouveau, et l'ancien n'ouvre plus la classe ; l'équipe copie le lien depuis la fiche de l'établissement

---

## Lot D — Voir les nouveaux arrivés, retirer un élève

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/classroom/remove_student.rb`
                     `app/infrastructure/queries/classroom/classroom_overview_query.rb` *(`joined_at`, voie, « nouveau », tri)*
                     `app/controllers/classroom/classroom_students_controller.rb`
                     `app/controllers/classroom/classrooms_controller.rb` *(droit de retrait passé à la vue)*
                     `app/views/classroom/classrooms/_roster.html.erb`
                     `app/views/classroom/classroom_students/destroy.turbo_stream.erb`
                     `test/domain/use_cases/classroom/remove_student_test.rb`
                     `test/infrastructure/queries/classroom/classroom_overview_query_test.rb`
                     `test/controllers/classroom/classroom_students_controller_test.rb`
                     `test/controllers/classroom/classrooms_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/classroom/classroom_overview_query_test.rb` (IL-13) · `test/domain/use_cases/classroom/remove_student_test.rb` (IL-14, IL-21) · `test/controllers/classroom/classroom_students_controller_test.rb` (IL-12 pour le retrait, IL-14)
- **Done quand**   : un enseignant voit « Nouveau » et « Inscrit seul » sur la ligne d'un élève arrivé depuis moins de 7 jours ; il le retire, la ligne disparaît et l'effectif baisse ; l'élève garde son compte et ses résultats

---

## Lot B — Élève sans classe : choisir sa classe

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : `app/domain/use_cases/classroom/join_as_student.rb` *(classe par `public_id` ou par jeton ; l'élève retiré)*
                     `app/infrastructure/queries/classroom/student_home_query.rb` *(dernière école de l'élève, retrait récent)*
                     `app/controllers/classroom/student_classroom_choices_controller.rb`
                     `app/controllers/classroom/student_homes_controller.rb`
                     `app/views/classroom/student_classroom_choices/new.html.erb`
                     `app/views/classroom/student_homes/_no_classroom.html.erb`
                     `app/views/classroom/student_homes/show.html.erb`
                     `config/locales/classroom/student_classroom_choices.fr.yml`
                     `config/locales/classroom/student_homes.fr.yml`
                     `test/domain/use_cases/classroom/join_as_student_test.rb`
                     `test/infrastructure/queries/classroom/student_home_query_test.rb`
                     `test/controllers/classroom/student_classroom_choices_controller_test.rb`
                     `test/controllers/classroom/student_homes_controller_test.rb`
- **Dépend de**    : Lot A *(le partial `_class_picker`, les deux lectures de la cascade et `JoinPolicy`)*
- **Test associé** : `test/domain/use_cases/classroom/join_as_student_test.rb` (IL-15, IL-16, IL-17) · `test/controllers/classroom/student_classroom_choices_controller_test.rb` (IL-15, IL-17, IL-18) · `test/controllers/classroom/student_homes_controller_test.rb` (IL-14 côté élève : accueil sans classe et son message)
- **Done quand**   : un élève retiré, ou dont la classe est archivée, voit « Choisis ta classe » sur son accueil, choisit une classe et y entre ; la classe dont il a été retiré lui est refusée par ce chemin, et son lien l'y ramène

---

## Lot E — La direction gère une classe

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/controllers/school_admin/classrooms_controller.rb`
                     `app/views/school_admin/classrooms/show.html.erb` *(bloc `_link` du Lot C, pastilles, menu et modale du Lot D)*
`app/infrastructure/queries/school/student_work_query.rb` *(la lecture qui nourrit cette page : jeton du lien, `joined_at`, voie, identifiant de l'élève pour le retrait)*
                     `config/locales/school_admin/classrooms.fr.yml`
                     `test/controllers/school_admin/classrooms_controller_test.rb`
- **Dépend de**    : Lot C, Lot D
- **Test associé** : `test/controllers/school_admin/classrooms_controller_test.rb` (IL-12 pour la direction : son établissement accordé, un autre 404 ; IL-13 et IL-14 depuis sa page)
- **Done quand**   : la direction ouvre une classe de son établissement, copie et change son lien, voit les nouveaux arrivés et retire un élève ; elle ne peut rien sur la classe d'un autre établissement

---

## Lot F — Retrait du code de classe et parcours de bout en bout

- **Couche**       : toutes (suppression) + tests système
- **Fichiers**     : `db/migrate/20261007120000_remove_classroom_join_codes.rb` · `db/schema.rb`
                     `app/domain/entities/classroom/join_code.rb` *(supprimé)*
                     `app/domain/use_cases/classroom/join_with_code.rb` · `app/domain/dtos/classroom/join_with_code_input.rb` *(supprimés)*
                     `app/domain/policies/classroom/join_policy.rb` *(plus de code)*
                     `app/domain/ports/classroom/classroom_repository_port.rb` · `app/infrastructure/repositories/classroom/classroom_repository.rb` *(retrait de `lock_by_join_code`, `taken_join_codes`)*
                     `app/domain/entities/classroom/classroom.rb`
                     `app/domain/use_cases/classroom/generate_missing_classrooms.rb` · `app/domain/use_cases/school/import_schools.rb` *(plus de code tiré)*
                     `app/controllers/classroom/join_codes_controller.rb` · `app/views/classroom/join_codes/new.html.erb` *(supprimés)*
                     `app/controllers/classroom/joins_controller.rb` *(un ancien code : redirection avec l'alerte)*
                     `app/infrastructure/queries/classroom/join_preview_query.rb` · `app/infrastructure/queries/classroom/classroom_header_query.rb` · `app/infrastructure/queries/classroom/student_home_query.rb` · `app/infrastructure/queries/school/school_detail_query.rb`
                     `app/views/classroom/classrooms/_header.html.erb` · `app/views/classroom/student_homes/_classroom_card.html.erb` · `app/views/classroom/student_classrooms/show.html.erb`
                     `app/views/homepage/_role_modal.html.erb` · `app/views/identity/pending_accounts/show.html.erb`
                     `app/controllers/school_admin/level_classrooms_controller.rb` · `app/controllers/teams/level_classrooms_controller.rb` · `app/controllers/teams/school_classrooms_controller.rb`
                     `app/views/teams/school_classrooms/create.turbo_stream.erb` · `app/views/teams/school_classrooms/_form.html.erb` · `app/views/teams/schools/_classroom_group.html.erb`
                     `config/routes/classroom.rb` *(`/join` redirigé)*
                     les fichiers de `config/locales/` qui portent une clé de code de classe *(liste à établir par `grep -rl join_code config/locales` à l'ouverture du lot)*
                     `test/domain/entities/classroom/join_code_test.rb` · `test/domain/use_cases/classroom/join_with_code_test.rb` · `test/domain/dtos/classroom/join_with_code_input_test.rb` · `test/controllers/classroom/join_codes_controller_test.rb` *(supprimés)*
                     `test/routing/v1_routes_test.rb` · `test/db/schema_constraints_test.rb` · `test/guards/repository_rules_test.rb`
                     `test/system/classroom/join_test.rb` *(réécrit : les deux voies)* · `test/system/classroom/student_removal_test.rb`
                     `docs/guide/glossaire.md` · `docs/decisions/udr/0009-rejoindre-une-classe.md` *(statut « Remplacée »)* · `docs/decisions/adr/0041-vie-d-une-classe-annee-scolaire-et-code.md` *(note d'amendement)*
- **Dépend de**    : Lot A, Lot B, Lot C, Lot D, Lot E
- **Test associé** : `test/routing/v1_routes_test.rb` (IL-02 : `/join` redirige) · `test/controllers/classroom/joins_controller_test.rb` (IL-09 pour l'ancien lien `/c/kfm37`) · `test/guards/repository_rules_test.rb` (aucun `join_code` sous `app/`) · `test/db/schema_constraints_test.rb` (plus de colonne `join_code`) · `test/system/classroom/join_test.rb` (IL-01, IL-08, IL-10 dans un vrai navigateur) · `test/system/classroom/student_removal_test.rb` (IL-14, IL-15, IL-16 de bout en bout)
- **Done quand**   : plus aucun écran ne montre un code de classe ; `/join` mène à `/student-signup` ; un ancien lien ouvre l'inscription standard avec l'alerte ; les deux parcours système passent sous Chrome ; `bin/ci` est vert

---

## Critères du PRD et lots

| Critère | Lot | Critère | Lot | Critère | Lot |
|---|---|---|---|---|---|
| IL-01 | A, F | IL-09 | A, F | IL-17 | B |
| IL-02 | A, F | IL-10 | A, F | IL-18 | B |
| IL-03 | A | IL-11 | C | IL-19 | A |
| IL-04 | A | IL-12 | 0, C, D, E | IL-20 | A |
| IL-05 | A | IL-13 | D, E | IL-21 | 0, D |
| IL-06 | A | IL-14 | D, B, E, F | IL-22 | 0 |
| IL-07 | A | IL-15 | B, F | IL-23 | A |
| IL-08 | A, F | IL-16 | B, F | | |

Aucun critère orphelin.

## Dispatch

```
Vague 1 : Lot 0                      → 1 agent, séquentiel
Vague 2 : Lot A ‖ Lot C ‖ Lot D      → 3 agents, worktrees isolés
Vague 3 : Lot B ‖ Lot E              → 2 agents, worktrees isolés
Vague 4 : Lot F                      → 1 agent, séquentiel
```

Chaque lot parallèle part de la branche de chantier, une fois la vague précédente fusionnée :

```bash
git worktree add ../lnclass-inscription-eleve-sans-code-lot-a -b feature/inscription-eleve-sans-code-lot-a feature/inscription-eleve-sans-code
```

## Vérification de collision

> Deux lots **parallèles** ne listent jamais le même fichier. Un fichier listé par deux lots **successifs** est noté ici avec l'ordre de passage : le second part de la branche où le premier est fusionné.

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/classroom.rb`, `config/routes/school.rb` | Lot 0 (ajouts) → Lot F (retrait de `/join`) |
| `config/locales/classroom/classrooms.fr.yml` | Lot 0 (clés de C et de D, écrites d'avance) |
| `db/schema.rb`, `test/db/schema_constraints_test.rb` | Lot 0 → Lot F |
| `classroom_repository_port.rb`, `classroom_repository.rb`, `classroom.rb` (entité) | Lot 0 → Lot F |
| `join_with_code.rb` et son test | Lot 0 (une ligne) → Lot F (suppression) ; le Lot A écrit `register_student.rb` à côté |
| `join_as_student.rb` et son test | Lot 0 (une ligne) → Lot B |
| `join_policy.rb` | Lot A → Lot F |
| `joins_controller.rb` et son test, `join_preview_query.rb` | Lot A → Lot F |
| `classroom_header_query.rb`, `_header.html.erb`, `school_detail_query.rb`, `teams/schools/_classroom_group.html.erb` | Lot C → Lot F |
| `student_home_query.rb` | Lot B → Lot F |
| `app/views/classroom/classrooms/show.html.erb` | aucun lot : `_header` (C) et `_roster` (D) y sont déjà rendus |
| `school_admin/classrooms/show.html.erb` et son contrôleur | Lot E seul (C et D n'y touchent pas) |
| `classrooms_controller.rb` et son test | Lot D seul |

Vague 2 (A ‖ C ‖ D) : aucun fichier commun — A est sous `student_registrations/`, `joins/` et la cascade ; C sous `classroom_links/`, `_link`, `_header` ; D sous `classroom_students/`, `_roster`. Vague 3 (B ‖ E) : aucun fichier commun.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md`
- [x] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md`
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Ici, il rejoue à 390 px et sur ordinateur : l'inscription standard jusqu'à l'accueil, l'inscription par le lien, la classe complète, la classe introuvable, le retrait d'un élève puis son retour refusé par la voie standard et accepté par le lien, et le changement de lien.
