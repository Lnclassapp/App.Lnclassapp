# La stack de Lnclass

> Ce fichier dit **ce qui tourne**, **à quoi ça sert ici** et **où c'est configuré**. Tous les chemins cités existent.
> L'organisation du code est dans [`architecture.md`](architecture.md), les contrats de nommage dans [`conventions.md`](conventions.md).

---

## 1. Vue d'ensemble

| Couche | Choix | Version épinglée où |
|---|---|---|
| Langage | Ruby | [`.ruby-version`](../../.ruby-version) → `3.4.9` |
| Framework | Rails | [`Gemfile`](../../Gemfile) → `~> 8.1.3`, `>= 8.1.3.1` |
| Base de données | PostgreSQL (`pg`) | [`config/database.yml`](../../config/database.yml) |
| Assets | Propshaft + jsbundling (esbuild) + cssbundling | [`package.json`](../../package.json), [`config/initializers/assets.rb`](../../config/initializers/assets.rb) |
| CSS | Tailwind v4, CSS-first | [`app/assets/stylesheets/application.tailwind.css`](../../app/assets/stylesheets/application.tailwind.css) |
| JS | Hotwire (Turbo + Stimulus), Node `24.13.1` | [`app/javascript/`](../../app/javascript/), [`.node-version`](../../.node-version) |
| Jobs / cache / websockets | Solid Queue, Solid Cache, Solid Cable — **sur PostgreSQL** | `config/queue.yml`, `config/cache.yml`, `config/cable.yml` |
| Tests | Minitest (natif Rails) + Capybara/Selenium | [`test/`](../../test/), [`test/test_helper.rb`](../../test/test_helper.rb) |
| Style Ruby | RuboCop, preset `rubocop-rails-omakase` | [`.rubocop.yml`](../../.rubocop.yml) |
| Sécurité | Brakeman, bundler-audit, Strix | [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml), [`.github/workflows/security.yml`](../../.github/workflows/security.yml) |
| Déploiement | **GitHub → Railway** (push = déploiement) | [ADR-0010](../decisions/adr/0010-stack-ops-solid-suite-postgresql-railway.md) |

Le fil directeur : **un monolithe Rails, une base PostgreSQL, zéro service tiers en plus.** Chaque brique ajoutée doit justifier sa facture d'exploitation — voir [ADR-0001](../decisions/adr/0001-architecture-hexagonale-rails8-monolithe.md) et [ADR-0010](../decisions/adr/0010-stack-ops-solid-suite-postgresql-railway.md).

---

## 2. Backend

### Rails 8.1 / Ruby 3.4

`config/application.rb` porte les trois réglages qui comptent :

```ruby
config.load_defaults 8.1

config.i18n.default_locale   = :fr
config.i18n.available_locales = [ :fr, :en ]

config.eager_load_paths << Rails.root.join("app", "domain")
config.eager_load_paths << Rails.root.join("app", "infrastructure")
```

Les deux dernières lignes sont ce qui fait exister l'hexagonale : `app/domain/` et `app/infrastructure/` ne sont pas des dossiers Rails standard, ils sont ajoutés explicitement aux chemins d'autoload. Sans elles, `Entities::`, `UseCases::`, `Ports::`, `Repositories::`, `Queries::` et `Orm::` ne se résolvent pas.

Rails est chargé en `rails/all` : Action Text, Active Storage et Action Cable sont actifs. `ostruct` est requis explicitement (`require "ostruct"` dans `config/application.rb` et gem `ostruct` au `Gemfile`) parce qu'`OpenStruct` sort de la stdlib par défaut en Ruby 3.5 — et le dépôt en compte 166 usages comme objet de retour des use cases (cf. [`conventions.md` §8](conventions.md#8-écarts-connus-entre-la-doc-et-le-code)).

### PostgreSQL

`config/database.yml` : trois environnements, tous PostgreSQL.

| Env | Base | Accès |
|---|---|---|
| `development` | `lnclassapp_development` | user/password `dev-rails` sur `localhost:5432` |
| `test` | `app_lnclassapp_test` | idem |
| `production` | via `DATABASE_URL` et `DATABASE_*` | variables d'environnement Railway |

Une seule base logique : les tables métier, `solid_queue_*`, `solid_cache_entries`, `solid_cable_messages`, `friendly_id_slugs` et `active_storage_*` y cohabitent (`db/schema.rb`, 45 tables).

### Solid Suite — pas de Redis

[ADR-0010](../decisions/adr/0010-stack-ops-solid-suite-postgresql-railway.md) tranche : **aucun Redis, aucun Sidekiq.** Les trois besoins habituellement délégués à Redis sont adossés à PostgreSQL.

