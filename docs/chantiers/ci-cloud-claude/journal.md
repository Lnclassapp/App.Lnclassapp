# Journal — La CI rejouée dans le cloud Claude

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-05 | Pas de runner GitHub dans le cloud Claude | Actions de la CI bloquées par le proxy de la session (403), jeton d'inscription impossible à obtenir depuis la session, session neuve à chaque déclenchement | Non : confirme l'ADR-0069 (runner auto-hébergé abandonné) |
| 2026-10-05 | La routine joue `bin/ci` et commente la PR | Pendant la coupure (ADR-0069, amendement du 2026-10-04), la preuve d'une PR est `bin/ci` joué et écrit dans la PR | Non |
| 2026-10-05 | Le hook se lance à la main depuis la routine | La branche par défaut est `main` : une session de routine ne porte le hook qu'une fois `Develop` promue. La routine passe sur `Develop` et lance le hook elle-même | Non |
| 2026-10-05 | PostgreSQL 16 du conteneur, pas de conteneur Docker 17 | Le workflow GitHub utilise aussi le PostgreSQL de l'image (ADR-0069 §9) ; seul `db/schema.rb` diffère, et il est remis | Non |

## Mesure

| Métrique | Contexte | Valeur | Comment mesurée |
|---|---|---|---|
| Premier passage du hook | Conteneur neuf, 4 cœurs, 15 Go | 7 min 58 s (Ruby 3.4.9 compilé) | `time` sur le hook |
| Passage suivant du hook | Même conteneur | 11 s | `time` sur le hook |
| `script/ci/cloud-check 177` | Fusion de la PR #177 dans `Develop` (462cb6fc) | **14 min 41 s, vert** : unitaires 2 min 42 (100 %), système 9 min 02, perf d'import 1 min 26 | sortie de `bin/ci` |

## Ce qui a dérapé

- Premier essai sur la PR #173 : trois gardes rouges (aucune locale dans la session : Ruby lisait les sources en US-ASCII ; `origin/Develop` vieux de plusieurs heures pour la garde du budget système), `db/schema.rb` réécrit par PostgreSQL 16 qui empêchait de revenir sur la branche, deux tests système rouges sous la charge de la suite complète (`teams/import_flow_test.rb:78`, `teams/blog_management_test.rb:47`), verts quand on les rejoue seuls. Les trois premiers points sont corrigés ; les deux tests sont instables sous charge, à suivre.

## Ce qu'on a appris sur la codebase

- Une session cloud neuve n'a ni `LANG` ni la bonne version de Ruby ou de Node, et son chromedriver (147) ne correspond pas au Chromium installé (141) : le hook les règle tous.
- Le runner GitHub démarre dans la session une fois `no_proxy` réduit à la boucle locale (la liste complète du proxy fait planter son analyseur), mais ne peut télécharger aucune action.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Deux tests système instables sous charge | Hors périmètre : le chantier n'a pas touché aux tests | [`tests-instables`](../tests-instables/) |
| Publier aussi la preuve d'arbre (`script/ci/prove`) depuis la routine | Décision du porteur (ADR-0069 §8) | — |
