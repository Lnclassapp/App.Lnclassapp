# Memo — Seeds joués deux fois au déploiement, `image_processing` réclamé au démarrage

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré (branche poussée, en attente de revue) |
| **Ouvert le** | 2026-09-29 |
| **Branche** | `fix/deploiement-seeds-variantes` |
| **Programme** | — |

Source : premier déploiement de production du nouveau projet Railway (base neuve), 2026-09-29. Comportement attendu : [ADR-0034](../../decisions/adr/0034-reprise-des-donnees-et-referentiel-seede.md), [ADR-0038](../../decisions/adr/0038-comptes-de-l-equipe-et-sous-roles.md), [ADR-0052, amendement du 2026-09-27](../../decisions/adr/0052-chaine-de-livraison-versionnee-et-worker-dans-puma.md), [ADR-0060](../../decisions/adr/0060-photo-de-profil-stockee-privee-recadree-par-le-navigateur.md). Pas de nouvel ADR : amendement daté de l'ADR-0052 (prémisse inexacte sur `db:prepare`). Pas d'UDR : rien ne change à l'écran.

## D1 — seeds joués deux fois à chaque déploiement

**Symptôme** — Logs du pré-déploiement Railway (`bin/rails db:prepare db:seed`) : `db/seeds.rb:4: warning: already initialized constant SEEDS`, puis **deux** « Invitation d'amorçage pour <numéro>, valable 72 h : /invitations/<jeton> ». Le premier lien est déjà révoqué par le second.

**Reproduction** — Base PostgreSQL vide mais existante (comme celle de Railway), `RAILS_ENV=production`, `TEAM_BOOTSTRAP_CONTACT=0700000042`, variables `BUCKET_*` et `SECRET_KEY_BASE` factices, `bin/rails db:prepare db:seed` : deux liens, deux lignes dans `invitations` (la première révoquée). Reproduit à la main le 2026-09-29 avant tout code. Test : `test/config/railway_deployment_test.rb`, « on a new database, each deploy seeds once… », rouge avant correctif : `Expected: 1, Actual: 2` avec les deux liens et l'avertissement dans la sortie.

**Portée** — Tout déploiement sur une base sans `schema_migrations` : le premier déploiement de chaque environnement neuf. Les déploiements suivants (base déjà initialisée) ne sèment qu'une fois. Données : une invitation révoquée de trop, inoffensive ; rien à réparer.

**Root cause** — `ActiveRecord::Tasks::DatabaseTasks#prepare_all` (Rails 8.1) sème toute base qu'il **initialise** (`initialize_database` : pas de table `schema_migrations` → chargement du schéma, puis `load_seed` si `db_config.seeds?`, vrai par défaut pour la base primaire). Puis `db:seed` rappelle `load_seed` dans le même processus. L'amendement du 2026-09-27 de l'ADR-0052 supposait que `db:prepare` ne sème qu'une base qu'il **crée** ; c'est faux pour une base existante vide. Trou de test : `railway_deployment_test.rb` ne vérifiait que le texte de la commande, et `seeds_test.rb` chargeait `db/seeds.rb` directement, jamais à travers les tâches Rake.

**Correctif** — `seeds: false` dans la configuration `production` de `config/database.yml` : en production, `db:prepare` ne sème plus, `db:seed` sème seul, une fois par déploiement, base neuve ou non. Commande de pré-déploiement inchangée, donc **aucun réglage Railway à modifier**. Écartés : rendre `db/seeds/identity.rb` idempotent dans un processus (état global, contredit les tests qui rejouent les seeds dans un même processus) ; retirer `db:seed` (plus aucune invitation sur une base déjà initialisée, le défaut du 2026-09-27) ; « n'émettre que si l'invitation a expiré » (un lien perdu dans des logs coupés bloquerait l'accès 72 h, contraire à l'amendement du 2026-09-27).

## D2 — `image_processing` réclamé à chaque démarrage

**Symptôme** — Au démarrage : « Generating image variants require the image_processing gem. Please add `gem "image_processing", "~> 1.2"` to your Gemfile or set `config.active_storage.variant_processor = :disabled` ».

**Reproduction** — N'importe quelle commande `bin/rails` en production (le pré-déploiement ci-dessus l'imprime en première ligne). Test : `test/config/storage_test.rb`, « no environment processes image variants… », rouge avant correctif : `{"processor" => "vips", "transformer" => ""}` au lieu de `disabled` / `NullTransformer`.

**Portée** — Tous les environnements, depuis `load_defaults 8.1` (processeur `:vips` par défaut). Aucun effet fonctionnel : aucune variante n'est jamais demandée. Rien à réparer.

**Root cause** — `load_defaults` choisit `:vips` ; l'initialiseur `active_storage.configs` tente de charger `ActiveStorage::Transformers::Vips`, qui requiert `image_processing`, absent du `Gemfile` : `LoadError` rattrapé et changé en avertissement.

**Décision : désactiver, pas ajouter la gem.** L'application n'utilise aucune variante : `has_one_attached :photo` (`Orm::User`) et `:source` (`Orm::ImportReport`) seulement ; aucun appel à `variant`, `preview`, `representation`, `variable?` ni `representable?` dans `app/` ; les couvertures de cours n'existent pas dans ce dépôt ; l'éditeur de texte riche refuse les pièces jointes. L'ADR-0060 a écarté les variantes (option A : libvips absent, construction Docker déjà cassée par `ruby-vips`, envoi lourd sur réseau lent) : la photo est recadrée par le navigateur, vérifiée et servie telle quelle, son blob créé `analyzed: true`. Ajouter la gem et libvips alourdirait l'image pour rien et rouvrirait un risque de construction. `config.active_storage.variant_processor = :disabled` dans `config/application.rb`, donc pour tous les environnements (cohérent : aucun ne génère de variante). Un test-garde vérifie qu'aucun code de `app/` ne demande de variante ; une fonctionnalité qui en voudrait rouvre la question par un ADR. `Dockerfile` inchangé.

## Hors périmètre

- Le `db:prepare` de `bin/docker-entrypoint` (au démarrage du serveur) : redondant avec le pré-déploiement, mais inoffensif, et il ne sème plus en production.
- Les analyseurs Active Storage (`ImageAnalyzer::Vips` des valeurs par défaut) : non sollicités, la photo naît analysée et les imports sont des fichiers texte.

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits
- [x] Bugs reproduits à la main (production locale, base vide) avant le correctif
- [x] Root cause : fichier, chaîne d'appels, trou de test
- [x] Tests de reproduction écrits avant les correctifs, rouges pour la bonne raison (D1 : `Expected: 1, Actual: 2` ; D2 : `processor` `vips`, transformateur absent)
- [x] Correctif dans la couche de la cause (configuration : `config/database.yml`, `config/application.rb`)
- [x] Cas symétrique : second déploiement sur base initialisée → un lien, différent du premier ; `db:prepare` sème toujours une base neuve en développement et en test ; `test/db/seeds_test.rb` vert
- [x] Reproduction rejouée à la main après correctif : un lien, une ligne `invitations` ouverte ; plus d'avertissement `image_processing`
- [x] Données corrompues : aucune
- [x] Commits `fix(deploy): …` avec `Chantier:`
- [x] `journal.md` rempli
