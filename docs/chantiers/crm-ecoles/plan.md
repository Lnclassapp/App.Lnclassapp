# Plan d'exécution — CRM des écoles (« Lnclass Intelligent »)

> Graphe des dépendances ci-dessous ; l’ordre réel (3 lots en parallèle au plus, 2 sessions) est dans « Dispatch ».
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Specs : [`prd.md`](prd.md) · Décisions : ADR-XXXX-contexte-crm-suivi-des-ecoles, ADR-XXXX-modeles-de-langage-par-openrouter, UDR-XXXX-bloc-suivi-de-la-fiche-etablissement, UDR-XXXX-pipeline-et-relances, UDR-XXXX-assistants-du-suivi.

## Graphe

```
Lot 0 — SOCLE : tables, entités, ports, policy, routes, hôtes des frames, usage par école, membres assignables
  ↓
  ├─► Lot A  Étape, responsable, usage            ┐
  ├─► Lot B  Contacts                             │
  ├─► Lot C  Journal des échanges                 ├─ dépendent du seul Lot 0
  ├─► Lot D  Relances (créer, terminer, réattribuer, page)
  ├─► Lot F  Pipeline sur « Établissements »      │
  └─► Lot G  Socle IA (OpenRouter, générations, carte Assistants)
        ↓
  Lot D ──► Lot E  À relancer (règle calculée, onglet, carte Accueil)   ┐
  Lot G ──► Lot H  Fiche de briefing                                     │
  Lot G ──► Lot I  Brouillon de relance WhatsApp                         ├─ dépendent d’un lot ci-dessus
  Lot G ──► Lot J  Rapport pédagogique                                   │
  Lot C + Lot G ──► Lot K  Compte rendu dicté                            ┘
```

**Pourquoi chaque sous-bloc de la fiche est un frame à part** (UDR-XXXX-bloc-suivi-de-la-fiche-etablissement) : le Lot 0 pose une coquille statique avec six `turbo-frame` paresseux ; chaque lot sert le sien par son propre contrôleur. Aucun lot ne touche le fichier d'un autre, et un sous-bloc en erreur ne casse pas les autres.

**Ordre de coupe** si le délai glisse : Lot K, puis Lot J. Le Lot H ne se coupe pas.

## Dispatch

Touré exécute **tous les lots**, en **3 jours** (jeudi 5 au samedi 7 novembre), avec deux limites fixées par le porteur : **3 lots en parallèle au plus**, **2 sessions Claude ouvertes au plus**.

| Session | Rôle | Lots |
|---|---|---|
| **Session 1 — Suivi** | Socle, métier du suivi, **seule à fusionner** dans `feature/crm-ecoles` | 0, C, D, A, E, B, F, K |
| **Session 2 — IA** | Assistants | G, H, I, J |

Dans chaque session, un agent `executant-lot` (Sonnet) par lot, chacun dans son worktree. La session 2 pousse ses branches de lot ; la session 1 les fusionne. Une seule session fusionne : pas de course sur la branche de chantier.

```
            Session 1 (Suivi)          Session 2 (IA)         Lots en parallèle
Jeu 5 matin   Lot 0                      —                     1
Jeu 5 après-m C ‖ D                      G                     3
Ven 6 matin   A ‖ E (après D)            H (après G)           3
Ven 6 après-m B ‖ F                      I (après G)           3
Sam 7 matin   K (après C et G)           J (après G)           2
Sam 7 après-m Revues, bin/ci-quiet, captures, PR prête → Konan teste → le porteur teste et fusionne
```

**Pourquoi cet ordre** : les lots qui débloquent le plus partent d'abord (G débloque H, I, J, K ; C débloque K ; D débloque E). Les lots qu'on coupe en premier (K, puis J) passent en dernier : si le samedi matin déborde, on les retire sans rien casser. H, le seul lot IA qui ne se coupe jamais, passe dès le vendredi matin.

