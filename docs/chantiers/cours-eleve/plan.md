# Plan d'exécution — Page Cours de l'élève aux couleurs Wave et Djamo

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Décisions : [PRD](prd.md) · [ADR-0090](../../decisions/adr/0090-lecture-des-fiches-par-l-eleve-et-rang-des-matieres.md) · [UDR-0085](../../decisions/udr/0085-page-cours-eleve-groupee-par-matiere-avec-bouton-d-avancement.md).
> **Prérequis** : la PR du chantier [`accueil-eleve`](../accueil-eleve/plan.md) est fusionnée (en-tête, menu de l'avatar, plus de barre du bas, `DailyExerciseQuery`). Le code se fait dans une nouvelle session, une seule PR, un commit par lot (5 commits).

## Graphe

```
Lot 0 — SOCLE (séquentiel)
  ↓
  ├─► Lot A  Lecture des fiches retenue        ┐
  ├─► Lot B  CourseCatalogQuery (élève)        ├─ en parallèle
  └─► Lot C  Page Cours de l'élève             ┘
  ↓
Lot D — PREUVE ET CLÔTURE
```

---

## Lot 0 — Socle

- **Couche**       : infrastructure (schéma) + domaine (contrats) + config
- **Fichiers**     : `db/migrate/…_create_essential_reads.rb` · `db/migrate/…_add_position_to_materials.rb` *(remplissage par slug, ADR-0090 §4.2)* · `db/schema.rb`
                     `app/infrastructure/orm/essential_read.rb`
                     `app/domain/ports/assessment/essential_read_repository_port.rb`
                     `app/domain/use_cases/assessment/record_essential_read.rb`
                     `app/infrastructure/repositories/assessment/essential_read_repository.rb`
                     `app/infrastructure/repositories/assessment/learning_data_eraser.rb` *(efface `essential_reads`)*
                     `app/infrastructure/queries/catalog/course_catalog_query.rb` *(contrat seul : `Row` gagne `material_slug`, `material_position`, `progress`, `resume_essential_slug` ; `Page` gagne `material_counts` ; valeurs neutres `:new`, `nil`, `{}`)*
                     `app/infrastructure/queries/classroom/student_home_query.rb` · `app/infrastructure/queries/assessment/daily_exercise_query.rb` *(`materials.position` à la place de `SUBJECT_ORDER`, supprimé)*
                     `config/locales/catalog/courses.fr.yml` *(toutes les clés élève du chantier)*
- **Dépend de**    : PR `accueil-eleve` fusionnée
- **Test associé** : `test/domain/use_cases/assessment/record_essential_read_test.rb` (CA-11) · `test/infrastructure/repositories/assessment/essential_read_repository_test.rb` (CA-12) · `test/infrastructure/repositories/assessment/learning_data_eraser_test.rb` (CA-16) · `test/infrastructure/queries/classroom/student_home_query_test.rb` (CA-17, ordre inchangé)
- **Done quand**   : les deux migrations passent dans les deux sens ; `grep -rn SUBJECT_ORDER app/` est vide ; les contrats `Row`/`Page` sont gelés ; les requêtes de `GET /courses` (élève) sont mesurées et notées dans `prd.md` §7

---

## Lot A — Lecture des fiches retenue (CA-7, CA-11, CA-12)

- **Couche**       : delivery
- **Fichiers**     : `app/controllers/catalog/essentials_controller.rb` · `app/controllers/classroom/classroom_essentials_controller.rb` *(appel de `RecordEssentialRead` après la policy, élève seulement ; échec journalisé, page affichée)*
                     `test/controllers/catalog/essentials_controller_test.rb` · `test/controllers/classroom/classroom_essentials_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : les deux tests de contrôleur ci-dessus : l'élève crée une lecture, l'enseignant non, une fiche hors niveau (404) n'en crée pas
- **Done quand**   : ouvrir une fiche en élève crée ou met à jour une ligne `essential_reads`, et rien d'autre ne change sur la page

---

## Lot B — `CourseCatalogQuery` pour l'élève (CA-1, CA-6 à CA-10, CA-15, CA-17)

- **Couche**       : infrastructure (query)
- **Fichiers**     : `app/infrastructure/queries/catalog/course_catalog_query.rb` *(implémentation : ordre `materials.position NULLS LAST` pour l'élève, `material_counts` en une requête groupée, `progress` et `resume_essential_slug` en une requête sur les fiches publiées, autres rôles inchangés)*
                     `test/infrastructure/queries/catalog/course_catalog_query_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/catalog/course_catalog_query_test.rb` : ordre, comptes, `:new` / `:started` / `:done`, fiche dépubliée, nouvelle fiche publiée, ordre des autres rôles inchangé
- **Done quand**   : la query rend les groupes dans l'ordre du programme et l'avancement juste, sans requête par carte

---

## Lot C — Page Cours de l'élève (CA-2 à CA-5, CA-13 à CA-15)

- **Couche**       : delivery + UI
- **Fichiers**     : `app/controllers/catalog/courses_controller.rb` *(param `after_material` pour la page suivante)*
                     `app/views/catalog/courses/index.html.erb` *(branche élève : titre ou matière, recherche seule, « Tout voir » pendant une recherche)*
                     `app/views/catalog/courses/_page.html.erb` · `_page_frame.html.erb` *(groupes, `after_material`)*
                     `app/views/catalog/courses/_course_group_title.html.erb` *(nouveau)*
                     `app/views/catalog/courses/_course_card.html.erb` *(variante élève)*
                     `test/controllers/catalog/courses_controller_test.rb` · `test/controllers/catalog/student_level_test.rb` · `test/system/catalog/course_catalog_test.rb`
- **Dépend de**    : Lot 0 *(contrat `Row`/`Page` ; les valeurs neutres suffisent pour rendre)*
- **Test associé** : `test/system/catalog/student_courses_test.rb` (nouveau : CA-2, CA-4, CA-5, CA-13, CA-14, CA-15 à 390 et 1 280 px) · `test/controllers/catalog/courses_controller_test.rb` (CA-3, enseignant inchangé)
- **Done quand**   : l'élève voit la page des maquettes (groupes, cartes, trois libellés de bouton) au téléphone, sur tablette et sur ordinateur, en clair et en sombre ; l'enseignant voit la page actuelle

---

## Lot D — Preuve et clôture

- **Couche**       : docs + preuve
- **Fichiers**     : `docs/chantiers/cours-eleve/journal.md` · `prd.md` *(§7 « Après »)* · `docs/chantiers/README.md` *(une ligne)* · index ADR/UDR *(par `script/docs/build_index`)* · statut d'ADR-0090 et d'UDR-0085 · ADR-0089 §4.1 *(renvoi vers `materials.position`)*
- **Dépend de**    : Lots A, B, C
- **Test associé** : `bin/ci-quiet` vert, verdict copié dans la PR · `security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer` une fois sur le diff final (use case, repository, migration, contrôleurs touchés)
- **Done quand**   : captures envoyées (390 px et ordinateur : tous les cours, une matière, aucun résultat, sans classe, menu ouvert, sombre, les trois boutons), PR ouverte prête

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `db/**` · `app/infrastructure/orm/essential_read.rb` | Lot 0 |
| `app/domain/**` · `app/infrastructure/repositories/assessment/**` | Lot 0 |
| `app/infrastructure/queries/classroom/student_home_query.rb` · `app/infrastructure/queries/assessment/daily_exercise_query.rb` | Lot 0 |
| `config/locales/catalog/courses.fr.yml` | Lot 0 |
| `app/infrastructure/queries/catalog/course_catalog_query.rb` | Lot 0 (contrat), puis Lot B |
| `app/controllers/catalog/essentials_controller.rb` · `app/controllers/classroom/classroom_essentials_controller.rb` | Lot A |
| `app/controllers/catalog/courses_controller.rb` · `app/views/catalog/courses/**` | Lot C |
| `test/infrastructure/queries/catalog/course_catalog_query_test.rb` | Lot B |
| `test/controllers/catalog/courses_controller_test.rb` · `test/system/catalog/**` | Lot C |

## Risques à surveiller

- `courses#index` est partagé par tous les rôles : chaque changement de vue passe par la branche `student`, et CA-3 le prouve.
- Écriture sur une page GET : l'upsert ne doit ni lever ni ralentir la fiche ; pas de `rescue` large (`silent-failure-hunter`).
- Le cadre `courses_page_N` est mis en cache par Turbo : `after_material` fait partie de son URL.
- Les seeds et fixtures de `materials` doivent recevoir `position`, sinon l'ordre des tests dépend du nom.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md` *(ADR-0090 écrit ; index à la clôture)*
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md` *(UDR-0085 écrite ; index à la clôture)*
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
