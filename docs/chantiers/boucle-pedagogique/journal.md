# Journal — Boucle pédagogique (V1)

> Rempli **pendant** le chantier, pas reconstitué à la fin. L'orchestrateur y reporte ce que chaque lot signale.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-25 | Le Lot 0a dessine **toutes** les routes V1, écrit tous les repositories et les fabriques complètes, au lieu de fichiers de routes vides | Plusieurs lots par contexte : des fichiers partagés les auraient mis en collision. Le shell 0c exige déjà les noms de route. | Non (organisation du chantier) |
| 2026-09-25 | Stimulus chargé par motif (`esbuild-rails`) | Supprime le manifeste `index.js` partagé | À porter dans l'ADR-0051 |
| 2026-09-25 | `ReadClassroomPolicy` au Lot 0 ; `IssuePinRecoveryCode` dans B8, la page de classe (D4) poste vers sa route | La policy sert plusieurs lots ; le use case n'en sert qu'un | Non |
| 2026-09-25 | ADR-0026 à ADR-0054 et UDR-0007 acceptés ; plan réécrit pour les appliquer | Décision de fondation du porteur | Déjà en ADR |
| 2026-09-25 | Badges à quatre paliers : Bronze ≥ 50, Argent ≥ 70, Or ≥ 80, Diamant = 100 | Choix du porteur | ADR-0033 |
| 2026-09-25 | CRUD du référentiel (niveaux, séries, liaisons, matières) réservé à l'équipe, slugs figés sans colonne `code`, seeds en local seulement | Choix du porteur | ADR-0034 |
| 2026-09-25 | `JoinPolicy` accepte le visiteur anonyme | Choix du porteur : c'est le cas nominal de l'adhésion | ADR-0028 |
| 2026-09-25 | V1 élargie : DRENA créées à l'écran sans seed de production (SC-02 écartée), établissements importés en JSON avec génération des classes (77, 38, 38, 28), référentiel, imports de contenu en brouillon | Choix du porteur : la production démarre vide | ADR-0030, ADR-0034, ADR-0039 |
| 2026-09-25 | Import **partiel** : valides écrits, invalides listés avec chemin JSON et motif, doublons ignorés et comptés, atomicité par élément racine, rejet en bloc seulement sur enveloppe ou version invalide | Choix du porteur : pas de tout ou rien | ADR-0039 |
| 2026-09-25 | Import en masse : lots de 100 racines rejoués élément par élément en cas d'échec (`TransactionPort#attempt`), job Solid Queue à un import actif par type, suivi toutes les 3 s, rapport persisté, moins de 2 min pour 500 écoles ou 200 cours | Choix du porteur | ADR-0039 |
| 2026-09-25 | Moteur d'import commun au Lot 0e ; un adaptateur par type d'import, chacun dans son lot avec **son** test de performance (`test/performance/<ctx>/import_<kind>_performance_test.rb`) au lieu du fichier unique de l'ADR-0039 | Paralléliser les imports sur des fichiers disjoints | Écart assumé, à noter dans l'ADR-0039 |
| 2026-09-25 | `ui_subject_badge(label, category:)` ; `materials.category` protégée par un CHECK | Plus de couleur déduite du nom (CA-26) | UDR-0005 |
| 2026-09-25 | Noms de routes de navigation gelés : `student_home`, `student_classroom`, `teacher_home`, `teacher_classrooms`, `team_home`, `courses`, `session` | Contrat avec le shell du Lot 0c | Non |
| 2026-09-25 | `Shared::ImportJob` résout l'importeur par `config.x.import_jobs` (nom du job par type, résolu à l'appel) | Un lot d'import n'édite aucun fichier du socle ; l'eager load reste vert tant que les adaptateurs ne sont pas mergés | Non |
| 2026-09-25 | Lot 0 découpé en quatre sous-lots à fichiers disjoints : 0a (schéma, ORM, routes, fabriques) ∥ 0b (domaine pur), puis 0d (authentification, shell) ∥ 0e (repositories, moteur d'import, front partagé ; e4 après 0d) | Le socle d'un seul tenant bloquait tout le parallélisme | Non (organisation du chantier) |
| 2026-09-25 | Tout CRUD passe par Hotwire (modale en frame, 422 dans le frame, `turbo_stream`, repli HTML, Stimulus en dernier recours) ; chaque lot à écran d'écriture livre ses `*.turbo_stream.erb`, un critère « sans rechargement de page » et un test système | Règle du porteur | UDR-0006 |
| 2026-09-25 | Clés Active Record Encryption posées dans les credentials par l'orchestrateur ; clés de test fixes dans `config/environments/test.rb` ; `cache_store :memory_store` en test pour `rate_limit` | La CI n'a pas de clé maître ; `rate_limit` exige un cache réel | Non |
| 2026-09-25 | `courses.content` et `essentials.content` en `text` ; éditeur riche reporté | Action Text retiré en V0 | Non |
| 2026-09-25 | L'élève ne voit pas le code de sa classe | Choix du porteur | Non |
| 2026-09-25 | `friendly_id` retiré (0a) : slugs figés par `Orm::HasFrozenSlug`, table `friendly_id_slugs` supprimée | Gem inutilisée, slugs figés à la création | Précision de l'ADR-0029 |

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- Le `ui_subject_badge(name)` du Lot 0c (état au 2026-09-25) déduit la couleur du nom de la matière, soit le défaut CA-26. Signalé à team-lead. Le Lot 0e fournit `ui_subject_badge(label, category:)`.

## Amendements requis avant le Lot 0a

- **UDR-0006** : l'entrée « Établissements » (`schools_path`) de la navigation équipe est active dès la V1.
- **ADR-0028** : policies ajoutées (`DeclareTeachingPolicy`, `IssuePinRecoveryCodePolicy`, `ResetSecondFactorPolicy`, `RegisterTeacherPolicy`, `ReadClassroomPolicy`, `SubmitAttemptPolicy`, `Identity::SessionPolicy`, `Identity::SecondFactorPolicy`) ; les exemptions restent les trois de l'ADR.
- **ADR-0039** (erratum) : la colonne `errors` s'appelle `import_errors`, `errors` étant réservé par `ActiveModel`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Espace des codes d'adhésion (884 736) consommé tant que les classes archivées gardent leur code | Libération des codes à l'archivage de l'année prévue en V3 | V3 (ADR-0041) |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
