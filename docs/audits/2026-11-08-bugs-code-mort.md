# Audit 1/3 — Bugs et code mort (2026-11-08)

Lecture seule, sur `Develop` au commit `a6f59db`. Rien n'a été modifié ni exécuté en production ; `bin/ci` non lancé.

**Méthode.** 10 agents de revue (un à deux par contexte borné, plus un transverse jobs/contrôleurs/routes/helpers/JS), chacun sur 2 000 à 5 000 lignes : la règle des 600 lignes par agent n'a pas été tenue (≈ 60 000 lignes de code ; il aurait fallu une centaine d'agents). La profondeur est donc inégale : les zones citées « non lues » plus bas sont à reprendre. Le code mort a été cherché par script (usages de chaque classe par `grep`, routes de `bin/rails routes`, clés I18n, partials, contrôleurs Stimulus), puis relu à la main. `graphify` n'a servi qu'à se repérer. Les constats marqués **à confirmer** sont plausibles mais non prouvés (non rejoués ou intention produit inconnue).

## Résumé

| Gravité | Constats |
|---|---|
| P0 critique | 0 |
| P1 majeur | 2 (dont 1 à confirmer) |
| P2 mineur | 5 (dont 1 à confirmer) |
| P3 confort | 38 bugs ou points, dont 17 à confirmer ; 5 entrées de code mort |

Aucune fuite de données entre écoles ou classes n'a été trouvée : les scopes école/classe/propriétaire tiennent dans les 6 contextes (les agents l'ont vérifié explicitement). I18n : aucune clé `t()` absente utilisée, aucun texte en dur dans les vues ; routes : toutes pointent vers un contrôleur et une action existants.

### Top 10

1. **B-001** P1 — un membre de l'équipe non admin (`content`, `field`) peut prendre le compte d'un admin (réinit. du 2e facteur + code de récupération du PIN).
2. **B-002** P1 (à confirmer) — pas de second facteur pour `school_admin`, alors que l'ADR-0044 l'exige.
3. **B-003** P2 — suppression d'un établissement : 500 si seul du personnel, des départs ou des annonces le référencent.
4. **B-004** P2 — compteur d'élèves faux après un retrait dans une classe de plus de 30 élèves.
5. **B-005** P2 — la recherche texte ne trouve pas « œuf » / « cœur » (titres réels de leçons).
6. **B-006** P2 — deux imports peuvent tourner en parallèle après 3 minutes (verrou de concurrence expiré).
7. **B-007** P2 (à confirmer) — une annonce programmée part sans revérifier les droits de l'auteur.
8. **B-008** P3 — `params.dig` sur un paramètre chaîne : 500 au lieu de 422 (3 contrôleurs).
9. **B-043** P3 — les jobs jettent le `Result` d'un use case : un échec ne laisse aucune trace.
10. **M-001 à M-003** P3 — trois classes du domaine jamais appelées (`NumericAnswer`, `ManageContentImagesPolicy`, `UploadQuestionImage`).

---

## Bugs

### B-001 · P1 · identity · Élévation de privilège entre rôles de l'équipe
- **Fichiers** : `app/domain/policies/identity/reset_second_factor_policy.rb:6`, `app/domain/policies/identity/issue_pin_recovery_code_policy.rb:9`
- **Description** : les deux policies acceptent tout acteur `team?`, sans regarder `team_role`. Les contrôleurs n'ajoutent que `allow_roles :team` (`teams/base_controller.rb:7`) ou `:team, :teacher` (`identity/pin_recovery_codes_controller.rb:6`). L'ADR-0031:71 réserve la réinitialisation au sous-rôle `admin` ; `InviteTeamPolicy` et `DeleteUserPolicy` l'exigent déjà.
- **Preuve** : `return Shared::Result.success if actor&.team? && target.team? && target.id != actor.user_id` ; `return Shared::Result.success if actor.team? && target.id != actor.user_id`. Les tests existants ne construisent que des acteurs `admin` (`reset_second_factor_policy_test.rb:10`) ou valident `team` → `team` (`issue_pin_recovery_code_policy_test.rb:23`).
- **Scénario** : un membre `content` émet un code de récupération pour un admin (`POST /accounts/:public_id/pin-recovery-codes`), réinitialise son TOTP, pose un nouveau PIN via `/identity/pin-reset`, enrôle son propre TOTP : il détient le compte admin.
- **Correction** : exiger `team_role == "admin"` dans `ResetSecondFactorPolicy` ; dans `IssuePinRecoveryCodePolicy`, n'accepter une cible `team` que d'un acteur `admin`. Ajouter les tests de refus (`content`, `field`).
- **Effort** : S

