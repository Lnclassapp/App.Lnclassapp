# Plan d'exécution — MVP Lnclass Teacher & Student — pilote du 27 octobre — **élève**

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot). Critères : [`prd.md`](prd.md) §4 (élève seulement). Écrans : [`carte-des-ecrans.md`](carte-des-ecrans.md) et les UDR du PRD §6.
>
> **Répartition validée par le porteur le 2026-10-24 (« option A »)** : on se concentre sur l'élève, l'enseignant vient après. Ce plan remplace celui de 15 lots (version `c766532`), qui reste la base des futurs lots enseignant (G, H, I, J, K, L de l'ancien plan).

**Branche de chantier** : `feature/mvp-teacher-student`, depuis `Develop`. Lots : `feature/mvp-teacher-student-lot-<x>` (`-lot-e1`, `-lot-e2`), depuis la branche de chantier **après** la fusion des lots dont ils dépendent. **Une seule PR** vers `Develop`.

**Pilotes** — un lot d'orchestrateur est exécuté par l'agent `executant-lot` ; un lot de Touré ou Konan, par eux :

| Lot | Pilote | Dépend de | Jour | État au 24/10, 11 h |
|---|---|---|---|---|
| B — Code de classe à 6 caractères | orchestrateur | — | samedi 24 | ✅ **fait** (ancien Lot 0 + ancien Lot A, `021804cc`) ; `security-reviewer` passé, aucun constat au-dessus de « bas » |
| A — Jetons de couleurs | orchestrateur (porteur, 2026-10-24 : « option A », repris de Touré), #285 | — | samedi 24 | ✅ **fusionné** (`8d009596`), captures validées par le porteur |
| F — Page d'accueil publique en photo | **Touré** (`toure-bangaly`), #286 (2026-10-26) | — | samedi 24 | à faire |
| B2 — Code visible sur la page de classe (provisoire) | orchestrateur | B | samedi 24 | à faire (porteur, 2026-10-24 : « A ») |
| C — Inscription élève en 3 étapes | orchestrateur | B | samedi 24 | ✅ **fusionné** (`dc2c78c5`), captures validées |
| D — Accueil élève, carte du prochain exercice | **Touré**, #298 (2026-10-26 ; code déjà sur `-lot-d`) | A | dimanche 25 → lundi 26 | à faire |
| E1 — « Mon compte » plein écran, profil sans doublons | Touré, #291 | A | dimanche 25 | à faire |
| E2 — Ma classe, fiche, résultat, Cours | **Touré**, #290 (2026-10-26) | A, F | dimanche 25 → lundi 26 | à faire |

**Répartition du 2026-10-26** (porteur : « Konan pour les écrans des enseignants et Touré pour les élèves, mobile comme ordinateur ») : **Touré pilote tous les lots élève**, téléphone et ordinateur, dans cet ordre : D (#298), E1 (#291), F (#286), E2 (#290), O3 (#299), O1 (#300), O6 (#301), O2 (#302), O4 (#303), O5 (#304). Les lots enseignant sont à Konan ([`plan-enseignant.md`](plan-enseignant.md)). Chaque issue porte la fiche du lot, les changements du 26, les maquettes de référence (archive v12) et la marche à suivre. La session « MVP teacher-student » reste la seule à fusionner dans la branche de chantier.

**Budget des tests système** (ADR-0069 §9 : 15 s par chantier) : C en prend 10,5 s ; **relevé à 50 s pour ce chantier** (porteur, 2026-10-24, amendement de l’ADR-0069). Chaque lot garde un test système court de son parcours principal et teste le reste au niveau contrôleur ou intégration.

**Un seul plan, deux sessions** (coordination du 2026-10-24) : ce fichier, sur `Develop`, est le seul plan ; le `plan.md` de 15 lots resté sur la branche de chantier est écrasé par celui-ci à la fusion de #295. La session « MVP teacher-student » tient la branche de chantier : elle exécute et fusionne les lots d'orchestrateur (C, puis D) et elle seule fusionne dans `feature/mvp-teacher-student`. Cette session tient le plan et les issues de Touré et Konan. Issues des lots enseignant (#287, #288, #289, #292, #293, #294) : en attente, reprises après les lots élève.

**Déjà livré par l'ancien Lot 0, hors plan élève, à ne pas refaire** : navigation sans barre basse (élève et enseignant), `_home_band`, `Grading.class_badge_for`, panneau « Mon compte » enseignant, menu enseignant sans « Annonces », drapeaux `school_space_enabled` et `TEACHER_ANNOUNCEMENTS_ENABLED` (`config/initializers/pilot_flags.rb`), clés de « Mon compte » dans `navigation.fr.yml`. Alphabet du code : 31 symboles, sans `l` (porteur, 2026-10-24).

**Suite** : les lots enseignant sont dans [`plan-enseignant.md`](plan-enseignant.md) (critères : [`prd-enseignant.md`](prd-enseignant.md)).

**Téléphone d'abord** (porteur, 2026-10-24) : chaque lot livre l'écran du téléphone (390 px) ; sur ordinateur, il vérifie seulement que rien n'est cassé. Les versions ordinateur (accueil en page large, « Mon compte » en panneau de 400 px, et les écrans encore à dessiner) font une phase à part, après les lots téléphone ([`prd.md`](prd.md) §4 bis).

**Rôle du porteur** : valider les captures de chaque lot (390 px et ordinateur) avant sa fusion ; recette sur un vrai téléphone Android lundi 26 ; inviter les élèves testeurs au test fermé Play Store. **Pilote : mardi 27 octobre 2026.**

## Graphe

```
Vague 1 (sam. 24)   A Jetons (Touré)        B Code de classe (Orch.)     F Page publique (Konan)
                      │                        │                            │
          ┌───────────┼───────────┐            │                            │
          ▼           ▼           ▼            ▼                            │
Vague 2   D Accueil   E1 Mon      E2 Ma classe C Inscription               │
(dim. 25)   élève     compte      fiche, Cours   3 étapes                  │
            (Orch.)   (Touré)     (Konan) ◄──────────────────────────────────┘
```

| Vague | Lots | En parallèle | Quand |
|---|---|---|---|
| 1 | A ‖ B ‖ F | 3 (Touré, 1 agent d'orchestrateur, Konan) | samedi 24 |
| 2 | C ‖ D ‖ E1 ‖ E2 | 4 (2 agents d'orchestrateur, Touré, Konan) | dimanche 25 → lundi 26 |

**Pas de Lot 0 séparé.** Le seul socle du chantier élève (migration, entité, port, route, fixture du code) n'est consommé que par C, qui dépend de B : **B tient le rôle du Lot 0 pour le code**, et gèle ses contrats à sa fusion. Les autres fichiers partagés ont chacun un seul propriétaire (tableau de collision). Un lot qui doit modifier un fichier d'un autre lot **s'arrête** et le signale sur son issue.

---

## Lot A — Jetons de couleurs : palette froide, DM Sans seule, graisse ≤ 500

- **Couche**       : ui (jetons, composants partagés, balayage)
- **Départ**       : la branche `feature/mvp-teacher-student-lot-p` (jetons et police déjà faits), après y avoir fusionné `feature/mvp-teacher-student`
- **Fichiers**     : app/assets/stylesheets/application.tailwind.css *(jetons de l'UDR palette §3.1 ; `@font-face` Bricolage Grotesque retiré, `--font-display` = DM Sans)*
                     app/assets/fonts/ *(fichier Bricolage Grotesque supprimé)*
                     app/helpers/components_helper.rb *(`ui_button`, `ui_card`, `ui_badge`, `ui_field` sur les jetons)*
                     app/helpers/assessment/badges_helper.rb *(`grade_class(score)` : vert ≥ 14/20, jamais rouge)*
                     test/design/design_tokens_test.rb *(valeurs des jetons ; refus de `font-semibold`, `font-bold`, `font-extrabold`, `font-black` dans `app/views` et `app/helpers`, sauf `app/views/homepage/`)*
                     **balayage** : chaque fichier de `app/views/` et `app/helpers/` que liste `grep -rlE 'font-(semibold|bold|extrabold|black)' app/views app/helpers` (147 fichiers au 2026-10-24), **sauf** `app/views/homepage/` (exception de l'UDR palette, lot F) — graisse ramenée à `font-medium` ou `font-normal` selon l'échelle §3.2, rien d'autre ne change
- **Dépend de**    : —
- **Test associé** : test/design/design_tokens_test.rb · test/helpers/components_helper_test.rb · test/helpers/assessment/badges_helper_test.rb
- **Done quand**   : l'app entière a un fond blanc, des gris froids et une seule police (CA-F1) ; aucun texte au-dessus de 500 hors page d'accueil publique, et le test le refuse (CA-F2) ; une note de 13/20 s'affiche en encre, 14/20 en vert, jamais en rouge (CA-F3) ; **captures élève et enseignant** (390 px et ordinateur) envoyées au porteur et validées avant la fusion)

## Lot B — Code de classe à 6 caractères

- **Couche**       : domaine + infrastructure + delivery + ui (aperçu)
- **Fichiers**     : db/migrate/20261024090000_add_join_code_to_classrooms.rb *(ajout nullable, remplissage par lots, `NOT NULL`, index unique, contrainte de format)* · db/schema.rb
                     app/domain/entities/classroom/join_code.rb *(nouveau, calqué sur `school/school_code.rb`)*
                     app/domain/entities/classroom/classroom.rb *(attribut `join_code`)*
                     app/domain/ports/classroom/classroom_repository_port.rb *(`#find_by_join_code(code:)`, contrat gelé à la fusion)*
                     app/infrastructure/orm/classroom.rb · app/infrastructure/repositories/classroom/classroom_repository.rb
                     app/infrastructure/queries/classroom/join_code_preview_query.rb *(nouveau)*
                     app/domain/use_cases/classroom/register_student.rb *(résout la classe par le code, `joined_via: "code"`)*
                     app/domain/use_cases/classroom/join_as_student.rb *(élève connecté sans classe, par code)*
                     app/controllers/classroom/classroom_codes_controller.rb *(nouveau, débit `classroom/joins` partagé, 10/min/IP)*
                     app/controllers/classroom/student_registrations_controller.rb *(accepte `code`)* · app/controllers/classroom/student_classroom_choices_controller.rb *(accepte `code`)*
                     app/views/classroom/classroom_codes/show.html.erb *(nouveau : Turbo Frame d'aperçu — trouvée, inconnue, trop de tentatives)*
                     config/routes/classroom.rb *(`GET /classroom-codes/:code`)*
                     config/locales/classroom/classroom_codes.fr.yml *(nouveau)*
                     test/fixtures/classrooms.yml *(un `join_code` par classe)*
- **Dépend de**    : —
- **Test associé** : test/domain/entities/classroom/join_code_test.rb · test/db/add_classroom_join_codes_migration_test.rb *(remplace `remove_classroom_join_codes_migration_test.rb`, ADR §6)* · test/integration/classroom/classroom_codes_test.rb · test/infrastructure/queries/classroom/join_code_preview_query_test.rb · test/domain/use_cases/classroom/register_student_test.rb · test/controllers/classroom/student_registrations_controller_test.rb · test/controllers/classroom/student_classroom_choices_controller_test.rb
- **Done quand**   : toute classe a un code au bon format, la migration se rejoue à l'envers (CA-B1) ; `/classroom-codes/k7m4q2` montre la classe, le niveau et l'établissement, rien d'autre (CA-B2) ; un code inconnu et une classe archivée répondent pareil (CA-B3) ; la 11ᵉ requête de la minute, lien, code et envoi confondus, reçoit 429 (CA-B4) ; un envoi d'inscription avec un code valide crée l'élève dans la classe, `joined_via` « code » ; un élève connecté sans classe la rejoint par le code (CA-B5)
- **Revue** : `security-reviewer` **obligatoire** avant fusion (ADR du code §6, ID-07 : énumération, fuite dans la réponse, compteur partagé, journalisation).

## Lot B2 — Code de classe visible sur la page de classe (provisoire)

- **Couche**       : ui
- **Fichiers**     : app/views/classroom/classrooms/_link.html.erb *(ligne « Code de la classe · k7m 4q2 » et bouton « Copier », dans le bloc du lien)*
                     config/locales/classroom/classrooms.fr.yml
- **Dépend de**    : B
- **Test associé** : test/system/classroom/classroom_page_test.rb · test/controllers/classroom/classrooms_controller_test.rb
- **Done quand**   : l'enseignant de la classe voit son code et le copie ; un enseignant d'une autre classe ne le voit pas ; « Changer le lien » change aussi le code affiché (CA-B7)
- **Provisoire** (porteur, 2026-10-24 : « A ») : sans cette ligne, aucun enseignant ne peut lire le code avant les lots enseignant, et l'inscription par code ne se teste pas lundi. La ligne part quand l'accueil enseignant porte le code (UDR enseignant §3.3) ; le lot enseignant qui la retire le dit.

## Lot F — Page d'accueil publique en photo

- **Couche**       : delivery + ui
- **Fichiers**     : app/controllers/homepage_controller.rb · app/views/homepage/index.html.erb · app/views/homepage/_role_modal.html.erb
                     app/assets/images/homepage/ *(photo WebP portrait et paysage)*
                     *(lit le drapeau `school_space_enabled` de `config/initializers/pilot_flags.rb`, déjà posé : il ne le modifie pas)*
                     config/locales/homepage/index.fr.yml
- **Dépend de**    : —
- **Test associé** : test/system/homepage_test.rb · test/controllers/homepage_controller_test.rb
- **Done quand**   : à 390 px et à 320 × 568, la page tient sur un écran avec la photo, « Tu comprends chap chap » en gras, la vague jaune, la pastille « même sans internet » et les entrées « Je suis élève » et « Enseignant(e) » (CA-A1) ; « Espace établissement » est absent drapeau éteint et revient drapeau allumé (CA-A2) ; le reste selon le chantier [`page-d-accueil-photo`](../page-d-accueil-photo/memo.md) (UDR-0059)

---

## Lot C — Inscription élève en trois étapes

- **Couche**       : ui + delivery
- **Fichiers**     : app/javascript/controllers/classroom/signup_steps_controller.js *(nouveau : étapes, avance automatique après ≈ 1 s, « ‹ Retour », région aria-live)*
                     app/views/classroom/student_registrations/new.html.erb · app/views/classroom/student_registrations/_form.html.erb · app/views/classroom/student_registrations/_class_picker.html.erb *(derrière « Je n'ai pas de code »)*
                     app/views/classroom/joins/new.html.erb
                     app/controllers/classroom/joins_controller.rb *(étape de départ ; lien invalide, archivé ou régénéré → étape 1)*
                     config/locales/classroom/student_registrations.fr.yml · config/locales/classroom/joins.fr.yml
- **Dépend de**    : B *(rend le Turbo Frame `classroom_codes/show` sans le modifier)*
- **Test associé** : test/system/identity/student_signup_steps_test.rb *(nouveau)* · test/system/classroom/join_test.rb · test/controllers/classroom/joins_controller_test.rb
- **Done quand**   : un élève s'inscrit par le code, par le lien (arrivée à l'étape 2 avec le rappel de classe) et par la cascade, sans bouton « Continuer », avec passage automatique et retour sans perte (CA-C1 à CA-C5) ; une erreur serveur rouvre la bonne étape (CA-C6) ; sans JavaScript, le formulaire aboutit (CA-C7) ; la ligne « En créant ton compte, tu acceptes… » est sous le bouton

## Lot D — Accueil élève : carte du prochain exercice

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : app/infrastructure/queries/classroom/student_home_query.rb *(état de la carte, 6 règles ; exercice du jour aussi quand tout est fait)*
                     app/controllers/classroom/student_homes_controller.rb
                     app/views/classroom/student_homes/show.html.erb · _band.html.erb *(nouveau)* · _next_step.html.erb *(nouveau)* · next_step/*.html.erb *(nouveaux, un par état)* · _subjects.html.erb · _history.html.erb *(remplace `_recent_activity`)*
                     *(supprimés : `_classroom_card`, `_todo`, `_assigned_exercise`, `_daily_exercise`, `_invite_teacher`, `_no_classroom`, `_recent_activity` ; `_pending_gaps` n'est plus rendu ici, E2 le déplace)*
                     app/views/shared/navigation/_header.html.erb · app/views/shared/navigation/_home_band.html.erb *(branche élève : seul lot qui modifie l'en-tête et le bandeau)*
                     app/views/layouts/shell.html.erb
                     config/locales/classroom/student_homes.fr.yml *(toutes les clés nouvelles du bandeau et de l'en-tête élève)*
- **Dépend de**    : A
- **Test associé** : test/infrastructure/queries/classroom/student_home_query_test.rb · test/controllers/classroom/student_homes_controller_test.rb · test/system/classroom/student_home_test.rb · test/integration/identity/student_header_test.rb · test/system/role_homes_test.rb
- **Done quand**   : l'accueil montre bandeau, carte, grille de 7 cases, annonces, Historique, sans barre basse ni « À faire ensuite » ni « Paiement » (CA-D1, CA-K3) ; les six états de la carte s'affichent chacun dans son cas, dont l'exercice du jour quand tout est fait (CA-D2 à CA-D7) ; le point de retard est sur la bonne matière (CA-D8) ; l'en-tête de la carte ouvre Ma classe (CA-D9) ; l'avatar du bandeau rend le menu de E1 sans le modifier

## Lot E1 — « Mon compte » en panneau plein écran, profil sans doublons

- **Couche**       : ui + delivery
- **Fichiers**     : app/views/shared/navigation/_avatar_menu.html.erb *(devient le panneau « Mon compte » plein écran ; seul lot qui modifie le menu de l'avatar)*
                     app/helpers/navigation_helper.rb *(`ACCOUNT_PANELS[:student]` : Mon profil, Modifier mon code secret)*
                     app/views/classroom/student_menus/show.html.erb · app/controllers/classroom/student_menus_controller.rb *(page de la coque Android, même liste)*
                     app/views/identity/profiles/show.html.erb · _student.html.erb · _student_identity.html.erb · _student_information.html.erb · _student_row.html.erb
                     config/locales/shared/navigation.fr.yml · config/locales/identity/profiles.fr.yml
- **Dépend de**    : A
- **Test associé** : test/system/identity/student_avatar_menu_test.rb · test/controllers/classroom/student_menus_controller_test.rb · test/system/identity/profile_test.rb · test/system/identity/profile_pin_test.rb
- **Done quand**   : l'avatar ouvre « Mon compte » avec Mon profil, Modifier mon code secret, Mode sombre, Se déconnecter, et rien d'autre (CA-E1) ; le profil a six lignes, Classe sans action, sans code secret, mode sombre ni déconnexion (CA-E2, CA-K2) ; le panneau enseignant (`_account_panel`) ne change pas

## Lot E2 — Ma classe, fiche de révision, résultat, Cours

- **Couche**       : ui + delivery
- **Fichiers**     : app/views/classroom/student_classrooms/show.html.erb · app/views/classroom/student_classrooms/_pending_gaps.html.erb *(déplacé depuis `student_homes/`, ancien fichier supprimé : seul lot qui déplace « Fiches à revoir »)*
                     app/views/catalog/essentials/show.html.erb *(« À revoir depuis le <date> », carte du bas retirée)*
                     app/views/assessment/session_results/show.html.erb *(seul « Recommencer »)*
                     app/views/catalog/courses/index.html.erb · _course_card.html.erb · _essential_row.html.erb · _course_group_title.html.erb *(lignes compactes de 44 px, progression écrite une fois ; côté élève seulement)*
                     config/locales/classroom/student_classrooms.fr.yml · config/locales/catalog/courses.fr.yml · config/locales/catalog/essentials.fr.yml · config/locales/assessment/session_results.fr.yml
- **Dépend de**    : A, F
- **Test associé** : test/system/classroom/student_classroom_test.rb · test/system/classroom/classroom_essential_test.rb · test/system/assessment/session_result_test.rb · test/controllers/assessment/session_results_controller_test.rb · test/controllers/catalog/courses_controller_test.rb
- **Done quand**   : Ma classe a « Fiches à revoir » juste après « Exercices assignés » (CA-E3) ; la fiche porte « À revoir depuis… » sans la carte du bas (CA-E4) ; le résultat n'a qu'un bouton, « Recommencer » (CA-E5) ; Cours écrit la progression une fois, en lignes entières cliquables de 44 px (CA-E6) ; le Cours de l'enseignant ne change pas

---

## Rattachement des critères du PRD

Les lettres des critères ne sont pas celles des lots.

| Critères | Lot |
|---|---|
| CA-A1, CA-A2 | F |
| CA-B1 à CA-B5 | B |
| CA-B7 | B2 |
| CA-C1 à CA-C7 | C |
| CA-D1 à CA-D9, CA-K3 | D |
| CA-E1, CA-E2, CA-K2 | E1 |
| CA-E3 à CA-E6 | E2 |
| CA-F1 à CA-F4 | A |

Aucun critère orphelin (34 critères ; CA-D10 passe à la phase ordinateur).

## Vérification de collision

Doublons cherchés mécaniquement (`awk … | sort | uniq -d`, vide). Fichiers partagés et leur seul propriétaire :

| Fichier | Lot propriétaire | Remarque |
|---|---|---|
| `config/routes/classroom.rb` | B | aucune autre route dans le chantier élève |
| `db/migrate/…`, `db/schema.rb`, `test/fixtures/classrooms.yml` | B | aucune autre migration ; un lot qui a besoin d'une fixture partagée nouvelle s'arrête |
| `app/domain/ports/classroom/classroom_repository_port.rb` | B | gelé à la fusion de B ; C le consomme via le Turbo Frame |
| `app/assets/stylesheets/application.tailwind.css`, `components_helper.rb`, `badges_helper.rb` | A | D, E1, E2 partent de la version de A |
| `test/design/design_tokens_test.rb` | A | |
| fichiers du balayage des graisses (147) | A | A part en parallèle de B et F : il ne touche ni `app/views/homepage/` (F) ni les fichiers nouveaux de B ; C, D, E1, E2 partent **après** la fusion de A |
| `app/views/shared/navigation/_header.html.erb`, `_home_band.html.erb`, `app/views/layouts/shell.html.erb` | D | règle anti-conflit validée : l'en-tête bleu n'est modifié que dans D |
| `app/views/shared/navigation/_avatar_menu.html.erb`, `app/helpers/navigation_helper.rb`, `config/locales/shared/navigation.fr.yml` | E1 | le menu de l'avatar appartient à E1 ; D le rend sans le modifier et met ses clés d'en-tête dans `student_homes.fr.yml` |
| `app/views/classroom/student_homes/_pending_gaps.html.erb` | E2 | règle validée : D cesse de le rendre, seul E2 le déplace et le supprime |
| `app/views/classroom/student_registrations/*`, `app/views/classroom/joins/new.html.erb`, `joins_controller.rb` | C | B ne touche que le contrôleur d'inscription (paramètre `code`), pas ses vues |
| `app/controllers/classroom/student_registrations_controller.rb` | B | C n'en a pas besoin : l'étape à rouvrir se déduit des erreurs dans la vue |
| `config/initializers/pilot_flags.rb` | — | déjà sur la branche de chantier ; F le lit sans le modifier |
| `app/views/catalog/courses/*` | E2 | |
| `app/views/classroom/classrooms/_link.html.erb` | B2 | dans le balayage de A : B2 fusionne avant A |

## Ordre de fusion dans la branche de chantier

Seule la session « MVP teacher-student » fusionne dans `feature/mvp-teacher-student`, lot par lot, après les captures (390 px et ordinateur) validées par le porteur.

1. **C** (inscription), dès sa revue faite : il est parti de `021804cc`, après B. **B2** (code sur la page de classe) juste après, en tout cas **avant A**, car son fichier est dans le balayage.
2. **A** (jetons) : l'orchestrateur fusionne d'abord la branche de chantier dans `-lot-p` (après B2), puis finit le balayage. Comme C est fusionné avant A, le balayage couvre aussi les vues de l'inscription. A ne fusionne qu'après les captures élève et enseignant validées.
3. **F** (page publique), dès qu'il est prêt, avant ou après A : il ne touche que `app/views/homepage/`, que le balayage exclut.
4. **D, E1** partent de la branche de chantier **après A** ; **E2** après A et F. Aucun ordre entre eux : si D retire l'interrupteur de l'en-tête avant que E1 ne le mette dans « Mon compte », la page Profil le porte encore (E1 l'en retire en même temps qu'il l'ajoute au menu).

Chaque fusion : `git merge --no-ff` de la branche de lot, tests des fichiers du lot et `bin/system-changed` relancés sur la branche de chantier, puis push.

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle *(ici : B fusionné avant C)*
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

Portes propres au pilote :

- [ ] `security-reviewer` sur le Lot B avant sa fusion (code de classe, ID-07)
- [ ] Captures à 390 px et sur ordinateur de chaque écran modifié, validées par le porteur, jamais commitées ; écrans élève et enseignant seulement (porteur, 2026-10-24 : les écrans de la direction et de l'équipe ne sont pas montrés)
- [ ] Recette sur un vrai téléphone Android, lundi 26 (porteur)
- [ ] Élèves testeurs invités au test fermé Play Store (porteur)
- [ ] Retour de l'« Espace établissement » le 2 novembre : drapeau `school_space_enabled` allumé, commit daté prévu

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Pour ce chantier : parcours élève (lien WhatsApp → inscription → accueil → exercice → résultat → Ma classe), sur un téléphone de 390 px et sur ordinateur ; chemins d'erreur : code inconnu, 11ᵉ essai dans la minute, lien régénéré, erreur serveur sur le numéro, élève sans classe.

---

## Phase ordinateur — élève

> Après les lots téléphone (porteur, 2026-10-24 : « téléphone d'abord, ordinateur ensuite »). Critères : [`prd.md`](prd.md) §4 bis ; écrans : UDR accueil §3.1, UDR inscription §3.5 bis, UDR écrans élève §3.1 et §3.6 bis. Captures à 1024 et 1440 px (et à 390 px pour O2 et O5, qui changent aussi le téléphone), validées par le porteur avant chaque fusion.
>
> **Ne change rien au téléphone** (porteur, 2026-10-24) : les lots O ne touchent qu'à ce qui s'affiche ≥ lg. Les écrans téléphone validés le 2026-10-23 (lots E1, E2) font foi. Le menu à « Mon établissement », le profil à carte bleue, l'écran « Mon établissement » et Cours par leçons sont **pour l'ordinateur seulement** (O2, O5) : chaque lot vérifie qu'à 390 px rien ne change.

| Lot | Dépend de | En parallèle avec |
|---|---|---|
| O1 — Accueil élève en page large | D | O2, O3, O4, O5, O6 |
| O2 — « Mon compte », profil et Mon établissement sur ordinateur | E1 | O1, O3, O4, O5, O6 |
| O3 — Inscription en deux colonnes | C | tous |
| O4 — Ma classe, fiche de révision, résultat sur ordinateur | E2 | tous |
| O5 — Cours par leçons sur ordinateur | E2 | tous |
| O6 — Page d'accueil publique sur ordinateur | F | tous |

### Lot O1 — Accueil élève en page large

- **Couche**       : ui
- **Fichiers**     : app/views/classroom/student_homes/show.html.erb · _band.html.erb *(masqué dès lg)* · _next_step.html.erb · _subjects.html.erb · _history.html.erb · app/views/communication/messages/_carousel.html.erb *(deux cartes visibles dès lg, branche élève)*
                     app/views/shared/navigation/_sidebar.html.erb *(branche élève : sans carte de profil, navigation dans une carte blanche ; seul lot de la phase élève qui touche la barre latérale — le lot enseignant P0 la touche aussi, à fusionner l'un après l'autre)*
                     app/views/layouts/shell.html.erb *(élève dès lg : fond `bg-mist` ; vaut pour tous les écrans élève)*
- **Dépend de**    : D
- **Test associé** : test/system/classroom/student_home_test.rb *(cas « ordinateur », fenêtre de 1440 px)*
- **Done quand**   : sur ordinateur, contenu de 912 px au plus à côté de la barre latérale sans carte de profil, sans bandeau (ligne bleue de la barre du haut seulement), sections empilées : carte, matières sur une ligne de 7, annonces à deux cartes visibles, Historique, fond `bg-mist` et sections en cartes blanches (CA-D10) ; à 390 px, l'accueil ne change pas

### Lot O2 — « Mon compte », profil et Mon établissement sur ordinateur

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : app/views/shared/navigation/_avatar_menu.html.erb *(panneau latéral droit de 400 px dès lg ; entrée « Mon établissement » visible dès lg seulement)*
                     app/views/identity/profiles/show.html.erb · _student.html.erb *(dès lg : colonne de 720 px, carte bleue au nom seul, 4 lignes ; à 390 px, inchangé)*
                     app/infrastructure/queries/school/student_school_query.rb *(nouveau : nom, sigle, DRENA, type de l'établissement de la classe de l'élève connecté, sans identifiant reçu)*
                     app/controllers/school/student_schools_controller.rb · app/views/school/student_schools/show.html.erb *(nouveaux)*
                     config/routes/school.rb *(`GET /students/school`)*
                     config/locales/shared/navigation.fr.yml · config/locales/identity/profiles.fr.yml · config/locales/school/student_schools.fr.yml *(nouveau)*
- **Dépend de**    : E1
- **Test associé** : test/system/identity/student_avatar_menu_test.rb · test/system/identity/profile_test.rb · test/infrastructure/queries/school/student_school_query_test.rb · test/controllers/school/student_schools_controller_test.rb
- **Done quand**   : sur ordinateur, « Mon compte » s'ouvre en panneau de 400 px et se ferme par Échap, la croix ou le voile, le focus revenant sur l'avatar (CA-E7) ; son en-tête n'a que l'avatar et le nom, et sa liste contient « Mon établissement », pas Ma classe (CA-E8) ; le profil a la carte bleue au nom seul et 4 lignes (CA-E9) ; « Mon établissement » montre Nom, Sigle, DRENA, Type de l'établissement de l'élève et de lui seul (CA-E10) ; à 390 px, menu et profil restent ceux de CA-E1 et CA-E2

### Lot O3 — Inscription en deux colonnes

- **Couche**       : ui
- **Fichiers**     : app/views/classroom/student_registrations/new.html.erb · _form.html.erb · app/views/classroom/joins/new.html.erb *(panneau de 360 px et colonne du formulaire dès lg)*
                     app/javascript/controllers/classroom/signup_steps_controller.js *(met à jour la liste des étapes du panneau et le rappel de classe sous l'étape 1)*
                     config/locales/classroom/student_registrations.fr.yml
- **Dépend de**    : C
- **Test associé** : test/system/identity/student_signup_steps_test.rb · test/system/classroom/join_test.rb *(cas « ordinateur »)*
- **Done quand**   : sur ordinateur, le panneau `brand-strong` (bienvenue, trois étapes, « Déjà un compte ? ») est le même aux trois étapes et remplace la barre ; la classe trouvée s'affiche sous l'étape 1 avec « Ce n'est pas ta classe ? › », pas au-dessus du formulaire (CA-C8, CA-C9) ; sans JavaScript, l'inscription aboutit toujours (CA-C7)

### Lot O4 — Ma classe, fiche de révision, résultat sur ordinateur

- **Couche**       : ui
- **Fichiers**     : app/views/classroom/student_classrooms/show.html.erb *(colonnes 2/3 – 1/3)*
                     app/views/catalog/essentials/show.html.erb *(élève : colonne « Exercices » de 300 px collante ; enseignant et équipe inchangés)*
                     app/views/assessment/session_results/show.html.erb *(colonne de 340 px collante)*
- **Dépend de**    : E2
- **Test associé** : test/system/classroom/student_classroom_test.rb · test/system/classroom/classroom_essential_test.rb · test/system/assessment/session_result_test.rb *(cas « ordinateur »)*
- **Done quand**   : Ma classe met assignés et fiches à revoir à gauche (2/3), traités à droite (1/3) (CA-E11) ; la carte « Exercices » de la fiche reste visible au défilement pour l'élève, l'enseignant garde l'ancienne mise en page (CA-E12) ; le résultat garde note et « Recommencer » visibles pendant la correction (CA-E13)

### Lot O5 — Cours par leçons sur ordinateur

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : app/views/catalog/courses/index.html.erb · _course_card.html.erb · _essential_row.html.erb *(élève, dès lg : pastilles des matières, cartes de leçon sur deux colonnes avec leurs fiches ; à 390 px, inchangé)*
                     app/infrastructure/queries/catalog/course_catalog_query.rb *(branche élève : fiches de chaque leçon et marque « à revoir », sans N+1)*
                     app/controllers/catalog/courses_controller.rb *(élève sans `?material=` : dernière matière touchée, gardée en session, sinon la première de la grille)*
                     config/locales/catalog/courses.fr.yml
- **Dépend de**    : E2
- **Test associé** : test/infrastructure/queries/catalog/course_catalog_query_test.rb · test/controllers/catalog/courses_controller_test.rb · test/system/catalog/student_courses_test.rb *(nouveau, 1440 et 390 px)*
- **Done quand**   : sur ordinateur, les leçons de la matière en cartes sur deux colonnes avec leurs fiches, 3 puis « Voir les N fiches », « À revoir » sur la bonne fiche (CA-E14) ; pastilles des 6 matières, la bonne en `aria-current="page"`, « Cours » de la barre latérale ouvre la dernière matière touchée (CA-E15) ; à 390 px, Cours reste celui de CA-E6 ; le Cours de l'enseignant ne change pas

### Lot O6 — Page d'accueil publique sur ordinateur

- **Couche**       : ui
- **Fichiers**     : app/views/homepage/index.html.erb *(variantes `lg:` ; seulement si F ne les a pas livrées)*
- **Dépend de**    : F
- **Test associé** : test/system/homepage_test.rb *(cas « ordinateur »)*
- **Done quand**   : sur ordinateur, texte à gauche et photo à droite sur un seul écran, sans en-tête ni pied de page, la feuille mordant sur la photo (CA-A3)

**Collision** : aucun fichier n'est listé par deux lots O. `_sidebar` n'est qu'à O1, `_avatar_menu`, `profiles/*` et `config/routes/school.rb` qu'à O2, `catalog/essentials/show` qu'à O4, `catalog/courses/*`, `course_catalog_query` et `courses_controller` qu'à O5. Les lots O touchent des fichiers des lots C, D, E1, E2 et F : ils partent donc de la branche de chantier **après** la fusion du lot dont ils dépendent.
