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
| 2026-09-27 | Une lacune n'est résolue qu'à partir de 75 % (`REMEDIATION_THRESHOLD`) ; entre 50 et 74 %, elle reste « à revoir » sans échec de plus | Décision du porteur (le PRD disait 70 %, l'ADR 50 %) | Amendement de l'ADR-0043 |
| 2026-09-27 | Réussite de la classe (D6) : part des élèves présents dont le meilleur score atteint 50 %, au lieu d'une moyenne de scores | Décision du porteur | UDR-0029 mise à jour |
| 2026-09-27 | Un établissement en brouillon ne reçoit pas de classe créée à la main ; le bouton est masqué et l'envoi direct est refusé en 422 | Décision du porteur | UDR-0031 mise à jour |
| 2026-09-27 | Lien « Voir le résultat » sur le dernier score de chaque élève, dans la page de classe | Décision du porteur (manque relevé par le Lot E) | UDR-0027 mise à jour |
| 2026-09-27 | Un import bloqué passe « Échoué » après 10 min, en file, en validation ou en cours (30 min avant, et jamais pour « en file ») | Décision du porteur (risque relevé par le Lot E) | Amendement de l'ADR-0039 |
| 2026-09-27 | Libellé de l'import `course_tree` : « Cours complets » | Décision du porteur (UDR-0007 ne connaît pas « chapitre ») | UDR-0038 mise à jour |
| 2026-09-27 | UDR-0009 à UDR-0040 acceptées et indexées | Décision du porteur | Index des UDR |
| 2026-09-27 | Page profil pour tous les utilisateurs : chantier séparé à ouvrir (`/feature`) | Décision du porteur | Non (nouveau chantier) |

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

- **La date.** Le plan à 72 h du 2026-09-18 visait une mise en ligne ferme au 2026-09-22 ; la V1 est passée en production le **2026-09-27** (PR #33, complétée par #36). Le périmètre avait entre-temps doublé : référentiels, établissements et imports sont entrés en V1 le 2026-09-25 (décisions du porteur, [journal du programme](../refonte-application/journal.md#2026-09-25--décisions-de-fondation-acceptées-en-bloc)).
- **CL-02 (modifier une classe) n'est pas livrée.** Aucun lot ne l'avait en charge : ni S2 (fiche de l'établissement), ni D (classes de l'enseignant). Elle part en V3, chantier `vie-de-la-classe` ([feuille de route §5](../refonte-application/feuille-de-route.md#v3--suivi-pédagogique-enseignant)).
- **La recette `Staging` par un rôle distinct n'a pas précédé la mise en production.** Les suites livrées le 2026-09-28 (profil, génération, pilotage…) sont passées avant elle. Elle est menée le 2026-09-28 ; son rapport sera consigné ici.
- **Deux correctifs après la mise en production** : menu du compte des accueils (#34) et réémission de l'invitation de démarrage (#35).

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
| CL-02 : modifier une classe | Aucun lot ne la portait ; l'ajout et le retrait de classes sont livrés à part (`classes-par-niveau`, ADR-0059) | V3, `vie-de-la-classe` |
| Recette `Staging` par un rôle distinct | Menée après la mise en production | En cours le 2026-09-28 ; rapport à consigner ici |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-09-27 (production, lnclass.com) · clos le 2026-09-28 |
| **PR** | Vers `Develop` : #8 (plan), #11, #13, #14, #15, #16, #28 (les lots, dont ceux du Lot E : #23 à #26, fusionnés dans `feature/boucle-pedagogique`) · vers `main` : **#33** et **#36** · correctifs après la mise en production : #34, #35 |
| **ADR produits** | Aucun nouvel ADR. Amendements : ADR-0027 (erratum `TransactionPort`), ADR-0028 (policies, retour du porteur), ADR-0030 (import seul, classes générées), ADR-0034, ADR-0039 (erratum, import bloqué libéré après 10 min), ADR-0043 (seuil de résolution à 75 %), ADR-0049 (nonce par session), ADR-0051 (éditeur riche), ADR-0052 (seed d'identité avant chaque déploiement, #31), ADR-0054 ; ligne Hotwire ajoutée à l'ADR-0009 |
| **UDR produits** | UDR-0009 à UDR-0040 (32 UDR d'écran, acceptées le 2026-09-27). UDR-0005 et UDR-0006 viennent du Lot 0c, au titre du programme (F-09, F-31) |
| **Recette `Staging`** | En cours le 2026-09-28, par un rôle distinct ; la case du [§9 de la feuille de route](../refonte-application/feuille-de-route.md#9-portes-de-sortie-du-programme) sera cochée avec son rapport |

## Recette Staging du 2026-09-28

Rôle distinct (agent de recette, sans secret ni accès équipe), sur `applnclassapp-staging-005b` (code `cb9d588f`), Chromium headless en 1280 et 390 px. **Verdict : acceptée avec réserves.**

| Critère | Résultat |
|---|---|
| Accueil, connexion, PIN masqué et bouton œil, 3 échecs de connexion (422, PIN vidé, numéro gardé) | OK |
| `/c/<code inconnu>` : 404 en français avec lien de reprise | OK |
| Formulaires d'inscription enseignant (avec et sans code) | OK à l'affichage |
| CSP à nonce, HSTS, cookie `secure; httponly; samesite=lax`, `nosniff`, `referrer-policy` | OK |
| Aucun défilement horizontal à 390 px (9 pages) ; `x-runtime` ≈ 10 ms | OK |
| Pages protégées sans session → `/login` | OK |
| Verrouillage à 5 échecs, inscription élève par code, injection `role=team` | Non recettés sur `Staging` (pas d'accès, écritures refusées) ; couverts par les tests |
| Boucle complète équipe → enseignant → élève → résultat et badge | **Preuve locale seulement** : `boucle_pedagogique_test` 1 run, 163 assertions, 0 échec |

**Défauts relevés**

- **D1 (majeur, à confirmer dans un vrai navigateur)** : sur `/join` au téléphone, un code bien formé mais inconnu (`ZZZ99`) redirige vers `/c/zzz99` (404), mais l'écran reste sur `/join`, sans message. Possible effet de l'interception réseau de la recette.
- **D2 (mineur)** : `public/404.html` est la page Rails par défaut, en anglais.
- **D3 (mineur)** : la CSP autorise `style-src-attr 'unsafe-inline'` ; à consigner dans un ADR si c'est voulu.

**Pour cocher la porte** : un compte équipe de recette sur `Staging` (TOTP ou code de secours transmis hors dépôt), un code d'établissement ou un compte enseignant de recette, et l'accord du porteur pour créer un élève et un enseignant de recette et tester le verrouillage à 5 échecs.

## Suites de la recette (2026-09-28)

- **D1 et D2 corrigés et en production** le 2026-09-28 : chantier [`recette-v1-defauts`](../recette-v1-defauts/journal.md) (#81, puis #82 vers `Staging` et #83 vers `main`). Vérifié sur `Staging`, www.lnclass.com et lnclass.com : `POST /join` avec `ZZZ99` renvoie 422 et « Code de classe invalide. Vérifie le code auprès de ton professeur, puis saisis-le de nouveau. » ; `/nexistepas` renvoie la 404 « Page introuvable · Lnclass », en français.
- **D3 clos sans nouvel ADR** : `style-src-attr 'unsafe-inline'` est une concession déjà consignée dans l'[ADR-0049](../../decisions/adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (« Coûts consentis ») et commentée dans `config/initializers/content_security_policy.rb` : KaTeX produit des attributs `style="…"`, qui n'exécutent aucun code. Les scripts restent sous nonce.
- **Volet authentifié en attente** : le porteur ne peut pas fournir de compte de recette sur `Staging` le 2026-09-28. La recette authentifiée (compte équipe, verrouillage à 5 échecs, inscription élève par code, boucle complète) est mise en attente ; la porte V1 reste ouverte sur ce seul point. Le reste du programme continue.