**Une vague ne démarre que si la précédente est fusionnée** dans `feature/crm-ecoles` (session 1), sauf dépendance explicite déjà satisfaite. Entre deux lots : tests des fichiers touchés et `bin/system-changed` ; `bin/ci-quiet` une seule fois, samedi après-midi, sur le head final.

Worktree d'un lot, créé **après** la fusion du Lot 0 et depuis la branche de chantier à jour :

```bash
git -C /chemin/App.Lnclassapp pull origin feature/crm-ecoles
```

```bash
git worktree add ../lnclass-crm-ecoles-lot-c -b feature/crm-ecoles-lot-c feature/crm-ecoles
```

Consignes à chaque agent : chemins **absolus** (`git -C <worktree>`) ; **interdiction de toucher un fichier hors de son champ `Fichiers`** — s'il en a besoin, il s'arrête et remonte (le fichier appartient au Lot 0 ou le plan est faux) ; ordre intra-lot : test rouge → domaine → infrastructure → delivery → vue ; en-tête HITL sur chaque fichier de `app/`.

### Calendrier

| Jour | Travail |
|---|---|
| Jeu 5 nov. | Lot 0 le matin ; C, D, G l'après-midi |
| Ven 6 nov. | A, E, H le matin ; B, F, I l'après-midi |
| Sam 7 nov. | K, J le matin ; l'après-midi : revues (`security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`), `bin/ci-quiet`, captures 390 px et ordinateur, PR prête ; test de Konan, puis du porteur ; fusion dans `Develop` |
| Lun 9 – Ven 13 | Rapport de stage, corrections éventuelles |
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
                     `db/seeds/development.rb` *(deux comptes équipe fictifs, PIN 2468 : `0700000001` `field`, `0700000002` `content`)*
                     *Squelettes de contrôleur et de vue (arbitrage du porteur : tout frame ou lien que le Lot 0 pose doit répondre ; chacun hérite de `Teams::Crm::BaseController` et rend son frame vide, puis passe au lot nommé)* :
                     `app/controllers/teams/crm/stages_controller.rb` · `usages_controller.rb` (Lot A) · `contacts_controller.rb` (Lot B) · `interactions_controller.rb` (Lot C) · `follow_ups_controller.rb` (`#school`, `#index` : Lot D) · `home_follow_ups_controller.rb` (Lot E) · `assistants_controller.rb` (Lot G)
                     `app/views/teams/crm/stages/show.html.erb` · `usages/show.html.erb` · `contacts/index.html.erb` · `interactions/index.html.erb` · `follow_ups/school.html.erb` · `follow_ups/index.html.erb` · `home_follow_ups/show.html.erb` · `assistants/show.html.erb`
                     *Adaptateurs squelettes (chaque méthode a la signature du port et lève `NotImplementedError, "Lot X"`, pour que `port_contracts_test` reste vert)* :
                     `app/infrastructure/repositories/crm/account_repository.rb` (Lot A) · `contact_repository.rb` (Lot B) · `interaction_repository.rb` (Lot C) · `generation_repository.rb` (Lot G) · `app/infrastructure/crm/open_router_language_model.rb` (Lot G)
                     `test/db/schema_constraints_test.rb` *(liste fermée `CRM_CASCADES`)* · `docs/guide/architecture.md` §5 *(sept contextes)* · `docs/decisions/adr/XXXX-modeles-de-langage-par-openrouter.md` *(échecs du port : `:unavailable` + `errors[:reason]` ; `mark_failed`)*
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/crm/stage_test.rb` (CA-03, CA-04, CA-05) · `test/domain/policies/crm/manage_crm_policy_test.rb` · `test/infrastructure/queries/crm/school_usage_query_test.rb` · `test/infrastructure/queries/crm/assignable_members_query_test.rb` · `test/infrastructure/repositories/crm/follow_up_repository_test.rb` · `test/controllers/teams/crm/accounts_controller_test.rb` (CA-01, CA-02 : 403 pour `content` et enseignant ; frame absent de la fiche pour `content`)
- **Done quand**   : après le seed, on se connecte avec `0700000001` (`field`) et `0700000002` (`content`) ; un membre `field` ouvre une fiche établissement et voit le bloc « Suivi » et ses six squelettes ; un membre `content` ne le voit pas et reçoit 403 sur `/teams/schools/:id/follow-up` ; `bin/rails runner "puts Ports::Crm::LanguageModelPort.name"` passe ; les ports sont gelés

---

## Lot 0 bis — Correction des contrats communs

*Réouverture du Lot 0, décidée par l'orchestrateur après les Lots C, D, G et H.*

- **Couche**       : domaine (ports, entité, use case) + infrastructure (dépôts, job) + delivery + UI
- **Fichiers**     : `app/domain/ports/crm/interaction_repository_port.rb` · `follow_up_repository_port.rb` *(+ `contact_public_id:`, `interaction_public_id:`)*
                     `app/infrastructure/repositories/crm/interaction_repository.rb` · `follow_up_repository.rb` · `generation_repository.rb` *(`created_at`)*
                     `app/domain/entities/crm/generation.rb` *(+ `created_at`, facultatif à la construction)* · `app/domain/use_cases/crm/record_interaction.rb`
                     `app/controllers/teams/crm/interactions_controller.rb` *(`contact_public_id:`)* · `app/jobs/crm/briefing_job.rb` *(commentaire)*
                     `app/jobs/crm/generation_job.rb` *(réponse vide ou illisible : `invalid_response`)*
                     `app/helpers/components_helper.rb` · `app/views/components/_error_state.html.erb` *(`retry_method:`)*
                     `app/controllers/teams/crm/generations_controller.rb` *(table type → route de relance, partial prêt)* · `app/views/teams/crm/generations/{show,_generation}.html.erb`
                     `app/views/teams/crm/briefings/_briefing.html.erb` · `config/locales/teams/crm/briefings.fr.yml` *(« Préparée il y a X »)*
                     `docs/decisions/adr/XXXX-contexte-crm-suivi-des-ecoles.md` · `docs/decisions/udr/XXXX-assistants-du-suivi.md`
- **Dépend de**    : Lots 0, C, D, G, H
- **Test associé** : `test/domain/use_cases/crm/record_interaction_test.rb` · `test/infrastructure/repositories/crm/{interaction,follow_up,generation}_repository_test.rb` · `test/controllers/teams/crm/generations_controller_test.rb` · `test/helpers/components_helper_test.rb` · `test/jobs/crm/generation_job_test.rb`
- **Done quand**   : un échange noté avec un contact a son `contact_id` ; la relance proposée a son `interaction_id` ; un identifiant public inconnu est refusé (`:not_found`) ; « Réessayer » relance réellement une génération (POST) ; la fiche prête d'un briefing, relue par le sondage, montre la liste et « Régénérer » ; « Préparée il y a X » ; une réponse vide est `invalid_response`

---

## Lot A — Étape, responsable et usage

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/crm/set_stage.rb` · `assign_owner.rb`
                     `app/infrastructure/repositories/crm/account_repository.rb`
                     `app/controllers/teams/crm/stages_controller.rb` *(`#show`, `#update`)* · `owners_controller.rb` *(`#edit`, `#update`)* · `usages_controller.rb` *(`#show`)* *(squelettes de stages et usages posés par le Lot 0)*
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
                     `app/controllers/teams/crm/contacts_controller.rb` *(`#index`, `#new`, `#create`, `#archive` en GET pour la confirmation, `#destroy` ; squelette du Lot 0)*
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
                     `app/controllers/teams/crm/follow_ups_controller.rb` *(`#index`, `#school`, `#new`, `#create` ; squelette du Lot 0)* · `follow_up_completions_controller.rb` *(`#update`)* · `follow_up_assignees_controller.rb` *(`#edit`, `#update`)* *(routes gelées par le Lot 0 : `complete.turbo_stream.erb` et `reassign.turbo_stream.erb` sont rendus explicitement par `update`)*
                     `app/views/teams/crm/follow_ups/index.html.erb` *(page « Relances », onglets « Mes relances » et « Sans destinataire »)* · `school.html.erb` *(frame de la fiche)* · `_follow_up.html.erb` · `_form.html.erb` · `new.html.erb` · `_assignee_form.html.erb` · `edit.html.erb` · `create.turbo_stream.erb` · `complete.turbo_stream.erb` · `reassign.turbo_stream.erb`
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
                     `app/controllers/teams/crm/pedagogy_reports_controller.rb` *(`#create` : POST depuis la carte puis redirection ; `#show` : `/teams/pedagogy-reports/:public_id`)*
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

