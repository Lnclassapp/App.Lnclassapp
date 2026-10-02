# Plan d'exécution — Interface épurée

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Décisions : [UDR-0057](../../decisions/udr/0057-ecrans-eleve-epures.md) (règle, deux familles) · [UDR-0058](../../decisions/udr/0058-accueil-eleve.md) (accueil élève) · [UDR-0059](../../decisions/udr/0059-homepage-telephone-et-tablette.md) (homepage). Aucun ADR (PRD §6).
>
> **Revu le 2026-10-02 (porteur, grill Q14)** : on épure d'abord la base de code actuelle, à toutes les tailles d'écran. On ajoute ensuite la version mobile des maquettes, sur cette base épurée. Les UDR ne changent pas : seul l'ordre de livraison change.

## Graphe

```
PHASE 1 — ÉPURER L'EXISTANT (mises en page actuelles, toutes tailles d'écran)

Lot 0 — Socle d'épuration : « Voir plus » (Stimulus reveal), assertions de la règle, mesures « avant »
  ↓
  ├─► Lot A — Accueil élève épuré (UDR-0058 §3.3, appliqué à toutes les tailles)   ┐
  ├─► Lot B — Landing épurée (UDR-0059 §3, famille ordinateur, toutes tailles)     │
  ├─► Lot C — Exercice, session, résultat   ⟶ porte ⟶ code                        ├─ en parallèle
  ├─► Lot D — Catalogue, page cours, fiche  ⟶ porte ⟶ code                        │
  ├─► Lot E — Ma classe, rejoindre          ⟶ porte ⟶ code                        │
  └─► Lot F — Profil, connexion, PIN        ⟶ porte ⟶ code                        ┘
  ↓
  Challenger de la phase 1 : l'existant épuré, sans régression

PHASE 2 — AJOUTER LA VERSION MOBILE (maquettes, sous 1 024 px)

Lot M0 — Socle mobile : tokens, shell sans chrome mobile, Stimulus fit-text, symboles des matières, logo
  ↓
  ├─► Lot M1 — Accueil élève, famille téléphone et tablette (UDR-0058 §3.2)   ┐ en parallèle
  └─► Lot M2 — Homepage, famille téléphone et tablette (UDR-0059 §3)          ┘
  ↓
  Challenger final : 390, 820 et 1 280 px
```

**Pendant la phase 1**, l'épuration de l'accueil élève (UDR-0058 §3.3) et de la landing (UDR-0059, famille ordinateur) s'applique **à toutes les tailles**. La phase 2 ajoute ensuite, sous 1 024 px, la famille téléphone et tablette. L'état final est exactement celui des UDR.

**Porte des lots C à F.** Ces écrans n'ont pas de maquette. Chacun commence par **amender son UDR** : il liste ce qui est retiré, où cela va, et le contrôle des six points de l'UDR-0057. Puis il **s'arrête**. Le porteur accepte l'amendement, et alors seulement le lot code. Un lot ne code jamais sur un amendement « Proposé ».

**Contrats gelés.**
- **Lot 0** : le contrôleur `reveal` (cibles `item`, `button`, `status` ; valeur `step`) et les assertions de la règle.
- **Lot M0** : les tokens du `@theme`, l'option `content_for :mobile_chrome` du shell, le contrôleur `fit-text`, et le partial `shared/_subject_symbols` (identifiants `i-<slug>`).

Un lot qui a besoin de changer un contrat **s'arrête** et remonte : son socle rouvre.

---

## PHASE 1 — Épurer l'existant

### Lot 0 — Socle d'épuration

- **Couche**       : ui (contrats partagés) + tests de garde
- **Fichiers**     :
  - `app/javascript/controllers/reveal_controller.js`
  - `config/locales/shared/components.fr.yml` : « Voir plus », « %{count} lignes de plus affichées »
  - `test/support/sobriety_assertions.rb` : `assert_single_primary_action`, `assert_blocks_above_fold(max: 5)`, `assert_list_capped(max: 3)`
  - `test/test_helper.rb`, `test/application_system_test_case.rb` : chargement des assertions
  - `docs/chantiers/interface-epuree/prd.md` §7 : colonne « Avant » mesurée
