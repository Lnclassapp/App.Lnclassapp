# Plan d'exécution — Réorganisation des espaces Équipe et Enseignant

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Contrats : [PRD](prd.md) (RE-01 à RE-28) · [UDR-0068](../../decisions/udr/0068-configuration-et-pilotage-par-etablissement.md) (équipe) · [UDR-0069](../../decisions/udr/0069-accueil-enseignant-par-niveau-et-assignation-depuis-le-catalogue.md) (enseignant) · [ADR-0062, amendement du 2026-10-03](../../decisions/adr/0062-indicateurs-de-pilotage-lus-en-direct.md).

## Graphe

```
Lot 0 — SOCLE (séquentiel) : navigation à deux listes, menu « Plus », carte latérale enseignant (frame),
        route du Référentiel, teintes, bulle et illustrations
  ↓
  ├─► Lot A  Équipe : page Référentiel, accueil sans Référentiel        (RE-01 à RE-05)  ┐
  ├─► Lot B  Pilotage : recherche de DRENA, « Par établissement »       (RE-06 à RE-10)  │
  ├─► Lot C  Catalogue : filtre « Série »                               (RE-14, RE-15)   │
  ├─► Lot D  Accueil enseignant : ordre, menu, cours par niveau         (RE-11 à RE-13,  ├─ en parallèle,
  │                                                                      RE-16 à RE-18, RE-20, RE-28) │  fichiers disjoints
  ├─► Lot E  Carte « Parrainage » de la barre latérale                  (RE-18, RE-19)   │
  ├─► Lot F  Assigner depuis le catalogue                               (RE-21 à RE-26)  │
  └─► Lot G  Le niveau d'un cours assigné ne change pas (ADR-0075)    (RE-27)          ┘
```

**Un seul contrat de domaine bouge** : la méthode `assigned_classroom_levels(id:)` de `Ports::Catalog::CourseRepositoryPort` (ADR-0075), gelée au Lot 0, implémentée au Lot G. Aucune entité, aucune migration. Le reste du Lot 0 gèle des contrats d'interface (helpers, composants, routes, locales partagées, emplacements de la barre latérale).

---

## Lot 0 — Socle

