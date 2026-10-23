# Plan d'exécution — MVP Lnclass Teacher & Student — pilote du 27 octobre

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot). Critères : [`prd.md`](prd.md) §4 (CA-A1 à CA-K3). Écrans : [`carte-des-ecrans.md`](carte-des-ecrans.md) et les UDR du PRD §6.

**Branche de chantier** : `feature/mvp-teacher-student`, depuis `Develop`. Lots : `feature/mvp-teacher-student-lot-<x>`, depuis la branche de chantier **après** la fusion du Lot 0 et du Lot P. **Une seule PR** vers `Develop`, prête lundi 26.

**Attribution** (porteur, 2026-10-23 : « assigner aux membres de l'équipe ») — une issue GitHub par lot, assignée à son pilote :

| Lot | Pilote | Issue |
|---|---|---|
| 0, A, B, C, Z | orchestrateur (`Kamkara007`, agents `executant-lot`) | — |
| P | Touré (`toure-bangaly`) | #285 |
| D | Touré | #286 |
| G | Touré | #287 |
| K | Touré | #288 |
| J | Touré | #289 |
| E | Konan (`konanmeschac777-cmyk`) | #290 |
| F | Konan | #291 |
| H | Konan | #292 |
| I | Konan | #293 |
| L | Konan | #294 |

**Pilotes** (porteur, 2026-10-22 : l'orchestrateur code le code de classe, l'inscription élève et l'accueil élève ; Touré et Konan le reste). Un lot d'orchestrateur est exécuté par l'agent `executant-lot` ; un lot de Touré ou Konan, par eux. Le porteur peut réattribuer un lot sans changer le plan.

## Graphe

```
Vague 1   Lot 0 — Socle (Orch.)      ‖   Lot P — Palette (Touré)
             │                               │
             └───────────────┬───────────────┘
                             ▼
Vague 2   A Code de classe (Orch.)        C Accueil élève (Orch.)
          D Page d'accueil publique (T.)  E Écrans élève et Cours (K.)
          F « Mon compte » plein écran (K.)  G Accueil enseignant (T.)
          H Plafonds et retraits (K.)     I Classe et fiche d'un élève (K.)
          K Rapport d'un exercice (T.)    L Déclarer, assigner, jours de séance (K.)
                             │
Vague 3   B Inscription élève (Orch., dépend de A)
                             │
Vague 4   J Inscription enseignant (T., dépend de B)
                             │
Vague 5   Z Balayage des graisses, test des jetons, captures (Orch., dépend de tous)
```

| Vague | Lots | Agents ou personnes en parallèle | Quand |
|---|---|---|---|
| 1 | 0 ‖ P | 2 | samedi 24, matin |
| 2 | A ‖ C ‖ D ‖ E ‖ F ‖ G ‖ H ‖ I ‖ K ‖ L | 10 (Orch. : 2 agents ; Touré : 3 lots ; Konan : 5 lots, à la suite) | samedi 24 → dimanche 25 |
| 3 | B | 1 | dimanche 25 |
| 4 | J | 1 | dimanche 25 soir |
| 5 | Z | 1 | lundi 26 |

Touré et Konan enchaînent leurs lots de vague 2 dans l'ordre de la liste ci-dessus ; chacun reste un lot vertical, démontrable seul.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + navigation partagée
- **Fichiers**     : db/migrate/20261024090000_add_join_code_to_classrooms.rb · db/schema.rb
                     app/domain/entities/classroom/join_code.rb *(nouveau, calqué sur `school/school_code.rb`)*
                     app/domain/entities/classroom/classroom.rb *(attribut `join_code`)*
                     app/domain/ports/classroom/classroom_repository_port.rb *(`#find_by_join_code(code:)`, `#regenerate_link_and_code(...)` : contrats gelés)*
                     app/infrastructure/orm/classroom.rb
                     app/domain/entities/assessment/grading.rb *(`class_badge_for` : badge d'un élève dans une classe, UDR enseignant §3.2)*
                     config/routes/classroom.rb *(`GET /classroom-codes/:code`)* · config/routes/identity.rb *(`GET /profile/materials` : écran de retrait)*
                     config/initializers/pilot_flags.rb *(nouveau : `school_space_enabled`, éteint jusqu'au 2 novembre)*
                     config/locales/shared/navigation.fr.yml *(toutes les clés de « Mon compte » et du bandeau, textes des UDR)* · config/locales/shared/common.fr.yml *(`shared.subjects.short`)*
                     app/helpers/navigation_helper.rb *(`BOTTOM_TABS` élève et enseignant vidés, `HOME_SECTIONS[:teacher]` avec `:history`, `ACCOUNT_PANELS` des deux rôles, `role_fill_class`)*
                     app/views/layouts/shell.html.erb · app/views/shared/navigation/_header.html.erb · app/views/shared/navigation/_bottom_bar.html.erb
                     app/views/shared/navigation/_home_band.html.erb *(nouveau : bandeau des deux accueils, rôle en paramètre)*
                     test/fixtures/classrooms.yml *(un `join_code` par classe)*
- **Dépend de**    : —
- **Test associé** : test/domain/entities/classroom/join_code_test.rb · test/domain/entities/assessment/grading_test.rb · test/db/add_classroom_join_codes_migration_test.rb · test/helpers/navigation_helper_test.rb
- **Done quand**   : la migration passe et se rejoue à l'envers ; toute classe a un code au bon format (CA-B1) ; `class_badge_for` rend Diamant, Or, Argent, Bronze ou Pas encore selon la table de l'UDR (CA-G3) ; l'élève et l'enseignant n'ont plus de barre basse ni de lune dans l'en-tête ; l'entrée « Annonces » de l'enseignant a disparu (CA-K1) ; les routes nouvelles répondent (vide)
- **Gel** : les lots verticaux **implémentent** ces contrats. Un lot qui doit changer un port, une route, une clé de `navigation.fr.yml` ou une constante de `NavigationHelper` **s'arrête** et le Lot 0 rouvre.

## Lot P — Palette froide et texte sans gras (jetons)

- **Couche**       : ui (jetons, composants partagés)
- **Fichiers**     : app/assets/stylesheets/application.tailwind.css *(jetons de l'UDR palette §3.1 ; Bricolage Grotesque retiré)*
                     app/assets/fonts/ *(fichier Bricolage Grotesque supprimé)*
                     app/helpers/components_helper.rb *(`ui_button`, `ui_card`, `ui_badge`, `ui_field` sur les jetons ; `ui_progress(done:, total:, role:)` nouveau)*
                     app/helpers/assessment/badges_helper.rb *(`badge_pill(level, count:)`, `grade_class(score)` : vert ≥ 14/20, jamais rouge)*
                     test/helpers/components_helper_test.rb · test/helpers/assessment/badges_helper_test.rb
- **Dépend de**    : —
- **Test associé** : test/design/design_tokens_test.rb *(valeurs des jetons)* · test/helpers/assessment/badges_helper_test.rb
- **Done quand**   : l'app entière a un fond blanc, des gris froids et une seule police (CA-F1) ; une note de 13/20 s'affiche en encre, 14/20 en vert, jamais en rouge (CA-F3) ; `ui_progress` rend une barre bleue pour l'élève, jaune pour l'enseignant

---

## Lot A — Code de classe : vérifier, rejoindre, changer

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : app/domain/use_cases/classroom/register_student.rb *(résout la classe par le code, `joined_via: "code"`)*
                     app/domain/use_cases/classroom/join_as_student.rb *(élève connecté sans classe, par code)*
                     app/domain/use_cases/classroom/change_classroom_link.rb *(change le lien et le code ensemble)*
                     app/infrastructure/repositories/classroom/classroom_repository.rb
                     app/infrastructure/queries/classroom/join_code_preview_query.rb *(nouveau)*
                     app/controllers/classroom/classroom_codes_controller.rb *(nouveau, débit `classroom/joins`)*
                     app/controllers/classroom/student_classroom_choices_controller.rb *(accepte `code`)*
                     app/views/classroom/classroom_codes/show.html.erb *(nouveau : Turbo Frame d'aperçu, trouvée / inconnue / trop d'essais)*
                     config/locales/classroom/classroom_codes.fr.yml *(nouveau)* · config/locales/classroom/student_classroom_choices.fr.yml
                     test/controllers/classroom/student_registrations_controller_test.rb *(lignes 39 et suivantes de l'ADR-0085 : remplacées)*
- **Dépend de**    : Lot 0
- **Test associé** : test/integration/classroom/classroom_codes_test.rb · test/infrastructure/queries/classroom/join_code_preview_query_test.rb · test/domain/use_cases/classroom/change_classroom_link_test.rb · test/controllers/classroom/student_classroom_choices_controller_test.rb
- **Done quand**   : un code valide montre la classe, le niveau et l'établissement, rien d'autre (CA-B2) ; un code inconnu et une classe archivée répondent pareil (CA-B3) ; la 11ᵉ requête de la minute reçoit 429 (CA-B4) ; « Changer le lien » change aussi le code, journalisé, et l'ancien code devient inconnu (CA-B6) ; un élève connecté sans classe rejoint sa classe par le code (CA-D7, partie serveur)
- **Revue** : `security-reviewer` obligatoire avant fusion (ADR du code §6, ID-07).

## Lot B — Inscription élève en trois étapes

- **Couche**       : ui + delivery
- **Fichiers**     : app/javascript/controllers/classroom/signup_steps_controller.js *(nouveau ; repris par le Lot J)*
                     app/views/classroom/student_registrations/new.html.erb · app/views/classroom/student_registrations/_form.html.erb
                     app/views/classroom/joins/new.html.erb
                     app/controllers/classroom/student_registrations_controller.rb · app/controllers/classroom/joins_controller.rb *(étape de départ, lien invalide → étape 1)*
                     config/locales/classroom/student_registrations.fr.yml · config/locales/classroom/joins.fr.yml
- **Dépend de**    : Lot A
- **Test associé** : test/system/classroom/join_test.rb · test/system/identity/student_signup_steps_test.rb *(nouveau)* · test/controllers/classroom/joins_controller_test.rb
- **Done quand**   : un élève s'inscrit par le code, par le lien (arrivée à l'étape 2 avec le rappel de classe) et par la cascade, sans bouton « Continuer », avec passage automatique et retour sans perte (CA-C1 à CA-C5) ; une erreur serveur rouvre la bonne étape (CA-C6) ; sans JavaScript, le formulaire aboutit (CA-C7) ; la ligne « En créant ton compte, tu acceptes… » est sous le bouton (chantier `page-d-accueil-photo`)

## Lot C — Accueil élève : carte du prochain exercice

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : app/infrastructure/queries/classroom/student_home_query.rb *(état de la carte, 6 règles ; exercice du jour aussi quand tout est fait)*
                     app/controllers/classroom/student_homes_controller.rb
                     app/views/classroom/student_homes/show.html.erb · _next_step.html.erb *(nouveau)* · next_step/*.html.erb *(nouveaux, un par état)* · _subjects.html.erb · _history.html.erb *(remplace `_recent_activity`)*
                     *(supprimés : `_classroom_card`, `_todo`, `_assigned_exercise`, `_daily_exercise`, `_invite_teacher`, `_no_classroom`, `_recent_activity` ; `_pending_gaps` est déplacé par le Lot E, ce lot cesse seulement de le rendre)*
                     config/locales/classroom/student_homes.fr.yml
- **Dépend de**    : Lot 0, Lot P
- **Test associé** : test/infrastructure/queries/classroom/student_home_query_test.rb · test/system/classroom/student_home_test.rb · test/controllers/classroom/student_homes_controller_test.rb
- **Done quand**   : l'accueil montre bandeau, carte, grille de 7 cases, annonces, Historique, sans barre basse ni « Paiement » (CA-D1, CA-K3) ; les six états de la carte s'affichent chacun dans son cas (CA-D2 à CA-D7) ; le point de retard est sur la bonne matière (CA-D8) ; l'en-tête de la carte ouvre Ma classe (CA-D9)

## Lot D — Page d'accueil publique en photo

- **Couche**       : delivery + ui
- **Fichiers**     : app/controllers/homepage_controller.rb · app/views/homepage/index.html.erb · app/views/homepage/_role_modal.html.erb
                     app/assets/images/homepage/ *(photo WebP portrait et paysage)*
                     app/views/identity/school_staff_registrations/new.html.erb *(ligne des conditions)*
                     config/locales/homepage/index.fr.yml
- **Dépend de**    : Lot 0, Lot P
- **Test associé** : test/system/homepage_test.rb · test/controllers/homepage_controller_test.rb
- **Done quand**   : à 390 px et à 320 × 568, la page tient sur un écran avec la photo, « Tu comprends chap chap » et les deux entrées (CA-A1) ; « Espace établissement » est absent drapeau éteint et revient drapeau allumé (CA-A2) ; le reste selon le chantier [`page-d-accueil-photo`](../page-d-accueil-photo/memo.md)

## Lot E — Écrans élève sans répétition, et Cours (élève et enseignant)

- **Couche**       : ui + delivery
- **Fichiers**     : app/views/identity/profiles/show.html.erb · _student.html.erb · _student_identity.html.erb · _student_information.html.erb · _student_row.html.erb · _information.html.erb *(ligne Matières de l'enseignant sans action)*
                     app/views/classroom/student_classrooms/show.html.erb · app/views/classroom/student_classrooms/_pending_gaps.html.erb *(déplacé depuis `student_homes/`, ancien fichier supprimé)*
                     app/views/catalog/essentials/show.html.erb · app/views/assessment/session_results/show.html.erb
                     app/views/catalog/courses/index.html.erb · _course_card.html.erb · _essential_row.html.erb · _course_group_title.html.erb *(lignes compactes ; côté enseignant : « Cours de Tle D », sans menus Niveau et Série, puces de matière)*
                     app/controllers/catalog/courses_controller.rb
                     config/locales/identity/profiles.fr.yml · config/locales/classroom/student_classrooms.fr.yml · config/locales/catalog/courses.fr.yml · config/locales/catalog/essentials.fr.yml · config/locales/assessment/session_results.fr.yml
- **Dépend de**    : Lot 0, Lot P
- **Test associé** : test/system/identity/profile_test.rb · test/system/classroom/student_classroom_test.rb · test/system/classroom/classroom_essential_test.rb · test/controllers/catalog/courses_controller_test.rb · test/integration/assessment/session_result_test.rb
- **Done quand**   : le profil élève a six lignes, Classe sans action (CA-E2, CA-K2) ; Ma classe a « Fiches à revoir » (CA-E3) ; la fiche porte « À revoir depuis… » sans la carte du bas (CA-E4) ; le résultat n'a qu'un bouton (CA-E5) ; Cours écrit la progression une fois, en lignes de 44 px (CA-E6) ; un rond de niveau ouvre « Cours de Tle D » sans menus (CA-G5) ; la ligne Matières du profil enseignant n'a plus « Modifier » (CA-H6)

## Lot F — « Mon compte » en plein écran (élève et enseignant)

- **Couche**       : ui + delivery
- **Fichiers**     : app/views/shared/navigation/_account_panel.html.erb · app/views/shared/navigation/_avatar_menu.html.erb
                     app/views/classroom/student_menus/show.html.erb · app/views/classroom/teacher_menus/show.html.erb
                     app/controllers/classroom/student_menus_controller.rb · app/controllers/classroom/teacher_menus_controller.rb *(compteurs « N sur 3 »)*
                     *(aucun JavaScript nouveau : le panneau garde son `<dialog>` actuel, passé en plein écran ; `dropdown_controller.js`, partagé par toute l'app, n'est pas touché)*
- **Dépend de**    : Lot 0, Lot P
- **Test associé** : test/system/identity/account_panel_test.rb · test/system/identity/student_avatar_menu_test.rb · test/controllers/classroom/teacher_menus_controller_test.rb
- **Done quand**   : l'avatar ouvre un panneau plein écran ; élève : Mon profil, Modifier mon code secret, Mode sombre, Se déconnecter (CA-E1) ; enseignant : en-tête « Math · PC · sigle », les six entrées avec « N sur 3 », grisées à 3, sans « Inviter un collègue » (CA-H1) ; établissement en cours dès deux (CA-H2)

## Lot G — Accueil enseignant

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : app/infrastructure/queries/classroom/teacher_home_query.rb *(sigle, code, compteurs de badges par classe)*
                     app/infrastructure/queries/classroom/teacher_follow_ups_query.rb *(« cette semaine » et « historique » avec moyenne de classe, sans recouvrement)*
                     app/controllers/classroom/teacher_homes_controller.rb
                     app/views/classroom/teacher_homes/show.html.erb · _classroom_card.html.erb · _add_classroom_card.html.erb *(nouveau)* · _course_levels.html.erb · _follow_ups.html.erb · _history.html.erb *(nouveau)*
                     config/locales/classroom/teacher_homes.fr.yml
- **Dépend de**    : Lot 0, Lot P
- **Test associé** : test/infrastructure/queries/classroom/teacher_home_query_test.rb · test/infrastructure/queries/classroom/teacher_follow_ups_query_test.rb · test/system/classroom/teacher_home_test.rb
- **Done quand**   : sans classe, la carte « Ajoutez vos classes » et son bouton (CA-L1, partie accueil) ; l'accueil montre bandeau jaune, classes, niveaux et « Inviter », annonces, Cette semaine, Historique, sans barre basse ni « Bonjour » (CA-G1) ; la carte de classe montre effectif, exercices, badges sans zéro, code et « Copier » (CA-G2, CA-B5) ; « + Ajouter une classe » termine le carrousel (CA-G4) ; une assignation est dans une seule liste, avec « pas encore » ou « en retard » (CA-G6, CA-G7) ; 3 lignes puis « Voir plus » (CA-G8) ; les barres viennent du helper de rôle (CA-G9)

## Lot H — Plafonds et retraits (matières, établissements)

- **Couche**       : delivery + ui
- **Fichiers**     : app/controllers/identity/profile_materials_controller.rb *(action `show` : écran de retrait)*
                     app/views/identity/profile_materials/show.html.erb *(nouveau)* · app/views/identity/profile_materials/edit.html.erb
                     app/controllers/school/teacher_schools_controller.rb · app/views/school/teacher_schools/index.html.erb
                     config/locales/identity/profile_materials.fr.yml · config/locales/school/teacher_schools.fr.yml
- **Dépend de**    : Lot 0, Lot P
- **Test associé** : test/controllers/identity/profile_materials_controller_test.rb · test/system/identity/teacher_materials_test.rb · test/system/school/teacher_schools_test.rb
- **Done quand**   : à 3 matières, l'écran « Mes matières » retire une matière sans toucher aux exercices assignés (CA-H3) ; retirer un établissement confirmé archive ses classes et devoirs et le compteur passe à 2 sur 3 (CA-H4) ; la dernière matière et le dernier établissement n'ont pas de bouton, et une requête forgée est refusée (CA-H5)

## Lot I — Page de classe et fiche d'un élève

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : app/infrastructure/queries/classroom/classroom_overview_query.rb *(badge par élève, filtre `badge=`)* · app/infrastructure/queries/classroom/student_file_query.rb *(moyenne et badge de classe)*
                     app/controllers/classroom/classrooms_controller.rb · app/controllers/classroom/classroom_students_controller.rb
                     app/views/classroom/classrooms/show.html.erb · _header.html.erb · _link.html.erb *(« Changer le lien et le code »)* · _assigned_exercises.html.erb · _roster.html.erb · _roster_title.html.erb *(`_session_days` n'est plus rendu)*
                     app/views/classroom/classroom_students/show.html.erb · _identity.html.erb · _summary.html.erb · _assignments.html.erb
                     config/locales/classroom/classrooms.fr.yml · config/locales/classroom/classroom_students.fr.yml
- **Dépend de**    : Lot 0, Lot P
- **Test associé** : test/infrastructure/queries/classroom/classroom_overview_query_test.rb · test/infrastructure/queries/classroom/student_file_query_test.rb · test/system/classroom/classroom_page_test.rb · test/system/classroom/classroom_roster_test.rb · test/system/classroom/student_file_test.rb
- **Done quand**   : la page de classe n'a ni code ni « jours de séance », « 20 élèves » sans plafond (CA-I1) ; le filtre « Or » ne montre que les élèves Or, « Pas encore » ceux sans badge (CA-I2) ; la fiche montre le numéro masqué, « Moyenne 14/20 · Or » et les badges nommés, sans Fragile ni Acquis (CA-I3)

## Lot K — Rapport d'un exercice en badges

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : app/infrastructure/queries/classroom/assignment_follow_up_query.rb · app/infrastructure/queries/assessment/comprehension_summary_query.rb · app/infrastructure/queries/assessment/comprehension_detail_query.rb *(cases par badge, `?badge=`)*
                     app/controllers/classroom/assignment_follow_ups_controller.rb
                     app/views/classroom/assignment_follow_ups/show.html.erb · app/views/assessment/comprehension/_section.html.erb · _badge_counts.html.erb *(`_circle` supprimé)*
                     app/helpers/assessment/comprehension_helper.rb
                     config/locales/classroom/assignment_follow_ups.fr.yml · config/locales/assessment/comprehension.fr.yml *(prochain geste en badges)*
- **Dépend de**    : Lot 0, Lot P
- **Test associé** : test/infrastructure/queries/classroom/assignment_follow_up_query_test.rb · test/system/classroom/comprehension_test.rb · test/controllers/classroom/assignment_follow_ups_controller_test.rb
- **Done quand**   : le rapport montre « 20 / 27 faits », la pastille de retard et cinq cases par badge qui filtrent la liste (CA-I4) ; le prochain geste parle en badges (CA-I5) ; la direction et l'équipe voient le même rapport

## Lot L — Premier parcours enseignant : déclarer ses classes, assigner, jours de séance

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : app/domain/dtos/classroom/assignment_input.rb *(`later` retiré : un jour au moins)*
                     app/controllers/classroom/assignments_controller.rb · app/controllers/classroom/session_days_controller.rb
                     app/views/classroom/assignments/new.html.erb · app/views/classroom/assignments/_toggle.html.erb · app/views/classroom/session_days/edit.html.erb
                     app/views/catalog/essentials/_exercise_progress.html.erb *(lignes par classe ; « Modifier les jours de la … »)*
                     app/views/classroom/teaching_selections/index.html.erb · app/views/classroom/teaching_selections/_level_group.html.erb
                     app/javascript/controllers/classroom/next_session_controller.js *(nouveau : « Prochaine séance : … »)*
                     config/locales/classroom/assignments.fr.yml · config/locales/classroom/session_days.fr.yml · config/locales/classroom/teaching_selections.fr.yml
- **Dépend de**    : Lot 0, Lot P
- **Test associé** : test/domain/dtos/classroom/assignment_input_test.rb · test/controllers/classroom/assignments_controller_test.rb · test/system/classroom/catalog_assignment_test.rb · test/system/classroom/teaching_selection_test.rb
- **Done quand**   : « Quelles classes enseignez-vous ? » coche des classes et met le compteur à jour (CA-L1, partie déclaration) ; la fiche montre une ligne par classe, un seul bouton plein (CA-L2) ; la fenêtre des jours n'a plus « Plus tard » et refuse l'envoi sans jour (CA-L3) ; « Modifier les jours » rouvre la fenêtre et enregistre (CA-L4)

## Lot J — Inscription enseignant en trois étapes, une matière

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : app/domain/use_cases/identity/register_teacher.rb · app/domain/dtos/identity/teacher_registration_input.rb *(`second_material_slug` retiré)*
                     app/controllers/identity/teacher_registrations_controller.rb
                     app/views/identity/teacher_registrations/new.html.erb · _form.html.erb · _school_fields.html.erb · _school_preview.html.erb
                     config/locales/identity/teacher_registrations.fr.yml
- **Dépend de**    : Lot B *(réutilise `signup_steps_controller.js` sans le modifier)*
- **Test associé** : test/domain/use_cases/identity/register_teacher_test.rb · test/controllers/identity/teacher_registrations_controller_test.rb · test/system/identity/teacher_signup_test.rb
- **Done quand**   : sans lien, l'inscription commence à l'étape 1 et passe seule à l'étape 2 (CA-J1) ; le lien d'invitation ouvre l'étape 2 avec le rappel d'établissement (CA-J2) ; une seule matière, sans « Autre matière » ni dans le formulaire ni dans le DTO (CA-J3) ; le compte est créé et mène à l'accueil (CA-J4) ; la ligne des conditions est sous le bouton

## Lot Z — Balayage des graisses, test des jetons, captures

- **Couche**       : ui (garde-fous)
- **Fichiers**     : test/design/design_tokens_test.rb *(refus de `font-semibold`, `font-bold`, `font-extrabold`, `font-black` dans `app/views` et `app/helpers`, sauf `app/views/homepage/`)*
                     les fichiers de `app/views/` et `app/helpers/` **hors des lots A à K** qui contiennent encore une graisse interdite (direction, équipe, pages publiques, composants) — liste produite par `grep -rlE 'font-(semibold|bold|extrabold|black)' app/views app/helpers` sur la branche de chantier, une fois les lots fusionnés
- **Dépend de**    : tous les lots
- **Test associé** : test/design/design_tokens_test.rb
- **Done quand**   : aucun texte au-dessus de 500 hors page d'accueil publique, et le test le refuse (CA-F2) ; captures à 390 px et sur ordinateur de chaque écran modifié, direction et équipe comprises, envoyées au porteur (CLAUDE.md, UDR palette §4)

---

## Rattachement des critères du PRD

| Critères | Lot |
|---|---|
| CA-A1, CA-A2 | D (drapeau posé par 0) |
| CA-B1 | 0 |
| CA-B2, CA-B3, CA-B4, CA-B6 | A |
| CA-B5 | G |
| CA-C1 à CA-C7 | B |
| CA-D1 à CA-D9 | C (CA-D7 : affichage C, adhésion A) |
| CA-E1 | F |
| CA-E2 à CA-E6 | E |
| CA-F1, CA-F3 | P |
| CA-F2 | Z |
| CA-G1, CA-G2, CA-G4, CA-G6 à CA-G9 | G |
| CA-G3 | 0 (règle) et G (affichage) |
| CA-G5 | E |
| CA-H1, CA-H2 | F |
| CA-H3, CA-H4, CA-H5 | H |
| CA-H6 | E |
| CA-I1, CA-I2, CA-I3 | I |
| CA-I4, CA-I5 | K |
| CA-J1 à CA-J4 | J |
| CA-K1 | 0 |
| CA-K2 | E |
| CA-K3 | C |
| CA-L1 | G (accueil) et L (déclaration) |
| CA-L2, CA-L3, CA-L4 | L |

Aucun critère orphelin.

## Vérification de collision

Doublons cherchés mécaniquement (`awk … | sort | uniq -d`, vide). Fichiers partagés et leur seul propriétaire :

| Fichier | Lot propriétaire | Remarque |
|---|---|---|
| `config/routes/classroom.rb`, `config/routes/identity.rb` | 0 | aucune route ajoutée ailleurs |
| `config/locales/shared/navigation.fr.yml`, `shared/common.fr.yml` | 0 | F, G et C lisent ces clés sans les écrire |
| `config/initializers/pilot_flags.rb` | 0 | D lit le drapeau |
| `app/helpers/navigation_helper.rb` | 0 | `role_fill_class`, onglets, panneaux |
| `app/views/layouts/shell.html.erb`, `shared/navigation/_header`, `_bottom_bar`, `_home_band` | 0 | C et G rendent `_home_band` sans le modifier |
| `test/fixtures/classrooms.yml` | 0 | un lot qui a besoin d'une fixture partagée nouvelle remonte au Lot 0 |
| `db/schema.rb`, `db/migrate/…` | 0 | aucune autre migration dans le chantier |
| `app/domain/entities/assessment/grading.rb` | 0 | G, I, K appellent `class_badge_for` |
| `app/assets/stylesheets/application.tailwind.css` | P | |
| `app/helpers/components_helper.rb` | P | `ui_progress` utilisé par C, G, I, K |
| `app/helpers/assessment/badges_helper.rb` | P | `badge_pill` utilisé par G, I, K |
| `app/javascript/controllers/classroom/signup_steps_controller.js` | B | J le réutilise sans le modifier (vague suivante) |
| `app/views/classroom/student_homes/_pending_gaps.html.erb` | E | C cesse de le rendre ; E le déplace et le supprime |
| `app/views/catalog/courses/index.html.erb` et partiels | E | Cours élève et enseignant dans le même lot |
| `app/views/identity/profiles/_information.html.erb` | E | ligne Matières de l'enseignant |
| `app/views/classroom/classrooms/_link.html.erb` | I | A change le use case, I le libellé |
| `app/views/catalog/essentials/_exercise_progress.html.erb` | L | E garde `essentials/show.html.erb` sans toucher au partiel |
| `app/infrastructure/repositories/classroom/classroom_repository.rb` | A | |
| `test/design/design_tokens_test.rb` | P (valeurs), puis Z (graisses) | vagues différentes, pas en parallèle |

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

Portes propres au pilote :

- [ ] `security-reviewer` sur le Lot A avant sa fusion (code de classe, ID-07)
- [ ] Captures à 390 px et sur ordinateur de chaque écran modifié, envoyées au porteur, jamais commitées (Lot Z)
- [ ] Essai des deux apps Android sur un vrai téléphone avant le 27
- [ ] Retour de l'« Espace établissement » le 2 novembre : drapeau `school_space_enabled` allumé, commit daté prévu

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Pour ce chantier : parcours élève (lien WhatsApp → inscription → accueil → exercice → résultat) et enseignant (invitation → classe → code → assigner → rapport), sur un téléphone de 390 px ; chemins d'erreur : code inconnu, 11ᵉ essai dans la minute, lien régénéré, retrait de la dernière matière.