| Gem | Remplace | Config | Tables |
|---|---|---|---|
| `solid_queue` | Sidekiq / Resque | `config/queue.yml`, `config/recurring.yml`, `bin/jobs` | `solid_queue_jobs`, `solid_queue_ready_executions`, … (11 tables) |
| `solid_cache` | Redis pour `Rails.cache` | `config/cache.yml` (`max_size: 256 Mo`, namespace = env) | `solid_cache_entries` |
| `solid_cable` | adaptateur Redis d'Action Cable | `config/cable.yml` | `solid_cable_messages` |

À connaître : `config/cable.yml` n'utilise `solid_cable` **qu'en production**. En développement l'adaptateur est `async` (in-process) et en test `test`. Un broadcast Turbo Stream déclenché depuis `bin/rails console` en local n'atteindra donc pas le navigateur — il faut passer par la web-console du processus serveur. Le service `redis`/`valkey` est présent mais **commenté** dans `.github/workflows/ci.yml` : vestige du générateur Rails, pas une dépendance.

### Authentification

Pas de Devise. `bcrypt` + `has_secure_password` natif, identité par **contact téléphonique** — [ADR-0002](../decisions/adr/0002-authentification-native-contact-telephonique-sans-devise.md). Le rôle est un `enum` sur `Orm::User` (`app/infrastructure/orm/user.rb`) : `team`, `teacher`, `student`, `parent`, `school_admin`.

---

## 3. Frontend

### Le pipeline en trois processus

