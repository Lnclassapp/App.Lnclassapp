# Journal — reserves-revue-train

## 2026-11-15

- Point 1 fait en premier (consigne de l'issue). Le fichier de concurrence rejoué 30 fois de suite : 30 / 30 verts (il échouait 10 fois sur 100 avant #638).
- Point 2 : l'issue propose des arguments positionnels de `sh -c` ; or la commande a deux listes (tests et fichiers touchés), que `sh` ne sait pas séparer sans tableau. Un petit script Ruby, `script/ci/unit_coverage`, reçoit les deux listes autour d'un `--` et n'appelle aucun shell. `script/ci/coverage_touched` exige désormais le `--`.
- La variable `COVERAGE_TOUCHED` disparaît de l'environnement de l'étape.

## À trancher

- Rien de bloquant. Note pour la décision « bloquer ou avertir » de [`couverture-branches-visible`](../couverture-branches-visible/journal.md) : le `|| true` n'existe plus ; pour bloquer, `script/ci/unit_coverage` devra sortir en échec quand `coverage_touched` signale un écart.
