# Plan d'exécution — CRM des écoles

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Specs : [`prd.md`](prd.md). Décisions : ADR-XXXX-suivi-commercial-des-ecoles, ADR-XXXX-acces-aux-modeles-ia-par-openrouter, ADR-XXXX-compte-rendu-dicte-fichier-son, ADR-XXXX-rapport-direction-en-pdf, UDR-XXXX-suivi-des-ecoles, UDR-XXXX-assistants-ia-du-suivi.

## Graphe

```
Lot 0 — SOCLE (séquentiel) : tables, entités, ports, policy, repositories, routes, shell
  ↓
  ├─► Lot A  Fiche de suivi : journal, échange, étape, relances      ┐
  ├─► Lot B  Page Suivi : « À relancer », « À voir »                 ├─ vague 2, en parallèle
  ├─► Lot C  Responsable, « Toutes », reprise d'usage               │
  └─► Lot E  Accès IA, briefing, brouillon WhatsApp                  ┘
                ↓                          ↓
          Lot F  Rapport direction (E)   Lot G  Compte rendu dicté (A + E)   ← vague 3, en parallèle
```

## Calendrier (livraison le 15 novembre)

| Jours ouvrés | Vague |
|---|---|
| J1 | Lot 0 |
| J2 – J4 | Lots A, B, C, E |
| J5 – J6 | Lots F, G |
| J7 – J8 | Preuve (challenger, CI), PR, rapport de stage |

Aucune marge (memo, réponse 8). Si une vague glisse d'un jour, le porteur tranche ce qui sort : la règle de tri proposée est **G puis F** (les plus risqués), jamais le socle.

## Contrats gelés par le Lot 0

