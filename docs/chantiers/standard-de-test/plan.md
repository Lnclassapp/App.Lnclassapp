# Plan d'exécution — Un standard de test pour Lnclass

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> **Une PR prête par lot**, preuve `bin/ci-quiet` dans la PR, jamais fusionnée par l'agent. Décisions tranchées par le porteur le 2026-11-02 (ADR §4). Lots indépendants en parallèle, 3 au plus. Un fichier partagé passe d'un lot à l'autre seulement entre lots **séquentiels** (`db/seeds.rb` : A puis H puis B).

## Graphe

```
Lot 0 — Manifeste, identités fictives (contrats gelés)
  ↓
  ├─► Lot A  Jeu de base + commande unique + PR/local     ┐
  ├─► Lot D  Rendu des leçons en CI          ⏸ n° 2     ├─ en parallèle
  └─► Lot E  Aperçu local d'un fichier                    ┘
        ↓ A
  Lot H  Environnement Demo (demo.lnclass.com) — prioritaire
        ↓ H
  ├─► Lot B  Trimestre d'activité déterministe ⏸ n° 3
  │     ↓ B
  │   Lot C  Grand établissement + pages lentes ⏸ n° 5
  ├─► Lot F  Rôle des environnements (Develop, Staging)
  └─► Lot I  Jeu standard semé sur Develop (établissements, classes, comptes)
        ↓ A, B, D, E
  Lot G  Recette par rôle + preuve de vague + règle de fusion
```

---

## Lot 0 — Manifeste et identités fictives

- **Couche**       : domaine + données
- **Fichiers**     : `db/seeds/standard/jeu.yml` · `db/seeds/standard/noms.yml`
                     `app/domain/entities/catalog/standard_test_set.rb`
                     `app/domain/entities/school/fictitious_identity.rb`
                     `docs/decisions/adr/XXXX-standard-de-test.md`
- **Dépend de**    : décisions n° 4, 8, 9 (défauts : couples vides, plage à confirmer, première leçon du programme)
- **Test associé** : `test/domain/entities/catalog/standard_test_set_test.rb` · `test/domain/entities/school/fictitious_identity_test.rb` · `test/db/seeds/standard_manifest_test.rb`
- **Done quand**   : le manifeste nomme les 3 établissements, les classes, les cas difficiles, les comptes et un v3 par couple ; les tests refusent fichier absent, couple oublié, contact hors plage

## Lot A — Jeu de base, une commande, local et PR

