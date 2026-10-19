# Plan d'exécution — « Fiche de cours » et « Fiche de révision » à l'écran

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Règles d'écriture : [UDR-0130](../../decisions/udr/0130-vocabulaire-fiche-de-cours-et-fiche-de-revision.md) §3, appliquée littéralement.

## Particularité du chantier

**Aucune migration, aucune entité, aucun port, aucune route, aucune clé de traduction nouvelle.** Seules changent :

- les **valeurs** des fichiers `config/locales/**/*.fr.yml` ;
- les tests qui comparent un texte exact ;
- la doc qui fait foi.

Les fichiers de traduction sont découpés par écran : chaque lot vertical possède les siens, et aucun n'est partagé entre deux lots (voir le tableau de collision). Le socle se réduit donc à la garde de vocabulaire.

## Graphe

```
Lot 0 — Garde de vocabulaire (rouge d'abord)
  ↓
  ├─► Lot A  Élève et enseignant lisent les nouveaux noms   ┐
  ├─► Lot B  L'équipe crée et importe des fiches             ├─ en parallèle
  ├─► Lot C  Le visiteur lit les pages publiques             │
  └─► Lot D  La doc qui fait foi parle comme l'écran         ┘
```

Le test de garde du Lot 0 est **rouge** à son merge, et c'est voulu : il liste toutes les valeurs encore fautives. Il ne passe au vert qu'une fois A, B et C mergés. C'est le test rouge du chantier entier.

---

## Lot 0 — Garde de vocabulaire

- **Couche**       : ui (garde des traductions) + doc (index)
- **Fichiers**     : `test/i18n/locale_files_test.rb`
                     `docs/chantiers/README.md` *(ligne du chantier)*
- **Dépend de**    : —
- **Test associé** : `test/i18n/locale_files_test.rb`
  - `FORBIDDEN` ajoute `essentielle` ;
  - `ALLOWED` passe à « Révisions de la leçon » sous les deux mêmes clés ;
  - le test « the vocabulary pattern catches what it must » vérifie que « Fiche essentielle » est attrapé et que « Fiche de révision » ne l'est pas.
- **Done quand**   : `bin/rails test test/i18n/locale_files_test.rb` échoue en listant les valeurs de A, B et C qui contiennent « essentielle » ou « Essentielles de la leçon », et uniquement celles-là.

---

## Lot A — Élève et enseignant lisent les nouveaux noms

- **Couche**       : ui
- **Fichiers**     : `config/locales/catalog/courses.fr.yml`
                     `config/locales/catalog/essentials.fr.yml`
                     `config/locales/classroom/classroom_courses.fr.yml`
                     `config/locales/classroom/classroom_essentials.fr.yml`
                     `config/locales/classroom/classrooms.fr.yml`
                     `config/locales/classroom/student_homes.fr.yml`
                     `config/locales/classroom/student_classrooms.fr.yml`
                     `config/locales/classroom/teacher_homes.fr.yml`
                     `config/locales/assessment/exercises.fr.yml`
                     `config/locales/communication/help.fr.yml`
                     `config/locales/shared/navigation.fr.yml`
                     `test/controllers/catalog/courses_controller_test.rb`
                     `test/controllers/catalog/essentials_controller_test.rb`
                     `test/controllers/catalog/student_level_test.rb`
                     `test/controllers/classroom/classroom_courses_controller_test.rb`
                     `test/controllers/classroom/classrooms_controller_test.rb`
                     `test/controllers/classroom/student_homes_controller_test.rb`
                     `test/controllers/classroom/teacher_homes_controller_test.rb`
                     `test/controllers/assessment/exercises_controller_test.rb`
                     `test/infrastructure/queries/assessment/session_result_query_test.rb`
                     `test/system/finitions/catalog_and_student_test.rb`
                     `test/system/classroom/classroom_page_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/catalog/courses_controller_test.rb` et `test/controllers/catalog/essentials_controller_test.rb`. Ils portent les critères du PRD « liste des fiches d'un cours », « surtitre », « compteur du catalogue », « onglet garde son nom » et « adresses ne changent pas ». `test/controllers/classroom/student_homes_controller_test.rb` porte « Fiches à revoir », et le bandeau « Fiche à revoir » est vérifié dans `essentials_controller_test.rb`.
