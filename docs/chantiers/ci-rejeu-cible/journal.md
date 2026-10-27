# Journal — Rejouer seulement ce qu'un changement peut casser

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-27 | Entrées d'une étape = l'arbre **moins** ce qu'elle ne lit pas, jamais une liste de ce qu'elle lit (sauf audits et perf) | Un dossier nouveau compte par défaut : fail-safe | ADR-XXXX-verdict-par-etape-de-la-ci |
| 2026-10-27 | Les tests Rails ne dépendent pas du front, sauf 67 fichiers rejoués seuls quand le front bouge | `grep` : jetons de design, bundle, sprites, CSS compilé lisent `app/assets` et `app/javascript` | idem |
| 2026-10-27 | La perf teste `GITHUB_ACTIONS`, plus `CI` | `bin/ci` pose `CI=true` (`ActiveSupport::ContinuousIntegration.run`) : en local, la perf ne se sautait jamais | idem |
| 2026-10-27 | Le train de `bin/ci-quiet` pose `CI=true` sur ses étapes | `config/environments/test.rb` : `eager_load = ENV["CI"].present?`, dont dépend la couverture de toute l'application | idem |
| 2026-10-27 | CA-C6 garde le délai de production (1 s) | Il prouve qu'un minuteur **encore en attente** ne repasse pas par-dessus l'étape 2 rouverte : à 100 ms, le minuteur part avant la réponse et le test ne prouve plus rien (message de la session d'orchestration) | non |

## Ce qui a dérapé

- `/usr/bin/time` n'existe pas sur la machine cloud : la première mesure parallèle n'a rien mesuré. Chronométrer en bash (`date +%s`).
- La mesure avant n° 1 a tourné sur `9ecaa07` ; #316 est arrivée sur `Develop` pendant le chantier. Les mesures n° 2 et n° 3, et toutes les mesures après, sont sur `16cbd82` et au-dessus.
- Deux tests instables vus pendant la mesure, hors chantier : `test/integration/assessment/question_matching_test.rb` (un identifiant cherché comme nombre dans la page) et `test/system/teams/blog_management_test.rb` (une fois sur trois).

## Ce qu'on a appris sur la codebase

- `ActiveSupport::ContinuousIntegration.run` pose `ENV["CI"] = "true"` : toute condition `${CI:-}` d'une étape de `config/ci.rb` est vraie en local aussi. La condition « perf sautée en local » (ADR-0039, ADR-0069 §9) n'a jamais fonctionné sous `bin/ci`.
- La parallélisation de Rails répartit les tests **un par un** (file DRb de `ActiveSupport::Testing::Parallelization`), pas fichier par fichier : découper un fichier système ne change rien en local.
- `test/system/boucle_pedagogique_test.rb` est un seul test de 38 à 63 s selon les passages : c'est la queue de la suite système.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `question_matching_test` instable | Hors périmètre | à ouvrir (`/bugfix`) |
| Variance de `boucle_pedagogique_test` (38 à 63 s) | Hors périmètre : accélérer un test n'est pas ce chantier | — |

## Clôture

| | |
|---|---|
| **Livré le** | |
| **PR** | |
| **ADR produits** | ADR-XXXX-verdict-par-etape-de-la-ci |
| **UDR produits** | — |
