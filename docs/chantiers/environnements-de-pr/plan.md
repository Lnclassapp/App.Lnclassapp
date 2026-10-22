# Plan d'exécution — Environnements de PR sur Railway

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot 0 — Reconnaître un environnement de PR, et son mot de passe (séquentiel)
  ↓
  ├─► Lot B — S'endormir : tâches et mises à jour dans le processus web   ┐ en parallèle
  └─► Lot C — Les données de test                                          ┘
  ↓ (Lots 0, B, C fusionnés dans Develop, réglages Railway posés : première PR d'essai)
Lot A — Migration de railway.json   ← attend `railway config migrate`, lancé par le porteur
Lot D — conditionnel : supprimer l'environnement d'une PR de promotion, s'il en apparaît un
```

Pas de port ni d'entité : le chantier est de la configuration. Le Lot 0 gèle le seul contrat, `PrEnvironment.active?` et `PrEnvironment::Gate`.

---

## Lot 0 — Reconnaître un environnement de PR, et le fermer par un mot de passe

- **Couche**       : infrastructure (configuration)
- **Fichiers**     : `config/pr_environment.rb` (nouveau : `PrEnvironment.active?`, middleware `PrEnvironment::Gate`)
                     `config/application.rb` (`require_relative "pr_environment"`)
                     `config/environments/production.rb` (insertion de `PrEnvironment::Gate`, adaptateur Active Job)
                     `test/config/pr_environment_test.rb` (nouveau)
                     `test/integration/production_configuration_test.rb`
                     `docs/guide/configuration.md` (`PR_BASE_ENVIRONMENT`, `PR_ACCESS_PASSWORD`, réglages Railway des PR)
- **Dépend de**    : —
- **Test associé** : `test/config/pr_environment_test.rb` · `test/integration/production_configuration_test.rb`
- **Done quand**   : un démarrage de production avec `PR_BASE_ENVIRONMENT=Develop` et un autre `RAILWAY_ENVIRONMENT_NAME` répond 401 sans le mot de passe, 200 avec, 200 sur `/up`, 401 si `PR_ACCESS_PASSWORD` manque ; sans la variable, rien ne change.
- **Critères couverts** : « Develop porte la variable… », « sans la variable… », « le mot de passe ferme… », « un mot de passe oublié… », « hors environnement de PR » (mot de passe).

## Lot B — S'endormir : tâches de fond et mises à jour en direct dans le processus web

- **Couche**       : infrastructure (configuration)
- **Fichiers**     : `config/puma.rb` (`plugin :solid_queue unless PrEnvironment.active?`)
                     `config/cable.yml` (adaptateur `async` en environnement de PR)
                     `test/guards/repository_rules_test.rb` (la seule condition admise sur le worker)
                     `test/config/pr_environment_runtime_test.rb` (nouveau : Puma et Action Cable, avec et sans les variables)
                     `docs/decisions/adr/0052-chaine-de-livraison-versionnee-et-worker-dans-puma.md` (ligne « Amendé par »)
- **Dépend de**    : Lot 0
- **Test associé** : `test/config/pr_environment_runtime_test.rb` · `test/guards/repository_rules_test.rb`
- **Done quand**   : avec les variables d'une PR, Puma ne charge pas le worker et Action Cable est `async` ; sans elles, le worker est chargé et Action Cable est `solid_cable` ; toute autre condition sur `plugin :solid_queue` fait échouer la garde.
- **Critères couverts** : « dans un environnement de PR, rien n'interroge la base en continu », « hors environnement de PR » (Solid Queue, Solid Cable). L'adaptateur Active Job est posé au Lot 0, qui tient `production.rb`.

## Lot C — Les données de test d'un environnement de PR

- **Couche**       : infrastructure (seeds)
- **Fichiers**     : `db/seeds.rb`
                     `db/seeds/catalog.rb` · `db/seeds/school.rb` · `db/seeds/development.rb` (garde : local ou environnement de PR)
                     `db/seeds/demo/trois_etablissements.rb` (garde : développement ou environnement de PR)
                     `test/db/pr_environment_seeds_test.rb` (nouveau)
                     `docs/decisions/adr/0034-reprise-des-donnees-et-referentiel-seede.md` (ligne « Amendé par »)
                     `docs/guide/onboarding.md` (« Tester une PR » : l'adresse Railway, le mot de passe, les comptes)
- **Dépend de**    : Lot 0
- **Test associé** : `test/db/pr_environment_seeds_test.rb` (et `test/db/seeds_test.rb`, `test/db/demo_schools_test.rb` inchangés, verts)
- **Done quand**   : en production avec les variables d'une PR, `db:seed` sur une base vide crée référentiel, DRENA, comptes fictifs et trois établissements, le compte 0531000001 se connecte avec 2468, un second `db:seed` ne crée rien ; sans les variables, seule l'identité est semée et les fichiers de test refusent de tourner.
- **Critères couverts** : « un environnement de PR reçoit les données de test », « la production ne reçoit jamais les données de test ».

## Lot A — Migration de `railway.json`, à comportement identique

- **Couche**       : déploiement
- **Fichiers**     : `.railway/railway.ts` (produit par `railway config migrate`, lancé par le porteur)
                     `railway.json` (supprimé)
                     `test/config/railway_deployment_test.rb` (lit le pré-déploiement dans `railway.ts`)
                     `docs/guide/retour-arriere.md` · `docs/guide/configuration.md` (références à `railway.json`)
- **Dépend de**    : Lot 0 (fichier `configuration.md`) ; le porteur, connecté à Railway, colle la sortie de `railway config migrate` (aperçu, sans `--apply`)
- **Test associé** : `test/config/railway_deployment_test.rb`
- **Done quand**   : `railway config plan` ne propose aucun changement sur Develop, Staging et production ; un déploiement de Develop joue `db:prepare db:seed` et répond sur `/up` ; `railway.json` n'existe plus. Avant le 2026-12-01.
- **Critères couverts** : aucun critère du PRD §4 (comportement identique) ; le test existant du pré-déploiement reste vert.

## Lot D — conditionnel : pas d'environnement pour une PR de promotion

- **Couche**       : CI
- **Fichiers**     : `.github/workflows/pr-environments.yml` (nouveau : à l'ouverture d'une PR vers `Staging` ou `main`, suppression de son environnement par l'API Railway)
- **Dépend de**    : l'observation de la prochaine promotion. Si Railway n'y crée pas d'environnement, le lot est abandonné. Sinon, le porteur crée un jeton Railway en secret GitHub.
- **Test associé** : à écrire avec le lot (le workflow ne s'exécute pas en local : vérification à la promotion suivante)
- **Done quand**   : une PR Develop → Staging n'a plus d'environnement Railway une minute après son ouverture.

---

## Actions du porteur dans Railway (hors dépôt)

1. **Project Settings › Environments** : PR Environments activés, base `Develop` (fait), **Bot PR Environments activés** (les PR ouvertes par Claude comptent comme PR de robot, constaté le 2026-10-22), Focused PR Environments désactivés.
2. **Variables de Develop**, non scellées : `PR_BASE_ENVIRONMENT=Develop`, `PR_ACCESS_PASSWORD=<mot de passe choisi>`. Vérifier qu'aucune variable indispensable n'est scellée (`RAILS_MASTER_KEY`, `DATABASE_URL`, `BUCKET_*`), sinon elle manquera dans les PR.
3. **Service web de Develop › Settings › Deploy › Serverless** : activé. Les PR en héritent ; Develop reste éveillé grâce à son worker.
4. Après la fusion des Lots 0, B et C : ouvrir une PR d'essai, constater données, mot de passe, veille, et vérifier que le stockage de fichiers de la PR n'est pas celui de Develop (journal).
5. Lot A : `railway login`, `railway link`, puis `railway config migrate` (aperçu), et coller la sortie.

## Vagues de dispatch

```
Vague 1 : Lot 0                 → 1 agent
Vague 2 : Lot B ‖ Lot C         → 2 agents, worktrees isolés depuis feature/environnements-de-pr
Vague 3 : Lot A                 → 1 agent, dès que le porteur colle la sortie de railway config migrate
Vague 4 : Lot D                 → seulement si une promotion crée un environnement
```

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/pr_environment.rb` | Lot 0 |
| `config/application.rb` | Lot 0 |
| `config/environments/production.rb` | Lot 0 |
| `test/integration/production_configuration_test.rb` | Lot 0 |
| `docs/guide/configuration.md` | Lot 0, puis Lot A (séquentiel : A dépend de 0) |
| `config/puma.rb` · `config/cable.yml` | Lot B |
| `test/guards/repository_rules_test.rb` | Lot B |
| ADR-0052 | Lot B |
| `db/seeds.rb` · `db/seeds/**` | Lot C |
| ADR-0034 · `docs/guide/onboarding.md` | Lot C |
| `railway.json` · `.railway/railway.ts` · `test/config/railway_deployment_test.rb` · `docs/guide/retour-arriere.md` | Lot A |
| ADR-0108, `docs/chantiers/environnements-de-pr/*`, index | clôture |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture) — sans objet : aucune vue
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/` — sans objet : aucun fichier dans `app/`
- [x] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [x] Pureté domaine · rubocop · tests · brakeman : au vert
- [x] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, démarre l'application en production avec les variables d'une PR, refait le parcours nominal (mot de passe, connexion 0531000001 / 2468, un import) *et* un chemin d'erreur (mauvais mot de passe, variable `PR_ACCESS_PASSWORD` absente). **Il ne relit pas le code, il le met à l'épreuve.** La veille effective, elle, se constate sur Railway, à la première PR d'essai.