- **Dépend de**    : —
- **Test associé** : `test/system/shared/reveal_test.rb` · `test/design/design_tokens_test.rb` (inchangé, doit rester vert)
- **Done quand**   : sur la page de démonstration du design, « Voir plus » révèle 3 lignes de plus et l'annonce ; toutes les autres pages sont inchangées (suite système verte).

### Lot A — Accueil élève épuré

- **Couche**       : ui
- **Fichiers**     :
  - vues de `app/views/classroom/student_homes/` : `show.html.erb`, `_assigned_exercise.html.erb`, `_classroom_card.html.erb`, `_pending_gaps.html.erb`, `_recent_activity.html.erb`
  - `config/locales/classroom/student_homes.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/controllers/classroom/student_homes_controller_test.rb`
  - `test/system/classroom/student_home_test.rb`
  - `test/system/role_homes_test.rb`
- **Done quand**   : à toutes les tailles, l'accueil actuel applique le tableau de l'UDR-0058 §3.3 :
  - « Bonjour, <prénom> » sans sous-titre ;
  - plus de bloc d'aide ;
  - des lignes « titre, matière, un bouton » ;
  - un seul bouton principal ;
  - 3 lignes puis « Voir plus » ;
  - une seule forme de la note dans l'activité.
  
  Le critère « Accueil élève, ordinateur » du PRD §4 passe, aussi à 390 px.

### Lot B — Landing épurée