### B-002 · P1 (à confirmer) · identity · Pas de 2e facteur pour la direction
- **Fichiers** : `app/domain/use_cases/identity/resolve_session.rb` (`actor_for`, `return if session.team? && !session.verified?`), `app/domain/policies/identity/second_factor_policy.rb:8` (`unless session&.team?`)
- **Description** : l'ADR-0044:69 (règle C-20) dit que `school_admin` suit le régime TOTP. Ici seul `team` est concerné : un `school_admin` obtient un acteur avec le PIN seul et ne peut même pas enrôler de TOTP (la policy répond `forbidden`).
- **À confirmer** : une ADR plus récente (0077 ?) a peut-être abandonné la règle ; le contrôleur de base de l'espace direction n'a pas été lu.
- **Correction** : étendre `SecondFactorPolicy` et `actor_for` aux `school_admin`, ou acter l'abandon dans une ADR.
- **Effort** : M

### B-003 · P2 · school · Suppression d'établissement : 500 au lieu du toast « référencé »
- **Fichier** : `app/infrastructure/repositories/school/school_repository.rb:190-196` (`referenced?`) et `:41-52` (`delete_if_unreferenced`)
- **Description** : le garde-fou oublie trois tables dont la clé étrangère est `on_delete: :restrict` vers `schools` : `school_staffs` (`db/schema.rb:1136`), `teacher_school_departures` (`:1155`), `messages` (`:1120`).
- **Preuve** : `referenced?` ne teste que `TeacherSchool`, `Invitation`, `SchoolJoinRequest`, `Referral` et les élèves/enseignants/devoirs des classes. `Transaction#call` et `Teams::SchoolsController#destroy` (l.62) n'attrapent pas `InvalidForeignKey`.
- **Scénario** : école n'ayant qu'un compte direction (actif ou archivé), des enseignants retirés ou des annonces : `Orm::School.delete_all` lève `ActiveRecord::InvalidForeignKey`, l'équipe obtient un 500.
- **Correction** : ajouter `Orm::SchoolStaff`, `Orm::TeacherSchoolDeparture`, `Orm::Message` (par `school_id`) à `referenced?`, ou traduire l'exception en `:conflict`/`referenced`.
- **Effort** : S

### B-004 · P2 · classroom · Compteur d'élèves faux après retrait (classe > 30)
- **Fichier** : `app/views/classroom/classroom_students/destroy.turbo_stream.erb:24` (et `:6-8`, `:19`), `app/controllers/classroom/classroom_students_controller.rb:58`
- **Description** : le stream affiche `@overview.students.size`, plafonné à `PER_PAGE=30` (`classroom_overview_query.rb:128`), et `read_roster` appelle la query sans `page` ni `badge`.
- **Scénario** : classe de 45 élèves, on en retire un : le titre passe à « 30 élèves » au lieu de « 30 sur 44 » ; avec un filtre de badge vidé par le retrait, l'état vide ne s'affiche pas (`students.empty?` faux).
- **Correction** : utiliser `students_total` (comme `_roster.html.erb:54-58`) et relayer `badge`/`page` dans `read_roster`.
- **Effort** : S