- **Couche**       : domaine (port) + delivery + ui (contrats partagés : navigation, composant, tokens, route)
- **Fichiers**     : `app/domain/ports/catalog/course_repository_port.rb` *(`assigned_classroom_levels(id:)`, contrat gelé, ADR-0075)*
                     `config/routes/teams.rb` *(route `teams_referential`, UDR-0068 §3.4)*
                     `config/locales/shared/navigation.fr.yml`
                     `app/helpers/navigation_helper.rb` *(DESTINATIONS team, SECONDARY_DESTINATIONS, secondary_navigation_for, more_active?, HOME_SECTIONS team et teacher, SIDEBAR_FRAMES)*
                     `app/views/shared/navigation/_sidebar.html.erb` *(2e carte « Configuration », frame `sidebar_referral` de l'enseignant)*
                     `app/views/shared/navigation/_bottom_bar.html.erb`
                     `app/views/shared/navigation/_more_menu.html.erb` *(nouveau)*
                     `app/helpers/components_helper.rb` *(`ui_subject_bubble`, `SUBJECT_ILLUSTRATIONS`, `subject_illustration`)*
                     `app/views/components/_subject_bubble.html.erb` *(nouveau)*
                     `app/assets/stylesheets/application.tailwind.css` *(7 teintes `--color-tint-*`, clair et les deux blocs sombres)*
                     `app/assets/images/subjects/{maths,physique-chimie,svt,francais,histoire-geographie,edhc,philosophie,inviter,generique}.svg` *(nouveaux)*
                     `test/helpers/navigation_helper_test.rb`
                     `test/helpers/components_helper_test.rb`
                     `test/support/factories/` *(seul propriétaire : un lot qui a besoin d'une nouvelle fabrique s'arrête et la demande au Lot 0)*
- **Dépend de**    : —
- **Test associé** : `test/helpers/navigation_helper_test.rb` (deux listes de l'équipe, 5 cases au plus, `more_active?`, sections d'accueil) · `test/helpers/components_helper_test.rb` (illustration par slug, alias, générique, `:invite`) · `test/design/dark_mode_test.rb` (inchangé, doit passer avec les 7 teintes)
- **Done quand**   : sur un écran large, un membre de l'équipe voit la carte « Configuration » (Référentiel, Imports) sous ses destinations ; à 390 px, « Plus » ouvre le menu vers le haut ; un enseignant a, dans sa barre latérale, le frame différé `sidebar_referral` ; `ui_subject_bubble` rend une bulle teintée en clair et en sombre ; les helpers sont gelés et les lots verticaux peuvent démarrer

---

## Lot A — Équipe : page Référentiel et accueil sans Référentiel

- **Couche**       : delivery + ui
- **Fichiers**     : `app/controllers/teams/referentials_controller.rb` *(nouveau)*
                     `app/views/teams/referentials/show.html.erb` *(nouveau)*
                     `app/views/teams/referentials/_summary.html.erb` *(nouveau, reprend `teams/homes/_referential`)*
                     `config/locales/teams/referentials.fr.yml` *(nouveau)*
                     `app/views/teams/homes/show.html.erb`
                     `app/views/teams/homes/_referential.html.erb` *(supprimé)*
                     `config/locales/teams/homes.fr.yml`
                     `test/controllers/teams/referentials_controller_test.rb` *(nouveau)*
                     `test/controllers/teams/homes_controller_test.rb`
                     `test/system/teams/team_home_test.rb`
                     `test/system/finitions/team_referential_test.rb`
                     `test/system/teams/configuration_navigation_test.rb` *(nouveau)*
                     `test/system/role_homes_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/teams/referentials_controller_test.rb` (RE-03, RE-04) · `test/controllers/teams/homes_controller_test.rb` (RE-05) · `test/system/teams/configuration_navigation_test.rb` (RE-01, RE-02 : carte en bureau, menu « Plus » à 390 px, `aria-current`)
- **Done quand**   : depuis la carte « Configuration » ou le menu « Plus », l'équipe ouvre « Référentiel » et y gère DRENA, niveaux, séries, matières et barème ; l'accueil équipe n'a plus de section Référentiel ; un élève reçoit 403 sur `/teams/referential`

---

## Lot B — Pilotage : recherche de DRENA et « Par établissement »

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/school/drena_schools_query.rb` *(nouveau)*
                     `app/controllers/teams/dashboards_controller.rb`
                     `app/views/teams/dashboards/show.html.erb`
                     `app/views/teams/dashboards/_drenas.html.erb`
                     `app/views/teams/dashboards/_schools.html.erb` *(nouveau)*
                     `app/javascript/controllers/table_filter_controller.js` *(nouveau ; enregistré par motif, aucun manifeste)*
                     `config/locales/teams/dashboards.fr.yml`
                     `test/infrastructure/queries/school/drena_schools_query_test.rb` *(nouveau)*
                     `test/controllers/teams/dashboards_controller_test.rb`
                     `test/system/teams/dashboard_test.rb`
                     `test/performance/school/heavy_screens_budget_test.rb` *(cas « pilotage filtré, plus grande DRENA »)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/school/drena_schools_query_test.rb` (RE-07 périmètre, RE-08 somme = ligne DRENA, RE-09 tri et pages, RE-10 recherche, établissement inactif compté, nombre de requêtes fixe) · `test/controllers/teams/dashboards_controller_test.rb` (RE-07 lien et remplacement du tableau, paramètres invalides) · `test/system/teams/dashboard_test.rb` (RE-06 filtre de DRENA, message vide, 390 px)
- **Done quand**   : sur le pilotage, l'équipe tape « abidj » et ne garde que les DRENA d'Abidjan ; elle clique « Abidjan 1 » et lit, période gardée, les établissements de la DRENA, 25 par page, cherchables par nom ; la somme des établissements égale la ligne de la DRENA ; le budget `PERF=1` du pilotage tient (< 300 ms p95)

---

## Lot C — Catalogue : filtre « Série »

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/catalog/course_catalog_query.rb`
                     `app/controllers/catalog/courses_controller.rb`
                     `app/views/catalog/courses/index.html.erb`
                     `config/locales/catalog/courses.fr.yml`
                     `test/infrastructure/queries/catalog/course_catalog_query_test.rb`
                     `test/controllers/catalog/courses_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/catalog/course_catalog_query_test.rb` (RE-15 : série vide ou choisie, série inconnue, série sans niveau ignorée) · `test/controllers/catalog/courses_controller_test.rb` (RE-14 : `level=tle&series=d&material=mathematiques` → cours de Maths Tle sans série et Tle D, ni Tle C ni Physique-Chimie ; liste « Série » absente pour l'élève)
- **Done quand**   : l'adresse d'une bulle « Tle D » (`/courses?level=tle&series=d&material=…`) liste exactement les cours de la matière en Tle sans série et en Tle D ; l'enseignant et l'équipe ont la liste « Série » dans les filtres, l'élève non

---

## Lot D — Accueil enseignant : ordre, menu de « Mes classes », cours par niveau

- **Couche**       : infrastructure + ui
- **Fichiers**     : `app/infrastructure/queries/classroom/teacher_home_query.rb`
                     `app/views/classroom/teacher_homes/show.html.erb`
                     `app/views/classroom/teacher_homes/_course_levels.html.erb` *(nouveau)*
                     `config/locales/classroom/teacher_homes.fr.yml`
                     `test/infrastructure/queries/classroom/teacher_home_query_test.rb`
                     `test/controllers/classroom/teacher_homes_controller_test.rb`
                     `test/system/classroom/teacher_home_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/classroom/teacher_home_query_test.rb` (couples niveau-série distincts, classes archivées et d'une autre année exclues, tri, `material_slug`) · `test/controllers/classroom/teacher_homes_controller_test.rb` (RE-11, RE-12, RE-13, RE-16, RE-17, RE-18 bulle, RE-28) · `test/system/classroom/teacher_home_test.rb` (RE-20 : bloc d'invitation visible à 390 px, masqué à 1280 px ; en-tête de « Mes classes » sans retour à la ligne à 375 px)
- **Done quand**   : un professeur de Maths en 3ème 1, 3ème 2, 1ère A et Tle D voit « Mes classes » (menu ⋮ « Modifier mes classes »), « Cours » avec les bulles « 3ème », « 1ère A », « Tle D » à l'illustration des Maths puis « Inviter », puis « Activités » ; chaque bulle mène au catalogue filtré ; aucun « Versement »

---

## Lot E — Carte « Parrainage » de la barre latérale

- **Couche**       : delivery + ui
- **Fichiers**     : `app/controllers/identity/referrals_controller.rb`
                     `app/views/identity/referrals/_sidebar_card.html.erb` *(nouveau)*
                     `config/locales/identity/referrals.fr.yml`
                     `test/controllers/identity/referrals_controller_test.rb`
                     `test/system/identity/sidebar_referral_test.rb` *(nouveau)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/identity/referrals_controller_test.rb` (RE-19 : réponse au frame `sidebar_referral` sans layout, compteur, badge, lien ; RE-18 : frame vide pour un établissement inactif, jamais 403 ; aucun identifiant partagé avec `_invite`) · `test/system/identity/sidebar_referral_test.rb` (RE-19 : carte chargée à 1280 px, partage WhatsApp compté ; absente de la page « Inviter un collègue » ; jamais demandée à 390 px)
- **Done quand**   : sur ordinateur, une enseignante d'un établissement actif voit sur chaque page de son espace la carte « Parrainage » (compteur, badge, lien, « WhatsApp », « Copier le lien ») ; un partage y est compté comme depuis la page d'invitation ; un enseignant d'établissement inactif n'a pas de carte

---

## Lot F — Assigner un exercice depuis le catalogue

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/classroom/catalog_assignment_targets_query.rb` *(nouveau)*
                     `app/controllers/catalog/essentials_controller.rb`
                     `app/controllers/assessment/exercises_controller.rb`
                     `app/views/catalog/essentials/show.html.erb`
                     `app/views/catalog/essentials/_exercise_progress.html.erb`
                     `app/views/assessment/exercises/show.html.erb`
                     `app/views/classroom/assignments/_toggle.html.erb`
                     `app/views/classroom/assignments/create.turbo_stream.erb`
                     `app/views/classroom/assignments/archive.turbo_stream.erb`
                     `config/locales/catalog/essentials.fr.yml`
                     `config/locales/assessment/exercises.fr.yml`
                     `config/locales/classroom/assignments.fr.yml`
                     `test/infrastructure/queries/classroom/catalog_assignment_targets_query_test.rb` *(nouveau)*
                     `test/controllers/catalog/essentials_controller_test.rb`
                     `test/controllers/assessment/exercises_controller_test.rb`
                     `test/controllers/classroom/assignments_controller_test.rb`
                     `test/system/classroom/catalog_assignment_test.rb` *(nouveau)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/classroom/catalog_assignment_targets_query_test.rb` (RE-23 niveau et série, cours sans série, classes d'un autre enseignant ou archivées exclues, états actifs, deux requêtes au plus) · `test/controllers/catalog/essentials_controller_test.rb` (RE-21, RE-24, RE-26) · `test/controllers/assessment/exercises_controller_test.rb` (RE-22, RE-26) · `test/controllers/classroom/assignments_controller_test.rb` (RE-25 : 422 `other_level`, rien d'écrit ; `aria-label` qui nomme la classe dans le stream) · `test/system/classroom/catalog_assignment_test.rb` (RE-21 : bascule → modale des jours → « Assigné · Pour … » sans rechargement)
- **Done quand**   : depuis une fiche du catalogue ou la page d'un exercice, un enseignant assigne un exercice à sa Tle D 1, une bascule par classe du bon niveau, avec la modale des jours la première fois ; aucune classe d'un autre niveau n'est proposée ; l'équipe ne voit aucune bascule

---

## Lot G — Le niveau d'un cours assigné ne change pas

- **Couche**       : domaine + infrastructure + ui (message du formulaire)
- **Fichiers**     : `app/domain/use_cases/catalog/update_course.rb`
                     `app/infrastructure/repositories/catalog/course_repository.rb`
                     `config/locales/teams/courses.fr.yml`
                     `test/domain/use_cases/catalog/update_course_test.rb`
                     `test/infrastructure/repositories/catalog/course_repository_test.rb`
                     `test/controllers/teams/courses_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/catalog/update_course_test.rb` (RE-27 : niveau changé avec une classe assignée → `:conflict`, rien d'écrit ; élargissement Tle D → Tle sans série permis ; restriction refusée seulement s'il reste une classe hors série ; nom seul permis) · `test/infrastructure/repositories/catalog/course_repository_test.rb` (`assigned_classroom_levels` : actives seulement, une entrée par classe, autres cours ignorés, une requête) · `test/controllers/teams/courses_controller_test.rb` (422, message sous « Niveau », cours inchangé en base)
- **Done quand**   : dans la modale de modification d'un cours de Tle D assigné à une Tle D 1, l'équipe qui choisit « 3ème » lit « Ce cours est assigné à des classes d'un autre niveau ou d'une autre série. Retirez ces assignations avant de le changer. » et le cours ne change pas ; passer à « Tle » sans série, ou renommer, est enregistré

---

## Couverture des critères d'acceptation

| Critère | Lot | Critère | Lot |
|---|---|---|---|
| RE-01, RE-02 | A (système), 0 (helper) | RE-15 | C |
| RE-03, RE-04, RE-05 | A | RE-16, RE-17 | D |
| RE-06 | B | RE-18 | D (bulle), E (carte) |
| RE-07, RE-08, RE-09, RE-10 | B | RE-19 | E |
| RE-11, RE-12, RE-13 | D | RE-20 | D |
| RE-14 | C | RE-21 à RE-26 | F |
| | | RE-27 | G (ADR-0075) |
| | | RE-28 | D |

Aucun critère orphelin.

## Dispatch

```
Vague 1 : Lot 0                                         → 1 agent, séquentiel
Vague 2 : Lot A ‖ Lot B ‖ Lot C ‖ Lot D ‖ Lot E ‖ Lot F ‖ Lot G   → 7 agents, worktrees isolés
```

- **Branche** : par décision du porteur (2026-10-03), le chantier vit **directement sur `Develop`**, sans branche de chantier ni PR. Chaque lot de la vague 2 travaille dans son worktree, sur `feature/reorganisation-equipe-enseignant-lot-<x>` créée **depuis `Develop` une fois le Lot 0 committé**, puis est fusionné dans `Develop` en local. **Rien n'est poussé avant que les portes de sortie soient vertes** : `Develop` ne reçoit jamais un état intermédiaire (navigation sans page Référentiel, frame sans réponse).
  ```bash
  git worktree add ../lnclass-reorg-lot-a -b feature/reorganisation-equipe-enseignant-lot-a Develop
  ```
- Chaque agent : chemin **absolu** de son worktree (`git -C <worktree>`), son lot recopié en entier, le PRD et l'UDR de son espace (A, B → UDR-0068 ; C à G → UDR-0069), ordre intra-lot test rouge → infrastructure → delivery → UI, en-tête HITL sur chaque fichier de `app/`. **Interdiction de toucher un fichier hors de son champ `Fichiers`** : s'il en faut un, il s'arrête et remonte (Lot 0 ou plan faux).

---

## Vérification de collision

> Faite mécaniquement, lot par lot (chemins extraits de chaque section `## Lot`, dédoublonnés dans le lot, puis comptés entre lots) : **aucun fichier n'appartient à deux lots**. Le `uniq -d` brut de la skill ne remonte que les fichiers de test cités deux fois dans leur propre lot (`Fichiers` et `Test associé`). Les fichiers qui auraient pu entrer en collision appartiennent au Lot 0.

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/teams.rb` | Lot 0 |
| `config/locales/shared/navigation.fr.yml` | Lot 0 |
| `app/helpers/navigation_helper.rb` (destinations, sections d'accueil des deux rôles, frame latéral) | Lot 0 |
| `app/views/shared/navigation/_sidebar.html.erb`, `_bottom_bar.html.erb`, `_more_menu.html.erb` | Lot 0 |
| `app/helpers/components_helper.rb`, `app/views/components/_subject_bubble.html.erb` | Lot 0 |
| `app/assets/stylesheets/application.tailwind.css` | Lot 0 |
| `app/assets/images/subjects/*.svg` | Lot 0 |
| `test/support/factories/` | Lot 0 |
| `app/domain/ports/catalog/course_repository_port.rb` | Lot 0 (contrat gelé, implémenté au Lot G) |
| `app/views/classroom/assignments/_toggle.html.erb` et ses deux streams | Lot F (seul lot qui les touche) |
| `app/javascript/controllers/table_filter_controller.js` | Lot B (enregistré par motif : aucun manifeste partagé) |
| `test/system/role_homes_test.rb` | Lot A |
| `config/locales/*` : un fichier par écran, chacun à un seul lot (teams/referentials, teams/homes → A ; teams/dashboards → B ; catalog/courses → C ; classroom/teacher_homes → D ; identity/referrals → E ; catalog/essentials, assessment/exercises, classroom/assignments → F ; teams/courses → G) | — |

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md`
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md`
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR *(remplacée, par décision du porteur, par une poussée directe sur `Develop` une fois toutes les autres portes vertes)*
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Pour ce chantier : parcours nominal équipe (carte « Configuration » → Référentiel ; pilotage → « abidj » → Abidjan 1 → page 2) et enseignant (bulle « Tle D » → fiche → « Assigner » → modale des jours → « Assigné ») ; chemins d'erreur : POST d'assignation hors niveau (422), changement de niveau d'un cours assigné (422, cours inchangé), élève sur `/teams/referential` (403), recherche de DRENA sans résultat ; à 390 px et à 1280 px, en clair et en sombre ; budget `PERF=1` du pilotage filtré.
