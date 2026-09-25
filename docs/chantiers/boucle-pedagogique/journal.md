# Journal — Boucle pédagogique (V1)

> Rempli **pendant** le chantier, pas reconstitué à la fin. L'orchestrateur y reporte ce que chaque lot signale.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-25 | Le Lot 0 dessine **toutes** les routes V1, écrit tous les repositories et les fabriques complètes, au lieu de fichiers de routes vides | Plusieurs lots par contexte : des fichiers partagés les auraient mis en collision. Le shell 0c exige déjà les noms de route. | Non (organisation du chantier) |
| 2026-09-25 | Stimulus chargé par motif (`esbuild-rails`) | Supprime le manifeste `index.js` partagé | À porter dans l'ADR-0051 |
| 2026-09-25 | `ReadClassroomPolicy` au Lot 0 ; `IssuePinRecoveryCode` dans B8, la page de classe (D4) poste vers sa route | La policy sert plusieurs lots ; le use case n'en sert qu'un | Non |
| 2026-09-25 | ADR-0026 à ADR-0054 et UDR-0007 acceptés ; plan réécrit pour les appliquer | Décision de fondation du porteur | Déjà en ADR |
| 2026-09-25 | Badges à quatre paliers : Bronze ≥ 50, Argent ≥ 70, Or ≥ 80, Diamant = 100 | Choix du porteur | ADR-0033 |
| 2026-09-25 | CRUD du référentiel (niveaux, séries, liaisons, matières) réservé à l'équipe, slugs et codes figés, seeds en local seulement | Choix du porteur | ADR-0034 (amendement requis) |
| 2026-09-25 | `JoinPolicy` accepte le visiteur anonyme | Choix du porteur : c'est le cas nominal de l'adhésion | ADR-0028 |
| 2026-09-25 | V1 élargie : DRENA sans seed de production, établissements avec génération des classes, imports JSON tout ou rien en brouillon | Choix du porteur : la production démarre vide | ADR-0034 et ADR-0039 (amendements requis) |
| 2026-09-25 | Import en masse : `insert_all` par tranches, job Solid Queue à concurrence 1, suivi de progression, rapport persisté, moins de 2 min pour 500 écoles (≈ 35 000 classes) ou 200 cours | Choix du porteur | ADR-0039 (amendement requis) |
| 2026-09-25 | Moteur d'import commun au Lot 0 ; un adaptateur par type d'import, chacun dans son lot avec son test de performance | Paralléliser les imports sur des fichiers disjoints | Non (organisation du chantier) |
| 2026-09-25 | `ui_subject_badge(label, category:)` ; `materials.category` protégée par un CHECK | Plus de couleur déduite du nom (CA-26) | UDR-0005 |
| 2026-09-25 | Noms de routes de navigation gelés : `student_home`, `student_classroom`, `teacher_home`, `teacher_classrooms`, `team_home`, `courses`, `session` | Contrat avec le shell du Lot 0c | Non |
| 2026-09-25 | Le job résout l'importeur par un `case` sur le type, à l'exécution | L'eager load reste vert tant que les lots d'adaptateurs ne sont pas mergés | Non |

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- Le `ui_subject_badge(name)` du Lot 0c (état au 2026-09-25) déduit la couleur du nom de la matière, soit le défaut CA-26. Signalé à team-lead. Le Lot 0 fournit un helper par catégorie.

## Amendements d'ADR requis avant le Lot 0

- **ADR-0034** : aucun seed de DRENA, d'établissement ni de référentiel en production ; écoles, référentiel et imports de contenu en V1 ; colonne `code` figée sur `levels` et `series`.
- **ADR-0039** : cinq types d'import, écriture en masse par `insert_all`, limites par type, colonnes `scope`, `progress` et `import_errors` (au lieu de `errors`, réservé par l'ORM), un import à la fois.
- **ADR-0027** (erratum) : `TransactionPort` dans `app/domain/ports/shared/`, comme l'ADR-0026.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Espace des codes d'adhésion (884 736) consommé tant que les classes archivées gardent leur code | Libération des codes à l'archivage de l'année prévue en V3 | V3 (ADR-0041) |
| `friendly_id` dans le Gemfile, inutilisé | À retirer si rien d'autre ne l'utilise | Lot 0 ou suivi |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
