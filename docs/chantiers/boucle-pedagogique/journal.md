# Journal — Boucle pédagogique (V1)

> Rempli **pendant** le chantier, pas reconstitué à la fin. L'orchestrateur y reporte ce que chaque lot signale.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-25 | Le Lot 0 dessine **toutes** les routes V1, écrit tous les repositories et les fabriques complètes, au lieu de fichiers de routes vides | Plusieurs lots par contexte : des fichiers partagés les auraient mis en collision. Le shell 0c exige déjà les noms de route. | Non (organisation du chantier) |
| 2026-09-25 | Stimulus chargé par motif (`esbuild-rails`) | Supprime le manifeste `index.js` partagé | À porter dans l'ADR-0051 |
| 2026-09-25 | `ReadClassroom` et `IssuePinRecoveryCode` remontés au Lot 0 | Utilisés par plusieurs lots verticaux | Non |

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- Le `ui_subject_badge(name)` du Lot 0c (état au 2026-09-25) déduit la couleur du nom de la matière, soit le défaut CA-26. Signalé à team-lead. Le Lot 0 fournit un helper par catégorie.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