`Procfile.dev`, lancé par `bin/dev` (qui installe `foreman` s'il manque et force `PORT=3000`) :

```
web: env RUBY_DEBUG_OPEN=true bin/rails server
js:  yarn build --watch
css: yarn build:css --watch
```

Les deux scripts sont dans `package.json` :

```json
"build":     "esbuild app/javascript/*.* --bundle --sourcemap --format=esm --outdir=app/assets/builds --public-path=/assets",
"build:css": "npx @tailwindcss/cli -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css --minify"
```

**Propshaft** ne compile rien : il sert `app/assets/builds/` et calcule les digests. Toute la compilation est faite par esbuild et par le CLI Tailwind, en dehors de Rails. Corollaire pratique : si une modification CSS ou JS n'apparaît pas, ce n'est presque jamais Propshaft — c'est le watcher `js:` ou `css:` qui est mort. Relance `bin/dev`.

### Tailwind v4 — CSS-first, **il n'y a pas de `tailwind.config.js`**

C'est le point qui surprend le plus les arrivants. En v4 la configuration est **dans le CSS**, via le bloc `@theme` de `app/assets/stylesheets/application.tailwind.css` :

```css
@import "tailwindcss";
@import "./actiontext.css";

@theme {
    --font-display: "Montserrat", sans-serif;
    --font-body: "Inter", sans-serif;

    --color-primary: #0066ff;
    --color-primary-hover: #0052cc;
    --color-secondary: #1a1a1a;
    --color-success: #00c851;
}
```

Chaque variable de `@theme` génère les utilitaires correspondants : `--color-primary` produit `bg-primary`, `text-primary`, `border-primary`. **Pour ajouter un token de design, tu édites ce fichier — et rien d'autre.** Ne crée pas de `tailwind.config.js` « pour faire propre » : il ne serait pas lu.

Le même fichier contient aussi les composants normés du design system (`card-ln`, `badge-success`, etc.) et importe `actiontext.css` (les styles de l'éditeur Trix). Voir [`../design/README.md`](../design/README.md) et les [UDR](../decisions/udr/).

### Hotwire

[ADR-0009](../decisions/adr/0009-stack-frontend-vanilla-css-tailwind-hotwire.md) rejette explicitement la SPA : cible mobile, réseaux 3G/4G instables en Côte d'Ivoire, budget JS minimal.

- **Turbo Drive / Frames / Streams** — gems `turbo-rails`, import dans `app/javascript/application.js`. Les vues `*.turbo_stream.erb` répondent aux actions sans rechargement.
- **Stimulus** — gem `stimulus-rails` + `@hotwired/stimulus`. **29 contrôleurs** enregistrés dans `app/javascript/controllers/index.js`, fichier *auto-généré* par `bin/rails stimulus:manifest:update` : ajoute ton contrôleur puis relance cette commande, ne l'édite pas à la main.
- **KaTeX** — chargé par CDN dans `app/views/layouts/application.html.erb` (`katex@0.16.21` + `auto-render`), déclenché sur `turbo:load` dans `app/javascript/application.js`. Les délimiteurs sont `$$…$$` (bloc) et `$…$` (inline).
- **Trix / Action Text** — `trix` et `@rails/actiontext` pour les contenus riches (messages, essentials).

### ❌ Redux n'est plus utilisé

L'[ADR-0009](../decisions/adr/0009-stack-frontend-vanilla-css-tailwind-hotwire.md) §3.3 mentionnait un store Redux Toolkit. L'[ADR-0013](../decisions/adr/0013-suppression-redux-et-introduction-dto.md) l'a **supprimé du projet le 2026-08-12**. `@reduxjs/toolkit` n'est plus dans `package.json`, il n'y a pas de `store.js`.

**L'état local du client passe exclusivement par des contrôleurs Stimulus**, qui persistent si besoin dans `localStorage` ou dans des `data-*`. Exemples réels : `app/javascript/controllers/theme_controller.js` (thème sombre/clair), `slideover_controller.js`, `tabs_controller.js`, `toast_container_controller.js`.

Si tu lis « Redux » quelque part, c'est de la doc périmée. Signale-le.

---

## 4. Les gems métier

| Gem | Ce qu'elle fait **ici** | Où c'est branché |
|---|---|---|
| `pagy` ~> 9.3 | Pagination des listes (cours, classes, élèves) | `config/initializers/pagy.rb` (charge `pagy/extras/array`), `app/controllers/application_controller.rb`, `app/helpers/application_helper.rb` |
| `friendly_id` | URLs lisibles à partir d'un nom | `config/initializers/friendly_id.rb`, `app/models/concerns/sluggable.rb` (`friendly_id :name, use: :slugged`), `app/infrastructure/orm/user.rb` (`friendly_id :fullname`) ; table `friendly_id_slugs` |
| `heroicons` ~> 2.2 | Jeu d'icônes en helper ERB : `heroicon "plus-circle", variant: :solid` | `config/initializers/heroicons.rb` (variant par défaut `:outline`, tailles par variant) |
| `active_storage_validations` ~> 3.0 | Validation des pièces jointes (type, taille) | modèles `Orm::` portant un `has_one_attached` |
| `image_processing` | Variantes d'images Active Storage | — |
| `rails-i18n` ~> 8.1 | Traductions Rails de base en `:fr` | `config/locales/fr.yml`, `en.yml`, `gamification.fr.yml` |
| `bcrypt` | Mots de passe (`has_secure_password`) | `app/infrastructure/orm/user.rb` |
| `jbuilder` | Vues JSON | rarement utilisé |
| `web-console` | Console sur les pages d'erreur, en développement | groupe `:development` |

> ⚠️ La gem `debugbar` **n'est plus au `Gemfile`** : retirée le 2026-10-03 par le chantier [`retrait-debugbar`](../chantiers/retrait-debugbar/memo.md). Après l'envoi d'une image, son middleware faisait répondre `500` à toutes les requêtes de développement jusqu'au redémarrage ; elle ouvrait aussi Action Cable à toute origine.

> ⚠️ La gem `nanoid` **n'est plus au `Gemfile`** : supprimée par [ADR-0017](../decisions/adr/0017-remplacement-nanoid-par-secure-random.md) au profit de `SecureRandom.base58`. Détail dans [`glossaire.md` §7](glossaire.md#7-identifiants--public_id-slug).

---

## 5. Qualité, sécurité, CI

### Ce qui tourne en local

| Commande | Effet |
|---|---|
| `bin/rails test` | Toute la suite Minitest |
| `bin/rubocop` / `bin/rubocop -A` | Style Ruby, preset `rubocop-rails-omakase` |
| `bin/brakeman --no-pager` | Analyse statique de sécurité Rails |
| `bin/bundler-audit` | CVE connues sur les gems (exceptions dans `config/bundler-audit.yml`) |
| `bin/validate_hitl` | Audit maison : syntaxe Ruby + présence des en-têtes HITL sur `app/` |
| `bin/ci` | Enchaîne le tout (voir `config/ci.rb`) |

Le hook `.githooks/pre-commit` refuse tout fichier de `app/` (`.rb`, `.js`, `.html.erb`, `.turbo_stream.erb`) qui ne compile pas ou qui n'a pas d'en-tête HITL. Il faut l'activer explicitement — voir [`onboarding.md`](onboarding.md).

### Ce qui tourne en CI

`.github/workflows/` contient trois workflows :

| Workflow | Jobs |
|---|---|
| `ci.yml` | `scan_ruby` (brakeman + bundler-audit) · `lint` (rubocop) · `test` (`bin/rails db:test:prepare test`) · `system-test` (`test:system`, screenshots uploadés en cas d'échec) |
| `hitl_audit.yml` | `bin/validate_hitl` + compilation de tous les `.rb` de `app/` |
| `security.yml` | Scan Strix sur chaque PR, SARIF remonté à GitHub Code Scanning |

Les services PostgreSQL sont lancés en conteneur ; `DATABASE_URL` est injecté par le workflow.

### 🕳️ Les trous d'outillage, dits franchement

| Manque | Conséquence |
|---|---|
| **Aucun linter JavaScript** — ni ESLint, ni Prettier | Le style des 29 contrôleurs Stimulus n'est tenu par rien d'autre que la relecture. Rien ne détecte une variable inutilisée ou un `import` mort. |
| **Aucun linter CSS** — pas de Stylelint | `application.tailwind.css` fait ~250 lignes et contient déjà des blocs d'accolades orphelins. Personne ne le voit passer. |
| **Aucun lint ERB** — ni `erb_lint`, ni `erb_lint`-équivalent | Les vues ne sont vérifiées ni pour le style, ni pour l'accessibilité, ni pour les `t(".key")` manquantes. |
| `hitl_audit.yml` épingle `ruby-version: '3.3.0'` | Divergence avec `.ruby-version` (`3.4.9`). Le job d'audit ne tourne pas sur la version du projet. |

Ce ne sont pas des détails à corriger en passant : ouvre un chantier si tu veux les combler.

---

## 6. Déploiement — GitHub + Railway

**Le déploiement est assuré par GitHub et Railway.** Push sur la branche principale → webhook Railway → build et mise en ligne automatiques. Il n'y a pas de commande de déploiement à lancer à la main.

**Kamal n'est pas utilisé.** La gem `kamal` est encore au `Gemfile`, `bin/kamal`, `config/deploy.yml` et `.kamal/` existent encore : **aucun de ces fichiers n'a de rôle opérationnel.** Ne t'appuie pas dessus, ne les modifie pas en croyant agir sur la production. Le point est arbitré dans l'encadré ✅ en tête de l'[ADR-0010](../decisions/adr/0010-stack-ops-solid-suite-postgresql-railway.md), qui corrige un champ Statut contradictoire de la version d'origine.

Le `Dockerfile` et `thruster` restent la base de l'image buildée par Railway. `bin/jobs` lance le worker Solid Queue.

---

## 7. Les ADR qui ont tranché cette stack

| ADR | Ce qu'il fixe |
|---|---|
| [0001](../decisions/adr/0001-architecture-hexagonale-rails8-monolithe.md) | Monolithe Rails 8 + hexagonale |
| [0002](../decisions/adr/0002-authentification-native-contact-telephonique-sans-devise.md) | Auth native par contact, sans Devise |
| [0009](../decisions/adr/0009-stack-frontend-vanilla-css-tailwind-hotwire.md) | Tailwind v4, Hotwire, KaTeX — **partie Redux caduque** |
| [0010](../decisions/adr/0010-stack-ops-solid-suite-postgresql-railway.md) | Solid Suite sur PostgreSQL, pas de Redis, déploiement GitHub → Railway |
| [0013](../decisions/adr/0013-suppression-redux-et-introduction-dto.md) | Suppression de Redux, maintien de Yarn + Propshaft, introduction des DTO |
| [0017](../decisions/adr/0017-remplacement-nanoid-par-secure-random.md) | `SecureRandom.base58` remplace la gem `nanoid` |
| [0020](../decisions/adr/0020-optimisations-bulk-insert-donnees-catalogue.md) | `insert_all` pour les imports de catalogue |
| [0022](../decisions/adr/0022-modelisation-hexagonale-du-catalogue-pedagogique.md) | Modélisation hexagonale du catalogue *(ex-ADR-0014, renuméroté)* |
| [0023](../decisions/adr/0023-modelisation-de-l-organisation-scolaire.md) | Modélisation de l'organisation scolaire *(ex-ADR-0015, renuméroté)* |

> ⚠️ **Renumérotation.** Les en-têtes HITL du code référencent encore « ADR-0014 (catalogue) » et « ADR-0015 (organisation scolaire) ». Ce sont désormais **ADR-0022** et **ADR-0023**. Les numéros 0014 et 0015 appartiennent à d'autres décisions (namespaces, stratégie de tests). Quand tu écris un nouvel en-tête, utilise les numéros à jour.

---

## 8. Où aller ensuite

| Tu veux | Ouvre |
|---|---|
| Installer et lancer le projet | [`onboarding.md`](onboarding.md) |
| Comprendre où va chaque fichier | [`architecture.md`](architecture.md) |
| Connaître un nom, un format, une règle bloquante | [`conventions.md`](conventions.md) |
| Écrire du code d'une couche | [`../blueprints/`](../blueprints/) |
| Parler le bon vocabulaire | [`glossaire.md`](glossaire.md) |
