# Plan d'exécution — MVP Lnclass Teacher & Student — **enseignant**

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot). Critères : [`prd-enseignant.md`](prd-enseignant.md) §4. Écrans : [UDR enseignant](../../decisions/udr/XXXX-ecrans-enseignant-sans-repetition.md) et [`carte-des-ecrans.md`](carte-des-ecrans.md).
>
> Suite du [plan élève](plan.md), même branche de chantier (`feature/mvp-teacher-student`) et même PR (#295). Les lots enseignant partent **après** les lots élève dont ils dépendent : ils lisent leurs fichiers sans les modifier. Repris des lots G à L de l'ancien plan (`c766532`), recalés sur ce que le Lot 0 et l'ancien Lot A ont déjà livré.

**Téléphone d'abord**, comme pour l'élève : les versions ordinateur (UDR enseignant §3.3, §3.4, §3.5, §3.8, et les écrans encore à dessiner) viennent après ([`prd-enseignant.md`](prd-enseignant.md) §4 bis).

**Même organisation que l'élève** : la session « MVP teacher-student » est la seule à fusionner dans la branche de chantier ; chaque lot fusionne après ses captures (390 px et ordinateur) validées par le porteur.

**Calendrier : tout avant le pilote** (porteur, 2026-10-24 : « B, rien ne doit être en retard »). Pour tenir, l'orchestrateur reprend J et L et lance ses lots en agents parallèles ; Touré et Konan enchaînent un lot élève puis deux lots enseignant chacun ; le lot A est repris par l'orchestrateur (porteur, 2026-10-24 : abonnement Max du porteur, Pro pour Touré et Konan).

| Lot | Pilote | Dépend de | Issue | Quand |
|---|---|---|---|---|
| J — Inscription enseignant en 3 étapes | orchestrateur | A, C | #289 | dimanche 25 |
| L — Premier parcours : déclarer, assigner, jours de séance | orchestrateur | A | #294 | dimanche 25 |
| K — Rapport d'un exercice en badges | Touré (`toure-bangaly`) | A | #288 | dimanche 25, après E1 |
| H — Plafonds et retraits (matières, établissements) | Konan (`konanmeschac777-cmyk`) | A | #292 | dimanche 25, après E2 |
| G — Accueil enseignant | Touré | A, D | #287 | lundi 26, matin |
| I — Page de classe et fiche d'un élève | Konan | A ; fusionne après G | #293 | lundi 26, matin |
| M — « Mon compte » enseignant | orchestrateur | E1 | — | lundi 26, matin |
| N — Cours de l'enseignant | orchestrateur | E2 | — | lundi 26, matin |

**Lundi 26, 14 h** : tous les lots fusionnés, `bin/ci-quiet` sur le head final, preuve dans #295. **Lundi 26, après-midi** : recette du porteur sur un vrai Android (élève et enseignant). **Mardi 27** : pilote.

**Si un lot glisse** : on ne repousse pas la date, on réduit le lot. Le lot qui glisse garde son critère principal (G : la carte et son code ; I : la classe sans code ni jours de séance ; K : les cases par badge) et reporte le reste dans `journal.md`, avec l'accord du porteur.

**Déjà livré, à ne pas refaire** : navigation sans barre basse, panneau « Mon compte » enseignant (structure et clés de `navigation.fr.yml`), menu sans « Annonces », annonces de l'enseignant fermées (CA-K1), `Grading.class_badge_for` (CA-G3, règle), « Changer le lien et le code » (CA-B6), `ui_progress` et `badge_pill` (Lot A, branche `-lot-p`), `role_fill_class`.

## Graphe

```
Lots élève :   A Jetons ──────────────┬───────────────┬──────────┐        C Inscription élève
                  │                   │               │          │            │
               D Accueil élève     E1 Mon compte   E2 Ma classe  │            │
                  │                   │            et Cours      │            │
                  ▼                   ▼               ▼          ▼            ▼
Lots ens. :    G Accueil ens.      M Mon compte    N Cours ens.  H ‖ K ‖ L    J Inscription ens.
                  │
                  ▼
               I Classe et fiche (fusionne après G)
```

| Vague | Lots | En parallèle | Quand |
|---|---|---|---|
| T1 | J ‖ L ‖ K ‖ H | 4 (orchestrateur ×2, Touré, Konan) | dimanche 25, dès la fusion de A |
| T2 | G ‖ I ‖ M ‖ N | 4 (Touré, Konan, orchestrateur ×2) | lundi 26, matin, après D, E1 et E2 |

J attend A, et pas seulement C : ses vues sont dans le balayage des graisses de A.

---

## Lot G — Accueil enseignant

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : app/infrastructure/queries/classroom/teacher_home_query.rb *(sigle, code, compteurs de badges par classe)*
                     app/infrastructure/queries/classroom/teacher_follow_ups_query.rb *(« cette semaine » et « historique » avec moyenne de classe, sans recouvrement)*
                     app/controllers/classroom/teacher_homes_controller.rb
                     app/views/classroom/teacher_homes/show.html.erb · _classroom_card.html.erb · _add_classroom_card.html.erb *(nouveau)* · _course_levels.html.erb · _follow_ups.html.erb · _history.html.erb *(nouveau)*
                     config/locales/classroom/teacher_homes.fr.yml
                     *(rend `shared/navigation/_home_band` en rôle enseignant sans le modifier : il appartient à D)*
- **Dépend de**    : A, D
- **Test associé** : test/infrastructure/queries/classroom/teacher_home_query_test.rb · test/infrastructure/queries/classroom/teacher_follow_ups_query_test.rb · test/system/classroom/teacher_home_test.rb
- **Done quand**   : sans classe, la carte « Ajoutez vos classes » et son bouton (CA-L1, partie accueil) ; l'accueil montre bandeau jaune, classes, niveaux et « Inviter », annonces, Cette semaine, Historique, sans barre basse ni « Bonjour » (CA-G1) ; la carte de classe montre effectif, exercices, badges sans zéro, code et « Copier » (CA-G2, CA-B8 partie accueil) ; badges de classe affichés (CA-G3) ; « + Ajouter une classe » termine le carrousel (CA-G4) ; une assignation dans une seule liste, « pas encore » ou « en retard » (CA-G6, CA-G7) ; 3 lignes puis « Voir plus » (CA-G8) ; couleurs du helper de rôle (CA-G9)

## Lot K — Rapport d'un exercice en badges

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : app/infrastructure/queries/classroom/assignment_follow_up_query.rb · app/infrastructure/queries/assessment/comprehension_summary_query.rb · app/infrastructure/queries/assessment/comprehension_detail_query.rb *(cases par badge, `?badge=`)*
                     app/controllers/classroom/assignment_follow_ups_controller.rb
                     app/views/classroom/assignment_follow_ups/show.html.erb · app/views/assessment/comprehension/_section.html.erb · _badge_counts.html.erb *(nouveau ; `_circle` supprimé)*
                     app/helpers/assessment/comprehension_helper.rb
                     config/locales/classroom/assignment_follow_ups.fr.yml · config/locales/assessment/comprehension.fr.yml *(prochain geste en badges)*
- **Dépend de**    : A
- **Test associé** : test/infrastructure/queries/classroom/assignment_follow_up_query_test.rb · test/system/classroom/comprehension_test.rb · test/controllers/classroom/assignment_follow_ups_controller_test.rb
- **Done quand**   : le rapport montre « 20 / 27 faits », la pastille de retard et cinq cases par badge qui filtrent la liste (CA-I4) ; le prochain geste parle en badges (CA-I5) ; la direction et l'équipe voient le même rapport

## Lot H — Plafonds et retraits (matières, établissements)

- **Couche**       : delivery + ui
- **Fichiers**     : app/controllers/identity/profile_materials_controller.rb *(action `show` : écran de retrait ; la route `GET /profile/materials` existe déjà)*
                     app/views/identity/profile_materials/show.html.erb *(nouveau)* · app/views/identity/profile_materials/edit.html.erb
                     app/controllers/school/teacher_schools_controller.rb · app/views/school/teacher_schools/index.html.erb
                     config/locales/identity/profile_materials.fr.yml · config/locales/school/teacher_schools.fr.yml
- **Dépend de**    : A
- **Test associé** : test/controllers/identity/profile_materials_controller_test.rb · test/system/identity/teacher_materials_test.rb · test/system/school/teacher_schools_test.rb
- **Done quand**   : à 3 matières, l'écran « Mes matières » retire une matière sans toucher aux exercices assignés (CA-H3) ; retirer un établissement confirmé archive ses classes et devoirs, et le compteur passe à 2 sur 3 (CA-H4) ; la dernière matière et le dernier établissement n'ont pas de bouton, et une requête forgée est refusée (CA-H5)

## Lot I — Page de classe et fiche d'un élève

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : app/infrastructure/queries/classroom/classroom_overview_query.rb *(badge par élève, filtre `badge=`)* · app/infrastructure/queries/classroom/student_file_query.rb *(moyenne et badge de classe)*
                     app/controllers/classroom/classrooms_controller.rb · app/controllers/classroom/classroom_students_controller.rb
                     app/views/classroom/classrooms/show.html.erb · _header.html.erb · _link.html.erb *(ligne provisoire du code de B2 retirée)* · _assigned_exercises.html.erb · _roster.html.erb · _roster_title.html.erb *(`_session_days` n'est plus rendu)*
                     app/views/classroom/classroom_students/show.html.erb · _identity.html.erb · _summary.html.erb · _assignments.html.erb
                     config/locales/classroom/classrooms.fr.yml · config/locales/classroom/classroom_students.fr.yml
- **Dépend de**    : A *(fusionne après G : la ligne provisoire du code ne part qu'une fois le code sur la carte de l'accueil)*
- **Test associé** : test/infrastructure/queries/classroom/classroom_overview_query_test.rb · test/infrastructure/queries/classroom/student_file_query_test.rb · test/system/classroom/classroom_page_test.rb · test/system/classroom/classroom_roster_test.rb · test/system/classroom/student_file_test.rb
- **Done quand**   : la page de classe n'a ni code ni « jours de séance », « 20 élèves » sans plafond (CA-I1, CA-B8 partie classe) ; le filtre « Or » ne montre que les élèves Or, « Pas encore » ceux sans badge (CA-I2) ; la fiche montre le numéro masqué, « Moyenne 14/20 · Or » et les badges nommés, sans Fragile ni Acquis (CA-I3)

## Lot L — Premier parcours : déclarer ses classes, assigner, jours de séance

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : app/domain/dtos/classroom/assignment_input.rb *(`later` retiré : un jour au moins)*
                     app/controllers/classroom/assignments_controller.rb · app/controllers/classroom/session_days_controller.rb
                     app/views/classroom/assignments/new.html.erb · app/views/classroom/assignments/_toggle.html.erb · app/views/classroom/session_days/edit.html.erb
                     app/views/catalog/essentials/_exercise_progress.html.erb *(lignes par classe ; « Modifier les jours de la … » ; E2 garde `essentials/show.html.erb` sans toucher au partiel)*
                     app/views/classroom/teaching_selections/index.html.erb · app/views/classroom/teaching_selections/_level_group.html.erb
                     app/javascript/controllers/classroom/next_session_controller.js *(nouveau : « Prochaine séance : … »)*
                     config/locales/classroom/assignments.fr.yml · config/locales/classroom/session_days.fr.yml · config/locales/classroom/teaching_selections.fr.yml
- **Dépend de**    : A
- **Test associé** : test/domain/dtos/classroom/assignment_input_test.rb · test/controllers/classroom/assignments_controller_test.rb · test/system/classroom/catalog_assignment_test.rb · test/system/classroom/teaching_selection_test.rb
- **Done quand**   : « Quelles classes enseignez-vous ? » coche des classes et met le compteur à jour (CA-L1, partie déclaration) ; la fiche montre une ligne par classe, un seul bouton plein (CA-L2) ; la fenêtre des jours n'a plus « Plus tard » et refuse l'envoi sans jour (CA-L3) ; « Modifier les jours » rouvre la fenêtre et enregistre (CA-L4)

## Lot J — Inscription enseignant en trois étapes, une matière

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : app/domain/use_cases/identity/register_teacher.rb · app/domain/dtos/identity/teacher_registration_input.rb *(`second_material_slug` retiré)*
                     app/controllers/identity/teacher_registrations_controller.rb
                     app/views/identity/teacher_registrations/new.html.erb · _form.html.erb · _school_fields.html.erb · _school_preview.html.erb
                     config/locales/identity/teacher_registrations.fr.yml
- **Dépend de**    : A, C *(réutilise `signup_steps_controller.js` sans le modifier ; ses vues sont dans le balayage de A)*
- **Test associé** : test/domain/use_cases/identity/register_teacher_test.rb · test/controllers/identity/teacher_registrations_controller_test.rb · test/system/identity/teacher_signup_test.rb
- **Done quand**   : sans lien, l'inscription commence à l'étape 1 et passe seule à l'étape 2 (CA-J1) ; le lien d'invitation ouvre l'étape 2 avec le rappel d'établissement (CA-J2) ; une seule matière, sans « Autre matière » ni dans le formulaire ni dans le DTO (CA-J3) ; le compte est créé et mène à l'accueil (CA-J4) ; la ligne des conditions est sous le bouton

## Lot M — « Mon compte » enseignant

- **Couche**       : ui + delivery
- **Fichiers**     : app/views/shared/navigation/_account_panel.html.erb *(plein écran)*
                     app/views/classroom/teacher_menus/show.html.erb · app/controllers/classroom/teacher_menus_controller.rb *(compteurs « N sur 3 »)*
                     app/helpers/navigation_helper.rb *(`ACCOUNT_PANELS[:teacher]` seulement)*
                     app/views/identity/profiles/_information.html.erb *(ligne Matières sans « Modifier »)*
- **Dépend de**    : E1 *(`navigation_helper.rb` est à E1 pendant la vague élève)*
- **Test associé** : test/system/identity/account_panel_test.rb · test/controllers/classroom/teacher_menus_controller_test.rb · test/system/identity/profile_test.rb
- **Done quand**   : l'avatar ouvre un panneau plein écran avec nom, « Math · PC · sigle », les six entrées avec « N sur 3 », grisées à 3, sans « Inviter un collègue » (CA-H1) ; établissement en cours dès deux (CA-H2) ; la ligne Matières du profil n'a plus « Modifier » (CA-H6)

## Lot N — Cours de l'enseignant

- **Couche**       : delivery + ui
- **Fichiers**     : app/controllers/catalog/courses_controller.rb *(filtre `level`, `series` venu du rond de niveau)*
                     app/views/catalog/courses/index.html.erb · _course_card.html.erb · _essential_row.html.erb · _course_group_title.html.erb *(branche enseignant : « Cours de Tle D », sans menus Niveau et Série, puces de matière)*
                     config/locales/catalog/courses.fr.yml
- **Dépend de**    : E2 *(mêmes vues que le Cours de l'élève)*
- **Test associé** : test/controllers/catalog/courses_controller_test.rb · test/system/catalog/teacher_courses_test.rb *(nouveau)*
- **Done quand**   : un rond de niveau ouvre « Cours de Tle D », « ‹ Accueil », sans menus Niveau ni Série, sans « Tle D » sur chaque ligne ; un bivalent voit les puces de matière (CA-G5) ; le Cours de l'élève ne change pas

---

## Rattachement des critères du PRD enseignant

| Critères | Lot |
|---|---|
| CA-B6, CA-G3 (règle), CA-K1 | déjà livrés (PRD enseignant §4) |
| CA-B8 | G (carte) et I (ligne provisoire retirée) |
| CA-G1, CA-G2, CA-G3 (affichage), CA-G4, CA-G6 à CA-G9 | G |
| CA-G5 | N |
| CA-H1, CA-H2, CA-H6 | M |
| CA-H3, CA-H4, CA-H5 | H |
| CA-I1, CA-I2, CA-I3 | I |
| CA-I4, CA-I5 | K |
| CA-J1 à CA-J4 | J |
| CA-L1 | G (accueil) et L (déclaration) |
| CA-L2, CA-L3, CA-L4 | L |

Aucun critère orphelin.

## Vérification de collision

Doublons cherchés mécaniquement entre lots enseignant (`awk … | sort | uniq -d` : seuls les fichiers de test associés à leur propre lot). Fichiers partagés avec les lots élève, et leur règle :

| Fichier | Propriétaire | Règle |
|---|---|---|
| `shared/navigation/_home_band.html.erb` | D (élève) | G le rend sans le modifier, après la fusion de D |
| `app/helpers/navigation_helper.rb`, `config/locales/shared/navigation.fr.yml` | E1 puis M | M part après la fusion de E1 et ne touche que `ACCOUNT_PANELS[:teacher]` ; les clés existent déjà |
| `app/views/catalog/courses/*`, `courses.fr.yml` | E2 puis N | N part après la fusion de E2 |
| `app/views/catalog/essentials/_exercise_progress.html.erb` | L | E2 garde `essentials/show.html.erb` sans toucher au partiel |
| `app/views/classroom/classrooms/_link.html.erb`, `classrooms.fr.yml` | B2 puis I | I part après B2 et fusionne après G |
| `app/views/identity/profiles/_information.html.erb` | M | E1 ne touche que les partiels `_student*` et `show` |
| `app/javascript/controllers/classroom/signup_steps_controller.js` | C | J le réutilise sans le modifier |
| `app/helpers/components_helper.rb`, `assessment/badges_helper.rb`, `application.tailwind.css` | A | `ui_progress`, `badge_pill` utilisés par G, I, K sans les modifier |

## Ordre de fusion

1. **H, K, L, J** dans l'ordre où ils sont prêts.
2. **G** après D ; **I** après G (le code passe de la page de classe à la carte de l'accueil sans trou).
3. **M** après E1 ; **N** après E2.

## Portes de sortie

Celles du [plan élève](plan.md#portes-de-sortie), plus :

- [ ] Captures enseignant à 390 px et sur ordinateur (accueil, « Mon compte », classe, fiche, rapport, Cours, inscription, retraits), validées par le porteur, jamais commitées
- [ ] Essai de l'app Android Lnclass Teacher sur un vrai téléphone

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.**
>
> Pour l'enseignant : invitation → inscription en 3 étapes → déclarer ses classes → code sur la carte → assigner (jours de séance) → Cette semaine → rapport ; chemins d'erreur : retrait de la dernière matière, requête de retrait forgée, assigner sans jour coché.


---

## Phase ordinateur — enseignant

> Ajoutée le 2026-10-24, après les lots téléphone (« téléphone d'abord, ordinateur ensuite »). Écrans : sous-sections « Sur ordinateur (≥ lg) » de l'[UDR enseignant](../../decisions/udr/XXXX-ecrans-enseignant-sans-repetition.md) ; critères : [`prd-enseignant.md`](prd-enseignant.md) §4 bis. Chaque lot ne touche que des classes `lg:` (le rendu sous 1024 px ne bouge pas) et se montre au porteur en captures à 1440 et 1024 px, plus 390 px pour prouver que le téléphone n'a pas bougé.
>
> **Ne change rien au téléphone** (porteur, 2026-10-24) : les lots P ne touchent qu'à la mise en page ≥ lg ; les écrans téléphone validés le 2026-10-23 (lots G à N) font foi.

**Fichiers partagés avec la phase ordinateur de l'élève** (autre session) : le panneau « Mon compte » à droite de 400 px est décidé pour les deux rôles (UDR enseignant §3.4, UDR écrans élève). Aujourd'hui, `_account_panel` s'ouvre en `placement: :drawer`, qui est un tiroir **à gauche** de 20 rem (`dialog.dialog-drawer`, `application.tailwind.css`). Le placement à droite de 25 rem, `_account_panel.html.erb`, `_sidebar.html.erb`, `navigation_helper.rb` et `application.tailwind.css` ne doivent avoir **qu'un lot propriétaire pour les deux rôles**. P0 est ce lot si la phase élève ne l'a pas déjà pris ; sinon P0 attend le sien et ne garde que les écrans de retrait.

| Lot | Écran | Dépend de |
|---|---|---|
| P0 | Panneau « Mon compte » à droite, barre latérale, écrans de retrait dans le panneau | M, H ; lot équivalent de l'élève s'il existe |
| P1 | Accueil en page large | G |
| P2 | Page de classe et fiche d'un élève | I ; fusionne après P1 |
| P3 | Rapport d'un exercice | K |
| P4 | Inscription | J |
| P5 | Cours, colonne de 40 rem | N |
| P6 | Déclarer, assigner, jours de séance | L |

Aucun lot de P1 à P6 ne touche un fichier de P0 (vérifié sur la branche de chantier : la barre latérale prend son entrée active de `content_for :nav_key`, posé par chaque vue) : ils ne dépendent donc pas de P0.

```
P0 (M, H, lot élève équivalent)
P1 (G) ── P2 (I)
P3 (K)   P4 (J)   P5 (N)   P6 (L)
```

Vagues : **O1** = P0 ‖ P1 ‖ P3 ‖ P4 ‖ P5 ‖ P6 ; **O2** = P2 (après P1, comme I après G).

### Lot P0 — Panneau « Mon compte » à droite, barre latérale, écrans de retrait dans le panneau

- **Couche**       : ui
- **Fichiers**     : app/assets/stylesheets/application.tailwind.css *(placement à droite de 25 rem à ≥ lg, plein écran dessous ; nouveau placement dans `MODAL_PLACEMENTS`, sans toucher à `dialog-drawer`)*
                     app/helpers/components_helper.rb *(`MODAL_PLACEMENTS` seulement)*
                     app/views/shared/navigation/_account_panel.html.erb *(nouveau placement)*
                     app/views/shared/navigation/_sidebar.html.erb *(enseignant : sans carte de profil)*
                     app/helpers/navigation_helper.rb *(`SIDEBAR_FRAMES[:teacher]` vidé : « Inviter » n'est que dans la grille, UDR §2)*
                     app/views/identity/profile_materials/show.html.erb · app/views/school/teacher_schools/index.html.erb *(écrans de retrait du lot H, rendus dans le panneau : frame du panneau, « ‹ Mon compte » qui y revient)*
- **Dépend de**    : M, H ; le lot de la phase ordinateur élève qui pose le panneau à droite, s'il existe
- **Test associé** : test/system/shared/teacher_account_panel_desktop_test.rb
- **Done quand**   : à 1280 px, l'avatar ouvre « Mon compte » à droite sur 400 px ; « Ajouter une matière » à 3 sur 3 ouvre « Mes matières » dans le même panneau ; un retrait garde le panneau ouvert avec « 2 sur 3 » ; la barre latérale enseignant n'a ni carte de profil ni « Inviter » ; à 390 px, rien ne change (CA-H7, CA-G11)

### Lot P1 — Accueil en page large

- **Couche**       : ui
- **Fichiers**     : app/views/classroom/teacher_homes/show.html.erb · _classroom_card.html.erb · _add_classroom_card.html.erb · _course_levels.html.erb · _follow_ups.html.erb · _history.html.erb
- **Dépend de**    : G
- **Test associé** : test/system/classroom/teacher_home_desktop_test.rb
- **Done quand**   : à 1280 px, contenu de 57 rem, bandeau sans avatar ni aide, cartes de classe en grille de 3 avec « + Ajouter une classe » en dernier, « Cette semaine » et « Historique » côte à côte avec titres visibles (UDR §3.3)

### Lot P2 — Page de classe et fiche d'un élève

- **Couche**       : ui
- **Fichiers**     : app/views/classroom/classrooms/show.html.erb · _link.html.erb · _assigned_exercises.html.erb · _gaps.html.erb · _roster_title.html.erb · _roster.html.erb
                     app/views/classroom/classroom_students/show.html.erb · _summary.html.erb · _manage.html.erb · _assignments.html.erb · _self_practice.html.erb
- **Dépend de**    : I ; fusionne après P1
- **Test associé** : test/system/classroom/classroom_desktop_test.rb
- **Done quand**   : à 1280 px, la page de classe a deux colonnes égales (UDR §3.5) et la fiche d'un élève a le résumé et la gestion à gauche, les exercices et « Fait seul » à droite, « Mes classes » actif (CA-I6)

### Lot P3 — Rapport d'un exercice

- **Couche**       : ui
- **Fichiers**     : app/views/classroom/assignment_follow_ups/show.html.erb
                     app/views/assessment/comprehension/_section.html.erb
- **Dépend de**    : K
- **Test associé** : test/system/classroom/assignment_follow_up_desktop_test.rb
- **Done quand**   : à 1280 px, « Voir l'exercice » est à droite du titre ; progression, cases par badge, prochain geste et questions à gauche, élèves à droite (UDR §3.8)

### Lot P4 — Inscription

- **Couche**       : ui
- **Fichiers**     : app/views/identity/teacher_registrations/new.html.erb · _form.html.erb
- **Dépend de**    : J
- **Test associé** : test/system/identity/teacher_registration_desktop_test.rb
- **Done quand**   : à 1280 px, deux colonnes, panneau gauche `bg-teacher` avec « Bienvenue sur Lnclass » une seule fois, trois étapes à droite sur 28 rem ; avec un lien d'invitation, ouverture à l'étape 2 (CA-J5, CA-J6)

### Lot P5 — Cours, colonne de 40 rem

Le lot P5 ne fait que la mise en page ordinateur :

- **Couche**       : ui
- **Fichiers**     : app/views/catalog/courses/index.html.erb · _course_card.html.erb *(branche enseignant)*
- **Dépend de**    : N
- **Test associé** : test/system/catalog/teacher_courses_test.rb *(cas à 1280 px ajouté)*
- **Done quand**   : à 1280 px, Cours est une colonne de 40 rem, cartes dans l'ordre de la progression, « Cours » actif (CA-N2) ; à 390 px, rien ne change par rapport à N

### Lot P6 — Déclarer, assigner, jours de séance

- **Couche**       : ui
- **Fichiers**     : app/views/classroom/teaching_selections/index.html.erb · _level_group.html.erb
                     app/views/catalog/essentials/show.html.erb · _exercise_progress.html.erb
                     app/views/classroom/assignments/new.html.erb · _toggle.html.erb
                     app/views/classroom/session_days/edit.html.erb
- **Dépend de**    : L
- **Test associé** : test/system/classroom/teacher_first_path_desktop_test.rb
- **Done quand**   : à 1280 px, les niveaux sont sur deux colonnes avec « Terminer » à droite et « Mes classes » actif (CA-L5), la colonne « Exercices » reste visible au défilement (CA-L6), et « Assigner » sans jours de séance ouvre une modale centrée qu'Échap ferme (CA-L7)