1. Le Lot 0 gèle les ports, les tables, les routes et les signatures des repositories. Les lots verticaux **implémentent**, ils ne redéfinissent pas. Un lot qui a besoin de changer un port, une table ou une route **s'arrête** : le Lot 0 rouvre.
2. **Aucun lot parallèle ne démarre avant que le Lot 0 soit mergé** dans `feature/crm-ecoles`.
3. Pages composées par plusieurs lots : chaque lot sert **son propre Turbo Frame** (route du Lot 0) et ne rend jamais le partial d'un autre lot. Cadres : `relationship_modal` (modales de la fiche, servies par A, C, E, F, G), `relationship_assistants` (carte des assistants, servie par E), `relationship_assistant` (résultat d'un assistant), `follow_ups_all` (onglet « Toutes », servi par C).
4. `AiRequestJob` (Lot E) exécute la demande par la table `Entities::School::AiPurpose::RUNNERS` du Lot 0 (usage → nom de use case). F et G écrivent leur use case `Run…` sans toucher au job.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + fichiers partagés
- **Fichiers**     : `db/migrate/*_create_school_relationships.rb` · `db/migrate/*_create_school_interactions.rb` · `db/migrate/*_create_school_follow_ups.rb` · `db/migrate/*_create_team_alerts.rb` · `db/migrate/*_create_ai_requests.rb` · `db/schema.rb`
                     `app/infrastructure/orm/school_relationship.rb` · `app/infrastructure/orm/school_interaction.rb` · `app/infrastructure/orm/school_follow_up.rb` · `app/infrastructure/orm/team_alert.rb` · `app/infrastructure/orm/ai_request.rb`
                     `app/domain/entities/school/relationship.rb` · `app/domain/entities/school/interaction.rb` · `app/domain/entities/school/follow_up.rb` · `app/domain/entities/school/team_alert.rb` · `app/domain/entities/school/relationship_stage.rb` · `app/domain/entities/school/ai_purpose.rb`
                     `app/domain/ports/school/relationship_repository_port.rb` · `app/domain/ports/school/interaction_repository_port.rb` · `app/domain/ports/school/follow_up_repository_port.rb` · `app/domain/ports/school/team_alert_repository_port.rb` · `app/domain/ports/school/ai_request_repository_port.rb` · `app/domain/ports/school/language_model_port.rb`
                     `app/domain/policies/school/follow_school_policy.rb`
                     `app/infrastructure/repositories/school/relationship_repository.rb` · `app/infrastructure/repositories/school/interaction_repository.rb` · `app/infrastructure/repositories/school/follow_up_repository.rb` · `app/infrastructure/repositories/school/team_alert_repository.rb` · `app/infrastructure/repositories/school/ai_request_repository.rb`
                     `app/infrastructure/queries/school/school_usage_signals_query.rb`
                     `config/routes/teams.rb` · `config/recurring.yml` · `Gemfile` · `Gemfile.lock` *(prawn, prawn-table ; pdf-reader en test)*
                     `app/helpers/navigation_helper.rb` · `config/locales/teams/navigation.fr.yml` *(ou la clé `navigation.team.follow_ups` dans le fichier qui la porte)* · `config/locales/school/relationships.fr.yml` *(étapes, types, résultats, motifs de perte)*
                     `app/views/teams/relationships/_stage_badge.html.erb`
                     `test/support/factories/school.rb` · `test/support/domain/fake_language_model.rb`
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/school/relationship_stage_test.rb` *(tous les critères « Étape affichée »)* · `test/domain/policies/school/follow_school_policy_test.rb` *(les trois gestes, `content` et enseignant refusés)* · `test/infrastructure/queries/school/school_usage_signals_query_test.rb` *(devoir, travail rendu, connexion seule, 15 jours, enseignant dans deux écoles)* · `test/infrastructure/repositories/school/relationship_repository_test.rb`
- **Done quand**   : `bin/rails db:migrate` passe ; un `admin` et un `field` voient l'entrée « Suivi » dans le shell, un `content` ne la voit pas ; toutes les routes du chantier existent (elles répondent 404 tant que leur lot n'est pas mergé) ; la fonction d'étape affichée passe sa table de cas.

> Le Lot 0 dépasse « une poignée de fichiers » : les repositories et la query d'usage sont lus par 3 à 5 lots chacun, ils remontent donc ici (étape 4). Il ne contient aucun use case.

---

## Lot A — Fiche de suivi : journal, noter un échange, changer l'étape, relances

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : `app/domain/use_cases/school/note_interaction.rb` · `app/domain/use_cases/school/change_stage.rb` · `app/domain/use_cases/school/plan_follow_up.rb` · `app/domain/use_cases/school/complete_follow_up.rb` · `app/domain/use_cases/school/cancel_follow_up.rb` · `app/domain/dtos/school/interaction_input.rb`
                     `app/infrastructure/queries/school/relationship_detail_query.rb`
                     `app/controllers/teams/relationships_controller.rb` · `app/controllers/teams/interactions_controller.rb` · `app/controllers/teams/stages_controller.rb` · `app/controllers/teams/follow_up_tasks_controller.rb`
                     `app/views/teams/relationships/show.html.erb` · `app/views/teams/relationships/_header.html.erb` · `app/views/teams/relationships/_usage.html.erb` · `app/views/teams/relationships/_follow_ups.html.erb` · `app/views/teams/relationships/_journal.html.erb` · `app/views/teams/relationships/_journal_entry.html.erb`
                     `app/views/teams/interactions/_form.html.erb` *(accepte des valeurs initiales, pour le Lot G)* · `app/views/teams/interactions/new.html.erb` · `app/views/teams/interactions/create.turbo_stream.erb` · `app/views/teams/stages/edit.html.erb` · `app/views/teams/stages/update.turbo_stream.erb` · `app/views/teams/follow_up_tasks/*`
                     `app/views/teams/schools/_header.html.erb` *(un seul lien « Suivi de l'école »)*
                     `config/locales/teams/relationships.fr.yml` · `config/locales/teams/interactions.fr.yml` · `config/locales/teams/stages.fr.yml` · `config/locales/teams/follow_up_tasks.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/school/note_interaction_test.rb` *(alerte au responsable, pas d'alerte sans responsable ni pour soi)* · `test/domain/use_cases/school/change_stage_test.rb` *(403 non responsable, 422 `active`, 422 Perdue sans motif, trace au journal)* · `test/domain/use_cases/school/complete_follow_up_test.rb` · `test/controllers/teams/relationships_controller_test.rb` *(403 `content`, alertes marquées lues)* · `test/controllers/teams/interactions_controller_test.rb` · `test/system/teams/relationship_test.rb` *(390 px : noter un appel, il apparaît au journal)*
- **Done quand**   : Touré ouvre la fiche de suivi d'une école, note un appel avec Mme Kouassi, le voit en tête du journal avec son nom ; il passe l'école à Démo faite et la trace « Prospect → Démo faite » apparaît ; Konan, sur une école de Touré, ne peut pas changer l'étape (403).

---

## Lot B — Page Suivi : file « À relancer » et alertes « À voir »

- **Couche**       : domaine + infrastructure (lecture) + delivery + ui
- **Fichiers**     : `app/domain/entities/school/follow_up_rule.rb`
                     `app/infrastructure/queries/school/follow_up_queue_query.rb` · `app/infrastructure/queries/school/team_alerts_query.rb`
                     `app/controllers/teams/follow_ups_controller.rb` · `app/controllers/teams/alerts_controller.rb`
                     `app/views/teams/follow_ups/index.html.erb` · `app/views/teams/follow_ups/_queue.html.erb` · `app/views/teams/follow_ups/_queue_row.html.erb` · `app/views/teams/follow_ups/_alerts.html.erb` · `app/views/teams/follow_ups/_unowned_banner.html.erb` · `app/views/teams/alerts/index.html.erb`
                     `config/locales/teams/follow_ups.fr.yml` · `config/locales/teams/alerts.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/entities/school/follow_up_rule_test.rb` *(trois motifs, ordre, « échange récent » écarte « inactive »)* · `test/infrastructure/queries/school/follow_up_queue_query_test.rb` *(relance due, démo sans suite 8 j, Abonnée inactive 20 j ; ≤ 8 requêtes pour 50 lignes)* · `test/controllers/teams/follow_ups_controller_test.rb` *(403 `content`, « N écoles sans responsable » pour `admin` seul)* · `test/system/teams/follow_ups_test.rb` *(390 px et ordinateur)*
- **Done quand**   : Touré ouvre « Suivi » et voit ses écoles à relancer avec leur motif (« Relance prévue le… », « Démo sans suite depuis 9 jours », « Plus de devoir depuis 20 jours ») ; une alerte « Konan a noté un appel » apparaît dans « À voir » ; un `admin` voit le bandeau « N écoles sans responsable ».

---

## Lot C — Responsable, onglet « Toutes », reprise d'usage d'une école perdue

- **Couche**       : domaine + infrastructure + delivery + ui + job
- **Fichiers**     : `app/domain/use_cases/school/assign_owner.rb` · `app/domain/use_cases/school/release_owned_schools.rb` · `app/domain/use_cases/school/detect_resumed_schools.rb`
                     `app/domain/use_cases/identity/anonymize_user.rb` *(un appel à `ReleaseOwnedSchools` dans sa transaction)*
                     `app/infrastructure/queries/school/followed_schools_query.rb` · `app/infrastructure/queries/school/resumed_schools_query.rb`
                     `app/jobs/school/detect_resumed_schools_job.rb`
                     `app/controllers/teams/followed_schools_controller.rb` · `app/controllers/teams/owners_controller.rb` · `app/controllers/teams/owner_assignments_controller.rb`
                     `app/views/teams/followed_schools/index.html.erb` *(cadre `follow_ups_all`)* · `app/views/teams/followed_schools/_filters.html.erb` · `app/views/teams/followed_schools/_row.html.erb` · `app/views/teams/followed_schools/_bulk_bar.html.erb` · `app/views/teams/owners/edit.html.erb` · `app/views/teams/owners/update.turbo_stream.erb`
                     `app/javascript/controllers/bulk_select_controller.js`
                     `config/locales/teams/followed_schools.fr.yml` · `config/locales/teams/owners.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/school/assign_owner_test.rb` *(403 `field`, trois écoles, trace « — → Touré », relances sans destinataire reprises)* · `test/domain/use_cases/school/release_owned_schools_test.rb` · `test/domain/use_cases/identity/anonymize_user_test.rb` *(2 écoles et 2 relances libérées)* · `test/domain/use_cases/school/detect_resumed_schools_test.rb` *(reprise, alerte, idempotence)* · `test/infrastructure/queries/school/followed_schools_query_test.rb` *(filtres, pagination 50)* · `test/controllers/teams/owner_assignments_controller_test.rb`
- **Done quand**   : un `admin` coche trois écoles sans responsable dans « Toutes » et les attribue à Touré ; Touré les voit dans ses écoles ; l'anonymisation de Touré les rend « sans responsable » ; une école Perdue où un devoir est donné repasse à Prospect au passage quotidien, avec la trace « Reprise d'usage » et une alerte.

---

## Lot E — Accès aux modèles IA, briefing et brouillon WhatsApp

- **Couche**       : domaine + infrastructure (adaptateur HTTP, job) + delivery + ui
- **Fichiers**     : `app/domain/use_cases/school/request_ai_assist.rb` *(policy, quota 40/j, budget, ligne `pending`, mise en file)* · `app/domain/use_cases/school/run_briefing.rb` · `app/domain/use_cases/school/run_whatsapp_draft.rb` · `app/domain/entities/school/prompt_redactor.rb` · `app/domain/entities/school/restricted_markdown.rb`
                     `app/infrastructure/queries/school/assist_context_query.rb` *(contexte sans élève : échanges, relances, chiffres agrégés)*
                     `app/infrastructure/school/open_router_language_model.rb`
                     `app/jobs/school/ai_request_job.rb` · `app/jobs/school/purge_ai_outputs_job.rb`
                     `app/controllers/teams/ai_requests_controller.rb` · `app/controllers/teams/assistants_controller.rb`
                     `app/views/teams/assistants/show.html.erb` *(cadre `relationship_assistants`, les quatre boutons)* · `app/views/teams/ai_requests/_pending.html.erb` · `app/views/teams/ai_requests/_failed.html.erb` · `app/views/teams/ai_requests/_briefing.html.erb` · `app/views/teams/ai_requests/_whatsapp_draft.html.erb` · `app/views/teams/ai_requests/show.html.erb` · `app/views/teams/whatsapp_drafts/new.html.erb`
                     `app/javascript/controllers/ai_request_controller.js`
                     `config/locales/teams/assistants.fr.yml` · `config/locales/teams/ai_requests.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/school/open_router_language_model_test.rb` *(réglage de non-conservation dans chaque corps ; 429, 402, 5xx, délai)* · `test/domain/use_cases/school/request_ai_assist_test.rb` *(41e appel et budget atteint : port non appelé)* · `test/domain/use_cases/school/run_briefing_test.rb` *(aucun nom d'élève envoyé ; appel tracé)* · `test/jobs/school/ai_request_job_test.rb` *(fournisseur muet → `failed`)* · `test/controllers/teams/ai_requests_controller_test.rb` *(un autre acteur : 404)* · `test/system/teams/assistants_test.rb` *(briefing avec le faux modèle ; erreur et « Réessayer »)*
- **Done quand**   : sur la fiche, Touré touche « Briefing » et voit, après l'attente, un briefing marqué « Brouillon IA — à relire » ; il génère un brouillon WhatsApp et le copie ; sans clé OpenRouter, le panneau dit « L'assistant ne répond pas » et la fiche reste utilisable.

> **Avant de coder l'adaptateur** : lire la documentation officielle d'OpenRouter (réglage de non-conservation, erreurs, entrée audio) et reporter les noms exacts dans l'ADR-XXXX-acces-aux-modeles-ia-par-openrouter §4.3. Le domaine `openrouter.ai` doit être autorisé dans le réseau de l'environnement ; sinon le lot s'arrête et remonte.

---

## Lot F — Rapport pour la direction en PDF

- **Couche**       : domaine + infrastructure (query, PDF) + delivery + ui
- **Fichiers**     : `app/domain/use_cases/school/run_director_report.rb` · `app/domain/use_cases/school/download_director_report.rb` · `app/domain/dtos/school/director_report_input.rb`
                     `app/infrastructure/queries/school/director_report_data_query.rb` *(chiffres par classe, élèves à suivre : rendu < 50 %, 10 par classe)*
                     `app/infrastructure/school/director_report_pdf.rb` · `vendor/fonts/DejaVuSans.ttf` · `vendor/fonts/DejaVuSans-Bold.ttf`
                     `app/controllers/teams/director_reports_controller.rb`
                     `app/views/teams/director_reports/new.html.erb` · `app/views/teams/ai_requests/_director_report.html.erb`
                     `config/locales/teams/director_reports.fr.yml`
- **Dépend de**    : Lot 0, Lot E
- **Test associé** : `test/infrastructure/queries/school/director_report_data_query_test.rb` · `test/domain/use_cases/school/download_director_report_test.rb` *(trace `report_downloaded` avec le texte relu et la période)* · `test/controllers/teams/director_reports_controller_test.rb` *(PDF, `no-store`, 403 `content`, 422 au-delà de 20 000 caractères)* · `test/infrastructure/school/director_report_pdf_test.rb` *(accents et phrase corrigée lus dans le PDF)*
- **Done quand**   : Touré prépare le rapport des 30 derniers jours d'une école de démonstration, corrige une phrase, télécharge le PDF qui contient sa phrase corrigée, et retrouve « Rapport téléchargé » au journal avec un lien pour le retélécharger.

---

## Lot G — Compte rendu dicté

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/dtos/school/dictation_input.rb` · `app/domain/entities/school/dictation_result.rb` · `app/domain/use_cases/school/run_dictation.rb`
                     `app/controllers/teams/dictations_controller.rb`
                     `app/views/teams/dictations/new.html.erb` · `app/views/teams/ai_requests/_dictation.html.erb` *(rend `teams/interactions/_form` du Lot A avec ses valeurs initiales)*
                     `app/javascript/controllers/audio_recorder_controller.js`
                     `config/locales/teams/dictations.fr.yml`
                     `test/fixtures/files/dictation_40s.m4a` · `test/fixtures/files/dictation_4min.mp3`
- **Dépend de**    : Lot 0, Lot A *(formulaire d'échange)*, Lot E *(file des demandes IA)*
- **Test associé** : `test/domain/dtos/school/dictation_input_test.rb` *(menaces D1 à D3 : HTML renommé, Xing menteur, 5 Mo + 1, WAV, 4 min)* · `test/domain/entities/school/dictation_result_test.rb` *(D6 : valeurs hors liste, JSON illisible)* · `test/jobs/school/ai_request_job_test.rb` *(D5 : blob purgé après succès et échec — cas ajouté au fichier du Lot E, après son merge)* · `test/controllers/teams/dictations_controller_test.rb` *(D8 ; 422 sans appel au fournisseur)*
- **Done quand**   : Touré choisit un M4A de 40 s enregistré sur son téléphone, voit le formulaire d'échange pré-rempli et marqué « Pré-rempli par l'IA », corrige l'interlocuteur et enregistre ; un fichier de 4 minutes est refusé avec son motif ; le fichier son n'existe plus dans le stockage.

> `security-reviewer` obligatoire sur ce lot (téléversement). La menace est déjà écrite : ADR-XXXX-compte-rendu-dicte-fichier-son §4.2.

---

## Couverture des critères d'acceptation (PRD §4)

| Bloc de critères | Lot |
|---|---|
| Accès (`content`, enseignant) | 0 (policy) · A, B, C, E, F, G (contrôleurs) |
| Étape affichée (6 critères) | 0 |
| Reprise d'une école perdue | C |
| Saisie de l'étape (4 critères) | A |
| Journal et alertes (2 critères) | A ; lecture de l'alerte : B |
| Responsable (3 critères) | C |
| Relances et « À relancer » (4 critères) | B ; « marquer faite » : A |
| Assistants IA (5 critères) | E |
| Compte rendu dicté (3 critères) | G |
| Rapport pour la direction | F |

Aucun critère orphelin.

## Dispatch

```
Vague 1 : Lot 0                          → 1 agent (executant-lot), séquentiel
Vague 2 : Lot A ‖ Lot B ‖ Lot C ‖ Lot E  → 4 agents, worktrees isolés
Vague 3 : Lot F ‖ Lot G                  → 2 agents, une fois A et E mergés
```

```bash
git worktree add ../lnclass-crm-ecoles-lot-a -b feature/crm-ecoles-lot-a feature/crm-ecoles
```

Chaque brief d'agent : chemin absolu du worktree, le lot recopié en entier, `prd.md`, l'UDR concernée, l'ordre test rouge → domaine → infrastructure → delivery → UI, `git -C <worktree>`, et **interdiction de toucher un fichier hors de son champ `Fichiers`**.

---

## Vérification de collision

> Deux lots ne listent jamais le même fichier. Contrôle mécanique : la commande `awk … | uniq -d` de la skill `plan-lots` ne rend que `test/jobs/school/ai_request_job_test.rb`, partagé **en séquence** (E crée, G ajoute un cas après le merge de E) : pas de collision entre lots parallèles.

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/teams.rb` | Lot 0 |
| `config/recurring.yml` | Lot 0 |
| `Gemfile`, `Gemfile.lock` | Lot 0 |
| `db/schema.rb`, `db/migrate/*` | Lot 0 |
| `app/helpers/navigation_helper.rb` | Lot 0 |
| `config/locales/school/relationships.fr.yml` | Lot 0 |
| `app/views/teams/relationships/_stage_badge.html.erb` | Lot 0 (rendu par A, B, C) |
| `app/infrastructure/repositories/school/*` (5 repositories du suivi) | Lot 0 |
| `app/infrastructure/queries/school/school_usage_signals_query.rb` | Lot 0 (lu par A, B, C, E, F) |
| `app/domain/policies/school/follow_school_policy.rb` | Lot 0 |
| `test/support/factories/school.rb` | Lot 0 |
| `test/support/domain/fake_language_model.rb` | Lot 0 |
| `app/views/teams/interactions/_form.html.erb` | Lot A (rendu par G en vague 3) |
| `app/views/teams/schools/_header.html.erb` | Lot A |
| `app/domain/use_cases/identity/anonymize_user.rb` | Lot C |
| `app/jobs/school/ai_request_job.rb` | Lot E |
| `test/jobs/school/ai_request_job_test.rb` | Lot E, puis Lot G (séquentiel) |
| `app/views/teams/ai_requests/*` | Lot E, sauf `_director_report` (F) et `_dictation` (G) |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Pour ce chantier : il refait le parcours nominal du PRD §3 (de « À relancer » au PDF téléchargé), puis au moins deux chemins d'erreur : un `field` qui force un changement d'étape sur l'école d'un autre (403), et un fichier son de 4 minutes (422, fournisseur non appelé). Il mesure le nombre de requêtes de « À relancer » (≤ 8 pour 50 lignes).
