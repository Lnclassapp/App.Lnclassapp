# Journal — Rejouer seulement ce qu'un changement peut casser

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-27 | Entrées d'une étape = l'arbre **moins** ce qu'elle ne lit pas, jamais une liste de ce qu'elle lit (sauf audits et perf) | Un dossier nouveau compte par défaut : fail-safe | ADR-0111 |
| 2026-10-27 | Les tests Rails ne dépendent pas du front, sauf 61 fichiers rejoués seuls quand le front bouge (161 au premier jet : « rebuilds » et `node.css(…)` de Nokogiri comptaient) | `grep` : jetons de design, bundle, sprites, CSS compilé lisent `app/assets` et `app/javascript` | idem |
| 2026-10-27 | La perf teste `GITHUB_ACTIONS`, plus `CI` | `bin/ci` pose `CI=true` (`ActiveSupport::ContinuousIntegration.run`) : en local, la perf ne se sautait jamais | idem |
| 2026-10-27 | Le train de `bin/ci-quiet` pose `CI=true` sur ses étapes | `config/environments/test.rb` : `eager_load = ENV["CI"].present?`, dont dépend la couverture de toute l'application | idem |
| 2026-10-27 | La clé des lecteurs du front = tout sauf `test/system` et `test/performance` | Sur l'arbre entier, une ligne d'un test de perf rejouait ces 61 fichiers (84 s de S3) | idem |
| 2026-10-27 | Fichiers non commités : aucun verdict d'étape n'est lu, tout joue ; aucun n'est écrit si l'arbre a bougé pendant le run ou si le Setup est rouge | Revue `silent-failure-hunter` et `security-reviewer` : les clés sont celles de HEAD, une modification non commitée passait au vert sans jouer | idem |
| 2026-10-27 | Les audits de dépendances gardent leur verdict un jour ; la garde d'index des décisions porte `docs/decisions` dans sa clé | Revues : la base d'avis bouge sans le code ; l'empreinte écarte le Markdown que l'index lit | idem |
| 2026-10-27 | CA-C6 garde le délai de production (1 s) | Il prouve qu'un minuteur **encore en attente** ne repasse pas par-dessus l'étape 2 rouverte : à 100 ms, le minuteur part avant la réponse et le test ne prouve plus rien (message de la session d'orchestration) | non |

## Ce qui a dérapé

- `/usr/bin/time` n'existe pas sur la machine cloud : la première mesure parallèle n'a rien mesuré. Chronométrer en bash (`date +%s`).
- La mesure avant n° 1 a tourné sur `9ecaa07` ; #316 est arrivée sur `Develop` pendant le chantier. Les mesures n° 2 et n° 3, et toutes les mesures après, sont sur `16cbd82` et au-dessus.
- Trois tests instables vus pendant les mesures, hors chantier : `test/integration/assessment/question_matching_test.rb` (un identifiant cherché comme nombre dans la page), `test/system/teams/blog_management_test.rb` (une fois sur trois) et `test/system/catalog/essential_images_test.rb` (« l'image est servie », une fois sur huit trains).
- Leviers abandonnés : les étapes en parallèle en local (point 3 : −3 à −6 % une fois la perf sautée, machine saturée) et le découpage des fichiers système (point 5 : les parts GitHub sont déjà équilibrées à 1,4 s près, Rails répartit test par test en local). Mesures et raisons dans `memo.md`.

## Ce qu'on a appris sur la codebase

- `ActiveSupport::ContinuousIntegration.run` pose `ENV["CI"] = "true"` : toute condition `${CI:-}` d'une étape de `config/ci.rb` est vraie en local aussi. La condition « perf sautée en local » (ADR-0039, ADR-0069 §9) n'a jamais fonctionné sous `bin/ci`.
- La parallélisation de Rails répartit les tests **un par un** (file DRb de `ActiveSupport::Testing::Parallelization`), pas fichier par fichier : découper un fichier système ne change rien en local.
- `test/system/boucle_pedagogique_test.rb` est un seul test de 38 à 63 s selon les passages : c'est la queue de la suite système.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `question_matching_test` instable | Hors périmètre | à ouvrir (`/bugfix`) |
| La sélection des étapes de `bin/ci-quiet` (clés back/front, fichiers en attente, enregistrement) n'a pas de test unitaire, seulement les bancs S1 à S3 | L'extraire en fonctions pures de `CiScope` dépasse ce chantier (revue `pr-test-analyzer`) | à ouvrir (`/refactor`) |
| Variance de `boucle_pedagogique_test` (38 à 63 s) | Hors périmètre : accélérer un test n'est pas ce chantier | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-27 |
| **PR** | `perf/ci-rejeu-cible` vers `Develop` |
| **ADR produits** | ADR-0111 |
| **UDR produits** | — |
