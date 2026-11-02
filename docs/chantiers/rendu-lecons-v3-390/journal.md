# Journal — Rendu des leçons v3 à 390 px

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-02 | `box_text` passe par `sheet_text` pour « À retenir » et « Notions mobilisées » | Une seule fonction de rendu sûr ; les noms de notions n'ont aucun balisage, rendu inchangé | Non |
| 2026-11-02 | Le validateur applique `structure` aux questions de `practice` et transmet `blank` | Même règle que l'import ; sans `blank`, deux cases portant la même réponse seraient refusées à tort | Non |

## Ce qui a dérapé

- Le premier test de doublon passait au vert : l'exercice était déjà couvert, la faute était dans `practice`. Test réécrit sur `practice`, rouge pour la bonne raison.
- Ma branche locale retardait de 183 commits sur `origin/Develop` : les leçons Tle/1ère n'y étaient pas.
- Pas de pilote Chrome 153 compatible ; mesures et captures faites avec le Chromium de Playwright.

## Ce qui reste ouvert

- Les 516 px d'« Énergie cinétique » 1ère C à reconfirmer à l'écran.
