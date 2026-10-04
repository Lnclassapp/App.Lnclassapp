# Plan d'exécution — Annonces ciblées, programmables et écartables

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Entrées : [memo](memo.md) · [PRD](prd.md) · [ADR-0078](../../decisions/adr/0078-annonces-trois-auteurs-classes-ciblees-et-retrait.md) (amende l'[ADR-0045](../../decisions/adr/0045-annonces-publication-programmee-et-audience.md)) · [UDR-0071](../../decisions/udr/0071-annonces.md).

**Condition d'entrée du Lot 0** (programme `refonte-application`, [`programme.md` §2](../../workflows/programme.md#2-décider--prdmd-cadre--adrudr-de-fondation)) : l'**ADR-0078** et l'**UDR-0071** sont `Accepté` par le porteur. Une décision « Proposé » ne débloque rien. **Tenue : acceptées le 2026-10-03.**

## Graphe

```
Lot 0 — SOCLE (séquentiel)
  schéma · entités · ports partagés et leurs adaptateurs · routes · locales partagées
  composants partagés (toast avec action, cases à cocher, onglets, illustrations) · fabriques de test
  ↓
  ├─► Lot A « Rédiger et gérer ses annonces »  ┐  en parallèle, worktrees isolés
  └─► Lot B « Lire, écouter et masquer »        ┘
                    ↓ (B : la carte et sa query)
        Lot C « Retirer une annonce »
                    ↓ (A, B, C)
        Lot D « Navigation et parcours de bout en bout »
```

Pourquoi C attend B : la modération affiche **la carte** (`_card`, `MessageCard`), que le Lot B construit avec la lecture. La mettre au Lot 0 aurait gonflé le socle d'un écran complet ; C est court.

Pourquoi D existe : `test/system/role_homes_test.rb` compte les entrées de navigation de chaque rôle et les suit toutes. Une entrée « Annonces » ajoutée avant que ses pages existent casse ce test dans chaque worktree. Les entrées naissent donc quand A, B et C sont mergés.

**Ports propres à un seul lot** : `DismissalRepositoryPort` et `ReadableMessagesPort` n'ont qu'un consommateur, le Lot B. Ils naissent avec leur adaptateur dans le Lot B (`test/architecture/port_contracts_test.rb` exige un adaptateur par port, dès qu'un port existe). Ce ne sont pas des contrats entre lots ; les ports partagés, eux, sont gelés au Lot 0.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + composants partagés
- **Fichiers**     : `db/migrate/<horodatage>_create_messages.rb`
                     `db/migrate/<horodatage>_create_message_classrooms.rb`
                     `db/migrate/<horodatage>_create_message_dismissals.rb`
                     `db/schema.rb`
                     `app/infrastructure/orm/message.rb` · `app/infrastructure/orm/message_classroom.rb` · `app/infrastructure/orm/message_dismissal.rb`
                     `app/domain/entities/communication/message.rb` (constantes, `frozen?`, `by_classrooms?`, `official?`, `moderatable_by?(actor, author_role:)`)
                     `app/domain/entities/communication/reader.rb`
                     `app/domain/entities/communication/audio_header.rb`
                     `app/domain/entities/identity/audit_action.rb` (+ `message.published`, `message.withdrawn`)
                     `app/domain/ports/communication/message_repository_port.rb`
                     `app/domain/ports/communication/attachment_store_port.rb`
                     `app/infrastructure/repositories/communication/message_repository.rb`
                     `app/infrastructure/repositories/communication/attachment_store.rb`
                     `config/routes/communication.rb` *(toutes les routes du chantier, ADR-0078 §6 et UDR-0071)*
                     `config/locales/communication/messages.fr.yml` *(libellés partagés : illustrations, statuts, destinataires, onglets, signature)*
                     `config/locales/shared/navigation.fr.yml` (`navigation.announcements`, `home.sections.announcements`)
                     `app/helpers/navigation_helper.rb` (`HOME_SECTIONS[:student]` seulement)
                     `app/helpers/components_helper.rb` (`ui_toast(action:)`, `turbo_stream_toast(action:)`, `ui_checkbox_group`)
                     `app/views/components/_toast.html.erb` · `app/views/components/_checkbox_group.html.erb`
                     `app/helpers/communication/illustrations_helper.rb` (`announcement_illustration`)
                     `app/views/communication/messages/illustrations/_info.html.erb` … `_holidays.html.erb` *(8 partiels, UDR-0071 §3.3)*
                     `app/views/communication/shared/_tabs.html.erb`
                     `app/views/design/index.html.erb` (vitrine des huit illustrations)
                     `test/support/factories/communication.rb` (`create_message`, `dismiss_message`)
- **Dépend de**    : — *(ADR-0078 et UDR-0071 acceptés)*
- **Test associé** : `test/domain/entities/communication/message_test.rb` · `test/domain/entities/communication/audio_header_test.rb` (mp3 ID3, mp3 sans ID3, m4a, wav et PDF refusés)
                     `test/infrastructure/orm/communication/message_constraints_test.rb` (chaque `CHECK` de l'ADR-0078 §4.1 refuse une ligne fautive ; unicité des rejets et des classes ciblées)
                     `test/infrastructure/repositories/communication/message_repository_test.rb` · `attachment_store_test.rb` (lecture d'une plage)
                     `test/helpers/components_helper_test.rb` (toast avec action, groupe de cases) · `test/helpers/communication/illustrations_helper_test.rb` (8 clés, aucune couleur hors tokens)
                     `test/routing/communication_routes_test.rb` (noms et verbes des routes, `public_id` et jamais d'`:id`)
- **Done quand**   : les trois tables existent avec leurs contraintes, les huit illustrations s'affichent sur `design/index`, `bin/rails runner "puts Entities::Communication::Message.name"` répond, et la suite complète reste verte (aucune entrée de navigation n'a changé). **AN-20** (côté entité).

---

## Lot A — Rédiger et gérer ses annonces (équipe, direction, enseignant)

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/dtos/communication/message_input.rb`
                     `app/domain/policies/communication/publish_policy.rb` · `app/domain/policies/communication/manage_own_policy.rb`
                     `app/domain/use_cases/communication/create_message.rb` · `update_message.rb` · `archive_message.rb` · `publish_scheduled_messages.rb`
                     `app/infrastructure/queries/communication/authored_messages_query.rb`
                     `app/jobs/communication/publish_scheduled_messages_job.rb` · `config/recurring.yml`
                     `app/controllers/communication/authored_messages_controller.rb` · `app/controllers/communication/message_archives_controller.rb`
                     `app/views/communication/authored_messages/index.html.erb` · `new.html.erb` · `edit.html.erb` · `_form.html.erb` · `_row.html.erb`
                     `app/views/teams/schools/_header.html.erb` (entrée « Publier une annonce »)
                     `config/locales/communication/authored_messages.fr.yml` · `config/locales/communication/message_archives.fr.yml`
                     `test/architecture/use_case_policies_test.rb` (`PublishScheduledMessages` dans `EXEMPT`, avec sa raison)
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/policies/communication/publish_policy_test.rb` (un refus par acteur et par portée) · `manage_own_policy_test.rb`
                     `test/domain/dtos/communication/message_input_test.rb` (longueurs, dates, PDF déguisé, tailles, formats)
                     `test/domain/use_cases/communication/create_message_test.rb` · `update_message_test.rb` (rejets effacés, `edited_at`) · `archive_message_test.rb` · `publish_scheduled_messages_test.rb`
                     `test/jobs/communication/publish_scheduled_messages_job_test.rb`
                     `test/infrastructure/queries/communication/authored_messages_query_test.rb` (statut « Terminée » déduit)
                     `test/controllers/communication/authored_messages_controller_test.rb` · `message_archives_controller_test.rb`
- **Done quand**   : un enseignant, une direction et l'équipe publient, programment, modifient et archivent leurs annonces depuis « Mes annonces » ; une annonce programmée paraît après le passage du job ; toute tentative hors droit est refusée. **AN-04, AN-06, AN-07, AN-14, AN-15, AN-18 (validation), AN-23**, et le versant écriture de **AN-01, AN-02, AN-03, AN-05, AN-08, AN-19**.

---

## Lot B — Lire, écouter et masquer (carrousel de l'accueil élève, « Reçues », fichiers)

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/ports/communication/dismissal_repository_port.rb` · `app/domain/ports/communication/readable_messages_port.rb`
                     `app/infrastructure/repositories/communication/dismissal_repository.rb`
                     `app/infrastructure/queries/communication/readable_messages.rb` *(la règle de lecture, seule définition)*
                     `app/infrastructure/queries/communication/inbox_query.rb` (+ `MessageCard`)
                     `app/domain/policies/communication/dismiss_policy.rb` · `app/domain/policies/communication/read_file_policy.rb`
                     `app/domain/use_cases/communication/dismiss_message.rb` · `restore_message.rb` · `read_message_file.rb`
                     `app/controllers/communication/inboxes_controller.rb` · `message_dismissals_controller.rb` · `message_files_controller.rb`
                     `app/controllers/classroom/student_homes_controller.rb`
                     `app/helpers/communication/messages_helper.rb` (`announcement_signature`)
                     `app/views/communication/messages/_card.html.erb` · `_carousel.html.erb`
                     `app/views/communication/inboxes/show.html.erb`
                     `app/views/communication/message_dismissals/create.turbo_stream.erb` · `destroy.turbo_stream.erb`
                     `app/views/classroom/student_homes/show.html.erb`
                     `app/javascript/controllers/communication/audio_controller.js` · `app/javascript/controllers/communication/carousel_controller.js`
                     `config/locales/communication/inboxes.fr.yml` · `config/locales/communication/message_dismissals.fr.yml` · `config/locales/classroom/student_homes.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/communication/readable_messages_test.rb` (**une condition par test**, ADR-0078 §7)
                     `test/infrastructure/queries/communication/inbox_query_test.rb` (ordre, plafond de 5, masquées, nombre de requêtes constant)
                     `test/domain/policies/communication/dismiss_policy_test.rb` · `read_file_policy_test.rb`
                     `test/domain/use_cases/communication/dismiss_message_test.rb` · `restore_message_test.rb` · `read_message_file_test.rb`
                     `test/controllers/communication/inboxes_controller_test.rb` · `message_dismissals_controller_test.rb` · `message_files_controller_test.rb` (404 hors audience, avant publication, après la fin, archivée, retirée ; `206` sur une plage)
                     `test/controllers/classroom/student_homes_controller_test.rb` · `test/helpers/communication/messages_helper_test.rb`
                     `test/system/communication/student_announcements_test.rb` (carrousel, ▶, masquer, Annuler, « Toutes les annonces »)
- **Done quand**   : un élève voit sur son accueil les annonces qui lui sont destinées, dans l'ordre et au plafond prévus, les écoute, les masque et annule ; un enseignant et une direction les lisent dans « Reçues » ; aucun fichier ne sort hors de la règle de lecture. **AN-09, AN-10, AN-11, AN-12, AN-13, AN-21**, **AN-18 (affichage)**, **AN-20 (affichage)**, et le versant lecture de **AN-01, AN-02, AN-03, AN-05, AN-08, AN-19**.

---

## Lot C — Retirer une annonce (équipe, direction)

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/policies/communication/withdraw_policy.rb`
                     `app/domain/use_cases/communication/withdraw_message.rb`
                     `app/infrastructure/queries/communication/moderation_query.rb`
                     `app/controllers/communication/moderations_controller.rb` · `app/controllers/communication/message_withdrawals_controller.rb`
                     `app/views/communication/moderations/index.html.erb` · `_moderated_message.html.erb`
                     `app/views/communication/message_withdrawals/create.turbo_stream.erb`
                     `config/locales/communication/moderations.fr.yml` · `config/locales/communication/message_withdrawals.fr.yml`
- **Dépend de**    : Lot B *(la carte et `MessageCard`)*
- **Test associé** : `test/domain/policies/communication/withdraw_policy_test.rb` (enseignant ; direction d'une autre école ; direction sur l'équipe ou une autre direction ; annonce déjà figée)
                     `test/domain/use_cases/communication/withdraw_message_test.rb` (`message.withdrawn` journalisé avec l'acteur)
                     `test/infrastructure/queries/communication/moderation_query_test.rb` (filtre par établissement, périmètre de la direction)
                     `test/controllers/communication/moderations_controller_test.rb` · `message_withdrawals_controller_test.rb`
- **Done quand**   : l'équipe retire n'importe quelle annonce d'un autre auteur depuis « Toutes », la direction celles de ses enseignants depuis « Enseignants » ; l'annonce disparaît pour son audience, et son auteur la voit « Retirée », sans pouvoir la republier. **AN-16, AN-17**.

---

## Lot D — Navigation et parcours de bout en bout

- **Couche**       : delivery + ui + tests système
- **Fichiers**     : `app/helpers/navigation_helper.rb` (`DESTINATIONS` des trois rôles adultes, `NAV_GRIDS` à 6)
                     `test/helpers/navigation_helper_test.rb`
                     `test/system/role_homes_test.rb` · `test/system/design_system_test.rb`
                     `test/system/communication/announcements_journey_test.rb`
- **Dépend de**    : Lots A, B et C
- **Test associé** : `test/system/communication/announcements_journey_test.rb` — parcours nominal du PRD §3 (M. Kouassi publie pour 3ème B et 3ème C avec un audio ; Awa le lit, l'écoute, le masque sur un téléphone et le retrouve « Masquée ») et un chemin d'erreur (Fatou retire l'annonce ; Awa ne la lit plus, son audio répond 404) ; `test/system/role_homes_test.rb` (« Annonces » active pour l'enseignant, la direction et l'équipe ; absente chez l'élève)
- **Done quand**   : chaque rôle adulte atteint « Annonces » par sa navigation, en bureau comme en barre basse, et le parcours nominal du PRD se joue de bout en bout en navigateur réel. **AN-22**.

---

## Dispatch

```
Vague 1 : Lot 0              → 1 agent, séquentiel, sur feature/annonces-lot-0
Vague 2 : Lot A ‖ Lot B      → 2 agents, worktrees isolés
Vague 3 : Lot C              → 1 agent (dès que B est mergé ; peut chevaucher la fin de A)
Vague 4 : Lot D              → 1 agent
```

Worktree de lot, **depuis la branche de chantier** une fois le lot précédent mergé :

```bash
git worktree add ../lnclass-annonces-lot-a -b feature/annonces-lot-a feature/annonces
git worktree add ../lnclass-annonces-lot-b -b feature/annonces-lot-b feature/annonces
```

Brief de chaque agent : chemin **absolu** du worktree (`git -C <worktree>`), son lot recopié en entier, le [PRD](prd.md), l'[ADR-0078](../../decisions/adr/0078-annonces-trois-auteurs-classes-ciblees-et-retrait.md) §4 et §6, l'[UDR-0071](../../decisions/udr/0071-annonces.md) pour toute vue ; ordre imposé : test rouge → domaine → infrastructure → delivery → UI ; en-tête HITL sur chaque fichier de `app/`. **Interdiction de toucher un fichier hors de son champ `Fichiers`** : s'il en faut un, l'agent s'arrête et remonte (Lot 0 à rouvrir, ou plan faux). Aucun lot ne redéfinit un port du Lot 0.

---

## Vérification de collision

> Rempli avant de lancer les lots parallèles. Détection mécanique : `awk '/^## Vérification de collision/{exit} 1' docs/chantiers/annonces/plan.md | grep -oE '(app|test|config|db|lib)/[A-Za-z0-9_/.-]+\.(rb|erb|yml|js)' | sort | uniq -d`.

| Fichier | Lot propriétaire | Remarque |
|---|---|---|
| `config/routes/communication.rb` | Lot 0 | toutes les routes, même celles des lots A, B, C |
| `config/locales/shared/navigation.fr.yml` | Lot 0 | libellé posé tôt, entrée ajoutée au Lot D |
| `config/locales/communication/messages.fr.yml` | Lot 0 | libellés communs à A, B, C ; chaque lot a ensuite **son** fichier de locale |
| `app/helpers/components_helper.rb`, `_toast`, `_checkbox_group` | Lot 0 | `ui_toast(action:)` sert B, `ui_checkbox_group` sert A : remontés au Lot 0 |
| illustrations et `illustrations_helper.rb` | Lot 0 | formulaire (A) et carte (B) |
| `communication/shared/_tabs.html.erb` | Lot 0 | pages de A, B, C |
| `app/views/design/index.html.erb` | Lot 0 | vitrine des illustrations ; ajouté au plan au lancement du Lot 0 |
| `message_repository.rb`, `attachment_store.rb` (+ ports) | Lot 0 | A écrit, B et C lisent |
| `app/domain/entities/identity/audit_action.rb` | Lot 0 | `message.published` (A), `message.withdrawn` (C) |
| `test/support/factories/communication.rb` | Lot 0 | données de test de tous les lots |
| `app/helpers/navigation_helper.rb` | **Lot 0 puis Lot D** | séquentiels, jamais en parallèle : Lot 0 change `HOME_SECTIONS` (carrousel du Lot B), Lot D change `DESTINATIONS` et `NAV_GRIDS`. La détection mécanique le signale ; c'est voulu |
| `app/controllers/classroom/student_homes_controller.rb`, `student_homes/show`, `student_homes.fr.yml` | Lot B | seul lot à toucher l'accueil élève |
| `app/views/teams/schools/_header.html.erb` | Lot A | seul lot à toucher la fiche d'établissement |
| `config/recurring.yml`, `test/architecture/use_case_policies_test.rb` | Lot A | |
| `app/views/communication/messages/_card.html.erb`, `inbox_query.rb` (`MessageCard`) | Lot B | lus par C, qui attend B |
| `test/system/role_homes_test.rb`, `design_system_test.rb`, `navigation_helper_test.rb` | Lot D | |
| `db/schema.rb` | Lot 0 | aucune migration hors du Lot 0 |
| `test/infrastructure/orm/models_test.rb`, `test/db/schema_constraints_test.rb`, `test/controllers/design_controller_test.rb`, `config/locales/design/index.fr.yml` | Lot 0 | hors du champ initial, touchés par le Lot 0 (compte des modèles, cascade, vitrine) ; aucun autre lot ne les touche |

Critères orphelins : **aucun**. AN-01 à AN-23 sont tous rattachés (voir « Done quand »).

---

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md`
- [x] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md`
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

Propres à ce chantier :

- [x] ADR-0078 et UDR-0071 `Accepté` **avant** le Lot 0 (programme, décisions de fondation)
- [ ] Registre des contradictions de la feuille de route mis à jour (PRD cadre ↔ ADR-0045, design system §10 ↔ ADR-0045, ADR-0065 ↔ ce chantier) ; fiche V6 précisée (« riches » = image et audio)
- [ ] Budget de l'accueil élève (ADR-0067) tenu avec le carrousel : nombre de requêtes constant, mesuré

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Pour ce chantier : il publie comme enseignant une annonce avec un audio pour deux classes, la lit et l'écoute comme élève d'une de ces classes sur un téléphone (viewport mobile), la masque, annule, la masque encore ; puis, comme élève d'une **autre** classe, il demande l'adresse de l'audio et doit obtenir 404 ; enfin, comme équipe, il la retire et vérifie qu'elle a disparu du carrousel.
