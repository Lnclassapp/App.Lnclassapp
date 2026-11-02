# Plan d'exécution — Un standard de test pour Lnclass

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> **Une PR prête par lot**, preuve `bin/ci-quiet` dans la PR. Le Lot D attend les décisions ouvertes n° 1 et 2 du [memo](memo.md).

## Graphe

```
Lot 0 — Manifeste du jeu standard (contrat gelé)
  ↓
  ├─► Lot A  Jeu standard en local et en PR      ┐
  ├─► Lot B  Test d'affichage des leçons + CI    ├─ en parallèle
  └─► Lot C  Aperçu local d'un fichier           ┘
        ↓ (A et B)
  Lot D  Rôle des environnements (Develop, Staging)   ⏸ décisions n° 1 et 2
  Lot E  Preuve d'une vague (après B et C)
```

---

## Lot 0 — Manifeste du jeu standard

- **Couche**       : domaine + données
- **Fichiers**     : `db/seeds/standard/jeu.yml`
                     `app/domain/entities/catalog/standard_test_set.rb`
                     `docs/decisions/adr/XXXX-standard-de-test.md`
- **Dépend de**    : — (choix des leçons : décision ouverte n° 5, défaut = première leçon du programme)
- **Test associé** : `test/domain/entities/catalog/standard_test_set_test.rb` · `test/db/seeds/standard_manifest_test.rb`
- **Done quand**   : le manifeste nomme 2 établissements, 14 classes, les comptes par rôle et un v3 par couple niveau-série-matière qui en a ; le test refuse un fichier absent, non v3 ou un couple oublié

---

## Lot A — Jeu standard en local et en environnement de PR

- **Couche**       : infrastructure + delivery (scripts)
- **Fichiers**     : `db/seeds/standard.rb`
                     `db/seeds.rb` *(table des stages : `pr` → standard)*
                     `bin/tester-pr` *(`--demo` → standard ; `--tout-contenu` → ancien jeu)*
                     `docs/guide/onboarding.md` *(comptes du jeu standard)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/db/seeds/standard_seed_test.rb` (deux chargements, aucun doublon, enseignant dans les deux établissements, leçons publiées = manifeste)
- **Done quand**   : `bin/tester-pr Develop --demo` charge le jeu standard en < 30 s et le porteur se connecte avec les comptes listés

---

## Lot B — Leçons vérifiées par la machine

- **Couche**       : tests + CI
- **Fichiers**     : `test/system/catalog/lesson_rendering_test.rb`
                     `test/fixtures/files/lecons_piegees/*.json`
                     `script/ci/system_budget.rb` *(dérogation nommée)*
                     `script/ci/test_timings.yml`
                     `script/ci/scope.rb` *(fichier de leçon touché → ce test)*
                     `.github/workflows/ci.yml` *(tâche `lecons` en parts de ≤ 5 min au train)*
- **Dépend de**    : Lot 0 (pour la liste des fichiers v3 et le niveau-série → compte élève)
- **Test associé** : le test lui-même, rouge sur chacun des 4 fichiers piégés, vert sur un fichier conforme
- **Done quand**   : une PR qui touche 3 leçons rend ces 3 leçons dans `bin/ci-quiet` ; `LECONS=tout LECONS_PART=i/n` rend tout en parts de ≤ 5 min ; premier passage complet chiffré dans le journal (défauts trouvés listés, pas corrigés ici)

---

## Lot C — Aperçu local d'un fichier

- **Couche**       : delivery (script) + infrastructure (réutilise `ImportCourseTree`, `replace: :lesson`)
- **Fichiers**     : `bin/apercu-lecon`
                     `lib/tasks/apercu.rake`
                     `docs/contenus/README.md` *(boucle courte : modifier → aperçu → valider → PR → Develop)*
- **Dépend de**    : Lot 0 (compte élève de la bonne série)
- **Test associé** : `test/tasks/apercu_task_test.rb` (refus hors développement ; un seul fichier importé ; JSON refusé → base intacte)
- **Done quand**   : modifier un JSON puis `bin/apercu-lecon <fichier>` montre la nouvelle version en < 15 s ; `--suivre` recharge à chaque enregistrement

---

## Lot D — Un rôle par environnement ⏸

- **Couche**       : domaine + infrastructure
- **Fichiers**     : `app/domain/entities/catalog/automatic_load_stage.rb`
                     `app/domain/use_cases/catalog/load_repository_lessons.rb`
                     `app/infrastructure/repositories/catalog/repository_lesson_source.rb`
                     `app/infrastructure/repositories/catalog/content_tree_writer.rb` *(mode `:create_only`)*
                     `lib/tasks/contenus.rake`
- **Dépend de**    : Lot 0, Lot A ; **décisions n° 1 et 2 du porteur**
- **Test associé** : `test/domain/entities/catalog/automatic_load_stage_test.rb` · `test/domain/use_cases/catalog/load_repository_lessons_test.rb` (Develop : manifeste seul, aucune suppression ; Staging : absentes ajoutées, présente intacte ; production : rien)
- **Done quand**   : un déploiement de Develop ne charge que le jeu standard sans rien supprimer ; Staging ajoute les leçons absentes ; vérifié dans le rapport de chargement des deux environnements

---

## Lot E — Preuve d'une vague

- **Couche**       : delivery (script) + doc
- **Fichiers**     : `bin/preuve-vague`
                     `docs/chantiers/contenus-v3-tous-niveaux/plan-de-test.md` *(renvoi vers la preuve)*
                     `docs/workflows/feature.md` *(section contenus : preuve d'une vague)*
- **Dépend de**    : Lot B, Lot C
- **Test associé** : `test/bin/preuve_vague_test.rb` (échoue si valider.rb ou le rendu échoue ; captures hors du dépôt)
- **Done quand**   : `bin/preuve-vague docs/contenus/lecons-traitees/tle-d` sort le verdict et une capture 390 px + ordinateur par matière dans `tmp/preuves/`

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `db/seeds/standard/jeu.yml` | Lot 0 |
| `app/domain/entities/catalog/standard_test_set.rb` | Lot 0 |
| `db/seeds.rb` · `bin/tester-pr` · `db/seeds/standard.rb` | Lot A |
| `script/ci/*` · `.github/workflows/ci.yml` · `test/system/catalog/lesson_rendering_test.rb` | Lot B |
| `bin/apercu-lecon` · `lib/tasks/apercu.rake` · `docs/contenus/README.md` | Lot C |
| `automatic_load_stage.rb` · `load_repository_lessons.rb` · `repository_lesson_source.rb` · `content_tree_writer.rb` · `lib/tasks/contenus.rake` | Lot D |
| `bin/preuve-vague` · `plan-de-test.md` · `docs/workflows/feature.md` | Lot E |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] UDR écrite pour **chaque** vue créée ou modifiée — sans objet : aucune vue
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR par lot vers `Develop`, référençant chantier + ADR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
