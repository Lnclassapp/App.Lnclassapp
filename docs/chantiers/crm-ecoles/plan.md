# Plan d'exécution — CRM des écoles (« Lnclass Intelligent »)

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Specs : [`prd.md`](prd.md) · Décisions : ADR-XXXX-contexte-crm-suivi-des-ecoles, ADR-XXXX-modeles-de-langage-par-openrouter, UDR-XXXX-bloc-suivi-de-la-fiche-etablissement, UDR-XXXX-pipeline-et-relances, UDR-XXXX-assistants-du-suivi.

## Graphe

```
Lot 0 — SOCLE : tables, entités, ports, policy, routes, hôtes des frames, usage par école, membres assignables
  ↓
  ├─► Lot A  Étape, responsable, usage            ┐
  ├─► Lot B  Contacts                             │
  ├─► Lot C  Journal des échanges                 ├─ vague 2 : 6 agents en parallèle
  ├─► Lot D  Relances (créer, terminer, réattribuer, page)
  ├─► Lot F  Pipeline sur « Établissements »      │
  └─► Lot G  Socle IA (OpenRouter, générations, carte Assistants)
        ↓
  Lot D ──► Lot E  À relancer (règle calculée, onglet, carte Accueil)   ┐
  Lot G ──► Lot H  Fiche de briefing                                     │
  Lot G ──► Lot I  Brouillon de relance WhatsApp                         ├─ vague 3 : 5 agents
  Lot G ──► Lot J  Rapport pédagogique                                   │
  Lot C + Lot G ──► Lot K  Compte rendu dicté                            ┘
```

**Pourquoi chaque sous-bloc de la fiche est un frame à part** (UDR-XXXX-bloc-suivi-de-la-fiche-etablissement) : le Lot 0 pose une coquille statique avec six `turbo-frame` paresseux ; chaque lot sert le sien par son propre contrôleur. Aucun lot ne touche le fichier d'un autre, et un sous-bloc en erreur ne casse pas les autres.

**Ordre de coupe** si le délai glisse : Lot K, puis Lot J. Le Lot H ne se coupe pas.

## Dispatch

```
Vague 1 : Lot 0                                       → 1 agent, séquentiel, sur feature/crm-ecoles
Vague 2 : Lot A ‖ B ‖ C ‖ D ‖ F ‖ G                   → 6 agents, worktrees isolés
Vague 3 : Lot E (D) ‖ H (G) ‖ I (G) ‖ J (G) ‖ K (C+G) → 5 agents, worktrees isolés
Puis    : revues (security-reviewer, silent-failure-hunter, pr-test-analyzer), bin/ci-quiet, captures, challenger
```

Agent d'exécution : `executant-lot` (Sonnet). Touré pilote : il lance les agents, relit, fusionne chaque lot dans `feature/crm-ecoles`, fait les captures.

Worktree d'un lot, créé **après** la fusion du Lot 0 :

```bash
git worktree add ../lnclass-crm-ecoles-lot-a -b feature/crm-ecoles-lot-a feature/crm-ecoles
```

Consignes à chaque agent : chemins **absolus** (`git -C <worktree>`) ; **interdiction de toucher un fichier hors de son champ `Fichiers`** — s'il en a besoin, il s'arrête et remonte (le fichier appartient au Lot 0 ou le plan est faux) ; ordre intra-lot : test rouge → domaine → infrastructure → delivery → vue ; en-tête HITL sur chaque fichier de `app/`.

### Calendrier visé