### B-005 · P2 · shared · La recherche ignore « œ » et « æ »
- **Fichier** : `app/infrastructure/queries/shared/text_search.rb:16` et `:20`
- **Description** : côté Ruby, `transliterate` donne `coeur` (et `?` pour tout caractère hors latin) ; côté SQL, `translate()` ne connaît que `ACCENTED` et laisse `cœur`.
- **Preuve** : vérifié en base par `bin/rails runner` (l'agent) : `translate(lower('Cœur'))` reste `cœur`.
- **Scénario** : un élève cherche « oeuf » ou « œuf » dans le catalogue (`course_catalog_query.rb:90`) : les leçons « …cellule-œuf… » (données réelles, `test/fixtures/files/lecons_v1/tle-d/svt/`) ne sortent pas. Même défaut pour écoles, élèves, élèves partis, aperçu de classe, modération (6 appelants).
- **Correction** : `replace(replace(lower(col),'œ','oe'),'æ','ae')` avant `translate`, ou `unaccent` des deux côtés ; test « oeuf » et « œuf » trouvent « cellule-œuf ».
- **Effort** : S

### B-006 · P2 · shared (jobs) · Verrou de concurrence des imports expire après 3 minutes
- **Fichiers** : `app/jobs/shared/import_job.rb:7`, `app/jobs/classroom/generate_missing_classrooms_job.rb:7`
- **Description** : `limits_concurrency to: 1` sans `duration:` ; Solid Queue 1.7.0 prend 3 minutes par défaut. Les jobs de régénération de masse posent, eux, `duration: STALE_AFTER` (10 min, ADR-0096 §4.3).
- **Scénario** : import de cours complets de plus de 3 minutes puis second envoi du même type : deux `RunImport` écrivent en parallèle, contre le commentaire « un seul import à la fois ». **Impact à confirmer** (durée réelle en production).
- **Correction** : `duration: UseCases::Catalog::StartImport::STALE_AFTER.seconds` aux deux jobs.
- **Effort** : S

### B-007 · P2 (à confirmer) · communication · Annonce programmée publiée sans revérifier les droits
- **Fichier** : `app/domain/use_cases/communication/publish_scheduled_messages.rb:20-36` (job toutes les 5 min, `config/recurring.yml:42`)
- **Description** : `publish` ne fait que verrouiller, vérifier `status == "scheduled"` puis publier ; `PublishPolicy` n'est appelée qu'à la création/modification.
- **Scénario** : un enseignant programme une annonce pour la classe C puis quitte l'école, perd C, est désactivé ou le flag `teacher_announcements_enabled` est coupé : l'annonce part quand même vers les élèves de C.
- **À confirmer** : le départ/la désactivation d'un enseignant archive-t-il déjà ses programmées ailleurs ?
- **Correction** : repasser `PublishPolicy` (avec `teachable_classroom_ids`) avant publication, sinon archiver/ignorer.
- **Effort** : M

### Constats P3 (confort, cas rares ou incohérences)

| ID | Contexte | Fichier:ligne | Constat | Preuve / scénario | Correction | Effort |
|---|---|---|---|---|---|---|
| B-008 | identity, catalog | `identity/profile_photos_controller.rb:49`, `profile_materials_controller.rb:23,41`, `teams/imports_controller.rb:94,100` | `params.dig(:x, :y)` lève `TypeError` si `x` est une chaîne : 500 au lieu de 422 (requête forgée). *À confirmer (non exécuté).* | `Hash#dig` sur String | `params.fetch(:x, {})` après contrôle de type, ou `.try(:[], :y)` | S |
| B-009 | identity | `use_cases/identity/change_own_photo.rb:34` + `repositories/identity/profile_photo_store.rb:15` | Fichier envoyé au bucket dans la transaction ; si l'audit échoue, base annulée mais blob orphelin. | Ordre des opérations | Écrire l'audit avant l'attach (comme `RemoveOwnPhoto:35`) | S |
| B-010 | identity | `identity/profile_photos_controller.rb:23-24` | `RemoveOwnPhoto` renvoie `success(false)` sans photo ; le toast « photo retirée » s'affiche quand même. | `remove_own_photo.rb:19`, valeur ignorée | Tester `result.value` | S |
| B-011 | classroom | `policies/classroom/read_classroom_policy.rb:10-17` | `ClassroomStudentsController` autorise `:school_admin` mais la policy n'a pas de branche direction : 403. *À confirmer (intention).* | Aucun lien direction vers la fiche | Branche « direction de l'école de la classe » ou retirer le rôle d'`allow_roles` | S |
| B-012 | classroom | `use_cases/classroom/set_session_days.rb:19-23`, `dtos/classroom/session_days_input.rb:24-29` | Liste vide de jours acceptée (efface tout, toast « enregistrés »), alors que `AssignmentInput:30-31` la refuse. *À confirmer.* | Champ caché `session_days[weekdays][]` vide | `errors.add(:weekdays, :blank)` + clé I18n | S |
| B-013 | classroom | `policies/classroom/declare_teaching_policy.rb:9-11` (via `withdraw_teaching.rb:17`) | Un enseignant ne peut pas se retirer d'une classe archivée (403). *À confirmer.* | `:classroom_archived` | Policy distincte pour le retrait | S |
| B-014 | school | `repositories/school/join_request_repository.rb:~47` → `teams/join_requests_controller.rb:~14` | `RecordNotUnique` (enseignant déjà rattaché) → `:conflict` sans erreur : message « déjà traitée » alors que la demande reste `pending`. | Rollback par savepoint correct, pas de corruption | Erreur distincte `already_attached` | S |
| B-015 | school | `use_cases/school/review_join_request.rb:~30` | Validation par l'équipe sans contrôle d'école active ni de départ ouvert (`VouchPolicy` et `JoinSchoolWithCode` en font un). *À confirmer.* | Lecture | Trancher l'intention | S |
| B-016 | school | `repositories/school/teacher_departure_repository.rb:~16` | `close` renvoie toujours `true`, même si `update_all` ne touche rien. Impact faible. | Lecture | Renvoyer `count.positive?` | S |
| B-017 | identity | `use_cases/identity/reset_pin_with_code.rb` (`case code.status`) | Un code non utilisé reste « actif » pour toujours (`active_for` sans filtre d'expiration) : réponse « Ce code a expiré » = énumération de compte. | Lecture | Répondre `INVALID` pour un code expiré | S |
| B-018 | identity | `controllers/identity/sessions_controller.rb`, `concerns/authentication.rb` (`start_session`) | Une nouvelle connexion ne détruit pas l'ancienne session (valide 30 j d'inactivité). | Lecture | `sign_out` de l'ancien cookie dans `start_session` | S |
| B-019 | identity | `use_cases/identity/reset_pin_with_code.rb` | `status` lu avant l'incrément atomique : `MAX_FAILED_ATTEMPTS = 5` dépassable en parallèle (effet négligeable, 10^8 codes). | Lecture | `FOR UPDATE` ou condition à la consommation | S |
| B-020 | classroom | `repositories/classroom/classroom_repository.rb:41-47` | `regenerate_link_and_code` sans `retrying_join_code_collision` : `RecordNotUnique` non rattrapé (très improbable). | Comparer `create` | Envelopper | S |
| B-021 | classroom | `repositories/classroom/session_days_repository.rb:17-21` | `delete_all` + `insert_all` sans verrou ; `InvalidForeignKey` brute possible. *À confirmer.* | Lecture | Verrou / traduction en `Result` | S |
| B-022 | classroom | `repositories/classroom/assignment_repository.rb:40-42` | Tout `RecordNotUnique` devient `:already_assigned` (y compris collision de `public_id`). | Lecture | Tester le nom de l'index | S |
| B-023 | classroom | `queries/classroom/teacher_home_query.rb:46`, `teacher_follow_ups_query.rb:67`, `teaching_selection_query.rb:21`, `catalog_assignment_targets_query.rb:50` | Filtre `SchoolYear.current(today)` (bascule 1er septembre) : tant que les classes de la nouvelle année n'existent pas, l'enseignant ne voit plus ses classes. *À confirmer (ADR-0041 ?).* | Lecture | Trancher | M |
| B-024 | catalog | `use_cases/catalog/{publish,archive}_{course,essential}.rb`, `repositories/catalog/course_repository.rb:33-42`, `essential_repository.rb:38-47` | Transitions de statut non atomiques (`update_all` sans `WHERE status = from`) : deux clics → deux audits, ordre final aléatoire. | Lecture | `WHERE status = :from` → `:conflict` | M |
| B-025 | catalog | `use_cases/catalog/update_level.rb`, `repositories/catalog/taxonomy_repository.rb:38` | Passer un niveau en premier cycle avec des `level_series` n'est pas refusé. *À confirmer.* | `LinkLevelSeries` refuse l'inverse | Garde dans `update` | S |
| B-026 | catalog | `use_cases/catalog/load_repository_lessons.rb:~118-122` | Checksum déjà `completed` → republication directe ; `slug_of` lève `KeyError` avalé par `guarded` si le cours a disparu. *À confirmer.* | Lecture | Ignorer le court-circuit si le cours est absent | S |
| B-027 | catalog | `use_cases/catalog/start_import.rb:12`, `repositories/catalog/import_report_repository.rb:54-59` | `fail_stale` marque `failed` un import sans écriture depuis 10 min alors que le job tourne ; sans filtre utilisateur. *À confirmer.* | Lecture | Heartbeat par lot | M |
| B-028 | catalog | `teams/levels_controller.rb:15`, `dtos/catalog/level_input.rb:10` | Position préremplie `max+1` : 1000 si max = 999 (`POSITION_MAX`), formulaire invalide dès l'ouverture. | Lecture | `[max+1, POSITION_MAX].min` | S |
| B-029 | communication | `policies/communication/withdraw_policy.rb:4-8`, `entities/communication/message.rb` (`moderatable_by?`) | Le retrait ne contrôle pas le statut : un admin peut retirer le brouillon d'un autre auteur (qui devient gelé). | La modération ne liste que `LIVE` | Exiger `scheduled`/`published` | S |
| B-030 | communication, shared | `use_cases/communication/publish_scheduled_messages.rb:19-22,47`, job `:7` | Seule `Frozen` est rattrapée : toute autre exception interrompt la boucle (annonces suivantes retardées de 5 min, voire bloquées si l'erreur persiste) ; le job ne journalise pas le total. | Lecture | `rescue StandardError` par message + `Rails.error.report` + log du total | S |
| B-031 | communication | `controllers/communication/article_images_controller.rb:5,16-18` | Images d'un article servies `max-age=31536000, public, immutable` ; après archivage (page 410), elles restent en cache navigateur/CDN un an. | `PUBLIC_CACHE` | Durée courte ou documenter | S |
| B-032 | communication | `policies/communication/read_file_policy.rb:9` | Toute l'équipe lit les fichiers de n'importe quelle annonce (brouillons, retirées). *À confirmer ; `public_id` opaque.* | Lecture | Aligner sur `moderatable_by?` | S |
| B-033 | communication | `use_cases/communication/update_article.rb:15-22` | `current.published?` lu hors transaction : validation sur statut périmé. *À confirmer, impact faible.* | Lecture | Verrou dans `ArticleRepository#update` | S |
| B-034 | communication | `repositories/communication/message_repository.rb` (`update`), `create_message.rb` (`make_room`) | Écriture par écrasement d'un instantané lu avant verrou : édition concurrente perdue. *À confirmer.* | Lecture | Verrou d'auteur | M |
| B-035 | communication | `queries/communication/readable_messages.rb:26-30` | Un élève sans classe active n'a que `school_id: nil` : il ne voit plus les annonces de son école. *À confirmer (règle produit).* | Lecture | Repli sur l'école d'inscription | S |
| B-036 | catalog | `queries/catalog/public_material_query.rb:25-26,57-62` + `views/catalog/material_pages/_page.html.erb:19` | Badge « N cours » d'un niveau compte toutes les séries alors que les cartes sont filtrées par série. | `counts` calculé avant `selection` | Passer le total filtré | S |
| B-037 | catalog | `queries/catalog/course_detail_query.rb:46-49` | Pour l'équipe, `exercises_count` inclut les exercices archivés (≠ feuilles). *À confirmer.* | Lecture | Exclure `archived` | S |
| B-038 | assessment | `controllers/assessment/exercise_copies_controller.rb:~58` | Tout `:conflict` sauf `exercise_archived` affiche « session remplacée » : faux pour `already_answered` (double envoi). | `submit_exercise_copy.rb` | Rediriger vers le résultat | S |
| B-039 | assessment | `controllers/assessment/session_results_controller.rb:~33` | Enseignant/équipe sur le résultat d'une session « started » : redirigé vers `exercise_session_path`, qui lui répond 403. | `ReadSessionPolicy` sans `teaches_student` | 404 ou « copie en cours » | S |
| B-040 | assessment | `repositories/assessment/exercise_repository.rb:~45` | `replace_questions` fait `delete_all` sans verrou ; une copie rendue entre la garde et la suppression → `InvalidForeignKey` (500). *À confirmer.* | Lecture | `lock` de l'exercice | M |
| B-041 | assessment | `javascript/controllers/assessment/numeric_controller.js` (`validate`) | Le client exige un nombre pur alors que le serveur accepte une unité (`without_unit`). *À confirmer (unité hors champ ?).* | `_numeric.html.erb:35` | Aligner | S |
| B-042 | shared | `domain/shared/result.rb`, `controllers/concerns/renders_result.rb` | `:unavailable` ∈ `ERROR_CODES` mais absent de `FORM_STATUSES` : `KeyError` latent (aucun chemin ne l'émet aujourd'hui). | Lecture | Compléter la table | S |
| B-043 | shared | `jobs/shared/import_job.rb:11-17`, `generate_missing_classrooms_job.rb:11`, `regenerate_school_codes_job.rb:13`, `regenerate_classroom_links_job.rb:13` | Le `Result` du use case est jeté : un `:conflict` laisse le job « réussi » sans trace. | Lecture | Journaliser `report_id`, `code`, sans donnée personnelle | S |
| B-044 | school | `use_cases/school/purge_archived_staff.rb:47-48`, `jobs/school/purge_archived_staff_job.rb:13` | `rescue StandardError` perd la classe de l'exception ; un compte qui échoue chaque nuit reste archivé sans cause lisible. | Lecture | Remonter `{user_id, exception}` et journaliser | S |
| B-045 | classroom | `queries/classroom/teacher_home_query.rb:56` | `members.count { … }` par classe : O(classes × élèves). Performance, pas de résultat faux. | Lecture | `tally` préalable | S |
| B-046 | catalog | `controllers/catalog/courses_controller.rb` (`show`) | L'enseignant lit toute leçon publiée par son slug, hors de ses matières (le catalogue est restreint). Probablement voulu (UDR-0077) ; contenu commun, pas de fuite entre écoles. *À confirmer.* | Lecture | Rien, sauf décision contraire | — |

Points écartés après vérification (ne pas refaire) : comparaisons constantes et usage unique des codes (OK), session fixation (OK), index uniques et verrous de classe/devoir (OK), nettoyage des sessions au changement de PIN (OK), `ClassroomCodesController#show` public (voulu, ADR-0109), seuils `Grading` (48 % = passage, testé).

---

## Code mort

Recherche d'usages par `grep` du nom de classe dans `app/`, `config/`, `lib/`, `db/seeds`, hors tests. **Aucun fichier non namespacé à la racine** de `entities/`, `repositories/`, `use_cases/`, `ports/`, `policies/`, `queries/` (le legacy est résorbé). **Aucun contrôleur Stimulus mort** (tous référencés). Les 5 jobs sans référence Ruby sont déclarés dans `config/recurring.yml`, les contrôleurs sont atteints par les routes (302 routes vérifiées) : ce ne sont pas des morts. Les partials « sans référence » (`kinds/_*`, `illustrations/_*`, `next_step/_*`, `sheet_kinds/_*`) sont rendus dynamiquement (`render "…/#{kind}"`) : non morts.

### M-001 · P3 · catalog · `Entities::Catalog::NumericAnswer`
- **Fichier** : `app/domain/entities/catalog/numeric_answer.rb`
- **Preuve** : `grep -rn NumericAnswer app config lib` → aucune référence hors du fichier ; seul `test/domain/entities/catalog/numeric_answer_test.rb` l'utilise. Usage dynamique improbable (constante).
- **Risque** : sa tolérance fixe `TOLERANCE = 0.011` ignore `questions.numeric_tolerance` ; quiconque le branche plus tard fausserait la correction.
- **Piste** : supprimer classe et test (la règle vit côté JS `bank.js` et `Numeric`), ou lui passer la tolérance. **Effort** : S

### M-002 · P3 · catalog · `Policies::Catalog::ManageContentImagesPolicy`
- **Fichier** : `app/domain/policies/catalog/manage_content_images_policy.rb`
- **Preuve** : aucune référence hors de son test ; citée seulement dans `docs/chantiers/images-dans-les-cours/menace.md`. `UploadQuestionImage` reçoit `Policies::Catalog::ManageContentPolicy` à la place.
- **Piste** : supprimer avec son test. **Effort** : S

### M-003 · P3 · assessment · `UseCases::Assessment::UploadQuestionImage`
- **Fichier** : `app/domain/use_cases/assessment/upload_question_image.rb`
- **Preuve** : aucune référence hors de `test/domain/use_cases/assessment/upload_question_image_test.rb`. `QuestionImagesController` n'utilise que `ReadQuestionImage` (l.42) ; le téléversement passe ailleurs. À confirmer qu'aucune route d'envoi d'image de question n'est prévue (chantier `images-dans-les-cours`).
- **Piste** : supprimer avec son test, ou le brancher si le téléversement est attendu. **Effort** : S

### M-004 · P3 · I18n · Clés `fr` jamais lues (54 candidates sur 4 100)
Détection par nom de clé (tolérante : le dernier segment cité n'importe où l'exclut) ; **usages dynamiques possibles** (suffixes `_student`, `status.*`, `lang.*` du rich-text via JS) : à confirmer clé par clé avant suppression.
- `catalog/courses.fr.yml` : `catalog.courses.index.student_progression`, `show.content_title`, `show.prepare_intro`, `show.due_today`, `sheets.interros_title`, `sheets.choice_true`, `sheets.choice_false`
- `classroom/classroom_courses.fr.yml` : `show.prepare_intro`, `show.due_today` ; `classroom/teacher_homes.fr.yml` : `show.previous_classrooms`, `show.next_classrooms`
- `communication/articles.fr.yml` : `show.status.draft_hint`, `show.status.archived_hint`
- `identity/profile_contacts|photos|pins|profiles.fr.yml` : les variantes `*_student` (`intro_student`, `current_pin_hint_student`, `changed_student`, `preview_student`, `unreadable_student`, `removed_student`, `pin_hint_student`, `updated_student`) et `profiles.information.edit_materials(_label)`
- `shared/classroom_settings.fr.yml` et `teams/school_classrooms.fr.yml` : `…max_students.not_an_integer` ; `shared/common.fr.yml` : `errors.codes.rate_limited_daily`
- `shared/components.fr.yml` : `components.rich_text_editor.lang.{bullets,heading1,italic,outdent,strike,urlPlaceholder,captionPlaceholder,attachFiles}` ; `shared/navigation.fr.yml` : `install_banner.ios_share|ios_add.{student,teacher}_html`
- `teams/` : `answer_keys.show.accepted_alternative`, `articles.article_row.signed_team|signed_author`, `classroom_plans.totals.{public,private}_{first,both}`, `imports.status.details.exercises_archived|exercises_ignored_v1`, `imports.schema_keywords.maxLength`, `schools.filters.all_school_type|all_cycle|all_status`
- Inverse : `teams.level_series.destroy.first_cycle` est **absente** mais jamais appelée (aucun effet).
- **Effort** : S

### M-005 · P3 · routes · Routes sans appel interne (à confirmer)
Helpers de chemin jamais utilisés dans `app/` : `teacher_invite` (`/teachers/invite` → `identity/referrals#show`), `teachers_schools` (POST → `school/teacher_schools#create`), `course_fiche` (301 de compatibilité, voulu : `routes/catalog.rb:10`), `course_essential`, `classroom_essential`, `mission`, `sales_terms`. Les pages `mission`/`sales_terms` sont probablement liées par clé dynamique (`PAGES`/`ONLINE`) ; `teacher_invite` et `teachers_schools` ont peut-être des liens construits en dur ou des envois par WhatsApp. Aucune route n'a de contrôleur ou d'action manquant.
- **Piste** : confirmer chaque URL dans les journaux d'accès avant retrait. **Effort** : S

### Non couvert par l'audit code mort
Méthodes publiques inutilisées dans les classes vivantes, vues entières sans route, scripts de `script/` et `bin/`, doublons de logique entre contextes : non examinés faute de temps ; à traiter dans un prochain passage.

---

## Ordre de traitement proposé pour demain

1. **B-001** (P1, S) : policies `ResetSecondFactor` et `IssuePinRecoveryCode` + tests de refus. À faire en premier ; passer par `security-reviewer`.
2. **B-002** : trancher avec le porteur (ADR-0044 vs réalité) ; si la règle tient, chantier dédié (M).
3. Lot « corrections rapides P2 » en une PR : **B-003**, **B-004**, **B-005**, **B-006** (tous S, chacun avec son test).
4. **B-007** : vérifier si le départ d'un enseignant archive ses programmées ; sinon corriger.
5. Lot « échecs muets » : **B-030**, **B-043**, **B-044**, **B-042** (journalisation des jobs, S).
6. Lot « 500 évitables » : **B-008**, **B-020**, **B-021**, **B-022**, **B-040** (traductions d'exceptions en `Result`).
7. Lot « messages trompeurs » : **B-010**, **B-014**, **B-038**, **B-039**, **B-029**.
8. Décisions produit à poser en un seul `AskUserQuestion` : B-011, B-012, B-013, B-015, B-023, B-032, B-035, B-046.
9. Nettoyage : **M-001 à M-003** (supprimer 3 classes et 3 tests), puis **M-004** après vérification des usages dynamiques, **M-005** après lecture des journaux d'accès.
10. Reste des P3 (B-009, B-016 à B-019, B-024 à B-028, B-031, B-033, B-034, B-036, B-037, B-041, B-045) : à regrouper par contexte en retouches.
