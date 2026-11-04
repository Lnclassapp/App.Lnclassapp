# Journal — La suite unitaire en parts sur GitHub

## Où part le temps (avant)

Run 41911503446 (train #476), tâche `unit unit`, par étape :

| Tentative | Total | `setup` (Ruby, Node) | `Run bin/ci` | Issue |
|---|---|---|---|---|
| 1 | 316 s | 49 s | 253 s | coupée |
| 2 | 317 s | 10 s | 295 s | coupée |

`bin/ci` : installation de la base, `test:prepare` (assets), puis la suite (862 fichiers, 8 127 tests, 4 processus). Les tests eux-mêmes portent le coût ; les autres tâches `unit` (lint…, perf) tiennent en 92 à 100 s, `system` en 163 à 200 s.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-04 | Le groupe `unit` devient un groupe `sharded` (comme `system`), équilibré sur `test_timings.yml` | Un seul mécanisme de découpage ; la garde vérifie déjà « chaque fichier dans une part, une seule » | ADR-0064 §8 |
| 2026-11-04 | Le profil SimpleCov sort de `test_helper.rb` dans `test/coverage_profile.rb` | Le test et la fusion lisent le même réglage et le même seuil | ADR-0064 §8 |
| 2026-11-04 | `coverage_collate` exige exactement 2 résultats | Une part perdue échoue bruyamment au lieu d'être mesurée comme du code non couvert | ADR-0064 §8 |
| 2026-11-04 | Preuve GitHub par une PR temporaire vers `Staging`, fermée après mesure | Le workflow ne tourne qu'aux PR vers `Staging`/`main` et n'a pas de `workflow_dispatch` ; l'ajouter élargirait le chantier | non |

## Ce qui a dérapé

- **`coverage` sans le bundle** : `script/ci/coverage_collate` chargeait SimpleCov hors de Bundler ; en local la gem est installée globalement, pas sur le runner (`cannot load such file -- simplecov`, run 41916186112). Corrigé par `require "bundler/setup"`. Leçon : un script de CI se prouve sur un runner, pas sur un poste où tout est installé.
- **Durées de perf écrasées** : `record_timings` sur un log de la suite unitaire a remis à 0 s les tests de perf (sautés sans `PERF`), ce qui aurait déséquilibré le groupe `perf`. Valeurs restaurées, et ces fichiers ne pèsent rien dans le découpage unitaire (`light:` de `CiPlan#sharded`).
- **Résultat de couverture résiduel en local** : SimpleCov fusionne tout `.resultset.json` de moins de 10 minutes (`merge_timeout`). Un `coverage/` laissé par des parts lancées à la main a fait tomber à tort une suite entière locale à 99,96 %. Sur GitHub chaque tâche part d'un dossier vide ; en local, vider `coverage/` avant de rejouer.
- **Couverture de `Develop` à 99,96 %** pendant le chantier (rencontre de #475 et #477) : corrigée par #479 (autre session), fusionnée dans la branche.

## Ce qu'on a appris sur la codebase

- La règle « jamais découpé » est posée par l'ADR-0064 §4.1, pas par l'ADR-0024 (qui ne pose que le seuil).
- `upload-artifact` ignore les fichiers cachés par défaut : `.resultset.json` exige `include-hidden-files: true`.
- Un nom d'artefact ne peut contenir ni `:` ni `/` : l'index de la tâche de matrice nomme la part.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Troisième mesure des parts | Une seule PR de preuve, deux runs | Prochain train (#476 ou suivant) |
| Parts < 3 min | La mise en place (base, assets) pèse 30 à 40 s par part | `UNIT_PARTS` = 3 si une part dépasse 4 min |
