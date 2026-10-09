# Guide Opérationnel Lnclass

Lnclass est une plateforme éducative (LMS) en Rails 8, construite en **architecture hexagonale (DDD)** pour isoler le métier des détails techniques.

> 📖 **La documentation fait autorité : [`docs/README.md`](docs/README.md).**
> Ce fichier n'en est que le raccourci. En cas de contradiction, `docs/` gagne.

---

## Communication avec le porteur

**Réponses courtes.** Pendant le travail, ne montrer que l'essentiel : le résultat, ce qui bloque, ce que le porteur doit décider. Pas de récit des étapes ni des détails techniques, sauf s'il les demande.

**PR prêtes.** Une PR sans conflit avec sa base s'ouvre directement « prête », jamais en brouillon.

**Captures d'écran.** Tout travail d'interface (UI/UX) se montre au porteur en images : chaque écran modifié à 390 px (téléphone) et sur ordinateur, menus ouverts si besoin. Les captures sont envoyées, jamais commitées.

---

## Sobriété de tokens

Chiffres et preuves : [`docs/chantiers/sobriete-tokens/memo.md`](docs/chantiers/sobriete-tokens/memo.md).

- **Une session par chantier**, 40 commits au maximum : au-delà, on ouvre une nouvelle session.
- **Un commit par lot**, documentation du lot comprise. Pas de commit qui ne touche que `docs/` en cours de lot.
- **Index** ADR / UDR : générés par `script/docs/build_index` au commit de clôture, jamais édités à la main. Index des chantiers : modifié une seule fois, à la clôture.
- **Pas de fusion sans preuve** : la CI GitHub est coupée (`CI_ENABLED` absente, ADR-0069), donc le `bin/ci` local est écrit dans la PR avant la fusion.
- **`bin/ci-quiet`** à la place de `bin/ci` pour les sessions d’agent : verdict, étapes en échec et 30 dernières lignes ; le journal complet est dans `tmp/ci.log`.
- **Sous-agents de revue** (`security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`) : une fois par PR, sur le diff final, et seulement au-delà de 150 lignes ou si un use case, une policy, une route ou un téléversement est touché.
- **Menace écrite d'abord** pour tout code qui lit un fichier envoyé par un utilisateur (image, import) : 6 corrections JPEG successives en ont montré le coût.
- **Charger à la demande** : `docs/guide/architecture.md` et `glossaire.md` seulement si la tâche l'exige.

---

## Avant de coder

**Tout travail suit [`docs/workflows/README.md`](docs/workflows/README.md)** — c'est le seul processus valide, en 5 phases : Cadrer → Décider → Planifier → Exécuter → Prouver.

Le travail vit dans [`docs/chantiers/<slug>/`](docs/chantiers/). Un chantier sans dossier n'existe pas.

```
/feature <slug>    /bugfix <slug>    /refactor <slug>    /optimize <slug>
```

---

## Stack

- **Backend** : Rails 8.1+ · Ruby 3.4+ · PostgreSQL
- **Frontend** : Tailwind v4 (CSS-first, bloc `@theme`) · Hotwire (Turbo/Stimulus)
- **Assets** : Propshaft + jsbundling (esbuild) + cssbundling
- **Tests** : Minitest

## Commandes

| Commande | Rôle |
|---|---|
| `bin/setup` | Setup complet de l'environnement (idempotent) |
| `bin/dev` | Serveur de développement (Rails + watch assets) |
| `bin/rails test` | Lance les tests |
| `bin/ci` | Pipeline complet en local, comme la CI |
| `bin/rubocop` | Vérifie le style Ruby (`-A` pour corriger) |
| `bin/brakeman` | Analyse de sécurité |
| `yarn build` / `yarn build:css` | Compile JS / CSS |

---

## Architecture

| Couche | Emplacement | Rôle |
|---|---|---|
| **Domaine** | `app/domain/` | Cœur métier en **Ruby pur** : `entities/`, `use_cases/`, `ports/`, `dtos/`, `policies/` |
| **Infrastructure** | `app/infrastructure/` | `repositories/` (adaptateurs des ports), `orm/` (ActiveRecord), `queries/` (lecture, CQRS) |
| **Delivery** | `app/controllers/` | Transforme les params, appelle le use case, décide du rendu. Zéro logique métier. |
| **UI** | `app/views/`, `app/javascript/` | Vues ERB, Turbo Streams, contrôleurs Stimulus |

**Contextes bornés** : `assessment`, `catalog`, `classroom`, `communication`, `identity`, `school`.

Patterns de code par couche : [`docs/blueprints/`](docs/blueprints/)

## Les règles d'or

1. **Zéro couplage** — le domaine n'importe jamais `ActiveRecord`, `ApplicationRecord` ni `Orm::`. Ce n'est pas une consigne : le pre-commit et la CI refusent le commit.
2. **Tout est namespacé par contexte borné.** Un fichier à la racine de `entities/` ou `repositories/` est du legacy à migrer.
3. **I18n** — locale par défaut `:fr`, toujours `t(".key")`. Code en anglais, interface en français.
4. **En-tête HITL** — 3 lignes en tête de chaque fichier de `app/`. Format dans [`docs/guide/conventions.md`](docs/guide/conventions.md#5-en-tête-hitl).

Conventions complètes (nommage, branches, commits, format des lots) : [`docs/guide/conventions.md`](docs/guide/conventions.md)

---

## Index documentation

| Besoin | Où aller |
|---|---|
| Comprendre l'architecture | [`docs/guide/architecture.md`](docs/guide/architecture.md) |
| Arriver dans l'équipe | [`docs/guide/onboarding.md`](docs/guide/onboarding.md) |
| Connaître le vocabulaire métier | [`docs/guide/glossaire.md`](docs/guide/glossaire.md) |
| Suivre un cycle de travail | [`docs/workflows/README.md`](docs/workflows/README.md) |
| Retrouver une décision technique | [`docs/decisions/adr/`](docs/decisions/adr/) |
| Retrouver une décision d'interface | [`docs/decisions/udr/`](docs/decisions/udr/) |
| Écrire un fichier d'une couche donnée | [`docs/blueprints/`](docs/blueprints/) |

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