| Jour | Travail |
|---|---|
| Mer 4 nov. | Lot 0 |
| Jeu 5 – Ven 6 | Vague 2 (A, B, C, D, F, G), fusions au fil de l'eau |
| Lun 9 – Mar 10 | Vague 3 (E, H, I, J, K) |
| Mer 11 | Revues, `bin/ci-quiet`, captures 390 px et ordinateur, PR prête |
| Jeu 12 | Challenger, corrections, fusion dans `Develop` |
| Ven 13 | Rapport de stage |
| Sam 14 | Marge |

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + delivery (fichiers partagés)
- **Fichiers**     : `db/migrate/<horodatage>_create_crm_tables.rb` *(5 tables, ADR contexte + ADR modèles)*
                     `app/infrastructure/orm/crm_account.rb` · `crm_contact.rb` · `crm_interaction.rb` · `crm_follow_up.rb` · `crm_generation.rb` *(`has_one_attached :audio`)*
                     `app/domain/entities/crm/account.rb` · `stage.rb` · `contact.rb` · `interaction.rb` · `follow_up.rb` · `generation.rb` · `school_usage.rb`
                     `app/domain/ports/crm/account_repository_port.rb` · `contact_repository_port.rb` · `interaction_repository_port.rb` · `follow_up_repository_port.rb` · `generation_repository_port.rb` · `language_model_port.rb`
                     `app/infrastructure/repositories/crm/follow_up_repository.rb` *(partagé par C et D)*
                     `app/domain/policies/crm/manage_crm_policy.rb`
                     `app/domain/entities/identity/audit_action.rb` *(+ `crm.stage_changed`, `crm.owner_changed`)*
                     `app/infrastructure/queries/crm/school_usage_query.rb` *(comptes, élèves actifs 14 j, dernière activité, premier rattachement, par lot d'écoles)*
                     `app/infrastructure/queries/crm/assignable_members_query.rb` *(membres `admin`/`field` non anonymisés)*
                     `config/routes/teams.rb` *(toutes les adresses du suivi)*
                     `config/initializers/language_models.rb`
                     `config/locales/teams/crm/common.fr.yml` *(étapes, motifs, raisons, types, résultats)*
                     `app/controllers/teams/crm/base_controller.rb` *(garde `ManageCrmPolicy`)*
                     `app/controllers/teams/schools_controller.rb` *(`#show` : `@can_manage_crm`)*
                     `app/controllers/teams/homes_controller.rb` *(`@can_manage_crm`)*
                     `app/views/teams/schools/show.html.erb` *(frame `school_crm`)*
                     `app/views/teams/crm/accounts/show.html.erb` *(coquille : section, grille, six frames paresseux)*
                     `app/controllers/teams/crm/accounts_controller.rb`
                     `app/views/teams/homes/show.html.erb` *(frame `team_home_follow_ups`)*
                     `app/helpers/navigation_helper.rb` · `config/locales/shared/navigation.fr.yml` *(« Relances » dans « Plus »)*
                     `test/support/fake_language_model.rb`
                     `docs/guide/conventions.md` §2 · `CLAUDE.md` · `docs/guide/glossaire.md` *(septième contexte `crm`)*
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/crm/stage_test.rb` (CA-03, CA-04, CA-05) · `test/domain/policies/crm/manage_crm_policy_test.rb` · `test/infrastructure/queries/crm/school_usage_query_test.rb` · `test/infrastructure/queries/crm/assignable_members_query_test.rb` · `test/infrastructure/repositories/crm/follow_up_repository_test.rb` · `test/controllers/teams/crm/accounts_controller_test.rb` (CA-01, CA-02 : 403 pour `content` et enseignant ; frame absent de la fiche pour `content`)
- **Done quand**   : un membre `field` ouvre une fiche établissement et voit le bloc « Suivi » et ses six squelettes ; un membre `content` ne le voit pas et reçoit 403 sur `/teams/schools/:id/follow-up` ; `bin/rails runner "puts Ports::Crm::LanguageModelPort.name"` passe ; les ports sont gelés

---

## Lot A — Étape, responsable et usage

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/crm/set_stage.rb` · `assign_owner.rb`
                     `app/infrastructure/repositories/crm/account_repository.rb`
                     `app/controllers/teams/crm/stages_controller.rb` · `owners_controller.rb` · `usages_controller.rb`
                     `app/views/teams/crm/stages/show.html.erb` · `_stage.html.erb` · `_form.html.erb` · `update.turbo_stream.erb`
                     `app/views/teams/crm/owners/_form.html.erb` · `update.turbo_stream.erb`
                     `app/views/teams/crm/usages/show.html.erb`
                     `config/locales/teams/crm/stages.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/crm/set_stage_test.rb` (CA-06, CA-07) · `test/domain/use_cases/crm/assign_owner_test.rb` (CA-07, CA-08) · `test/infrastructure/repositories/crm/account_repository_test.rb` (contrainte motif) · `test/controllers/teams/crm/stages_controller_test.rb` · `test/system/teams/crm_stage_test.rb`
- **Done quand**   : un membre `field` passe une école à « Démo faite », s'en nomme responsable, voit le badge et son nom changer sans rechargement ; « Perdue » sans motif est refusé ; « Active » n'est pas proposé ; l'audit contient les deux actions

---

## Lot B — Contacts

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/crm/add_contact.rb` · `archive_contact.rb`
                     `app/infrastructure/repositories/crm/contact_repository.rb`
                     `app/controllers/teams/crm/contacts_controller.rb`
                     `app/views/teams/crm/contacts/index.html.erb` · `_contact.html.erb` · `_form.html.erb` · `new.html.erb` · `archive.html.erb` · `create.turbo_stream.erb` · `destroy.turbo_stream.erb`
                     `config/locales/teams/crm/contacts.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/crm/add_contact_test.rb` (CA-10) · `test/domain/use_cases/crm/archive_contact_test.rb` (CA-09) · `test/infrastructure/repositories/crm/contact_repository_test.rb` · `test/controllers/teams/crm/contacts_controller_test.rb` · `test/system/teams/crm_contacts_test.rb`
- **Done quand**   : un membre ajoute « Mme Kouassi, directrice, 0701020304 », la voit avec ses liens « Appeler » et WhatsApp, puis la retire ; « 12345 » est refusé

---

## Lot C — Journal des échanges

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/crm/record_interaction.rb` *(crée la relance proposée via le port des relances)*
                     `app/infrastructure/repositories/crm/interaction_repository.rb`
                     `app/controllers/teams/crm/interactions_controller.rb`
                     `app/views/teams/crm/interactions/index.html.erb` · `_interaction.html.erb` · `_form.html.erb` *(réutilisé par le Lot K)* · `new.html.erb` · `create.turbo_stream.erb`
                     `config/locales/teams/crm/interactions.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/crm/record_interaction_test.rb` (CA-11) · `test/infrastructure/repositories/crm/interaction_repository_test.rb` · `test/controllers/teams/crm/interactions_controller_test.rb` (CA-12 : aucune route `edit`/`update`/`destroy`) · `test/system/teams/crm_journal_test.rb`
- **Done quand**   : un membre note un appel positif avec une note et une relance dans 3 jours ; l'échange apparaît en tête du journal, la relance existe ; au-delà de 20 échanges, « Voir les échanges plus anciens » charge la suite

---

## Lot D — Relances

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : `app/domain/use_cases/crm/schedule_follow_up.rb` · `complete_follow_up.rb` · `reassign_follow_up.rb`
                     `app/infrastructure/queries/crm/follow_ups_query.rb` *(relances d'une école ; « mes relances » ; orphelines)*
                     `app/controllers/teams/crm/follow_ups_controller.rb` · `follow_up_completions_controller.rb` · `follow_up_assignees_controller.rb`
                     `app/views/teams/crm/follow_ups/index.html.erb` *(page « Relances », onglets « Mes relances » et « Sans destinataire »)* · `school.html.erb` *(frame de la fiche)* · `_follow_up.html.erb` · `_form.html.erb` · `new.html.erb` · `_assignee_form.html.erb` · `create.turbo_stream.erb` · `complete.turbo_stream.erb` · `reassign.turbo_stream.erb`
                     `config/locales/teams/crm/follow_ups.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/crm/schedule_follow_up_test.rb` · `test/domain/use_cases/crm/complete_follow_up_test.rb` (CA-13, déjà faite sans effet) · `test/domain/use_cases/crm/reassign_follow_up_test.rb` (CA-14) · `test/infrastructure/queries/crm/follow_ups_query_test.rb` · `test/controllers/teams/crm/follow_ups_controller_test.rb` · `test/system/teams/crm_follow_ups_test.rb`
- **Done quand**   : un membre crée une relance pour demain, la retrouve dans « Mes relances », la marque « Faite » ; un `admin` réattribue la relance d'un membre anonymisé ; un `field` non responsable ne le peut pas

---

## Lot E — À relancer (règle calculée)

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/entities/crm/follow_up_signals.rb`
                     `app/infrastructure/queries/crm/follow_up_signals_query.rb`
                     `app/controllers/teams/crm/follow_ups_controller.rb` *(onglet `signals`, en série après D)*
                     `app/views/teams/crm/follow_ups/index.html.erb` *(onglet « À relancer », en série après D)* · `_signal_row.html.erb`
                     `app/controllers/teams/crm/home_follow_ups_controller.rb`
                     `app/views/teams/crm/home_follow_ups/show.html.erb` *(carte de l'Accueil)*
                     `config/locales/teams/crm/signals.fr.yml`
- **Dépend de**    : Lot D
- **Test associé** : `test/domain/entities/crm/follow_up_signals_test.rb` (CA-15 à CA-19) · `test/infrastructure/queries/crm/follow_up_signals_query_test.rb` (requêtes constantes) · `test/controllers/teams/crm/home_follow_ups_controller_test.rb` (CA-20) · `test/system/teams/crm_signals_test.rb`
- **Done quand**   : l'Accueil d'un membre montre « À relancer : 2 » avec la raison de chaque école ; l'onglet « À relancer » liste ses écoles avec leurs badges ; une école désactivée ou perdue sans usage n'y est jamais

---

## Lot F — Pipeline sur « Établissements »

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/school/schools_query.rb` *(filtres `stage`, `owner` ; colonnes étape et responsable)*
                     `app/controllers/teams/schools_controller.rb` *(`#index`, en série après le Lot 0)*
                     `app/views/teams/schools/_filters.html.erb` · `_school_row.html.erb` · `index.html.erb`
                     `config/locales/teams/crm/pipeline.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/school/schools_query_test.rb` (CA-21, requêtes constantes) · `test/controllers/teams/schools_controller_test.rb` (filtres absents pour `content`) · `test/system/teams/schools_test.rb`
- **Done quand**   : un membre filtre par « Démo faite » et « Moi » et ne voit que ses écoles en démo, avec la colonne « Étape » ; l'adresse porte les filtres ; `content` voit la liste d'avant

---

## Lot G — Socle IA

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/crm/open_router_language_model.rb`
                     `app/infrastructure/repositories/crm/generation_repository.rb`
                     `app/jobs/crm/generation_job.rb` *(classe de base : appel, statut, durée, jetons, purge de l'audio)*
                     `app/controllers/teams/crm/generations_controller.rb` · `assistants_controller.rb`
                     `app/views/teams/crm/generations/_generation.html.erb` · `show.html.erb`
                     `app/views/teams/crm/assistants/show.html.erb` · `_card.html.erb`
                     `app/javascript/controllers/generation_poll_controller.js`
                     `config/locales/teams/crm/assistants.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/crm/open_router_language_model_test.rb` (succès, clé absente, délai, 500, corps invalide) · `test/infrastructure/repositories/crm/generation_repository_test.rb` (une seule génération en cours par école et type) · `test/jobs/crm/generation_job_test.rb` · `test/controllers/teams/crm/assistants_controller_test.rb` (CA-23) · `test/javascript/generation_poll_controller.test.js`
- **Done quand**   : sans clé, la carte affiche « Assistant non configuré » ; avec le faux modèle, une génération `pending` se met à jour seule à l'écran quand elle passe `done` ou `failed`

---

## Lot H — Fiche de briefing

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/crm/request_briefing.rb` *(empreinte des entrées, réutilisation)*
                     `app/domain/entities/crm/briefing_prompt.rb`
                     `app/infrastructure/queries/crm/briefing_inputs_query.rb`
                     `app/jobs/crm/briefing_job.rb`
                     `app/controllers/teams/crm/briefings_controller.rb`
                     `app/views/teams/crm/briefings/_briefing.html.erb` · `create.turbo_stream.erb`
                     `config/locales/teams/crm/briefings.fr.yml`
- **Dépend de**    : Lot G
- **Test associé** : `test/domain/use_cases/crm/request_briefing_test.rb` (CA-22 : second clic sans appel) · `test/domain/entities/crm/briefing_prompt_test.rb` · `test/jobs/crm/briefing_job_test.rb` (CA-24) · `test/system/teams/crm_briefing_test.rb`
- **Done quand**   : avec le faux modèle, « Préparer l'appel » affiche une fiche de 5 lignes au plus ; un second clic sans nouvel échange ne rappelle pas le modèle ; un échec affiche « Réessayer »

---

## Lot I — Brouillon de relance WhatsApp

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/crm/request_whatsapp_draft.rb`
                     `app/domain/entities/crm/whatsapp_draft_prompt.rb`
                     `app/jobs/crm/whatsapp_draft_job.rb`
                     `app/controllers/teams/crm/whatsapp_drafts_controller.rb`
                     `app/views/teams/crm/whatsapp_drafts/new.html.erb` · `_draft.html.erb`
                     `app/javascript/controllers/whatsapp_link_controller.js`
                     `config/locales/teams/crm/whatsapp_drafts.fr.yml`
- **Dépend de**    : Lot G
- **Test associé** : `test/domain/use_cases/crm/request_whatsapp_draft_test.rb` · `test/domain/entities/crm/whatsapp_draft_prompt_test.rb` (600 caractères) · `test/jobs/crm/whatsapp_draft_job_test.rb` · `test/system/teams/crm_whatsapp_draft_test.rb` (CA-28)
- **Done quand**   : depuis une relance, « Rédiger un message » affiche un brouillon modifiable, « Copier » et « Ouvrir dans WhatsApp » vers le contact choisi ; l'application n'envoie rien

---

## Lot J — Rapport pédagogique

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/crm/request_pedagogy_report.rb`
                     `app/domain/entities/crm/pedagogy_report_prompt.rb`
                     `app/infrastructure/queries/crm/pedagogy_report_query.rb` *(30 jours : élèves actifs, devoirs, taux de rendu, réussite par matière, 5 lacunes)*
                     `app/jobs/crm/pedagogy_report_job.rb`
                     `app/controllers/teams/crm/pedagogy_reports_controller.rb`
                     `app/views/teams/crm/pedagogy_reports/show.html.erb` · `_figures.html.erb` · `_subjects.html.erb` · `_gaps.html.erb`
                     `app/javascript/controllers/print_controller.js`
                     `config/locales/teams/crm/pedagogy_reports.fr.yml`
- **Dépend de**    : Lot G
- **Test associé** : `test/infrastructure/queries/crm/pedagogy_report_query_test.rb` · `test/domain/use_cases/crm/request_pedagogy_report_test.rb` (CA-30 : pas d'appel sans donnée) · `test/jobs/crm/pedagogy_report_job_test.rb` · `test/system/teams/crm_pedagogy_report_test.rb` (CA-29)
- **Done quand**   : pour une école active, la page montre les quatre chiffres, la réussite par matière, les 5 lacunes et la synthèse, s'imprime proprement ; pour une école sans activité, « Pas encore assez d'activité »

---

## Lot K — Compte rendu dicté

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/crm/submit_dictation.rb` *(contrôles taille et type avant tout appel)*
                     `app/domain/entities/crm/dictation_draft.rb` *(schéma fermé de la réponse, repli sur la transcription)*
                     `app/domain/entities/crm/dictation_prompt.rb`
                     `app/jobs/crm/dictation_job.rb`
                     `app/controllers/teams/crm/dictations_controller.rb`
                     `app/views/teams/crm/dictations/new.html.erb` · `_recorder.html.erb` · `_prefilled.html.erb` *(rend `interactions/_form` du Lot C)*
                     `app/javascript/controllers/voice_recorder_controller.js`
                     `config/locales/teams/crm/dictations.fr.yml`
- **Dépend de**    : Lot C, Lot G
- **Test associé** : `test/domain/use_cases/crm/submit_dictation_test.rb` (CA-26) · `test/domain/entities/crm/dictation_draft_test.rb` (CA-27) · `test/jobs/crm/dictation_job_test.rb` (CA-25 : audio purgé) · `test/controllers/teams/crm/dictations_controller_test.rb` · `test/system/teams/crm_dictation_test.rb`
- **Done quand**   : avec le faux modèle, un enregistrement de 40 s ouvre « Noter un échange » pré-rempli ; rien n'est enregistré avant validation ; l'audio a disparu du stockage ; 12 Mo ou `audio/wav` sont refusés ; le vrai modèle audio d'OpenRouter est vérifié une fois à la main (sinon : repli transcription, noté au journal)

---

## Rattachement des critères d'acceptation

| Critères | Lot |
|---|---|
| CA-01, CA-02 | Lot 0 (et 403 rejoué par chaque contrôleur de lot) |
| CA-03, CA-04, CA-05 | Lot 0 (`Stage`) |
| CA-06, CA-07, CA-08 | Lot A |
| CA-09, CA-10 | Lot B |
| CA-11, CA-12 | Lot C |
| CA-13, CA-14 | Lot D |
| CA-15 à CA-20 | Lot E |
| CA-21 | Lot F |
| CA-23 | Lot G |
| CA-22, CA-24 | Lot H |
| CA-28 | Lot I |
| CA-29, CA-30 | Lot J |
| CA-25, CA-26, CA-27 | Lot K |

Aucun critère orphelin.

---

## Vérification de collision

> Deux lots parallèles ne listent jamais le même fichier. Les doublons ci-dessous sont **en série** (dépendance), jamais en parallèle.

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/teams.rb` | Lot 0 |
| `config/locales/teams/crm/common.fr.yml` | Lot 0 (chaque lot a son propre fichier `config/locales/teams/crm/<lot>.fr.yml`) |
| `config/locales/shared/navigation.fr.yml`, `app/helpers/navigation_helper.rb` | Lot 0 |
| `db/migrate/*_create_crm_tables.rb`, `app/infrastructure/orm/crm_*.rb` | Lot 0 |
| `app/domain/ports/crm/*` | Lot 0 (gelés) |
| `app/infrastructure/repositories/crm/follow_up_repository.rb` | Lot 0 (utilisé par C et D) |
| `app/domain/entities/identity/audit_action.rb` | Lot 0 |
| `app/views/teams/schools/show.html.erb`, `app/views/teams/homes/show.html.erb` | Lot 0 |
| `app/controllers/teams/schools_controller.rb` | Lot 0 (`#show`), puis Lot F (`#index`) **en série** |
| `app/controllers/teams/crm/follow_ups_controller.rb`, `app/views/teams/crm/follow_ups/index.html.erb` | Lot D, puis Lot E **en série** |
| `app/views/teams/crm/interactions/_form.html.erb` | Lot C ; le Lot K le **rend** sans le modifier |
| `test/support/fake_language_model.rb` | Lot 0 |
| `test/fixtures/` | Aucun lot ne modifie de fixture partagée ; s'il en faut une pour `crm_*`, elle remonte au Lot 0 |

Contrôle mécanique à relancer après toute modification du plan :

```bash
awk '/^## Vérification de collision/{exit} 1' docs/chantiers/crm-ecoles/plan.md \
  | grep -oE '(app|test|config|db|lib)/[A-Za-z0-9_/.-]+\.(rb|erb|yml|js)' | sort | uniq -d
```

Sortie attendue : `app/controllers/teams/crm/follow_ups_controller.rb`, `app/controllers/teams/schools_controller.rb`, `app/views/teams/crm/follow_ups/index.html.erb` (tous en série, voir le tableau).

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Pour ce chantier : il refait le parcours nominal du PRD §3 (filtre du pipeline → fiche → briefing → dictée → relance → brouillon WhatsApp → rapport) avec un compte `field`, à 390 px et sur ordinateur, puis deux chemins d'erreur : un compte `content` qui tente une adresse du suivi (403), et l'assistant sans clé OpenRouter (« Assistant non configuré »).
