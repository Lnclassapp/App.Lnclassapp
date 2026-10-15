# Plan d'exécution — Accueil élève aux couleurs Wave et Djamo

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Décisions : [PRD](prd.md) · [ADR-0089](../../decisions/adr/0089-exercice-du-jour-calcule-a-la-lecture-et-fait-seul-deduit.md) · [UDR-0084](../../decisions/udr/0084-accueil-eleve-en-tete-au-logo-menu-de-l-avatar-et-exercice-du-jour.md).
> Le code se fait dans une **nouvelle session**, sur une branche issue de `Develop`, avec **une seule PR** pour tout le chantier. Un commit par lot (6 commits).

## Graphe

```
Lot 0 — SOCLE (séquentiel)
  ↓
  ├─► Lot A  En-tête, menu de l'avatar, plus de barre du bas      ┐
  ├─► Lot B  Accueil redessiné ──► Lot C  Exercice du jour         ├─ A, B et D en parallèle ; C après B
  └─► Lot D  « Fait seul » chez l'enseignant et la direction      ┘
  ↓
Lot E — PREUVE ET CLÔTURE (séquentiel)
```

---

## Lot 0 — Socle

- **Couche**       : domaine (contrat) + UI (helpers partagés) + config (locales)
- **Fichiers**     : `app/domain/entities/assessment/daily_rotation.rb` *(complet : fonction pure, ADR-0089 §6)*
                     `app/infrastructure/queries/assessment/daily_exercise_query.rb` *(contrat seul : `Row`, `call(student_id:, today:)` qui lève `NotImplementedError`)*
                     `app/helpers/components_helper.rb` *(`ui_avatar` : `add_photo:`, ton stable par `public_id` ; `ui_icon` : repli sur `vendor/lnclass-icons`)*
                     `vendor/lnclass-icons/24/outline/headset.svg` · `vendor/lnclass-icons/24/outline/door-open.svg`
                     `app/helpers/navigation_helper.rb` *(opt-out de la barre du bas par rôle : `bottom_bar?(role)`, faux pour `:student` ; `DESTINATIONS` inchangé)*
                     `config/locales/classroom/student_homes.fr.yml` *(toutes les clés du chantier côté élève : en-tête, menu, blocs, carte du jour, invitation)*
                     `config/locales/shared/navigation.fr.yml` *(libellés du menu de l'avatar)*
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/assessment/daily_rotation_test.rb` (tour, saut, aucun candidat, changement de jour, liste vide) · `test/helpers/components_helper_test.rb` (badge « + », couleur stable, icône maison) · `test/helpers/navigation_helper_test.rb` (`bottom_bar?`)
- **Done quand**   : les contrats `DailyRotation`, `DailyExerciseQuery::Row`, `ui_avatar(add_photo:)`, `ui_icon "headset"/"door-open"` et `bottom_bar?` sont gelés ; le nombre de requêtes SQL de `GET /students` est mesuré et écrit dans `prd.md` §7 (colonne « Avant »)

---

## Lot A — En-tête, menu de l'avatar, plus de barre du bas (CA-1 à CA-5, CA-19)

- **Couche**       : UI + delivery
- **Fichiers**     : `app/views/layouts/shell.html.erb` *(barre du bas et `pb-28` seulement si `bottom_bar?`)*
                     `app/views/shared/navigation/_header.html.erb` *(branche élève : logo, aide ≥ 700 px, thème, avatar)*
                     `app/views/shared/navigation/_avatar_menu.html.erb` *(nouveau, UDR-0084 §3.2)*
                     `app/views/shared/navigation/_account_panel.html.erb` *(Android `/students/menu` : liens 3 à 7)*
                     `app/javascript/controllers/dropdown_controller.js` *(réutilisé ; étendu seulement si le clavier du §3.10 manque)*
                     `test/integration/identity/student_header_test.rb` · `test/system/identity/account_panel_test.rb` · `test/controllers/classroom/student_menus_controller_test.rb` · `test/system/role_homes_test.rb` · `test/integration/app_android_shell_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/system/identity/student_avatar_menu_test.rb` (CA-1, CA-2, CA-3 à 390 et 1 280 px) · `test/system/role_homes_test.rb` (CA-5) · `test/integration/app_android_shell_test.rb` (CA-19)
- **Done quand**   : à 390 px l'élève n'a plus de barre du bas et navigue par le menu de l'avatar ; l'enseignant garde la sienne ; l'app Android est inchangée

---

## Lot B — Accueil redessiné (CA-4, CA-6, CA-7, CA-20)

- **Couche**       : infrastructure (query) + UI
- **Fichiers**     : `app/views/classroom/student_homes/show.html.erb` *(colonne 720 / 960 px, ordre des blocs, « À faire » extrait dans `_todo`)*
                     `app/views/classroom/student_homes/_todo.html.erb` *(nouveau : travail de l'enseignant + emplacement `_daily_exercise` rendu seulement si `local_assigns[:daily]`)*
                     `app/views/classroom/student_homes/_classroom_card.html.erb` · `_subjects.html.erb` · `_assigned_exercise.html.erb` · `_pending_gaps.html.erb` · `_recent_activity.html.erb` · `_no_classroom.html.erb`
                     `app/infrastructure/queries/classroom/student_home_query.rb` *(retrait du calcul eager de `recent_sessions`, lu seulement par le cadre lazy)*
                     `test/system/classroom/student_home_test.rb` · `test/controllers/classroom/student_homes_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/system/classroom/student_home_test.rb` (CA-4, CA-6, CA-7) · `test/system/communication/carousel_test.rb` (CA-20, relancé)
- **Done quand**   : l'accueil montre les cinq blocs dans l'ordre, en clair et en sombre, au téléphone, sur tablette et sur ordinateur ; le nombre de requêtes de `GET /students` est ≤ avant

---

## Lot C — Exercice du jour et « Inviter mon enseignant » (CA-8 à CA-15, CA-18)

- **Couche**       : infrastructure + delivery + UI
- **Fichiers**     : `app/infrastructure/queries/assessment/daily_exercise_query.rb` *(implémentation, ADR-0089 §4.1)*
                     `app/controllers/classroom/student_homes_controller.rb` *(lit `DailyExerciseQuery` seulement si `assigned_exercises` est vide)*
                     `app/views/classroom/student_homes/_daily_exercise.html.erb` *(nouveau, 3 états)*
                     `app/views/classroom/student_homes/_invite_teacher.html.erb` *(nouveau)*
                     `app/views/classroom/student_homes/_todo.html.erb` *(passe `daily:`)*
- **Dépend de**    : Lot 0, Lot B *(`_todo` est créé par B)*
- **Test associé** : `test/infrastructure/queries/assessment/daily_exercise_query_test.rb` (CA-8, CA-9, CA-10, CA-12 à CA-15, avec `travel_to` et l'heure d'Abidjan) · `test/system/classroom/daily_exercise_test.rb` (CA-8, CA-10, CA-11, CA-18 : parcours complet, de « Commencer » à « Bravo, à demain ! »)
- **Done quand**   : un élève sans enseignant voit un exercice, le fait, revient et lit « Bravo, à demain ! » avec la matière de demain ; un élève en retard ne voit pas de proposition

---

## Lot D — « Fait seul » chez l'enseignant et la direction (CA-16, CA-17)

- **Couche**       : infrastructure + UI
- **Fichiers**     : `app/infrastructure/queries/classroom/classroom_overview_query.rb` *(`StudentRow#self_practice_count`, avec `show_roster` seulement)*
                     `app/views/classroom/classrooms/_roster.html.erb`
                     `config/locales/classroom/classrooms.fr.yml`
                     `app/infrastructure/queries/school/direction_home_query.rb` *(`self_practice_count` par niveau, même cache)*
                     `app/views/school_admin/classrooms/_levels.html.erb`
                     `config/locales/school_admin/classrooms.fr.yml`
                     `test/infrastructure/queries/classroom/assignment_follow_up_query_test.rb` *(cas ajouté : une session sans assignation ne change pas `Counts`)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/classroom/classroom_overview_query_test.rb` (CA-16) · `test/infrastructure/queries/school/direction_home_query_test.rb` (CA-17, dont l'autre établissement) · `test/system/classroom/classroom_roster_test.rb` (colonne visible)
- **Done quand**   : l'enseignant et la direction voient « Fait seul (7 j) » ; les comptes des exercices donnés sont identiques avant et après

---

## Lot E — Preuve et clôture

- **Couche**       : docs + preuve
- **Fichiers**     : `docs/chantiers/accueil-eleve/journal.md` · `docs/chantiers/accueil-eleve/prd.md` *(§7, colonne « Après »)* · `docs/chantiers/README.md` *(une ligne, à la clôture)* · `docs/decisions/adr/README.md` et `docs/decisions/udr/README.md` *(générés par `script/docs/build_index`)* · statut d'ADR-0089 et d'UDR-0084
- **Dépend de**    : Lots A, B, C, D
- **Test associé** : `bin/ci-quiet` vert, verdict copié dans la PR · sous-agents `security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer` une fois sur le diff final (use case/query/route touchés, diff > 150 lignes)
- **Done quand**   : captures envoyées au porteur (390 px et ordinateur, menu ouvert, trois états de la carte, sombre, page de la classe, accueil de la direction), PR ouverte prête

---

## Vérification de collision

> Deux lots ne listent jamais le même fichier, sauf `_todo.html.erb` : B le crée, C y ajoute `daily:`, d'où C après B.

| Fichier | Lot propriétaire |
|---|---|
| `app/domain/entities/assessment/daily_rotation.rb` | Lot 0 |
| `app/helpers/components_helper.rb` · `app/helpers/navigation_helper.rb` | Lot 0 |
| `vendor/lnclass-icons/**` | Lot 0 |
| `config/locales/classroom/student_homes.fr.yml` · `config/locales/shared/navigation.fr.yml` | Lot 0 |
| `app/views/layouts/shell.html.erb` · `app/views/shared/navigation/**` | Lot A |
| `test/system/role_homes_test.rb` · `test/integration/identity/student_header_test.rb` | Lot A |
| `app/views/classroom/student_homes/show.html.erb` et partials existants | Lot B |
| `app/infrastructure/queries/classroom/student_home_query.rb` | Lot B |
| `app/views/classroom/student_homes/_todo.html.erb` | Lot B, puis Lot C |
| `app/infrastructure/queries/assessment/daily_exercise_query.rb` | Lot 0 (contrat), puis Lot C |
| `app/controllers/classroom/student_homes_controller.rb` | Lot C |
| `app/views/classroom/student_homes/_daily_exercise.html.erb` · `_invite_teacher.html.erb` | Lot C |
| `app/infrastructure/queries/classroom/classroom_overview_query.rb` · `app/views/classroom/classrooms/_roster.html.erb` · `config/locales/classroom/classrooms.fr.yml` | Lot D |
| `app/infrastructure/queries/school/direction_home_query.rb` · `app/views/school_admin/classrooms/_levels.html.erb` · `config/locales/school_admin/classrooms.fr.yml` | Lot D |

## Risques à surveiller

- Le shell est partagé par tous les rôles, `/aide` et `DesignController#shell` : l'opt-out ne touche que `:student` (CA-5).
- `_account_panel` sert aussi l'enseignant (UDR-0082) : la branche élève seule change.
- L'id `student_home_announcements` doit rester (CA-20).
- `DailyExerciseQuery` reçoit `today:` ; aucun `Date.today` (fuseau du serveur) dans la query.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md` *(ADR-0089 écrit ; index généré à la clôture)*
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md` *(UDR-0084 écrite ; index généré à la clôture)*
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