### Menace — téléversement audio (Lot K)

- **Ce qui entre** : un fichier `audio` envoyé en `multipart` par un membre `admin` ou `field` (ManageCrmPolicy ; `content` reçoit 403). Rien d'autre n'est lu de la requête : ni durée, ni nom, ni extension, ni `content_type` annoncé par le navigateur, qui ne servent jamais à décider.
- **Taille** : 10 Mo au plus. **La vraie borne du corps est 55 Mo, posée par Puma (`http_content_length_limit`, `config/puma.rb`)** : Rack lit le multipart (et l'écrit sur disque) avant le contrôleur, quoi que fasse le contrôleur ensuite. Le 422 sur `Content-Length` (plus de 11 Mo) ne protège donc pas le serveur : il sert l'interface (message clair, rien de gardé). La taille réelle du fichier reçu est revérifiée dans le use case (10 Mo). Un fichier vide est refusé. Test : contrôleur (requête annonçant plus de 11 Mo : 422 et rien de stocké) + `submit_dictation_test` (taille réelle).
- **Type réel** : détecté par les octets magiques (Marcel, sans nom ni type annoncé). Liste blanche : webm/matroska (`MediaRecorder` Chrome, Firefox), ogg, mp4/m4a (Safari). `audio/wav` (RIFF), texte, image, HTML : refusés (CA-26) ; des octets webm annoncés `audio/wav` passent, des octets wav annoncés `audio/webm` sont refusés. Test : `submit_dictation_test` et contrôleur.
- **Durée** : les 3 min ne sont contrôlées que dans le navigateur (`voice-recorder`) ; le serveur ne décode pas l'audio, il ne la connaît donc pas et ne la croit pas : c'est la taille de 10 Mo qui borne. Aucun analyseur audio côté serveur : l'audio n'est ni décodé, ni transcodé, ni lu ; la pièce est créée « déjà analysée » pour qu'Active Storage ne lance pas ffprobe dessus (test : `dictation_job_test`, `blob.analyzed?`).
- **Ordre** : tous les refus ont lieu avant tout appel au modèle et avant tout stockage durable (aucune génération n'est créée, aucune pièce attachée). Test : le faux modèle n'est pas appelé, `Orm::CrmGeneration` et `ActiveStorage::Blob` ne bougent pas.
- **Stockage** : pièce jointe privée de `Orm::CrmGeneration#audio` (service Active Storage privé, jamais servi par une URL), pendant la durée du job seulement. Purgée dans un `ensure` du job, en succès comme en échec (CA-25). Test : `dictation_job_test` (succès, échec du modèle, exception).
- **Chez OpenRouter** : l'audio en base64 et une consigne fixe, rien d'autre (ni nom d'élève, ni numéro, ni historique de l'école). Aucun outil n'est donné au modèle.
- **À l'écran** : la réponse est validée par un schéma fermé (clés connues, listes de valeurs, longueurs du formulaire) ; sinon repli sur la transcription brute dans la note (CA-27). Elle pré-remplit un formulaire que l'humain valide : rien n'est enregistré avant. Elle est toujours affichée échappée par ERB (jamais `html_safe`). Test : `dictation_draft_test`, contrôleur avec `<script>` dans la réponse.
- **Une dictée à la fois par école** (index unique partiel) : une seconde envoyée pendant l'attente reçoit 409, et son audio n'est jamais stocké.
- **Résiduel accepté** : Rack écrit le corps multipart dans un fichier temporaire (jusqu'à 55 Mo, borne de Puma) avant tout contrôle de taille ; un fichier webm/matroska qui n'est pas de l'audio passe le contrôle des octets et est refusé par le fournisseur (échec `provider_error`, audio purgé).

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
| `app/controllers/teams/crm/{stages,usages}_controller.rb`, `app/views/teams/crm/{stages,usages}/show.html.erb`, `app/infrastructure/repositories/crm/account_repository.rb` | Lot 0 → Lot A (séquentiel) |
| `app/controllers/teams/crm/contacts_controller.rb`, `app/views/teams/crm/contacts/index.html.erb`, `app/infrastructure/repositories/crm/contact_repository.rb` | Lot 0 → Lot B (séquentiel) |
| `app/controllers/teams/crm/interactions_controller.rb`, `app/views/teams/crm/interactions/index.html.erb`, `app/infrastructure/repositories/crm/interaction_repository.rb` | Lot 0 → Lot C (séquentiel) |
| `app/controllers/teams/crm/follow_ups_controller.rb`, `app/views/teams/crm/follow_ups/{school,index}.html.erb` | Lot 0 → Lot D → Lot E (séquentiel) |
| `app/controllers/teams/crm/home_follow_ups_controller.rb`, `app/views/teams/crm/home_follow_ups/show.html.erb` | Lot 0 → Lot E (séquentiel) |
| `app/controllers/teams/crm/assistants_controller.rb`, `app/views/teams/crm/assistants/show.html.erb`, `app/infrastructure/repositories/crm/generation_repository.rb`, `app/infrastructure/crm/open_router_language_model.rb` | Lot 0 → Lot G (séquentiel) |
| `test/db/schema_constraints_test.rb`, `test/system/role_homes_test.rb` | Lot 0 (liste `CRM_CASCADES` ; entrée « Relances » du menu « Plus ») |
| Fichiers du Lot 0 bis (ports et dépôts `interaction`/`follow_up`/`generation`, `entities/crm/generation.rb`, `record_interaction.rb`, `generation_job.rb`, `components_helper.rb`, `_error_state`, `generations_controller.rb` et ses vues, `_briefing`, `briefings.fr.yml`) | Lot 0 bis, après les Lots C, D, G, H (séquentiel) ; le Lot 0 bis ne touche aucun fichier des Lots A et E |
| `test/fixtures/` | Aucun lot ne modifie de fixture partagée ; s'il en faut une pour `crm_*`, elle remonte au Lot 0 |

Contrôle mécanique à relancer après toute modification du plan :

```bash
awk '/^## Vérification de collision/{exit} 1' docs/chantiers/crm-ecoles/plan.md \
  | grep -oE '(app|test|config|db|lib)/[A-Za-z0-9_/.-]+\.(rb|erb|yml|js)' | sort | uniq -d
```

Sortie attendue : `follow_ups_controller.rb`, `stages_controller.rb`, `schools_controller.rb`, `open_router_language_model.rb`, `account_repository.rb`, `follow_ups/index.html.erb` et `stages/show.html.erb` (tous en série : squelette du Lot 0 puis lot propriétaire, voir le tableau).

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
> Pour ce chantier, **Konan puis le porteur** : Konan refait le parcours nominal du PRD §3 (filtre du pipeline → fiche → briefing → dictée → relance → brouillon WhatsApp → rapport) avec un compte `field`, à 390 px et sur ordinateur, puis deux chemins d'erreur : un compte `content` qui tente une adresse du suivi (403), et l'assistant sans clé OpenRouter (« Assistant non configuré »). Le porteur rejoue les deux chemins d'erreur, puis décide de la fusion.
