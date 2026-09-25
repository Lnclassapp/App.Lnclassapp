# Journal — Amorçage du dépôt (V0)

> Rempli pendant le chantier. Chaque garde-fou de la [feuille de route §2](../refonte-application/feuille-de-route.md#2-phase-0--amorçage-du-dépôt) a ici sa preuve : la commande lancée et sa sortie résumée.

## Les sept garde-fous et leurs preuves

### 1. Socle documentaire versionné — ⚠️ prouvé, avec un écart

```
$ git ls-files CLAUDE.md docs/README.md .claude/skills | head -3   → présents
$ git log --diff-filter=A --format=%h -- docs/README.md           → 624ee23
$ git rev-list --max-parents=0 HEAD                                → 128db59 (« first commit »)
```

**Écart** : la preuve exigée est « le premier commit ». Le dépôt existait déjà (10 commits de `rails new`, landing, configuration) quand la documentation a été copiée en `624ee23`. Le socle est présent **avant tout code métier**, ce qui est l'intention du garde-fou. Réécrire l'historique de `Develop` pour le déplacer n'a pas été fait : c'est au porteur d'en décider.

### 2. `bin/setup` active le hook, de façon idempotente — ✅

```
$ git config core.hooksPath                 → <non défini>
$ bin/setup --skip-server                   → exit 0, core.hooksPath = .githooks
$ md5sum $(git rev-parse --git-common-dir)/config   → bc89b50d…
$ bin/setup --skip-server                   → exit 0, core.hooksPath = .githooks
$ md5sum $(git rev-parse --git-common-dir)/config   → bc89b50d…  (identique)
$ git config --get-all core.hooksPath | wc -l        → 1
```

`core.hooksPath` est dans la configuration commune du dépôt : il s'applique à **tous** les worktrees. Il n'a été posé qu'après avoir vérifié que le hook laissait passer un commit propre (`7c16afb`, hook lancé à la main, exit 0).

### 3. Pre-commit : quatre commits fautifs, quatre refus — ✅

Sur une branche jetable `tmp/preuve-pre-commit` (supprimée ensuite), hook actif, **sans** `--no-verify` :

| # | Faute | Sortie du hook | `git commit` |
|---|---|---|---|
| 1 | `app/domain/catalog/course.rb` appelle `Orm::Course.find(id)` | `DomainPurityTest … app/domain/catalog/course.rb:7: def self.load(id) = Orm::Course.find(id)` puis `🚫 COMMIT REFUSÉ.` | exit 1 |
| 2 | `app/controllers/probe_controller.rb` sans en-tête | `❌ [En-tête HITL] app/controllers/probe_controller.rb n'a pas d'en-tête de couche dans ses 5 premières lignes.` | exit 1 |
| 3 | `app/models/probe.rb` avec `# :nocov:` | `❌ [Couverture] « # :nocov: » est interdit (ADR-0024) : app/models/probe.rb:5 …` | exit 1 |
| 4 | `app/models/probe.rb` avec `LIST = [1,2]` | `Layout/SpaceInsideArrayLiteralBrackets … ❌ [Style] Rubocop refuse des fichiers stagés.` | exit 1 |

`git log` après les quatre tentatives : inchangé (`bf6620d`).

### 4. Une CI identique en local et sur GitHub — ⚠️ prouvé sauf les tests système

- `config/ci.rb` est **la seule** liste d'étapes. `.github/workflows/ci.yml` n'a qu'un job, qui lance `bin/ci` : les deux ne peuvent plus diverger.
- Ordre : pureté du domaine → HITL / `:nocov:` / worker dans Puma → rubocop → bundler-audit → `yarn npm audit` → brakeman → suite complète à 100 % → tests système Chrome headless (`COVERAGE=0`) → seeds → budget de poids.
- SimpleCov : `enable_coverage :branch`, `cover "{app,lib}/**/*.rb"`, `merge_subprocesses true`, `minimum_coverage line: 100, branch: 100`.

Dernier `bin/ci` local (commit `bf6620d`, les deux tests en attente de design mis de côté) :

```
✅ Setup · ✅ Guard: Domain purity · ✅ Guard: HITL headers, no :nocov:, worker in Puma
✅ Style: Ruby · ✅ Security: Gem audit · ✅ Security: Yarn vulnerability audit · ✅ Brakeman
✅ Tests: Rails (coverage 100 % lines and branches)   Line coverage: 19 / 19 (100.00%)
❌ Tests: System (headless Chrome)     ← pas de Chrome dans le bac à sable de l'agent (voir « Ce qui a dérapé »)
✅ Tests: Seeds
❌ Assets: Budget                      ← application.js 92,0 Ko gzip / 60 Ko, en attente de design
```

Depuis `8713a6c` (trix et Action Text retirés, arbitrage de l'orchestrateur), `yarn build` échoue sur cette branche (`Could not resolve "trix"`) tant que design n'a pas retiré les deux imports de `application.js`. Simulation locale, imports retirés et non commités : `application.js 36,3 Ko gzip / 60 Ko`, `bin/check-asset-budget` exit 0, `bin/rails test` exit 0, `Line coverage: 19 / 19 (100.00%)`.

**Une couverture sous 100 % est refusée** (branche jetable, un fichier dont une seule branche est testée) :

```
Line coverage: 21 / 21 (100.00%)
Branch coverage: 1 / 2 (50.00%)
Branch coverage (50.00%) is below the expected minimum coverage (100.00%).
     50.00%  app/models/coverage_probe.rb
SimpleCov failed with exit 2 due to a coverage related error
```

**La mesure tient avec la parallélisation de minitest** (`parallelize(workers: 3, threshold: 1)` forcé le temps d'un essai) : `Coverage report generated for Minitest, Minitest (subprocess: 1), (subprocess: 2), (subprocess: 3)` — `Line coverage: 19 / 19 (100.00%)`. Un lancement partiel ne réutilise pas les résultats d'un lancement précédent (vérifié : 4 tests → 26,31 %, refusé).

### 5. Branches protégées — ⏳ à exécuter par l'orchestrateur

Aucune action GitHub depuis un agent. Commandes exactes, dépôt `Lnclassapp/App.Lnclassapp` :

```bash
# 1. Créer Staging depuis Develop
SHA=$(gh api repos/Lnclassapp/App.Lnclassapp/git/ref/heads/Develop --jq .object.sha)
gh api repos/Lnclassapp/App.Lnclassapp/git/refs -f ref=refs/heads/Staging -f sha="$SHA"

# 2. Protéger Develop, Staging et main : PR obligatoire, job « ci » vert, aucun push direct,
#    même pour les administrateurs, ni force-push ni suppression.
for BRANCH in Develop Staging main; do
  gh api -X PUT "repos/Lnclassapp/App.Lnclassapp/branches/$BRANCH/protection" --input - <<'JSON'
{
  "required_status_checks": { "strict": true, "contexts": ["ci"] },
  "enforce_admins": true,
  "required_pull_request_reviews": { "required_approving_review_count": 0 },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
done

# 3. Preuve : un push direct est refusé (GH006 Protected branch update failed)
git switch -c tmp/preuve-push Develop && git commit --allow-empty -m "chore(infra): direct push probe"
git push origin HEAD:Develop    # attendu : refus
git switch - && git branch -D tmp/preuve-push
```

Le contexte `ci` est le nom du job de `.github/workflows/ci.yml` : il n'existe côté GitHub qu'après une première exécution du workflow (pousser la branche avant de protéger, ou protéger après la première PR). `required_approving_review_count: 0` impose la PR sans exiger de relecteur humain ; à monter quand l'équipe grandit.

**Railway** (ADR-0052) : l'environnement de recette suit `Staging`, la production suit `main`, chacun avec sa base.

### 6. Production — ✅ un test par point

| Point | Réglage | Test |
|---|---|---|
| HTTPS | `assume_ssl`, `force_ssl` (HSTS + cookies sécurisés) | `production_configuration_test.rb` : requête HTTP derrière le proxy → 200 servie en HTTPS, `strict-transport-security: max-age=…` |
| `/up` | route existante, exclue de la redirection et du contrôle d'hôte | `health_check_test.rb` ; `production_configuration_test.rb` (`http://healthcheck.railway.app/up` → 200, exclusion `[/up → true, / → false]`) |
| `:contact` filtré | `filter_parameters` + `:contact`, `/\Apin/` (ADR-0025) | `parameter_filtering_test.rb` |
| CSP | `content_security_policy.rb` d'ADR-0049, nonce par requête | `content_security_policy_test.rb` (`/` et `/teams/jobs`, nonce différent à chaque requête) ; `production_configuration_test.rb` |
| `config.hosts` | `RAILWAY_PUBLIC_DOMAIN` + `APP_HOSTS` ; sans variable, `localhost` seul (fermé par défaut) | `production_configuration_test.rb` : hôte inconnu → 403, domaine perso → 200, sans variable → `["localhost"]` |
| Stockage (F-25) | `:local` par défaut ; `ACTIVE_STORAGE_SERVICE=amazon` bascule sur le service S3-compatible | `production_configuration_test.rb` : service `:amazon` construit avec bucket et endpoint Railway |
| Traductions | `raise_on_missing_translations = true` en dev et test ; `default_locale = :fr` ; `rails-i18n` ; `config/locales/**/*.yml` chargés | `i18n_configuration_test.rb`, `development_configuration_test.rb` |
| Navigateurs (ADR-0051) | `allow_browser` ne bloque plus, pose `@outdated_browser` ; `public/406-unsupported-browser.html` supprimé | `application_controller_test.rb` ; `supported_browsers_test.rb` **en attente de design** (bandeau) |
| Worker (ADR-0052) | `plugin :solid_queue` sans condition ; `:solid_queue` en dev et prod ; tables dans la base principale | `repository_rules_test.rb`, `development_configuration_test.rb`, `production_configuration_test.rb`, `recurring_tasks_test.rb` |
| Mission Control | monté sous `/teams/jobs`, parent `Teams::BaseController`, fermé (redirection) jusqu'à l'authentification V1 | `teams/base_controller_test.rb` |
| `railway.json` | Dockerfile, `preDeployCommand`, `/up`, redémarrage sur échec | — (vérifié au premier déploiement de recette, ADR-0052 §6) |

Les réglages de production sont prouvés sur un **vrai démarrage en production** (`test/support/environment_probe.rb` : `bin/rails runner` dans un processus enfant, requêtes Rack contre l'application), pas en relisant le fichier de configuration.

### 7. Test système « page d'accueil » — ⚠️ écrit, non prouvé localement

`test/system/homepage_test.rb` : titre, `h1`, et Turbo démarré sous la CSP (preuve que le JavaScript de l'application n'est pas bloqué). Pilote `selenium` + `headless_chrome`, jamais `rack_test`.

**Non prouvé** dans le bac à sable de l'agent : pas de réseau (selenium-manager ne peut pas télécharger Chrome), et Chromium en snap refuse de démarrer (`snap-confine has elevated permissions and is not confined`). Conformément à [configuration.md §4.3](../../guide/configuration.md), un test système qui n'a pas tourné dans un navigateur est **non prouvé**, pas prouvé. À lancer quand Chrome sera réparé (`sudo systemctl start snapd.apparmor`, décision du porteur) : `CHROME_BIN=/snap/bin/chromium CHROMEDRIVER_PATH=/snap/bin/chromium.chromedriver bin/ci`, puis en CI GitHub (Chrome préinstallé).

`test/application_system_test_case.rb` lit `CHROME_BIN` et `CHROMEDRIVER_PATH` s'ils sont posés, sinon selenium-manager ; options `--headless=new`, `--no-sandbox`, `--disable-dev-shm-usage`, fenêtre 1400×1400. `bin/check-chrome` passe avant les tests système dans `bin/ci` et échoue avec un message explicite :

```
❌ Chrome ne démarre pas (chromium) : les tests système ne sont PAS prouvés.
   Please make sure that the snapd.apparmor service is enabled and started.
   Chromium en snap exige le service snapd.apparmor : sudo systemctl start snapd.apparmor
```

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-25 | Le workflow GitHub lance `bin/ci` au lieu de dupliquer les étapes | seule façon de garantir « identique en local et sur GitHub » (piège de la feuille de route §2) | non — application d'ADR-0024/0052 |
| 2026-09-25 | `cover` au lieu de `track_files` | `track_files` est déprécié dans simplecov 1.3 ([configuration.md §4.2](../../guide/configuration.md)) ; même effet | non |
| 2026-09-25 | Tables Solid Queue / Cache / Cable créées par migrations dans la base principale ; `db/*_schema.rb` supprimés | ADR-0010 et 0052 ; piège « schémas jamais chargés » | non |
| 2026-09-25 | `config.hosts` fermé par défaut (`localhost`) sans variable d'hôte | un tableau vide autorise tous les hôtes en silence | non |
| 2026-09-25 | Le contrôle `:nocov:` du pre-commit est limité à `app/` et `lib/` | périmètre de l'ADR-0024 ; il refusait le test de garde qui cherche la balise | non |
| 2026-09-25 | `.yarnrc.yml` (`nodeLinker: node-modules`) et `packageManager: yarn@4.5.3` versionnés | le poste de dev le tenait d'un `~/.yarnrc.yml` global : la CI et Docker auraient résolu en PnP | non |
| 2026-09-25 | `Teams::BaseController` refuse tout (redirection vers l'accueil) | ADR-0052 le crée en V0, l'authentification arrive en V1 : fermé par défaut | non |
| 2026-09-25 | Paquets yarn `trix` et `@rails/actiontext`, framework Action Text et sa table retirés ; les imports JS et `actiontext.css` restent à design | arbitrage de l'orchestrateur : `package.json` appartient à l'amorçage, `app/javascript` à design | non |
| 2026-09-25 | `ACTIVE_STORAGE_SERVICE` choisit le service de stockage en production (défaut `local`) | prépare ADR-0047 sans le trancher | à confirmer par ADR-0047 |

## Ce qui a dérapé

- **Premier commit de couverture passé sans hook** : lancé à la main avec `bash .githooks/pre-commit | tail -3 && git commit`, le code de sortie était celui de `tail`. Le hook avait refusé (faux positif `:nocov:` dans le test de garde), le commit est passé. Annulé (`git reset --soft`), le hook corrigé, puis recommité. Leçon : ne jamais enchaîner un contrôle et un commit à travers un tube.
- **`assume_ssl` rend la redirection HTTPS inobservable dans l'application** : derrière le proxy, toute requête est traitée comme HTTPS. La preuve porte donc sur HSTS et sur l'exclusion de `/up`, pas sur un 301.
- **`Rack::MockRequest` ne pose pas `HTTP_HOST`** : les premières requêtes du test de production étaient bloquées (« Blocked hosts: » vide). L'en-tête est passé explicitement.
- **Tests système impossibles dans le bac à sable** : voir garde-fou 7.

## Ce qui reste bloqué par un autre chantier

Trois contrôles dépendent de fichiers possédés par `design-baseline` (demande envoyée à l'agent design le 2026-09-25) :

| Contrôle | Fichier de design | Correctif attendu |
|---|---|---|
| `test/views/no_third_party_resources_test.rb` (ADR-0049) | `app/views/homepage/index.html.erb` charge Google Fonts | polices auto-hébergées |
| `bin/check-asset-budget` (ADR-0051), et avant lui `yarn build` | `app/javascript/application.js` importe `trix` et `@rails/actiontext`, dont les paquets sont retirés | retirer ces imports, `actiontext.css` et `layouts/action_text/` (36,3 Ko mesurés) |
| `test/integration/supported_browsers_test.rb` (ADR-0051) | `app/views/layouts/application.html.erb` | bandeau `.outdated-browser` + clé `layouts.outdated_browser` |

Les deux tests sont écrits mais **pas commités** tant qu'ils sont rouges (le hook les refuserait, et `SKIP_HOOKS` est exclu) ; ils attendent dans le worktree. Ils entrent dans le dépôt après que l'orchestrateur a mergé `design-baseline` dans `feature/amorcage-depot`. Chacun échoue pour la bonne raison : `homepage/index.html.erb` cité comme ressource tierce, `Translation missing: fr.layouts.outdated_browser` pour le bandeau.

## Pour l'orchestrateur

Variables Railway (par environnement, `Staging` et `main`) :

| Variable | Valeur |
|---|---|
| `RAILS_MASTER_KEY` | contenu de `config/master.key` |
| `DATABASE_URL` | référence au PostgreSQL de l'environnement |
| `RAILWAY_PUBLIC_DOMAIN` | fournie par Railway — rien à faire |
| `APP_HOSTS` | domaines personnalisés, séparés par des virgules (facultatif) |
| `ACTIVE_STORAGE_SERVICE`, `AWS_BUCKET`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_ENDPOINT_URL`, `AWS_FORCE_PATH_STYLE` | à poser avec ADR-0047 : `amazon` et les références au bucket Railway (`BUCKET`, `ACCESS_KEY_ID`, `SECRET_ACCESS_KEY`, `REGION`, `ENDPOINT`) |

`SOLID_QUEUE_IN_PUMA` ne sert plus (worker toujours dans Puma)  : retiré de [configuration.md §2](../../guide/configuration.md), où les variables d'hôte et de stockage sont ajoutées.