- **Couche**       : ui
- **Fichiers**     :
  - `app/views/homepage/index.html.erb` (retrait de `section#rejoindre` et du lien d'en-tête « Commencer »)
  - `config/locales/homepage/index.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/homepage_controller_test.rb` · `test/system/homepage_test.rb` (dont le test existant des liens)
- **Done quand**   : à toutes les tailles, la landing n'a plus ni « Rejoindre » ni « Commencer », et les deux modales de rôle s'ouvrent depuis le héros.

### Lot C — Exercice, session, résultat

- **Couche**       : docs + ui
- **Fichiers**     :
  - `docs/decisions/udr/0021-page-exercice.md`, `docs/decisions/udr/0022-session-d-exercice.md`, `docs/decisions/udr/0023-resultat-de-session.md` (amendements)
  - `app/views/assessment/exercises/` : `show.html.erb`, `_student_progress.html.erb`, `_questions_preview.html.erb`
  - `app/views/assessment/exercise_sessions/` : `show.html.erb`, `_question_card.html.erb`, `_feedback_card.html.erb`, `_progress_bar.html.erb`
  - `app/views/assessment/session_results/` : `show.html.erb`, `_badge.html.erb`, `_question_review.html.erb`
  - `config/locales/assessment/` : `exercises.fr.yml`, `exercise_sessions.fr.yml`, `session_results.fr.yml`
- **Dépend de**    : Lot 0 ; **porte** : amendements acceptés par le porteur
- **Test associé** :
  - `test/system/assessment/exercise_page_test.rb`
  - `test/system/assessment/exercise_session_test.rb`
  - `test/system/assessment/session_result_test.rb`
- **Done quand**   :
  - la page de l'exercice reprend badge, meilleur score, maîtrise et sessions, retirés de l'accueil (Q4) ;
  - les trois écrans passent les assertions de la règle à 390 px ;
  - l'enseignant et l'équipe voient ces écrans inchangés.

### Lot D — Catalogue, page cours, fiche essentielle (vue élève)

- **Couche**       : docs + ui
- **Fichiers**     :
  - `docs/decisions/udr/0013-catalogue-et-page-cours.md`, `docs/decisions/udr/0015-page-fiche-essentielle.md` (amendements)
  - `app/views/catalog/courses/` : `index.html.erb`, `show.html.erb`, `_course_card.html.erb`, `_essential_row.html.erb`
  - `app/views/catalog/essentials/` : `show.html.erb`, `_exercise_progress.html.erb`
  - `config/locales/catalog/` : `courses.fr.yml`, `essentials.fr.yml`
- **Dépend de**    : Lot 0 ; **porte** : amendements acceptés par le porteur
- **Test associé** : `test/system/catalog/course_catalog_test.rb` · `test/system/catalog/essential_page_test.rb`
- **Done quand**   :
  - pour l'élève, le catalogue (dont le filtre par matière), la page cours et la fiche passent la règle à 390 px ;
  - les actions de l'enseignant et de l'équipe (`_role_actions`) sont inchangées.

### Lot E — Ma classe, rejoindre une classe

- **Couche**       : docs + ui
- **Fichiers**     :
  - `docs/decisions/udr/0011-ma-classe.md`, `docs/decisions/udr/0009-rejoindre-une-classe.md` (amendements)
  - `app/views/classroom/student_classrooms/` : `show.html.erb`, `_assigned_course.html.erb`
  - `app/views/classroom/joins/` : `new.html.erb`, `_classroom_preview.html.erb`, `_signup_form.html.erb`
  - `app/views/classroom/join_codes/new.html.erb`
  - `config/locales/classroom/` : `student_classrooms.fr.yml`, `joins.fr.yml`
- **Dépend de**    : Lot 0 ; **porte** : amendements acceptés par le porteur
- **Test associé** : `test/system/classroom/student_classroom_test.rb` · `test/system/classroom/join_test.rb`
- **Done quand**   : « Ma classe » et le parcours « rejoindre une classe » passent la règle à 390 px, sans liste nominative (UDR-0011).

### Lot F — Profil élève, connexion, récupération du PIN

- **Couche**       : docs + ui
- **Fichiers**     :
  - `docs/decisions/udr/0060-connexion-et-recuperation-du-pin.md` (nouvelle : aucune UDR ne couvre ces deux écrans)
  - `app/views/identity/profiles/` : `show.html.erb`, `_information.html.erb`
  - `app/views/identity/sessions/new.html.erb`
  - `app/views/identity/pin_resets/new.html.erb`
  - `config/locales/identity/` : `profiles.fr.yml`, `sessions.fr.yml`, `pin_resets.fr.yml`
- **Dépend de**    : Lot 0 ; **porte** : UDR-0060 acceptée par le porteur
- **Test associé** :
  - `test/system/identity/profile_test.rb`
  - `test/system/identity/sign_in_test.rb`
  - `test/controllers/identity/sessions_controller_test.rb`
- **Done quand**   :
  - la connexion et la récupération du PIN, épurées pour **tous les rôles** (grill Q9), passent la règle à 390 px ;
  - le profil de l'élève passe la règle ;
  - un enseignant et la direction se connectent comme avant.

---

## PHASE 2 — Ajouter la version mobile

Démarre quand la phase 1 est prouvée par son challenger.

### Lot M0 — Socle mobile

- **Couche**       : ui (contrats partagés)
- **Fichiers**     :
  - `app/assets/stylesheets/application.tailwind.css` : tokens de l'UDR-0058 §3.4, `.progress-bar`, classes `.c-*` des illustrations, et deux `@import` vers les feuilles de M1 et M2
  - `app/assets/stylesheets/components/student_home.css` *(créée vide, propriété de M1 ensuite)*
  - `app/assets/stylesheets/components/entry_screen.css` *(créée vide, propriété de M2 ensuite)*
  - `app/views/layouts/shell.html.erb`, `app/views/shared/navigation/_header.html.erb`, `app/views/shared/navigation/_bottom_bar.html.erb` : avec `content_for :mobile_chrome, "none"`, l'en-tête et la barre basse disparaissent sous `lg` ; inchangés sinon
  - `app/javascript/controllers/fit_text_controller.js` (valeurs `full`, `short`)
  - `app/views/shared/_subject_symbols.html.erb` : symboles `i-maths`, `i-physique-chimie`, `i-svt`, `i-francais`, `i-histoire-geographie`, `i-edhc`, `i-philosophie`, `i-invite`
  - `app/assets/images/logo/lnclass-mark.png` : baobab détouré, extrait de la maquette
- **Dépend de**    : phase 1 prouvée
- **Test associé** :
  - `test/system/shared/fit_text_test.rb`
  - `test/helpers/navigation_helper_test.rb` (chrome mobile)
  - `test/design/design_tokens_test.rb`
- **Done quand**   :
  - une vue qui pose `mobile_chrome: "none"` n'a ni en-tête ni barre basse sous 1 024 px, et les a au-dessus ;
  - un texte trop long bascule sur sa forme courte à 360 px ;
  - toutes les autres pages sont inchangées.

### Lot M1 — Accueil élève, téléphone et tablette

- **Couche**       : infrastructure + ui
- **Fichiers**     :
  - `app/infrastructure/queries/classroom/student_home_query.rb` (champs de l'UDR-0058 §3.1)
  - `app/helpers/student_home_helper.rb` (`SUBJECT_TILES`, choix de la carte du haut, groupes de jours)
  - vues de `app/views/classroom/student_homes/` : `show.html.erb` (les deux familles), `_phone.html.erb`, `_band.html.erb`, `_next_card.html.erb`, `_subject_grid.html.erb`, `_invite_modal.html.erb`, `_todo.html.erb`, `_recent_activity.html.erb`
  - `config/locales/classroom/student_homes.fr.yml`
  - `app/assets/stylesheets/components/student_home.css`
- **Dépend de**    : Lot M0
- **Test associé** :
  - `test/infrastructure/queries/classroom/student_home_query_test.rb`
  - `test/helpers/student_home_helper_test.rb`
  - `test/controllers/classroom/student_homes_controller_test.rb`
  - `test/system/classroom/student_home_test.rb`
- **Done quand**   :
  - à 390 px, un élève voit le bandeau, la carte « Prochain exercice », la grille et « Inviter », « À faire ensuite » et « Historique » en 3 lignes, sans barre basse, et démarre un exercice depuis la carte ;
  - à 820 px, le même écran en colonne centrée ;
  - à 1 280 px, l'accueil épuré de la phase 1, inchangé ;
  - tous les critères « Accueil élève, téléphone et tablette » du PRD §4 passent.

### Lot M2 — Homepage, téléphone et tablette

- **Couche**       : ui
- **Fichiers**     :
  - `app/views/homepage/index.html.erb` (les deux familles)
  - `app/views/homepage/_entry_screen.html.erb`
  - `app/views/homepage/_role_modal.html.erb` (libellé du déclencheur selon `placement: :entry`)
  - `app/helpers/homepage_helper.rb`
  - `config/locales/homepage/index.fr.yml`
  - `app/assets/images/homepage/eleves.jpg` (≤ 150 Ko, 1 080 px de large au plus)
  - `app/assets/stylesheets/components/entry_screen.css`
- **Dépend de**    : Lot M0
- **Test associé** : `test/controllers/homepage_controller_test.rb` · `test/system/homepage_test.rb`
- **Done quand**   :
  - à 390 px et à 820 px, un visiteur voit l'écran d'entrée de la maquette et ouvre la modale élève ;
  - à 1 280 px, la landing épurée de la phase 1, inchangée ;
  - la photo pèse au plus 150 Ko ;
  - les critères « Homepage » du PRD §4 passent.

---

## Rattachement des critères du PRD §4

| Critère | Lot |
|---|---|
| Accueil élève, ordinateur (épuration) | A (phase 1, à toutes les tailles) |
| Accueil élève, téléphone et tablette (11 critères) | M1 |
| Homepage, ordinateur (sans « Rejoindre ») | B |
| Homepage, téléphone | M2 |
| Règle de sobriété, sur chaque écran | 0 (assertions), puis A à F, M1, M2 (chacun sur ses écrans) |
| Enseignant sur l'accueil élève → 403 | A |
| Aucun `#hex`, `style`, `[…]`, `dark:` | 0 et M0 (test existant), vérifié par chaque lot |

Aucun critère orphelin.

## Dispatch

```
PHASE 1
Vague 1 : Lot 0                                         → 1 agent, séquentiel
Vague 2 : Lot A ‖ Lot B ‖ C, D, E, F (amendements)      → 6 agents, worktrees isolés
          C à F s'arrêtent à leur porte : amendement « Proposé », relu par le porteur
Vague 3 : C ‖ D ‖ E ‖ F (code), après acceptation       → jusqu'à 4 agents
          Challenger de la phase 1

PHASE 2
Vague 4 : Lot M0                                        → 1 agent, séquentiel
Vague 5 : M1 ‖ M2                                       → 2 agents
          Challenger final
```

Branche de chantier : `feature/interface-epuree`. Branches de lot : `feature/interface-epuree-lot-<x>` (tiret, conventions §3), créées depuis la branche de chantier **après la fusion de leur socle**. Une seule PR vers `Develop` : la #113.

---

## Vérification de collision

> Deux lots **parallèles** ne listent jamais le même fichier.

| Fichier | Lot propriétaire |
|---|---|
| `app/javascript/controllers/reveal_controller.js` | Lot 0 |
| `config/locales/shared/components.fr.yml` | Lot 0 |
| `test/support/sobriety_assertions.rb`, `test/test_helper.rb`, `test/application_system_test_case.rb` | Lot 0 |
| `app/assets/stylesheets/application.tailwind.css` | Lot M0 |
| `app/assets/stylesheets/components/student_home.css` | Lot M0 (création), puis M1 |
| `app/assets/stylesheets/components/entry_screen.css` | Lot M0 (création), puis M2 |
| `app/views/layouts/shell.html.erb` et `app/views/shared/navigation/*` | Lot M0 |
| `app/javascript/controllers/fit_text_controller.js`, `app/views/shared/_subject_symbols.html.erb` | Lot M0 |
| `app/views/classroom/student_homes/*`, `config/locales/classroom/student_homes.fr.yml` | Lot A (phase 1), puis M1 (phase 2), jamais en même temps |
| `app/views/homepage/index.html.erb`, `config/locales/homepage/index.fr.yml` | Lot B (phase 1), puis M2 (phase 2), jamais en même temps |
| `test/system/classroom/student_home_test.rb`, `test/controllers/classroom/student_homes_controller_test.rb` | Lot A, puis M1 |
| `test/system/homepage_test.rb`, `test/controllers/homepage_controller_test.rb` | Lot B, puis M2 |
| `test/system/role_homes_test.rb` | Lot A |
| `config/locales/<contexte>/<écran>.fr.yml` des lots C à F | le lot de l'écran (un fichier par écran, aucun partagé) |
| `docs/decisions/udr/README.md` | orchestrateur, à la fusion de chaque lot |
| `docs/chantiers/interface-epuree/journal.md` | orchestrateur |
| `test/fixtures/`, `db/` | aucun lot (aucune migration, aucune fixture modifiée) |

Doublons vérifiés mécaniquement (commande de la skill `plan-lots`) : ce sont des **passations entre phases** (A puis M1, B puis M2, M0 puis M1/M2), jamais des lots parallèles.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md` *(sans objet : aucun, PRD §6)*
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md` *(0057, 0058, 0059 faites ; amendements et UDR-0060 aux lots C à F)*
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
> **Phase 1** :
> - il parcourt chaque écran élève, la landing, la connexion et la récupération du PIN, à 390 et 1 280 px ;
> - il vérifie les six points de la règle ;
> - il vérifie que l'enseignant, la direction et l'équipe ne voient aucun changement hors des écrans d'entrée ;
> - il rejoue un chemin d'erreur (élève sans exercice, enseignant sur l'accueil élève).
>
> **Phase 2** :
> - il ouvre l'accueil élève et la homepage à 390, 820 et 1 280 px, et compare aux maquettes et aux UDR ;
> - il refait « Commencer l'exercice », « Inviter » puis « Copier », et « Voir plus » ;
> - il mesure le poids de la page et de la photo (PRD §7).
