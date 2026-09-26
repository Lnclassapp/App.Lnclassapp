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
| 2026-09-25 | ~~`courses.content` et `essentials.content` en `text` ; éditeur riche reporté~~ → **remplacée** : éditeur riche en V1 (Action Text + Trix, `has_rich_text :content`), voir « Retour du porteur » ci-dessous | Action Text retiré en V0 ; le porteur le réintroduit en V1 | Amendement de l'ADR-0051 |
| 2026-09-25 | ~~L'élève ne voit pas le code de sa classe~~ → **remplacée** : l'élève voit le code de sa classe principale, jamais la liste nominative | Retour du porteur | Amendement de l'ADR-0028 |
| 2026-09-25 | ~~L'enseignant ne voit jamais les bonnes réponses en V1~~ → **tranchée : visible pour l'enseignant** (et pour l'équipe). L'élève ne les voit jamais pendant sa session | Retour du porteur | Amendements des ADR-0028 et ADR-0054 |
| 2026-09-25 | Classes générées : table de l'ancien code (ADR-0030), le mixte suit le privé. 77 pour un lycée public avec le référentiel de l'ADR-0034 (2nde en A et C) ; les 71 de l'ancienne application venaient d'une 2nde liée à C seule | Réponse du porteur ; le total dépend de `level_series` | ADR-0030 |
| 2026-09-25 | `users.gender` obligatoire (`male`, `female`) ; limites d'import de l'ADR-0039 acceptées | Réponses du porteur | ADR-0037, ADR-0039 |
| 2026-09-25 | Vague 3 découpée en quatre sous-vagues de 8 lots au plus (3a à 3d), chemin critique d'abord | Demande de team-lead : limiter les agents et la file de merge | Non (organisation du chantier) |
| 2026-09-25 | `friendly_id` retiré (0a) : slugs figés par `Orm::HasFrozenSlug`, table `friendly_id_slugs` supprimée | Gem inutilisée, slugs figés à la création | Précision de l'ADR-0029 |
| 2026-09-26 | La suite du chantier passe sur Claude Code on the web : un lot par session, PR vers `feature/boucle-pedagogique` ; état, brief et questions dans [`reprise/`](reprise/README.md) | Demande du porteur, pour aller plus vite | Non (organisation du chantier) |
| 2026-09-26 | Nonce CSP stable par session (gardé dans la session) et rechargement complet de la page d'arrivée après une connexion, une inscription ou une déconnexion ; les erreurs 422 restent sans rechargement | Trix perdait ses styles après une navigation Turbo (reprise §3) ; validé par le porteur | Amendement de l'ADR-0049 |

## Retour du porteur du 2026-09-25

Décisions consignées dans la branche `docs/retour-porteur-v1`.

1. **Protection des branches GitHub abandonnée.** Le dépôt est privé, en offre gratuite : l'API de protection répond HTTP 403. Le hook pre-commit local et la discipline des PR protègent à la place. Seul le porteur fait le passage `Develop` → `main`. Consigné dans le journal d'`amorcage-depot` (garde-fou 5, écart assumé), la boucle de travail et la feuille de route.
2. **Éditeur riche en V1.** Action Text + Trix pour le contenu des cours et des fiches essentielles (`has_rich_text :content` ; plus de colonne `content` en `text`). Trix et `@rails/actiontext` sont chargés par import dynamique (contrôleur Stimulus `rich_text_editor`), seulement sur les pages d'édition, hors du bundle commun de 60 Ko ; `trix.css` est une feuille à part. Les lots B2 et B4 utilisent l'éditeur ; les imports I1 et I2 écrivent du HTML assaini, et un test le vérifie. **Impact sur le lot 0a en cours** : `require "action_text/engine"`, migration `20260925100032_create_action_text_tables.rb` (32 migrations), `has_rich_text` sur `Orm::Course` et `Orm::Essential`, `trix` et `@rails/actiontext` dans `package.json`, point d'entrée `trix.css` dans `esbuild.config.mjs`, test de schéma. Amendement ajouté à l'ADR-0051.
3. **L'enseignant voit les bonnes réponses**, l'équipe aussi. L'élève ne les voit pas pendant sa session. **Impact sur le lot 0b en cours** : `Assessment::RevealAnswersPolicy`. Lots C1, C3 et E mis à jour. Amendements ajoutés aux ADR-0028 et ADR-0054.
4. **L'élève voit le code de sa classe** (sa classe principale, en majuscules), jamais la liste nominative. Le critère et le test contraires du lot A3 sont retirés ; A2 et A3 affichent `join_code_display`.
5. **Pas de formulaire de création d'établissement ; génération des classes à l'import seulement.** Les établissements arrivent uniquement par l'import JSON (S3), qui génère leurs classes. Jamais de classes pré-créées. Totaux : lycée public 77, lycée privé ou mixte 38, collège public 28. Le lot S2 perd `new`, `create`, `School::CreateSchool`, leur vue et leurs tests ; il garde la liste nationale, la fiche, la modification, la désactivation et la suppression ; « Importer des établissements » devient l'action principale de l'écran. Les tests de totaux passent dans l'import (S3). **Impact sur le lot 0a en cours** : `resources :schools` avec `except: %i[new create]`. Amendement ajouté à l'ADR-0030 ; plan (point 5 du socle, routes, S2, S3, collisions, traçabilité) et PRD (SC-03, SC-08, SC-09) mis à jour.
6. **Points approuvés** : UDR-0005 (design system) et UDR-0006 (shell par rôle, toasts, CRUD Hotwire) passent au statut **Accepté** ; F-09 (thème sombre écarté en V1) et F-31 (shell unique par rôle) sont approuvés (feuille de route, `features-refonte.md`, inventaires) ; la gem `rails-i18n` est ajoutée pour des messages de validation en français (déjà dans le `Gemfile`, prouvée par un test du lot 0a).
7. **Le genre reste obligatoire** (`male`, `female`), comme l'ADR-0037 le prévoit.

8. **Éditeur de texte uniquement** : aucune pièce jointe dans Trix en V1. Le contrôleur `rich_text_editor` annule `trix-file-accept`, et aucun `direct_upload` n'est branché (ADR-0047, ADR-0049). D'abord arbitré par l'orchestrateur, puis confirmé par le porteur : ce n'est plus un point « à rouvrir ». Précisé dans l'amendement de l'ADR-0051.

9. **Portée des réponses visibles par l'enseignant** : tout exercice qu'il peut lire, y compris avant de l'assigner, pour préparer sa classe. **Décision de l'orchestrateur, que le porteur peut rouvrir.** Le PRD cadre (« classe assignée ») est aligné, avec une entrée datée dans le journal du programme.

Aucune question ne reste ouverte pour le porteur.

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- Le `ui_subject_badge(name)` du Lot 0c (état au 2026-09-25) déduit la couleur du nom de la matière, soit le défaut CA-26. Signalé à team-lead. Le Lot 0e fournit `ui_subject_badge(label, category:)`.

## Amendements écrits dans la branche du plan (2026-09-25)

- **ADR-0027** (erratum) : `TransactionPort` vit dans `app/domain/ports/shared/` (`Ports::Shared::TransactionPort`, ADR-0026).
- **UDR-0006** : l'entrée « Établissements » (`schools_path`) de la navigation équipe est active dès la V1.
- **ADR-0028** : policies ajoutées (`DeclareTeachingPolicy`, `IssuePinRecoveryCodePolicy`, `ResetSecondFactorPolicy`, `RegisterTeacherPolicy`, `ReadClassroomPolicy`, `SubmitAttemptPolicy`, `Identity::SessionPolicy`, `Identity::SecondFactorPolicy`) ; les exemptions restent les trois de l'ADR.
- **ADR-0039** (erratum et précisions) : la colonne `errors` s'appelle `import_errors`, `errors` étant réservé par `ActiveModel` ; un test de performance par type ; jobs dérivés de `Shared::ImportJob`, associés par `config.x.import_jobs`.
- **ADR-0034** : aucun seed de DRENA, d'établissement ni de référentiel en production ; le slug figé tient lieu de code pour les niveaux et les séries.
- Chaque amendement est une section « Amendement du 2026-09-25 » en bas du fichier, sans réécriture du texte accepté.
- L'amendement de l'ADR-0039 décrit `import_reports` telle que 0a l'implémente : colonnes `scope`, `filename` et `byte_size` en plus, sans la contrainte sur `total_count` du plan (0a.2).

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