- **Done quand**   : un élève ouvre l'onglet « Cours », lit « 3 fiches de cours », ouvre une fiche de cours, lit « Révisions de la leçon », ouvre une fiche de révision dont le surtitre dit « Fiche de révision ». Avec une lacune, il lit « Fiches à revoir » sur son accueil. L'enseignant lit « Fiches de cours » dans son accueil et sa classe.

---

## Lot B — L'équipe crée et importe des fiches

- **Couche**       : ui
- **Fichiers**     : `config/locales/teams/courses.fr.yml`
                     `config/locales/teams/essentials.fr.yml`
                     `config/locales/teams/exercises.fr.yml`
                     `config/locales/teams/import_course_tree.fr.yml`
                     `config/locales/teams/import_essentials.fr.yml`
                     `config/locales/teams/import_exercises.fr.yml`
                     `config/locales/teams/imports.fr.yml`
                     `config/locales/teams/invitations.fr.yml`
                     `config/locales/teams/publish_cascade.fr.yml`
                     `config/locales/teams/levels.fr.yml`
                     `config/locales/teams/series.fr.yml`
                     `config/locales/teams/materials.fr.yml`
                     `config/locales/teams/level_classrooms.fr.yml`
                     `config/locales/teams/homes.fr.yml`
                     `config/locales/teams/referentials.fr.yml`
                     `config/locales/shared/common.fr.yml`
                     `config/locales/design/index.fr.yml`
                     `test/controllers/teams/courses_controller_test.rb`
                     `test/controllers/teams/essentials_controller_test.rb`
                     `test/controllers/teams/exercises_controller_test.rb`
                     `test/controllers/teams/imports_controller_test.rb`
                     `test/controllers/teams/levels_controller_test.rb`
                     `test/controllers/teams/series_controller_test.rb`
                     `test/controllers/teams/materials_controller_test.rb`
                     `test/controllers/teams/homes_controller_test.rb`
                     `test/controllers/design_controller_test.rb`
                     `test/system/finitions/team_content_test.rb`
                     `test/system/catalog/import_course_tree_test.rb`
                     `test/system/catalog/import_essentials_test.rb`
                     `test/system/imports_end_to_end_test.rb`
                     `test/system/teams/import_flow_test.rb`
                     `test/system/teams/levels_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/teams/courses_controller_test.rb` porte « l'équipe crée une fiche de cours », toast accordé au féminin. `test/controllers/teams/essentials_controller_test.rb` porte « l'équipe crée une fiche de révision » et le refus « La fiche de cours de cette fiche de révision n'est pas publiée… ». `test/controllers/teams/exercises_controller_test.rb` porte « Publiez d'abord la fiche de révision et sa fiche de cours. »
- **Done quand**   : l'équipe crée « Thalès » et lit « Fiche de cours « Thalès » créée (brouillon). », puis crée « Réciproque » et lit « Fiche de révision « Réciproque » créée (brouillon). ». Ses imports s'intitulent « Fiches de cours complètes » et « Fiches de révision ». Ses tableaux du référentiel ont une colonne « Fiches de cours », lisible à 390 px.

---

## Lot C — Le visiteur lit les pages publiques

- **Couche**       : ui
- **Fichiers**     : `config/locales/homepage/index.fr.yml`
                     `config/locales/communication/pages/mission.fr.yml`
                     `config/locales/communication/pages/terms.fr.yml`
                     `test/controllers/homepage_controller_test.rb`
                     `test/controllers/communication/pages/mission_test.rb`
                     `test/controllers/communication/pages_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/communication/pages_controller_test.rb` porte « les CGU nomment les nouveaux objets sans nouvelle version » : texte attendu, et `updated_on` égal à « 2 octobre 2026 ».
