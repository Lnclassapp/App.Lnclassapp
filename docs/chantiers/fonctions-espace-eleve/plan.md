# Plan d'exécution — Fonctions de l'espace élève

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Décisions, acceptées le 2026-10-02 (porteur : « lance les lots ») : [ADR-0072](../../decisions/adr/0072-assignation-d-exercices-et-echeance-a-la-prochaine-seance.md) · [UDR-0061](../../decisions/udr/0061-carte-d-aide-et-faq.md) · [UDR-0062](../../decisions/udr/0062-echeances.md) · [UDR-0063](../../decisions/udr/0063-pages-publiques-mission-confidentialite-cgu-cgv.md). Proposé : [amendement de l'ADR-0036](../../decisions/adr/0036-suppression-archivage-et-anonymisation.md) (lot R). Specs : [PRD](prd.md). Textes publics : [`pages-publiques.md`](pages-publiques.md).
>
> **Déjà livré** : la FAQ `/aide` (UDR-0061 §3.1), commit `2bd842f2`.

## Graphe

```
Vague 1   Lot 0 — SOCLE : migrations additives (due_on, jours de séance), entités, ports, DTO, policies,
          DueDateHelper, routes, gabarit des pages publiques et liste ONLINE (vide), pied de page
  ↓
Vague 2   ├─► Lot A  — Retrait de l'assignation de cours et de fiches (type Exercise seul)   ┐
          ├─► Lot B  — Carte d'aide (FAQ, WhatsApp, appel)                                  │
          ├─► Lot P1 — Page « Notre mission »                                               ├─ en parallèle
          ├─► Lot P2 — Page « Protection des données »                                      │
          └─► Lot P3 — Page « Conditions d'utilisation »                                    ┘
  ↓ (A mergé)
Vague 3   ├─► Lot C — Assigner un exercice avec les jours de séance   ┐
          ├─► Lot D — Échéance chez l'élève                           ├─ en parallèle
          └─► Lot E — Page de la classe et suivi de l'exercice        ┘
  ↓
          Challenger des échéances, de la carte et des pages

Hors vague, dès que sa dépendance externe est levée (en parallèle de tout le reste, fichiers disjoints) :
          ├─► Lot P4 — Page « Conditions de vente »      ← attend le chantier abonnement-mobile-money
          └─► Lot R  — Conservation : anonymisation 30 jours après le départ   ← attend la définition du « départ »

AVANT LE DÉPLOIEMENT (porte de sortie)
          Lot R livré  →  Lot Z — Mise en ligne (ONLINE, numéros du support), séquentiel, après validation des juristes
```

**Écart avec la demande « A, B, C, D, E, P1, P2, P3 en parallèle »** : le Lot A ne peut pas tourner en même temps que C, D et E. Restreindre `assignable_type` à `Exercise` (contrainte en base) casse toute assignation de cours créée par les tests : la fabrique `create_assignment` assigne un cours par défaut, et 49 fichiers de test en dépendent, dont ceux que C, D et E possèdent (`assign_resource_test`, `student_home_query_test`, `classroom_overview_query_test`…). A doit donc être mergé avant la vague 3. La seule autre option était de mettre le Lot A dans le Lot 0, qui serait devenu un lot de plus de 70 fichiers.

**Contrats gelés au Lot 0.** `Entities::Classroom::SessionDays` (`#next_after`), `Entities::Classroom::Assignment#due_on`, `Ports::Classroom::SessionDaysRepositoryPort` (`for`, `replace`), `Dtos::Classroom::AssignmentInput#weekdays`, `Dtos::Classroom::SessionDaysInput`, `Policies::Classroom::SetSessionDaysPolicy`, `Policies::Classroom::FollowAssignmentPolicy`, `DueDateHelper#due_badge` et `#due_for_teacher`, les noms des routes, `Communication::PagesController.online?(page)` et `PublicPagesHelper#public_page_links`. Un lot qui a besoin de changer un contrat **s'arrête** et remonte : le Lot 0 rouvre.

**Exception assumée** : le Lot R porte son propre petit socle (port `identity`, et une migration si la définition du « départ » en demande une). Aucun autre lot ne touche le contexte `identity`, et R démarre à une date inconnue, bien après le Lot 0.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + delivery (routes, gabarit) + ui (fichiers partagés)
- **Fichiers**     :
  - `db/migrate/20261003090000_add_due_on_to_classroom_assignments.rb`, `db/migrate/20261003090100_create_classroom_session_days.rb`, `db/schema.rb`
  - `app/infrastructure/orm/classroom_session_day.rb`, `app/infrastructure/orm/classroom_assignment.rb` (rien d'autre que l'en-tête HITL, ADR 0072)
  - `app/domain/entities/classroom/session_days.rb`, `app/domain/entities/classroom/assignment.rb` (`due_on`)
  - `app/domain/ports/classroom/session_days_repository_port.rb`, `app/domain/ports/classroom/assignment_repository_port.rb` (`create` écrit `due_on` ; `resolve_assignable` documenté pour `Exercise` seul)
  - `app/infrastructure/repositories/classroom/session_days_repository.rb` (l'adaptateur, exigé par `test/architecture/port_contracts_test.rb`), `app/infrastructure/repositories/classroom/assignment_repository.rb` (`due_on` lu et écrit)
  - `app/domain/dtos/classroom/assignment_input.rb` (`weekdays`, `later`), `app/domain/dtos/classroom/session_days_input.rb`
  - `app/domain/policies/classroom/set_session_days_policy.rb`, `app/domain/policies/classroom/follow_assignment_policy.rb`
  - `app/helpers/due_date_helper.rb`, `config/locales/shared/due_dates.fr.yml` (formats `due_short`, `due_long`, libellés de l'UDR-0062 §3.1)
  - `config/routes/classroom.rb` (ajouts : `new_classroom_assignment`, `edit_classroom_session_days`, `classroom_session_days`, `classroom_assignment` du suivi)
  - `config/routes/communication.rb` (`mission`, `privacy`, `terms`, `sales_terms`)
  - `app/controllers/communication/pages_controller.rb` (`ONLINE = [].freeze`, `.online?`, 404 hors de la liste), `app/views/communication/pages/_page.html.erb`, `app/helpers/public_pages_helper.rb`, `config/locales/communication/public_pages.fr.yml`
  - `app/views/homepage/index.html.erb` (seconde liste du pied de page, par `public_page_links`), `config/locales/homepage/index.fr.yml` (« des cours et des exercices » → « des exercices », UDR-0062 §4)
  - `app/views/communication/help/show.html.erb` (ligne « Vos données », UDR-0063 §3.4)
  - `docs/guide/glossaire.md` *(déjà fait le 2026-10-02)*
  - tests listés ci-dessous
- **Dépend de**    : —
- **Test associé** :
  - `test/domain/entities/classroom/session_days_test.rb`, `test/domain/entities/classroom/assignment_test.rb`
  - `test/domain/dtos/classroom/session_days_input_test.rb`
  - `test/domain/policies/classroom/set_session_days_policy_test.rb`, `test/domain/policies/classroom/follow_assignment_policy_test.rb` (refus : élève, autre enseignant, direction, `nil`, classe archivée pour les jours)
  - `test/infrastructure/repositories/classroom/session_days_repository_test.rb`, `test/infrastructure/repositories/classroom/assignment_repository_test.rb` (`due_on` écrit et relu)
  - `test/db/classroom_assignments_constraints_test.rb` (`due_on` le jour même ou à + 8 refusé ; jour 7 refusé ; jour sans déclaration refusé)
  - `test/helpers/due_date_helper_test.rb` (les sept cas de l'UDR-0062 §3.1)
  - `test/controllers/communication/pages_controller_test.rb` (404 hors de `ONLINE`, 200 avec `online?` simulé), `test/helpers/public_pages_helper_test.rb`
  - `test/architecture/port_contracts_test.rb` (inchangé, doit rester vert)
- **Done quand**   : la suite complète est verte sans changement visible pour un utilisateur ; `bin/rails runner "puts Entities::Classroom::SessionDays.new(weekdays: [1, 4]).next_after(Date.new(2026, 10, 5))"` affiche `2026-10-08` ; `/mission` répond 404.

---

## Vague 2

### Lot A — Retrait de l'assignation de cours et de fiches

- **Couche**       : infrastructure + domaine + delivery + ui
- **Fichiers**     :
  - `db/migrate/20261003100000_restrict_classroom_assignments_to_exercises.rb`, `db/schema.rb` *(passation après le Lot 0)*
  - `app/domain/entities/classroom/assignable.rb` (`TYPES = %w[Exercise]`)
  - `app/infrastructure/repositories/classroom/assignment_repository.rb` *(passation)* : `resolve_course`, `resolve_essential`, `RESOURCES` réduits
  - queries : `app/infrastructure/queries/classroom/classroom_course_query.rb`, `app/infrastructure/queries/classroom/classroom_essential_query.rb`, `app/infrastructure/queries/classroom/student_home_query.rb`, `app/infrastructure/queries/classroom/classroom_overview_query.rb` (retrait de `courses`), `app/infrastructure/queries/classroom/student_classroom_query.rb`, `app/infrastructure/queries/catalog/essential_detail_query.rb`
  - supprimés : `app/controllers/classroom/course_assignments_controller.rb`, `app/infrastructure/queries/classroom/course_assignment_targets_query.rb`, `app/views/classroom/course_assignments/index.html.erb`, `config/locales/classroom/course_assignments.fr.yml`, `app/views/classroom/classrooms/_assigned_courses.html.erb`, `app/views/classroom/student_classrooms/_assigned_course.html.erb`
  - `config/routes/classroom.rb` *(passation)* : la route `course_assignments` part
  - vues : `app/views/catalog/courses/_role_actions.html.erb`, `app/views/classroom/classroom_courses/show.html.erb`, `app/views/classroom/classroom_essentials/show.html.erb` (bascule de la fiche), `app/views/classroom/classrooms/show.html.erb` (« Cours assignés » retiré), `app/views/classroom/student_classrooms/show.html.erb` (carte retirée)
  - locales : `config/locales/catalog/courses.fr.yml`, `config/locales/classroom/classroom_courses.fr.yml`, `config/locales/classroom/classroom_essentials.fr.yml`, `config/locales/classroom/classrooms.fr.yml`, `config/locales/classroom/student_classrooms.fr.yml`
  - `test/support/factories/classroom.rb` (`create_assignment` assigne un exercice par défaut)
  - tests à adapter (ils créent une assignation de cours ou de fiche) : `test/controllers/assessment/exercise_sessions_controller_test.rb`, `test/controllers/catalog/essentials_controller_test.rb`, `test/controllers/classroom/assignments_controller_test.rb`, `test/controllers/classroom/classroom_courses_controller_test.rb`, `test/controllers/classroom/classroom_essentials_controller_test.rb`, `test/controllers/classroom/classrooms_controller_test.rb`, `test/controllers/classroom/student_classrooms_controller_test.rb`, `test/controllers/classroom/student_homes_controller_test.rb`, `test/controllers/classroom/teacher_homes_controller_test.rb`, `test/controllers/classroom/teachings_controller_test.rb`, `test/controllers/school_admin/classrooms_controller_test.rb`, `test/controllers/school_admin/teacher_reinstatements_controller_test.rb`, `test/controllers/school_admin/teachers_controller_test.rb`, `test/controllers/teams/courses_controller_test.rb`, `test/controllers/teams/essentials_controller_test.rb`, `test/domain/dtos/classroom/assignment_input_test.rb`, `test/domain/entities/classroom/assignable_test.rb`, `test/domain/ports/classroom/assignment_repository_port_test.rb`, `test/domain/use_cases/catalog/archive_course_test.rb`, `test/domain/use_cases/classroom/assign_resource_test.rb`, `test/infrastructure/queries/catalog/essential_detail_query_test.rb`, `test/infrastructure/queries/classroom/classroom_course_query_test.rb`, `test/infrastructure/queries/classroom/classroom_essential_query_test.rb`, `test/infrastructure/queries/classroom/classroom_overview_query_test.rb`, `test/infrastructure/queries/classroom/student_classroom_query_test.rb`, `test/infrastructure/queries/classroom/student_home_query_test.rb`, `test/infrastructure/queries/classroom/teacher_home_query_test.rb`, `test/infrastructure/queries/school/student_work_query_test.rb`, `test/infrastructure/queries/school/team_dashboard_query_test.rb`, `test/infrastructure/repositories/classroom/assignment_repository_test.rb`, `test/infrastructure/repositories/classroom/classroom_repository_test.rb`, `test/infrastructure/repositories/classroom/teaching_repository_test.rb`, `test/infrastructure/repositories/school/school_repository_test.rb`, `test/integration/catalog/course_lifecycle_test.rb`, `test/support/factories_test.rb`, `test/system/classroom/assignment_toggle_test.rb`, `test/system/classroom/classroom_page_test.rb`, `test/system/classroom/student_classroom_test.rb`, `test/system/classroom/student_home_test.rb`, `test/system/classroom/teacher_home_test.rb`, `test/system/error_paths_test.rb`, `test/system/finitions/catalog_and_student_test.rb`, `test/system/role_homes_test.rb`, `test/system/school_admin/student_work_test.rb`, `test/system/school_admin/teachers_test.rb`
  - supprimés : `test/controllers/classroom/course_assignments_controller_test.rb`, `test/infrastructure/queries/classroom/course_assignment_targets_query_test.rb`, `test/system/classroom/course_assignments_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/architecture/assignable_types_test.rb` (aucun `"Course"` ni `"Essential"` passé comme type assignable dans `app/`)
  - `test/db/restrict_classroom_assignments_to_exercises_test.rb` (une ligne `Course` fait échouer `#up` et reste intacte)
  - `test/domain/entities/classroom/assignable_test.rb`, `test/infrastructure/repositories/classroom/assignment_repository_test.rb`
  - `test/controllers/catalog/courses_controller_test.rb` (aucun lien vers `course_assignments_path` pour l'enseignant)
- **Done quand**   : un enseignant ne voit plus aucun bouton ni bascule d'assignation d'un cours ou d'une fiche (page du cours, cours et fiche dans la classe) ; `/courses/<slug>/assignments` répond 404 ; la migration passe sur une base sans assignation de cours ni de fiche, et échoue avec le nombre de lignes sinon ; « Ma classe » n'a plus de carte « Cours assignés » ; la suite complète est verte.

### Lot B — Carte d'aide

- **Couche**       : delivery (configuration) + ui
- **Fichiers**     :
  - `config/support.yml` (création ; valeurs vides en production, fictives en test), `config/application.rb` (`config.x.support = config_for(:support)`)
  - `app/helpers/support_helper.rb`, `app/views/shared/_help_sheet.html.erb`, `config/locales/shared/help_sheet.fr.yml`
  - `app/helpers/components_helper.rb` (`ui_modal placement:`), `app/views/components/_modal.html.erb`, `app/assets/stylesheets/application.tailwind.css` (`.dialog-sheet`, `.sheet-handle`)
  - `app/javascript/controllers/modal_controller.js` (retour du focus), `app/javascript/controllers/autofocus_controller.js` (`data-autofocus-first`)
  - `app/views/classroom/student_homes/show.html.erb` (le lien devient le déclencheur de la carte, repli vers `/aide`)
- **Dépend de**    : Lot 0 (`public_page_links` au pied de la carte)
- **Test associé** :
  - `test/system/communication/help_sheet_test.rb` (390 px : feuille en bas, ≥ 25 %, focus sur « Questions fréquentes », Échap et retour du focus ; 1 280 px : modale centrée ; sans JavaScript : `/aide`)
  - `test/helpers/support_helper_test.rb` (ligne absente sans numéro ; `wa.me` et `tel:`), `test/config/support_config_test.rb`, `test/helpers/components_helper_test.rb` (`placement: :sheet`)
- **Done quand**   : sur l'accueil élève, « Besoin d'aide ? » ouvre la carte : une feuille qui monte du bas sur téléphone, une modale sur ordinateur ; la ligne FAQ mène à `/aide` ; avec des numéros de test, WhatsApp et l'appel ouvrent `wa.me` et `tel:` ; sans numéro, seule la ligne FAQ s'affiche.

### Lot P1 — Page « Notre mission »

- **Couche**       : ui
- **Fichiers**     : `app/views/communication/pages/mission.html.erb` · `config/locales/communication/pages/mission.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/communication/pages/mission_test.rb` (avec `online?` simulé : 200 sans connexion, un `h1`, une `h2` par section, « Accueil » vers `root_path`)
- **Done quand**   : avec la page simulée en ligne, `/mission` montre le texte de [`pages-publiques.md`](pages-publiques.md) §1, validé par le porteur ; sans simulation, elle répond toujours 404.

### Lot P2 — Page « Protection des données »

- **Couche**       : ui
- **Fichiers**     : `app/views/communication/pages/privacy.html.erb` · `config/locales/communication/pages/privacy.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/communication/pages/privacy_test.rb` (sommaire, ancres des `h2`, « Lnclass Côte d'Ivoire SARL », Tiassalé, les deux numéros, loi n° 2013-450)
- **Done quand**   : avec la page simulée en ligne, `/confidentialite` montre le texte de [`pages-publiques.md`](pages-publiques.md) §2, sommaire compris, marques « ‹ … : à compléter par les juristes › » encore présentes ; elle reste hors de `ONLINE` (lot Z).

### Lot P3 — Page « Conditions d'utilisation »

- **Couche**       : ui
- **Fichiers**     : `app/views/communication/pages/terms.html.erb` · `config/locales/communication/pages/terms.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/communication/pages/terms_test.rb`
- **Done quand**   : avec la page simulée en ligne, `/conditions-utilisation` montre le texte de [`pages-publiques.md`](pages-publiques.md) §3, sommaire compris ; elle reste hors de `ONLINE` (lot Z).

---

## Vague 3 (après le merge du Lot A)

### Lot C — Assigner un exercice avec les jours de séance

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     :
  - `app/domain/use_cases/classroom/assign_resource.rb` (jours, échéance, transaction), `app/domain/use_cases/classroom/set_session_days.rb`
  - `app/infrastructure/repositories/classroom/teaching_repository.rb` (`withdraw` et `withdraw_all_in_school` retirent les jours)
  - `app/infrastructure/queries/classroom/classroom_essential_query.rb` *(passation après A)* : `due_on` et `needs_session_days`
  - `app/controllers/classroom/assignments_controller.rb` (`new`, `create` avec jours et « Plus tard »), `app/controllers/classroom/session_days_controller.rb` (`edit`, `update` → `turbo_stream.refresh`), `app/controllers/classroom/classroom_essentials_controller.rb`
  - `app/views/classroom/assignments/_toggle.html.erb`, `app/views/classroom/assignments/new.html.erb`, `app/views/classroom/assignments/create.turbo_stream.erb`, `app/views/classroom/session_days/edit.html.erb`, `app/views/classroom/classroom_essentials/show.html.erb` *(passation)*
  - `config/locales/classroom/assignments.fr.yml`, `config/locales/classroom/session_days.fr.yml`, `config/locales/classroom/classroom_essentials.fr.yml` *(passation)*
- **Dépend de**    : Lot 0, Lot A
- **Test associé** :
  - `test/domain/use_cases/classroom/assign_resource_test.rb` (lundi → jeudi, jeudi → lundi, + 7, dimanche → lundi, 23 h 30 à Abidjan, « Plus tard », équipe `:forbidden` sur les jours)
  - `test/domain/use_cases/classroom/set_session_days_test.rb` (les échéances existantes ne bougent pas ; tout décocher = non renseigné)
  - `test/infrastructure/repositories/classroom/teaching_repository_test.rb`, `test/infrastructure/queries/classroom/classroom_essential_query_test.rb`
  - `test/controllers/classroom/assignments_controller_test.rb` (422 sans jour), `test/controllers/classroom/session_days_controller_test.rb` (403 autre enseignant, classe archivée), `test/controllers/classroom/classroom_essentials_controller_test.rb`
  - `test/system/classroom/assignment_toggle_test.rb`, `test/system/classroom/classroom_essential_test.rb`
- **Done quand**   : un enseignant sans jours touche « Assigner », coche lundi et jeudi : l'exercice est assigné avec « Pour jeu. 8 oct. » (horloge au 5 octobre), les autres « Assigner » n'ouvrent plus la modale ; « Plus tard » assigne sans date et la modale revient ; un membre de l'équipe assigne sans modale ni date.

### Lot D — Échéance chez l'élève

- **Couche**       : infrastructure + ui
- **Fichiers**     :
  - `app/infrastructure/queries/classroom/student_home_query.rb` *(passation après A)* : `due_on`, ordre de l'UDR-0062 §3.2, `late_material_slugs`
  - `app/views/classroom/student_homes/_assigned_exercise.html.erb`, `config/locales/classroom/student_homes.fr.yml`
  - `app/controllers/communication/help_controller.rb` (question `late` dans `QUESTIONS`), `config/locales/communication/help.fr.yml` (« Que veut dire « En retard » ? »)
- **Dépend de**    : Lot 0, Lot A
- **Test associé** :
  - `test/infrastructure/queries/classroom/student_home_query_test.rb` (ordre : dû le 8, dû le 12, sans échéance ; terminé en fin de liste, sans date)
  - `test/controllers/classroom/student_homes_controller_test.rb` (« À rendre demain » en `warning`, « À rendre jeudi » en `neutral`, « En retard · prévu hier »)
  - `test/system/classroom/student_home_test.rb`, `test/controllers/communication/help_controller_test.rb`
- **Done quand**   : un élève voit « À rendre demain » en ambre sur l'exercice le plus urgent, en tête de liste avec le seul bouton principal ; un exercice dépassé reste faisable et dit « En retard · prévu … » ; la FAQ explique « En retard ».

### Lot E — Page de la classe et suivi de l'exercice

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     :
  - `app/infrastructure/queries/classroom/classroom_overview_query.rb` *(passation après A)* : jours de séance de l'acteur, exercices assignés et leurs trois comptes, cours de la classe (UDR-0062 §3.4)
  - `app/infrastructure/queries/classroom/assignment_follow_up_query.rb`
  - `app/controllers/classroom/classrooms_controller.rb`, `app/controllers/classroom/assignment_follow_ups_controller.rb`
  - `app/views/classroom/classrooms/show.html.erb` *(passation)*, `app/views/classroom/classrooms/_session_days.html.erb`, `app/views/classroom/classrooms/_assigned_exercises.html.erb`, `app/views/classroom/classrooms/_courses.html.erb`, `app/views/classroom/assignment_follow_ups/show.html.erb`
  - `config/locales/classroom/classrooms.fr.yml` *(passation)*, `config/locales/classroom/assignment_follow_ups.fr.yml`
- **Dépend de**    : Lot 0, Lot A
- **Test associé** :
  - `test/infrastructure/queries/classroom/assignment_follow_up_query_test.rb` (jour de l'échéance = à l'heure ; lendemain = en retard ; refait = reste en retard ; remédiation ne compte pas ; élève parti ignoré ; archivée absente ; nombre de requêtes fixe)
  - `test/infrastructure/queries/classroom/classroom_overview_query_test.rb`
  - `test/controllers/classroom/assignment_follow_ups_controller_test.rb` (403 élève, autre enseignant, direction ; 404 assignation archivée ou d'une autre classe)
  - `test/controllers/classroom/classrooms_controller_test.rb`, `test/system/classroom/classroom_page_test.rb`
- **Done quand**   : l'enseignant voit sur la page de sa classe ses jours de séance, « 18 faits, dont 3 en retard · 7 pas encore faits » et les cours de sa matière ; le suivi nomme les seuls rendus en retard ; le p95 du suivi et de la page tient sous 100 ms au volume de l'ADR-0067.

---

## Hors vague

### Lot P4 — Page « Conditions de vente »

- **Couche**       : ui
- **Fichiers**     : `app/views/communication/pages/sales_terms.html.erb` · `config/locales/communication/pages/sales_terms.fr.yml`
- **Dépend de**    : Lot 0 ; **chantier [`abonnement-mobile-money`](../abonnement-mobile-money/memo.md)** (offre, prix, durée, remboursement)
- **Test associé** : `test/controllers/communication/pages/sales_terms_test.rb`
- **Done quand**   : avec la page simulée en ligne, `/conditions-vente` montre les CGV complétées avec l'offre ; elle reste hors de `ONLINE` (lot Z).

### Lot R — Conservation : anonymisation 30 jours après le départ

- **Couche**       : domaine + infrastructure (son propre socle, contexte `identity`)
- **Fichiers**     :
  - `docs/decisions/adr/0036-suppression-archivage-et-anonymisation.md` (amendement accepté, « départ » défini)
  - `app/domain/use_cases/identity/anonymize_user.rb`, `app/domain/policies/identity/auto_anonymize_policy.rb`
  - `app/domain/ports/identity/user_repository_port.rb` (`departed_before`, `anonymize`), `app/infrastructure/repositories/identity/user_repository.rb`
  - `app/domain/entities/identity/audit_action.rb` (`user.anonymized`)
  - `app/jobs/identity/anonymize_departed_users_job.rb`, `config/recurring.yml`
  - si la définition du « départ » demande une colonne : `db/migrate/…`, `db/schema.rb` *(passation, après le merge du Lot A)*
- **Dépend de**    : la définition du « départ » et des données « sensibles » (memo, questions ouvertes) ; amendement de l'ADR-0036 accepté
- **Test associé** :
  - `test/domain/use_cases/identity/anonymize_user_test.rb` (données sensibles effacées, usage conservé ; refus enseignant, élève, direction)
  - `test/jobs/identity/anonymize_departed_users_job_test.rb` (31 jours → anonymisé ; 29 jours → intact ; second passage sans effet)
  - `test/config/recurring_test.rb`
- **Done quand**   : un compte parti depuis plus de 30 jours est anonymisé chaque nuit (nom « Compte supprimé », numéro et photo effacés, connexions fermées) ; ses sessions et badges restent, et la réussite de sa classe ne change pas.

### Lot Z — Mise en ligne (séquentiel, avant le déploiement)

- **Couche**       : delivery (configuration)
- **Fichiers**     : `app/controllers/communication/pages_controller.rb` (`ONLINE`) *(passation après le Lot 0)* · `config/support.yml` (numéros et horaires du support) *(passation après le Lot B)* · `docs/chantiers/fonctions-espace-eleve/journal.md`
- **Dépend de**    : P1, P2, P3 (et P4 pour les CGV) ; **Lot R** pour la page « Protection des données » ; **validation des juristes** pour chaque page ; numéros du support fournis par le porteur
- **Test associé** : `test/i18n/public_pages_test.rb` (aucune marque « ‹ », « à compléter », « à fournir » ni « à fixer » dans une page de `ONLINE`) · `test/controllers/communication/pages_controller_test.rb`
- **Done quand**   : **une page n'entre dans `ONLINE` qu'après la validation des juristes**, sa date de mise à jour posée et ses marques retirées ; la page « Protection des données » n'y entre qu'avec le lot R livré ; les CGV, qu'avec l'offre d'`abonnement-mobile-money` ; le pied de page de la homepage, `/aide` et la carte d'aide montrent exactement les pages en ligne.

---

## Dispatch

```
Vague 1 : Lot 0                                   → 1 agent, séquentiel
Vague 2 : Lot A ‖ Lot B ‖ Lot P1 ‖ Lot P2 ‖ Lot P3 → 5 agents, worktrees isolés
Vague 3 : Lot C ‖ Lot D ‖ Lot E                   → 3 agents (après le merge de A)
Libres  : Lot P4 (après abonnement-mobile-money), Lot R (après la définition du « départ ») → 1 agent chacun, à leur date
Final   : Lot Z                                   → 1 agent, séquentiel, avant le déploiement
```

Worktree de lot, depuis la branche de chantier, une fois le Lot 0 mergé :

```bash
git worktree add ../lnclass-fonctions-espace-eleve-lot-a -b feature/fonctions-espace-eleve-lot-a feature/fonctions-espace-eleve
```

Chaque agent reçoit son lot en entier (5 champs), le [PRD](prd.md), l'ADR ou l'UDR de son lot, et l'ordre intra-lot : test rouge → domaine → infrastructure → delivery → UI. Chemins absolus, `git -C <worktree>`. **Interdiction de toucher un fichier hors de son champ `Fichiers`** : s'il en a besoin, il s'arrête et remonte.

## Critères d'acceptation du PRD §4, rattachés

| Bloc Gherkin du PRD | Lot |
|---|---|
| Domaine et données (types, migration Q7, calcul de l'échéance, contrainte `due_on`) | 0 (échéance, contraintes), A (types, migration) |
| Assigner (modale, « Plus tard », 422, équipe, page de la classe, deux enseignants, retrait de la déclaration) | C ; affichage des jours sur la page de la classe : E |
| Accueil élève | D |
| Suivi de l'enseignant | E |
| Refus de policy | 0 (policies), C (jours), E (suivi) |
| Retrait de l'assignation de cours et de fiches | A ; bloc « Cours » : E |
| FAQ | livrée ; question « En retard » : D |
| Carte d'aide | B |
| Pages publiques | 0 (404, liens), P1 à P4, Z |
| Conservation | R |
| Garde-fous | A (`assignable_types_test`), tous (tokens, pureté du domaine) |

Aucun critère orphelin.

## Vérification de collision

> Doublons trouvés mécaniquement (commande de la skill `plan-lots`, tableau exclu). Chacun est une **passation entre vagues**, jamais deux lots parallèles.

| Fichier | Lot propriétaire |
|---|---|
| `db/schema.rb` | Lot 0, puis A, puis R (si migration) |
| `config/routes/classroom.rb` | Lot 0 (ajouts), puis A (retrait de `course_assignments`) |
| `config/routes/communication.rb` | Lot 0 |
| `app/infrastructure/repositories/classroom/assignment_repository.rb`, `test/infrastructure/repositories/classroom/assignment_repository_test.rb` | Lot 0 (`due_on`), puis A |
| `app/domain/entities/classroom/assignment.rb`, `test/domain/entities/classroom/assignment_test.rb` | Lot 0 |
| `app/infrastructure/queries/classroom/classroom_essential_query.rb`, son test, `app/views/classroom/classroom_essentials/show.html.erb`, `config/locales/classroom/classroom_essentials.fr.yml`, `test/controllers/classroom/classroom_essentials_controller_test.rb` | A, puis C |
| `test/domain/use_cases/classroom/assign_resource_test.rb`, `test/controllers/classroom/assignments_controller_test.rb`, `test/system/classroom/assignment_toggle_test.rb`, `test/infrastructure/repositories/classroom/teaching_repository_test.rb` | A, puis C |
| `app/infrastructure/queries/classroom/student_home_query.rb`, son test, `test/controllers/classroom/student_homes_controller_test.rb`, `test/system/classroom/student_home_test.rb` | A, puis D |
| `app/infrastructure/queries/classroom/classroom_overview_query.rb`, son test, `app/views/classroom/classrooms/show.html.erb`, `config/locales/classroom/classrooms.fr.yml`, `test/controllers/classroom/classrooms_controller_test.rb`, `test/system/classroom/classroom_page_test.rb` | A, puis E |
| `app/views/classroom/student_homes/show.html.erb` | B (D ne touche que `_assigned_exercise`) |
| `config/locales/classroom/student_homes.fr.yml` | D |
| `app/controllers/communication/help_controller.rb`, `config/locales/communication/help.fr.yml`, `test/controllers/communication/help_controller_test.rb` | D |
| `app/views/communication/help/show.html.erb` | Lot 0 |
| `app/controllers/communication/pages_controller.rb`, `test/controllers/communication/pages_controller_test.rb` | Lot 0, puis Z |
| `app/views/communication/pages/<page>.html.erb`, `config/locales/communication/pages/<page>.fr.yml` | P1 à P4, un fichier chacun |
| `app/views/homepage/index.html.erb`, `config/locales/homepage/index.fr.yml` | Lot 0 |
| `app/helpers/components_helper.rb`, `app/views/components/_modal.html.erb`, `app/assets/stylesheets/application.tailwind.css`, `app/javascript/controllers/modal_controller.js`, `app/javascript/controllers/autofocus_controller.js`, `config/application.rb` | B |
| `config/support.yml` | B (création), puis Z (valeurs) |
| `config/recurring.yml` | R |
| `test/support/factories/classroom.rb` | A |
| `test/fixtures/` | aucun lot |
| `docs/decisions/adr/README.md`, `docs/decisions/udr/README.md`, `docs/chantiers/fonctions-espace-eleve/journal.md` | orchestrateur, à chaque merge (Z clôt le journal) |

**Fichiers partagés non attribuables à un seul lot** : aucun dans une même vague. Six groupes changent de propriétaire d'une vague à l'autre (tableau ci-dessus) ; l'orchestrateur ne lance un lot qu'une fois le précédent mergé. Point d'attention : `db/schema.rb` si le lot R ajoute une migration, à merger après A.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé` *(Q1 à Q18)*
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md` *(ADR-0072 accepté ; amendement de l'ADR-0036 proposé, pour le lot R)*
- [x] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md` *(0061, 0062, 0063 ; amendements 0011, 0013, 0015, 0027, 0028, 0029 ; 0030 dépréciée)*
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Lot A mergé avant la vague 3
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

**Avant le déploiement** (en plus des portes ci-dessus) :

- [ ] **Lot R livré** : anonymisation automatique 30 jours après le départ, sur l'amendement accepté de l'ADR-0036 (« départ » défini)
- [ ] **Lot Z fait** : chaque page publique validée par les juristes avant d'entrer dans `ONLINE` ; « Protection des données » seulement avec le lot R ; numéros du support posés dans `config/support.yml`

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Pour ce chantier, il :
> - assigne en enseignant un premier exercice (modale des jours), puis un second (sans modale), et « Plus tard » dans une autre classe ;
> - ouvre l'accueil de l'élève avec l'horloge avancée au lendemain, puis au surlendemain de l'échéance : « À rendre demain », puis « En retard · prévu … », et l'exercice se fait encore ;
> - ouvre le suivi en enseignant (comptes, retardataires), puis en élève et en direction (403) ;
> - vérifie qu'aucun bouton n'assigne un cours ni une fiche, et que `/courses/<slug>/assignments` répond 404 ;
> - ouvre la carte d'aide à 390 et 1 280 px, au clavier (Échap, retour du focus) ;
> - mesure le p95 de la page de la classe et du suivi (PRD §7).
