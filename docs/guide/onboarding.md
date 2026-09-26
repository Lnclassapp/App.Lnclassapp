# Jour 1 sur Lnclass

> Objectif : de `git clone` à ton premier chantier ouvert, en une demi-journée.
> Tout ce qui suit a été vérifié dans le dépôt. Si une commande échoue autrement que décrit ici, c'est la doc qui a tort — voir [§ Où poser une question](#8-où-poser-une-question).

---

## 1. Prérequis

| Outil | Version attendue | Vérifier |
|---|---|---|
| Ruby | `3.4.9` — épinglé dans [`.ruby-version`](../../.ruby-version) | `ruby -v` |
| Node | `24.13.1` — épinglé dans [`.node-version`](../../.node-version) | `node -v` |
| Yarn | Yarn moderne (le dépôt a un dossier `.yarn/` et un `yarn.lock`) | `yarn -v` |
| PostgreSQL | 14+ | `psql --version` |
| Git | — | `git --version` |
| `foreman` | installé automatiquement par `bin/dev` s'il manque | — |

Un gestionnaire de versions (`rbenv`, `mise`, `asdf`…) lit directement `.ruby-version` et `.node-version` : c'est le plus simple.

### Le rôle PostgreSQL — à faire avant tout

`config/database.yml` code en dur les identifiants de développement :

```yaml
db_config: &db_config
  username: dev-rails
  password: dev-rails
  host: localhost
  port: 5432
```

Le rôle `dev-rails` doit donc exister **avant** `bin/setup`, sinon la préparation de la base échoue :

```bash
sudo -u postgres createuser --superuser --pwprompt dev-rails   # mot de passe : dev-rails
```

Bases créées ensuite par Rails : `lnclassapp_development` et `app_lnclassapp_test`.

---

## 2. Installer

```bash
git clone <url-du-depot> Lnclassapp
cd Lnclassapp
bin/setup --skip-server
```

[`bin/setup`](../../bin/setup) est idempotent. Il fait exactement, dans cet ordre :

1. `bundle check` et, si besoin, `bundle install`
2. `yarn install`
3. `bin/rails db:prepare` — crée la base et charge `db/schema.rb` si elle n'existe pas, sinon applique les migrations en attente
4. `bin/rails log:clear tmp:clear`
5. `exec bin/dev` — **sauf** si tu passes `--skip-server`

Deux options utiles :

| Option | Effet |
|---|---|
| `--skip-server` | s'arrête après la préparation, ne lance pas le serveur |
| `--reset` | ajoute un `bin/rails db:reset` (drop + create + schema + seeds) |

`db/seeds.rb` fait 9 lignes : ne compte pas dessus pour avoir un jeu de données réaliste.

### Activer le hook de pre-commit — **obligatoire, et ça ne se fait pas tout seul**

Le hook vit dans [`.githooks/pre-commit`](../../.githooks/) et non dans `.git/hooks/`. Il n'est actif que si tu le déclares :

```bash
git config core.hooksPath .githooks
```

Vérifie : `git config core.hooksPath` doit répondre `.githooks`.

Sans ça, tu committeras du code que la CI rejettera. Le hook bloque tout fichier de `app/` (`.rb`, `.js`, `.html.erb`, `.turbo_stream.erb`) qui ne compile pas ou qui n'a pas son en-tête HITL de 3 lignes — format dans [`conventions.md` §5](conventions.md#5-en-tête-hitl).

---

## 3. Lancer

```bash
bin/dev
```

→ http://localhost:3000

[`bin/dev`](../../bin/dev) installe `foreman` si nécessaire, fixe `PORT=3000` par défaut, puis démarre les trois processus de [`Procfile.dev`](../../Procfile.dev) :

| Process | Commande | Rôle |
|---|---|---|
| `web` | `env RUBY_DEBUG_OPEN=true bin/rails server` | Puma, avec le débogueur attachable |
| `js` | `yarn build --watch` | esbuild → `app/assets/builds/application.js` |
| `css` | `yarn build:css --watch` | Tailwind CLI → `app/assets/builds/application.css` |

Autre port : `PORT=3001 bin/dev`.

