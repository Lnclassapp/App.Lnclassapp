# Configuration — secrets et variables d'environnement

> **À configurer dans le nouveau projet avant la première mise en ligne.**
> Ce document liste ce qui doit exister, où, et ce qui casse si ça manque. Aucune valeur réelle n'y figure et aucune ne doit y être ajoutée : ce fichier est versionné.

---

## 1. Secrets GitHub Actions

À déclarer dans **Settings → Secrets and variables → Actions → New repository secret**.

### Analyse de sécurité — `security.yml`

| Secret | Rôle | Si absent |
|---|---|---|
| `STRIX_LLM` | Le modèle utilisé par le scanner, ex. `openrouter/<fournisseur>/<modèle>` | Le scan sort en code 1 → **le job échoue à chaque PR** |
| `LLM_API_KEY` | La clé d'API du fournisseur | Idem |

C'est l'échec constaté sur la [PR #14](https://github.com/Lnclassapp/App.Lnclassapp/pull/14) : le workflow existe, les secrets non.

Deux variables apparaissent dans l'aide de l'outil mais **ne sont pas câblées** dans notre workflow — ne les déclarer que si on les branche explicitement :

- `LLM_API_BASE` — uniquement pour un modèle exécuté en local
- `EXA_API_KEY`, `PERPLEXITY_API_KEY` — recherche web, optionnelles

> ⚠️ **Deuxième défaut du même workflow, indépendant des clés.** L'étape `Upload SARIF` échoue avec *« The CodeQL Action does not support uploading multiple SARIF runs with the same category »* : `strix_runs` contient plusieurs fichiers `findings.sarif`. Configurer les clés ne suffira donc pas — il faut aussi n'envoyer qu'un seul run, ou donner une `category` distincte à chacun.
>
> **Tant que les deux ne sont pas réglés, ce job est rouge sur chaque PR. Une CI durablement rouge cesse d'être lue** — mieux vaut retirer le workflow que le laisser échouer.

---

## 2. Variables d'environnement de production

### Obligatoires

| Variable | Rôle | Si absente |
|---|---|---|
| `RAILS_MASTER_KEY` | Déchiffre `config/credentials.yml.enc` | **L'application ne démarre pas.** Contenu de `config/master.key`, qui est gitignoré — à copier à la main dans Railway |
| `DATABASE_URL` | Connexion PostgreSQL | L'application ne démarre pas. Fournie automatiquement par Railway si la base est liée au service |
| `RAILS_ENV` | `production` | Valeurs par défaut de développement en production |
| `BUCKET_NAME`, `BUCKET_ENDPOINT`, `BUCKET_ACCESS_KEY_ID`, `BUCKET_SECRET_ACCESS_KEY` | Service `railway` de `config/storage.yml` (ADR-0047) ; références aux variables du bucket Railway de l'environnement (`${{Bucket.BUCKET}}`, `${{Bucket.ENDPOINT}}`…) | **L'application ne démarre pas** (`missing required option :name`) : Railway garde l'ancienne version, `/up` ne répond pas |
| `RAILWAY_PUBLIC_DOMAIN` | Hôte autorisé par `config.hosts` | Fournie par Railway. Sans elle ni `APP_HOSTS`, seul `localhost` est servi : toute page répond 403, sauf `/up` |

### Facultatives — hôtes et stockage

| Variable | Rôle |
|---|---|
| `APP_HOSTS` | Domaines personnalisés autorisés, séparés par des virgules |
| `BUCKET_REGION` | Région du bucket, `auto` par défaut |
| `BUCKET_FORCE_PATH_STYLE` | `true` si le bucket Railway annonce des URL en *path-style* |

### Facultatives — réglage de charge

Toutes ont une valeur par défaut raisonnable. À ne toucher qu'avec une mesure à l'appui.

| Variable | Rôle |
|---|---|
| `WEB_CONCURRENCY` | Nombre de processus Puma |
| `RAILS_MAX_THREADS` | Threads par processus |
| `JOB_CONCURRENCY` | Concurrence des jobs Solid Queue |
| `PORT` | Port d'écoute — Railway le fournit |
| `RAILS_LOG_LEVEL` | `info` par défaut |
| `PIDFILE` | Chemin du fichier PID |

### Développement local uniquement

`DATABASE_NAME` · `DATABASE_USERNAME` · `DATABASE_PASSWORD` · `DATABASE_PORT` — lues par `config/database.yml`. En production, `DATABASE_URL` prime.

`CHROME_BIN` · `CHROMEDRIVER_PATH` — lues par `test/application_system_test_case.rb` et `bin/check-chrome`. Un Chrome et son pilote locaux, hors snap, par exemple Chrome for Testing :

```bash
CHROME_BIN=~/.cache/chrome-for-testing/chrome-linux64/chrome \
CHROMEDRIVER_PATH=~/.cache/chrome-for-testing/chromedriver-linux64/chromedriver \
  bin/ci
```

Sans elles, selenium-manager trouve Chrome (runner GitHub) ou le télécharge (réseau requis). `bin/check-chrome` arrête `bin/ci` avec un message explicite si le navigateur ne démarre pas.

> Dans l'ancienne application, `config/database.yml` contenait un mot de passe de développement **en clair et versionné**. Toléré parce qu'il ne concernait qu'une base locale. **Dans le nouveau projet, ces quatre variables doivent venir d'un `.env` non versionné.**

---

## 3. Trois réglages absents qui casseront en production

Constatés dans `config/environments/production.rb` de l'ancienne application. Ce ne sont pas des variables à déclarer, ce sont des décisions à prendre.

### `force_ssl` est commenté

```ruby
# config/environments/production.rb
# config.assume_ssl = true      ← ligne 28, commentée
# config.force_ssl  = true      ← ligne 31, commentée
```

Le cookie de session porte à lui seul toute l'authentification. Sans HTTPS forcé, il circule en clair. **Prérequis bloquant** — voir [`securite.md`](../chantiers/refonte-application/securite.md).

### Le stockage des fichiers est sur le disque local

```ruby
config.active_storage.service = :local
```

Sur Railway, le disque du conteneur est **éphémère** : chaque déploiement efface les fichiers téléversés. Les images de couverture et les messages vocaux disparaîtraient à la première mise à jour, sans erreur ni avertissement.

**Réglé dans le nouveau projet par l'[ADR-0047](../decisions/adr/)** : service `railway` (bucket Railway, S3-compatible) en production, fichiers servis par l'application (`rails_storage_proxy`), variables `BUCKET_*` du §2.

### L'hôte des liens de mail est un exemple

```ruby
config.action_mailer.default_url_options = { host: "example.com" }
```

Et la configuration SMTP est entièrement commentée. Tout lien envoyé par courriel pointerait vers `example.com`.

**Ça devient bloquant dès qu'un parcours de récupération de mot de passe existe** — et c'est précisément ce que le nouveau projet doit livrer, puisque l'ancien n'en avait aucun. Si la récupération passe par SMS plutôt que par courriel, ce sont les identifiants du fournisseur SMS qu'il faut prévoir ici.

---

## 4. Configuration des tests et de la CI — trois pièges vérifiés

Les trois ont été constatés sur la [PR #14](https://github.com/Lnclassapp/App.Lnclassapp/pull/14), où ils ont fait échouer la CI alors que tout était vert en local. Ce ne sont pas des bugs applicatifs : ce sont des erreurs de configuration, et elles se reproduiront à l'identique dans le nouveau projet si on ne les prévoit pas.

### 4.1 Le seuil de couverture ne doit pas s'appliquer aux exécutions partielles

`minimum_coverage` posé dans `test_helper.rb` s'applique à **toutes** les exécutions, y compris celles qui ne lancent qu'un sous-ensemble de la suite.

Constat : le job « Parcours critiques » ne lance que les 6 tests système. Couverture naturelle **42,49 % lignes / 4,01 % branches** — très en dessous du seuil, qui vise la suite complète.

```
Line coverage (42.49%) is below the expected minimum coverage (45.00%).
SimpleCov failed with exit 2 due to a coverage related error
```

Le job échoue alors que rien n'est cassé. **Un seuil est une mesure de suite complète ; l'appliquer à un sous-ensemble produit un faux négatif garanti.**

**Parade** — désactiver la mesure sur toute exécution partielle, via la variable que `test_helper.rb` doit prévoir dès le départ :

```yaml
# .github/workflows/ci.yml — job des parcours système
- name: Run System Tests
  env:
    COVERAGE: "0"          # le seuil est vérifié par le job de suite complète
  run: bin/rails db:test:prepare test:system
```

Le pre-commit applique déjà ce principe : il lance `COVERAGE=0 bin/rails test <fichiers ciblés>`.

### 4.2 `SimpleCov.track_files` est déprécié

```
[DEPRECATION] `SimpleCov.track_files` is deprecated.
Replace with `SimpleCov.cover "{app,lib}/**/*.rb"`
```

`cover` fait ce que faisait `track_files` — inclure les fichiers présents sur disque mais jamais chargés — **et** restreint le rapport à l'ensemble correspondant.

```ruby
# test/test_helper.rb
SimpleCov.start "rails" do
  enable_coverage :branch
  cover "{app,lib}/**/*.rb"   # et non : track_files
  minimum_coverage line: 100, branch: 100
end
```

Cette ligne n'est pas cosmétique : **sans elle, les fichiers qu'aucun test ne charge disparaissent du rapport et la couverture affichée grimpe artificiellement.** Dans l'ancienne application, l'écart était de 27 points sur le seul domaine.

### 4.3 `rack_test` ne connaît pas la visibilité — un test système vert en local ne prouve rien

C'est le piège le plus coûteux, parce qu'il donne l'assurance inverse de la réalité.

Sous `rack_test` (pilote par défaut, sans navigateur), Capybara **ignore la visibilité CSS** : un élément caché dans un menu déroulant fermé est trouvé comme s'il était affiché. Sous Chrome headless, il ne l'est pas.

```
expected to find text "Déconnexion" … (However, it was found 2 times including non-visible text.)
Capybara::ExpectationNotMet: expected to find visible button "Déconnexion" that is not disabled
  … Also found "", which matched the selector but not all filters.
```

Deux tests d'authentification passaient en local et échouaient en CI, pour cette seule raison : ils cherchaient un bouton vivant dans un menu qu'il fallait ouvrir d'abord.

**Trois règles qui en découlent :**

1. **Les parcours système se valident dans un vrai navigateur, jamais sous `rack_test`.** Si Chrome headless n'est pas disponible localement, un test système vert est **non prouvé**, pas prouvé — et il faut le dire ainsi dans la PR plutôt que de le compter comme une garantie.
2. **Un test qui cherche un élément dans un menu ouvre le menu d'abord.** `click_on "…"` sur le déclencheur, puis l'assertion.
3. **Les captures d'écran d'échec sont le premier réflexe de diagnostic.** La CI les écrit dans `tmp/screenshots/` — les publier en artefact, au même titre que le rapport de couverture.

---

## 5. Ce qui ne doit jamais être versionné

| Fichier | État attendu |
|---|---|
| `config/master.key` | gitignoré — `/config/*.key` |
| `.env`, `.env.local` | gitignorés |
| `config/credentials.yml.enc` | **versionné**, c'est sa raison d'être — il est chiffré |
| `.claude/settings.local.json` | gitignoré — permissions personnelles |

Vérification :

```bash
git check-ignore -v config/master.key .env
```

Une sortie vide sur l'un d'eux signifie qu'il **sera** committé.

---

## 6. Checklist avant la première mise en ligne

- [ ] `RAILS_MASTER_KEY` posée dans Railway, et `config/master.key` conservée ailleurs qu'en local — la perdre rend `credentials.yml.enc` définitivement illisible
- [ ] `DATABASE_URL` fournie par le service PostgreSQL lié
- [ ] `force_ssl` **décommenté et vérifié actif** en production
- [ ] Stockage des fichiers sur un service persistant, pas `:local`
- [ ] `default_url_options[:host]` pointe sur le vrai domaine
- [ ] Le canal de récupération de mot de passe (SMTP ou SMS) est configuré et testé
- [ ] `STRIX_LLM` et `LLM_API_KEY` posées — **ou** `security.yml` retiré
- [ ] L'upload SARIF n'envoie qu'un run par catégorie
- [ ] `git check-ignore` confirme que `master.key` et `.env` sont ignorés
- [ ] Aucun secret dans l'historique git : `git log -p | grep -iE "api[_-]?key|secret|password"` ne remonte rien de réel
- [ ] Le seuil de couverture n'est appliqué qu'aux exécutions de suite complète (`COVERAGE=0` sur les jobs partiels)
- [ ] `SimpleCov.cover` est utilisé, pas `track_files`
- [ ] Les parcours système tournent sous Chrome headless en CI, et les captures d'échec sont publiées en artefact