- **Done quand**   : un visiteur lit « fiches de cours, fiches de révision et exercices » sur l'accueil, la mission et les CGU. La date de mise à jour des CGU n'a pas bougé. Le sens courant (« comprendre leurs cours », « Révise l'essentiel du cours ») est intact.

---

## Lot D — La doc qui fait foi parle comme l'écran

- **Couche**       : doc
- **Fichiers**     : `docs/guide/glossaire.md`
                     `docs/guide/architecture.md`
                     `docs/README.md`
                     `docs/contenus/README.md`
                     `docs/contenus/prompt-redaction.md`
- **Dépend de**    : Lot 0
- **Test associé** : pas de test automatisé de la doc. La vérification est mécanique : `grep -rniE "fiches? essentielles?" docs/guide docs/contenus/README.md docs/contenus/prompt-redaction.md docs/README.md` ne renvoie que les mentions explicites de l'ancien nom (« anciennement « Fiche essentielle » »). Le prompt de rédaction garde ses clés JSON `essentials`.
- **Done quand**   : le glossaire (§3 et §8) donne « Fiche de cours » pour `Course` et « Fiche de révision » pour `Essential`, ajoute « Fiche essentielle » aux interdits d'écran et renvoie à l'UDR-0130. Le prompt de rédaction demande des « fiches de révision ».

---

## Dispatch

```
Vague 1 : Lot 0                          → 1 agent, séquentiel
Vague 2 : Lot A ‖ Lot B ‖ Lot C ‖ Lot D  → 4 agents, worktrees isolés
Vague 3 : challenger empirique           → 1 rôle distinct
```

Les branches de lot partent de `feature/renommage-fiche-revision` **après le merge du Lot 0** :

```bash
git worktree add ../lnclass-renommage-fiche-revision-lot-a -b feature/renommage-fiche-revision-lot-a feature/renommage-fiche-revision
```

Consignes à chaque agent de lot :

- chemins **absolus** et `git -C <worktree>` ;
- **interdiction de toucher un fichier absent de son champ `Fichiers`**. S'il en a besoin, il s'arrête et remonte ;
- il applique l'UDR-0130 §3 à la lettre : accords au féminin, faux amis intacts, rubrique « Cours » intacte ;
- il lance les tests de ses fichiers ; le test de garde reste rouge tant que les autres lots ne sont pas mergés.

## Vérification de collision

> Aucun fichier n'apparaît dans deux lots. Vérifié mécaniquement : `awk '/^## Vérification de collision/{exit} 1' plan.md | grep -oE '(app|test|config|db|lib)/[A-Za-z0-9_/.-]+\.(rb|erb|yml|js)' | sort | uniq -d` ne renvoie que des fichiers cités deux fois **dans le même lot** (champ `Fichiers` puis `Test associé`). Chacun a été contrôlé : aucun n'est partagé entre deux lots. Tous les chemins listés existent.

| Fichier | Lot propriétaire |
|---|---|
| `test/i18n/locale_files_test.rb` | Lot 0 |
| `docs/chantiers/README.md` | Lot 0 |
| `config/locales/shared/navigation.fr.yml` | Lot A |
| `config/locales/catalog/courses.fr.yml` (porte une des deux clés `ALLOWED`) | Lot A |
| `config/locales/classroom/classroom_courses.fr.yml` (porte l'autre clé `ALLOWED`) | Lot A |
| `config/locales/shared/common.fr.yml` | Lot B |
| `config/locales/design/index.fr.yml` | Lot B |
| `config/routes.rb`, `app/views/layouts/`, `db/` | aucun lot : non touchés |

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
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Ici, il parcourt l'application **à 390 px et sur ordinateur**, en élève, en enseignant et en équipe :
> - parcours nominal : catalogue → fiche de cours → fiche de révision → accueil avec une lacune ;
> - chemin d'erreur : publier une fiche de révision dont la fiche de cours est en brouillon.
>
> Il relève toute occurrence restante de « fiche essentielle », tout accord oublié, et tout en-tête de colonne qui déborde. Les captures sont envoyées au porteur, jamais commitées.

## Couverture des critères du PRD

| Critère (PRD §4) | Lot |
|---|---|
| Plus aucune « fiche essentielle » à l'écran | 0 (garde), verte après A + B + C |
| La liste des fiches d'un cours | A |
| Le surtitre de la fiche de révision | A |
| La fiche à revoir | A |
| L'équipe crée une fiche de cours | B |
| L'équipe crée une fiche de révision | B |
| Le compteur du catalogue | A |
| L'onglet de navigation garde son nom | A |
| Les adresses ne changent pas | A |
| Les CGU sans nouvelle version | C |

Aucun critère orphelin.