- **Couche**       : infrastructure + scripts
- **Fichiers**     : `db/seeds/standard.rb` · `bin/jeu-standard`
                     `db/seeds.rb` *(stage `pr` → standard)* · `bin/tester-pr` *(`--demo` → standard ; `--tout-contenu`)*
                     `docs/guide/onboarding.md` *(comptes du jeu)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/db/seeds/standard_seed_test.rb` (deux chargements sans doublon ; `--reset` refusé sur environnement distant sans confirmation ; leçons publiées = manifeste)
- **Done quand**   : `bin/jeu-standard --reset` charge établissements, comptes et leçons en local ; `bin/tester-pr Develop --demo` donne le même jeu

## Lot B — Trimestre d'activité déterministe

- **Couche**       : infrastructure (seed par les use cases)
- **Fichiers**     : `db/seeds/standard/activite.rb` · `db/seeds/demo/saint_michel.rb` *(retiré, absorbé)*
- **Dépend de**    : Lot H *(ajoute `standard/activite` au stage `demo`, `development` et `pr` de `db/seeds.rb`)*
- **Test associé** : `test/db/seeds/standard_activity_test.rb` (empreinte des totaux attendue, sur une activité réduite ; identique à deux dates de chargement)
- **Done quand**   : tableaux de bord enseignant, direction et équipe filtrée par DRENA montrent séances, notes, lacunes, devoirs rendus et en retard ; classe vide et élève sans activité en état vide ; captures 390 px et ordinateur envoyées au porteur

## Lot C — Grand établissement et pages lentes

- **Couche**       : infrastructure + script
- **Fichiers**     : `db/seeds/standard/grand.rb` · `bin/pages-lentes`
- **Dépend de**    : Lot B
- **Test associé** : `test/db/seeds/standard_grand_test.rb` (effectif ~1 500, activité échantillonnée, sous 5 min mesuré)
- **Done quand**   : `bin/pages-lentes` liste les pages de chaque rôle avec leur temps ; les pages lentes sont notées au journal, chacune avec un chantier `optimize` proposé

## Lot D — Leçons vérifiées par la machine

- **Couche**       : tests + CI
- **Fichiers**     : `test/system/catalog/lesson_rendering_test.rb` · `test/fixtures/files/lecons_piegees/*.json`
                     `script/ci/system_budget.rb` · `script/ci/test_timings.yml` · `script/ci/scope.rb`
                     `.github/workflows/ci.yml` *(tâche `lecons`, parts de ≤ 5 min)*
- **Dépend de**    : Lot 0
- **Test associé** : le test lui-même, rouge sur chacun des 4 fichiers piégés, vert sur un conforme
- **Done quand**   : une PR qui touche 3 leçons les rend dans `bin/ci-quiet` ; le train rend tout en parts ≤ 5 min ; premier passage complet chiffré au journal

## Lot E — Aperçu local d'un fichier

- **Couche**       : script + infrastructure (réutilise `ImportCourseTree`)
- **Fichiers**     : `bin/apercu-lecon` · `lib/tasks/apercu.rake` · `docs/contenus/README.md` *(boucle courte)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/tasks/apercu_task_test.rb` (refus hors développement ; un seul fichier importé ; JSON refusé → base intacte)
- **Done quand**   : modifier un JSON puis lancer l'aperçu montre la nouvelle version en < 15 s ; `--suivre` recharge à chaque enregistrement

## Lot F — Un rôle par environnement

- **Couche**       : domaine + infrastructure
- **Fichiers**     : `app/domain/entities/catalog/automatic_load_stage.rb` · `app/domain/use_cases/catalog/load_repository_lessons.rb`
                     `app/infrastructure/repositories/catalog/repository_lesson_source.rb` · `app/infrastructure/repositories/catalog/content_tree_writer.rb`
                     `lib/tasks/contenus.rake`
- **Dépend de**    : Lot H
- **Test associé** : `test/domain/entities/catalog/automatic_load_stage_test.rb` · `test/domain/use_cases/catalog/load_repository_lessons_test.rb`
- **Done quand**   : Develop charge le jeu sans rien supprimer ; Staging ajoute les absentes sans toucher les présentes ; production rien ; vérifié dans le rapport de chargement des deux environnements

## Lot H — Environnement Demo (demo.lnclass.com) — prioritaire

- **Couche**       : config + infrastructure (seeds) + domaine
- **Fichiers**     : `config/pr_environment.rb` *(un environnement nommé `Demo`, casse ignorée, n'est jamais un environnement de PR)*
                     `config/demo_environment.rb` · `db/seeds.rb` *(stage `demo` : identity, catalog, school, standard)*
                     `app/domain/entities/catalog/automatic_load_stage.rb` *(`demo` → aucun chargement des leçons du dépôt)*
                     `docs/guide/configuration.md` *(variables de Demo : à poser, à ne pas copier)*
- **Dépend de**    : Lot A
- **Test associé** : `test/config/demo_environment_test.rb` · `test/config/pr_environment_test.rb` (Demo avec `PR_BASE_ENVIRONMENT=Develop` copié → pas PR) · `test/db/seeds/demo_stage_test.rb` · `automatic_load_stage_test.rb`
- **Done quand**   : avec `RAILWAY_ENVIRONMENT_NAME=Demo`, `db:seed` charge référentiel + jeu standard, sans mot de passe PR, sans `lecons_completes`, sans chargement des leçons du dépôt ; comptes équipe seulement si `DEMO_TEAM_PIN` est posée ; production inchangée

## Lot I — Jeu standard semé sur Develop

- **Couche**       : infrastructure (seeds)
- **Fichiers**     : `db/seeds.rb` *(stade `develop` : `contenus` puis `standard`, échec du jeu imprimé et journalisé, jamais levé)*
                     `db/seeds/standard.rb` *(Develop : établissements, classes, comptes, pas de leçons ; contact pris par un autre compte laissé tel quel et signalé, partout ; équipe seulement avec `STANDARD_TEAM_PIN` scellée)*
                     `docs/guide/configuration.md` *(variable `STANDARD_TEAM_PIN` de Develop)*
- **Dépend de**    : Lot H ; se fusionne avec F (leçons de Develop) sans conflit de fichier, avec B sur `db/seeds.rb` : quand B est fusionné, le stade `develop` reçoit aussi `activite`
- **Test associé** : `test/db/seeds/develop_stage_test.rb` · `test/db/seeds/standard_seed_test.rb` (compte existant non modifié)
- **Done quand**   : avec `RAILWAY_ENVIRONMENT_NAME=Develop` en production Rails, `db:seed` ajoute les 3 établissements, leurs classes et comptes, rien en double, aucun compte existant modifié, aucun compte équipe sans `STANDARD_TEAM_PIN` ; Staging et production : rien du jeu

## Lot G — Recette, preuve de vague, règle de fusion

- **Couche**       : docs + scripts + garde CI
- **Fichiers**     : `docs/recette/*.md` *(élève, enseignant, direction, DRENA, équipe, table écran → parcours)*
                     `bin/preuve-vague` · `.github/pull_request_template.md` · `bin/ci-quiet` *(garde de la section de preuve)*
                     `docs/guide/conventions.md` *(règle de fusion)* · `docs/chantiers/contenus-v3-tous-niveaux/plan-de-test.md` *(renvoi)*
- **Dépend de**    : Lots A, B, D, E
- **Test associé** : `test/bin/preuve_vague_test.rb` · `test/guards/proof_section_test.rb`
- **Done quand**   : une PR sans section de preuve est refusée par `bin/ci-quiet` ; `bin/preuve-vague docs/contenus/lecons-traitees/tle-d` sort le verdict et les captures dans `tmp/preuves/`

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `db/seeds/standard/jeu.yml` · `noms.yml` · entités `standard_test_set`, `fictitious_identity` | Lot 0 |
| `db/seeds/standard.rb` · `bin/jeu-standard` · `bin/tester-pr` · `docs/guide/onboarding.md` | Lot A |
| `db/seeds/standard/activite.rb` · `db/seeds/demo/saint_michel.rb` | Lot B |
| `db/seeds/standard/grand.rb` · `bin/pages-lentes` | Lot C |
| `script/ci/*` · `.github/workflows/ci.yml` · `lesson_rendering_test.rb` | Lot D |
| `bin/apercu-lecon` · `lib/tasks/apercu.rake` · `docs/contenus/README.md` | Lot E |
| `automatic_load_stage.rb` · `load_repository_lessons.rb` · `repository_lesson_source.rb` · `content_tree_writer.rb` · `lib/tasks/contenus.rake` | Lot F |
| `db/seeds.rb` | Lot A, puis Lot H, puis Lot B (séquentiels) |
| `config/pr_environment.rb` · `config/demo_environment.rb` · `docs/guide/configuration.md` | Lot H |
| `automatic_load_stage.rb` | Lot H, puis Lot F (séquentiels) |
| `docs/recette/` · `bin/preuve-vague` · `.github/pull_request_template.md` · `bin/ci-quiet` · `conventions.md` · `plan-de-test.md` | Lot G |

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
- [ ] Une PR par lot vers `Develop`, référençant chantier + ADR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