**Le réflexe quand « le CSS ne se met pas à jour » :** ce n'est presque jamais Propshaft, c'est le process `css` ou `js` qui est mort dans la sortie de foreman. Regarde les logs, relance `bin/dev`. Détails dans [`stack.md` §3](stack.md#3-frontend).

---

## 4. Lancer les tests

```bash
bin/rails test                  # toute la suite Minitest
bin/rails test test/domain      # juste le domaine — rapide, sans base
bin/rails test:system           # Capybara + Selenium, lent
```

> ⚠️ **La suite de tests était cassée et elle est en cours de réparation au moment où ce guide est écrit.** Ne pars pas du principe qu'un `bin/rails test` vert est l'état normal, et n'attribue pas automatiquement un échec à ton propre travail.
>
> **L'état de référence, c'est le dernier passage CI sur `Develop`**, pas ton exécution locale : va voir l'onglet Actions du dépôt (workflow `CI`, jobs `test` et `system-test`) avant de conclure quoi que ce soit. Si un test échoue de la même façon sur `main` et sur ta branche, ce n'est pas toi — signale-le, ne le « répare » pas en passant.

Les autres portes, celles qui bloquent une PR :

```bash
bin/rubocop          # style Ruby (bin/rubocop -A pour corriger)
bin/brakeman --no-pager
bin/bundler-audit
bin/validate_hitl    # audit maison : syntaxe + en-têtes HITL sur app/
bin/ci               # enchaîne tout, cf. config/ci.rb
```

La liste faisant foi est dans [`conventions.md` §7](conventions.md#7-ce-qui-bloque).

---

## 5. Le tour du propriétaire

Ne lis pas `app/` de haut en bas. Lis **un parcours vertical** : le §2 d'[`architecture.md`](architecture.md#2-un-parcours-tracé-de-bout-en-bout) suit une session d'exercice du contrôleur jusqu'à la table SQL, fichier par fichier. C'est la lecture la plus rentable de ta journée.

Le squelette, pour situer :

```
app/
├── domain/              🧠 Ruby pur — ne dépend de RIEN
│   ├── entities/        (37) règles métier
│   ├── use_cases/       (47) une classe = une action
│   ├── ports/           interfaces que l'infra doit remplir
│   ├── dtos/            validation de frontière (ADR-0013)
│   ├── policies/        ClassroomAccessPolicy
│   └── strategies/      import polymorphe du catalogue
├── infrastructure/      🔌 les détails techniques
│   ├── repositories/    implémentent les ports, mappent Record ⇄ Entité
│   ├── orm/             modèles ActiveRecord anémiques (Orm::)
│   └── queries/         lecture pure, court-circuite le domaine
├── controllers/         🌐 HTTP → use case ou query, zéro métier
├── views/               🌐 ERB + Turbo Streams
├── javascript/          ⚡ Stimulus (29 contrôleurs) + Turbo
├── assets/stylesheets/  application.tailwind.css — le bloc @theme
├── helpers/ · jobs/ · mailers/ · models/
config/
├── application.rb       locale :fr + eager_load de domain/ et infrastructure/
├── routes.rb
├── database.yml · cable.yml · cache.yml · queue.yml
└── initializers/        friendly_id, heroicons, pagy, repositories_aliases
docs/                    ← tu es ici
test/                    domain/ infrastructure/ controllers/ integration/ …
```

⚠️ `app/presenters/` et `app/domain/validators/` sont cités par de vieilles docs : **ils n'existent pas.** Ne les crée pas pour « être conforme ».

Trois lectures, dans cet ordre, avant d'écrire une ligne :

1. [`architecture.md`](architecture.md) — les 4 couches, le sens des dépendances, les erreurs classiques
2. [`conventions.md`](conventions.md) — nommage, branches, commits, en-tête HITL, ce qui bloque
3. [`../workflows/README.md`](../workflows/README.md) — les 5 phases, valables pour **tout** type de travail

Puis, en signet : [`glossaire.md`](glossaire.md) et [`../blueprints/`](../blueprints/).

---

## 6. Ouvrir ton premier chantier

**Aucun travail ne commence par du code.** Il commence par un dossier dans [`../chantiers/`](../chantiers/). Un chantier sans dossier n'existe pas ([`../README.md`](../README.md)).

Dans Claude Code, les slash commands sont actives (elles vivent dans `.claude/skills/`) :

```
/feature <slug>       nouvelle capacité pour un acteur
/bugfix <slug>        un comportement documenté ne se produit pas
/refactor <slug>      même comportement, meilleure structure
/optimize <slug>      même résultat, plus vite / moins de requêtes
/hotfix <slug>        la prod est cassée maintenant
```

La commande crée `docs/chantiers/<slug>/`, lance la phase 1 (cadrage) et t'accompagne jusqu'au plan de lots. Sans Claude Code, copie [`../chantiers/_TEMPLATE/`](../chantiers/_TEMPLATE/) à la main : `memo.md`, `prd.md`, `plan.md`, `journal.md`, `pr-faq.md`. Le processus est identique.

Le `<slug>` est en kebab-case, court, **sans type ni numéro** : `messagerie-classe`, pas `feature-5-messagerie`.

Ta branche :

```bash
git switch -c feature/<slug>          # ou fix/ refactor/ perf/ hotfix/ docs/
```

Jamais de commit direct sur `Develop`, `Staging` ni `main`. Une seule PR par chantier. Les branches de lot s'écrivent `feature/<slug>-lot-a` — **avec un tiret**, pas un slash : git refuse `feature/x/lot-a` quand `feature/x` existe. Voir [`conventions.md` §3](conventions.md#3-branches).

### Un bon premier chantier

Prends un `/bugfix` sur un écran que tu viens d'ouvrir dans le navigateur, ou une correction de documentation. Tu traverseras les 5 phases une première fois sans être noyé par le métier.

Deux bugs latents déjà identifiés, si tu cherches une cible réelle : les références à `Orm::ClassroomExercise` (classe et table inexistantes) dans `app/infrastructure/queries/student_feed_query.rb` et `app/controllers/teachers/classroom_exercises_controller.rb`. Contexte dans [`architecture.md` §7](architecture.md#7-écarts-connus-entre-cette-architecture-et-le-code).

---

## 7. Tes 5 premiers réflexes

**1. Avant de coder, ouvrir le workflow.** [`../workflows/README.md`](../workflows/README.md). Les 5 phases — cadrer, décider, planifier, exécuter, prouver — s'appliquent à une correction d'une ligne comme à une feature complète. Ce qui change, c'est leur poids, pas leur existence.

**2. Chercher la décision avant de la reprendre.** Un choix qui te semble bizarre a probablement un ADR. `ls docs/decisions/adr/` puis `grep -ril "<mot-clé>" docs/decisions/`. Si le choix est vraiment mauvais, tu écris un ADR qui remplace l'ancien — tu ne le contournes pas en silence.

**3. Suivre le code réel, pas la doc, quand les deux divergent — et signaler l'écart.** Les divergences connues sont listées dans [`conventions.md` §8](conventions.md#8-écarts-connus-entre-la-doc-et-le-code) et [`architecture.md` §7](architecture.md#7-écarts-connus-entre-cette-architecture-et-le-code). Une divergence non listée est une découverte : elle vaut un chantier `docs/<slug>`, pas une correction opportuniste au milieu d'une feature.

**4. Copier un voisin du même contexte borné, jamais un fichier racine.** Les fichiers à la racine de `entities/`, `ports/` ou `repositories/` sont du legacy à migrer (≈13 entités et 5 repositories sont dupliqués racine + contexte). Ton modèle, c'est `app/domain/use_cases/assessment/submit_question_attempt.rb`, pas `app/domain/entities/user.rb`.

**5. Ne jamais élargir le périmètre en cours de route.** Tu trouves un bug pendant un refactoring ? Tu le notes dans le `journal.md` du chantier et tu ouvres un chantier à part. Un refactoring qui change un comportement est une feature déguisée — c'est un interdit explicite du workflow.

---

## 8. Où poser une question

| Ta question | Où chercher d'abord | Si ça ne répond pas |
|---|---|---|
| « Comment on nomme ça ? » | [`conventions.md`](conventions.md) | Demande à l'équipe **avant** d'inventer un nom : un synonyme de plus coûte cher |
| « Où va ce fichier ? » | [`architecture.md`](architecture.md) puis [`../blueprints/`](../blueprints/) | Poste le cas dans le canal équipe |
| « Pourquoi c'est fait comme ça ? » | [`../decisions/adr/`](../decisions/adr/) — l'index est dans [`README.md`](../decisions/adr/README.md) | Si aucun ADR ne couvre le sujet, c'est qu'il faut l'écrire |
| « Ce mot veut dire quoi ? » | [`glossaire.md`](glossaire.md) | Un terme métier absent du glossaire = à ajouter, pas à improviser |
| « À quoi doit ressembler cette vue ? » | [`../decisions/udr/`](../decisions/udr/) et [`../design/README.md`](../design/README.md) | Un nouveau motif d'interface sans UDR ne s'écrit pas ; une vue qui réutilise les motifs existants n'en demande pas |
| « La commande X échoue » | Ce fichier, puis le dernier run CI sur `main` | Canal équipe, avec la sortie complète |
| « La doc dit A, le code fait B » | Les deux sections « écarts connus » | **C'est un bug de la documentation.** Ouvre un chantier `docs/<slug>`. Une doc fausse coûte plus cher qu'une doc absente. |

---

## 9. Ta checklist jour 1

- [ ] `ruby -v` → 3.4.9, `node -v` → 24.13.1
- [ ] rôle PostgreSQL `dev-rails` créé
- [ ] `bin/setup --skip-server` passe jusqu'au bout
- [ ] `git config core.hooksPath .githooks` configuré et vérifié
- [ ] `bin/dev` sert http://localhost:3000, les 3 process tournent
- [ ] `bin/rails test test/domain` lancé — et comparé au dernier run CI de `main`
- [ ] `bin/rubocop` passe
- [ ] [`architecture.md` §2](architecture.md#2-un-parcours-tracé-de-bout-en-bout) lu, fichiers ouverts au fur et à mesure
- [ ] [`../workflows/README.md`](../workflows/README.md) lu en entier
- [ ] premier chantier ouvert avec `/bugfix` ou `/feature`, `memo.md` écrit
