# ADR-0034 : Aucune reprise de l'ancienne base ; la taxonomie est créée par l'équipe dès la V1, les seeds ne servent qu'en développement et en test

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-12**, bloque la V1, la V2 et la V4 |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ancienne application n'a jamais été mise en ligne pour de vrais élèves. Ses données sont des comptes de test, des comptes démo (retirés du plan le 2026-09-22) et des contenus importés à la main. Elle crée la taxonomie à la volée à chaque import : « Physique Chimie » et « Physique-Chimie » y sont deux matières distinctes. La `category` d'une matière est laissée à `NULL`, alors que la couleur de la matière en dépend (CA-22, CA-26). Le nouveau projet a besoin, dès la V1, d'une taxonomie fiable sur laquelle s'appuient les classes et le contenu.

## 2. Moteurs de décision

1. Rien d'incertain n'entre dans la nouvelle base.
2. La taxonomie de production est la responsabilité de l'équipe pédagogique, pas d'un fichier de code.
3. Les environnements de développement et de test démarrent pleins, en une commande.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Migrer l'ancienne base | Rien à ressaisir | Importe les doublons, les comptes démo et des mots de passe faibles |
| B — Taxonomie seedée en production | Reproductible | Toute correction demande une PR ; l'équipe ne possède pas son référentiel |
| C — **Taxonomie créée par l'équipe dans l'interface dès la V1, seeds hors production** | L'équipe corrige sans développeur ; aucune donnée de code en production | Un écran de plus en V1 |

Option C retenue par le porteur le 2026-09-25.

## 4. Décision

> **Nous ne reprenons aucune donnée de l'ancienne base. L'équipe crée les niveaux, les séries, leurs associations et les matières par l'interface dès la V1. Les seeds ne servent qu'en développement et en test, sauf pour les DRENA.**

**Préalable** : le porteur confirme qu'aucune donnée utilisateur réelle n'existe dans l'ancienne base (journal du 2026-09-25).

**Taxonomie par l'équipe, en V1** (contexte `catalog`). Policy : `Catalog::ManageTaxonomyPolicy`, soit `team`, puis les sous-rôles `admin` et `content` à partir de la V4 (ADR-0038).

| Use cases | Règles |
|---|---|
| `Catalog::CreateLevel`, `UpdateLevel`, `DeleteLevel` | `name` unique, `position` (ordre d'affichage), `cycle` (`CHECK IN ('first','second')`) |
| `Catalog::CreateSeries`, `UpdateSeries`, `DeleteSeries` | `name` unique |
| `Catalog::LinkLevelSeries`, `UnlinkLevelSeries` | couple unique ; une série n'est acceptée sur une classe ou un cours que si le couple existe |
| `Catalog::CreateMaterial`, `UpdateMaterial`, `DeleteMaterial` | `name` et `shortname` (≤ 10) uniques ; `category` **obligatoire**, `CHECK IN ('literature','science','other')`, car elle porte l'icône et la couleur (CA-26) |

- Le slug est dérivé du nom, puis figé (ADR-0029).
- Une suppression est refusée par `:conflict` tant qu'une ligne référence l'élément (ADR-0036).
- Journal : `taxonomy.changed`.

**Seeds** : un fichier par contexte (`db/seeds/<contexte>.rb`), tous chargés par `db/seeds.rb`.

| Fichier | Environnements | Contenu |
|---|---|---|
| `db/seeds/school.rb` | **tous**, production comprise | les DRENA, depuis `db/seeds/data/drenas.yml` ; idempotent par slug |
| `db/seeds/identity.rb` | tous | la première invitation `team` pour `ENV["TEAM_BOOTSTRAP_CONTACT"]`, si aucun compte `team` n'existe (ADR-0038) ; aucun compte avec un PIN connu |
| `db/seeds/catalog.rb` | développement et test | niveaux : `6ème`, `5ème`, `4ème`, `3ème` (cycle `first`), `2nde`, `1ère`, `Tle` (cycle `second`) ; séries : `A1`, `A2`, `C`, `D`, rattachées à `1ère` et à `Tle` ; matières : Mathématiques, Physique-Chimie, SVT (`science`), Français, Anglais, Histoire-Géographie, Philosophie (`literature`) |
| `db/seeds/development.rb` | développement | comptes, écoles, classes et contenus fictifs |

Garde : un fichier réservé au développement ou au test lève une erreur s'il est évalué ailleurs.

**Par vague** :

| Vague | Données | Moyen |
|---|---|---|
| V1 | niveaux, séries, `level_series`, matières | écrans de l'équipe |
| V1 | DRENA | seed, en lecture seule |
| V2 | DRENA en écriture, écoles, import JSON d'écoles | écrans de l'équipe ; rapport dans `import_reports` (`kind: 'schools'`, ADR-0039) |
| V4 | cours, fiches et exercices en masse | import du format arbre (ADR-0039) |

## 5. Conséquences

### 🟢 Positives

- L'équipe possède et corrige sa taxonomie sans développeur.
- Aucun doublon de taxonomie ni compte démo ne passe dans le nouveau projet.
- La catégorie des matières est toujours renseignée : la couleur n'est plus déduite du nom.

### 🔴 Coûts consentis

- La V1 gagne les écrans de gestion de la taxonomie (CA-18, CA-19, CA-20, CA-22, CA-24, CA-25).
- Une production vierge est inutilisable tant que l'équipe n'a pas saisi la taxonomie. C'est une étape de mise en service, inscrite au runbook.
- La liste des DRENA (`drenas.yml`) doit être fournie avant la première mise en production.
- Tout le contenu de l'ancien est réimporté en V4.

## 6. Notes d'implémentation

```ruby
# db/seeds.rb
SEEDS = { "school" => :all, "identity" => :all, "catalog" => %w[development test], "development" => %w[development] }.freeze

SEEDS.each do |name, envs|
  next unless envs == :all || envs.include?(Rails.env)

  load Rails.root.join("db/seeds/#{name}.rb")
end
```

```ruby
# db/seeds/catalog.rb — première ligne
raise "db/seeds/catalog.rb est réservé au développement et au test" unless Rails.env.local?
```

## 7. Comment vérifier que la décision est respectée

- `test/db/seeds_test.rb` : deux exécutions de `db:seed` donnent les mêmes nombres de lignes. Évaluer `catalog.rb` ou `development.rb` avec `RAILS_ENV=production` lève une erreur.
- Tests de policy : `ManageTaxonomyPolicy` refuse `teacher`, `student` et `school_admin`.
- Test de use case : une matière sans `category` donne `:invalid` ; supprimer un niveau qui a des classes donne `:conflict`.

## 8. Remplace, complète, amende

- Ne remplace aucun ADR. Il fixe l'origine des données que l'ADR-0022 modélisait sans en dire la provenance.

## 9. Arbitrage du porteur (2026-09-25)

- La taxonomie est créée par l'équipe via l'interface et n'est pas seedée en production. Cela remplace la proposition initiale d'un référentiel seedé en production.
- Les DRENA restent seedées : le porteur ne les a pas citées, la recommandation est maintenue.
- Le niveau s'écrit `2nde`.
