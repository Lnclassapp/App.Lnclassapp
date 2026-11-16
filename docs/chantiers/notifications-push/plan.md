# Plan d'exécution — Notifications poussées aux élèves

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

**Seulement Web Push** : la coque Android ne reçoit pas le Web Push, elle relèvera d'un chantier FCM séparé (ADR-0070). L'envoi se livre derrière `PUSH_DELIVERY_ENABLED` (faux par défaut) pour une mise en service progressive.

## Graphe

```
Lot 0 — SOCLE (séquentiel) : migration, entités, ports, 6 requêtes vides, routes, locales, gem, tâches récurrentes
  ↓
  ├─► Lot A  invitation + abonnement + interrupteur du profil (élève) ┐
  ├─► Lot B  moteur d'envoi Web Push + motif « inactif » + purge       │
  ├─► Lot C  motifs « devoir à rendre » et « préparer une interro »    │
  ├─► Lot D  motifs « exercice commencé » et « résultat/médaille »     ├─ en parallèle, fichiers disjoints
  ├─► Lot E  motif « annonce de l'équipe »                             │
  ├─► Lot G  fermeture de session et anonymisation                     │
  └─► Lot H  tuile du pilotage de l'équipe                             ┘
```

Vagues :

```
Jour 1 : Lot 0                                → 1 agent
         Lot A ‖ B ‖ C ‖ D ‖ E ‖ G ‖ H        → 7 agents, worktrees isolés depuis feature/notifications-push
```

Si la journée ne suffit pas, les lots restants repartent le lendemain de `Develop` à jour sur `feature/notifications-push-2`.

Contrats gelés au Lot 0, que les lots utilisent sans les changer :

- `Ports::Communication::PushCandidatesPort#for(now:)` → `[Entities::Communication::PushCandidate(user_id, motive, object_key, url, variables, valid_until)]` ; six requêtes `Queries::Communication::PushCandidates::<Motive>` créées **vides** (`[]`) au Lot 0, remplies chacune par son lot.
- `Queries::Communication::PushCandidates::LastActivity#at(user_ids:)` → `{ user_id => Time }` (définition de l'entonnoir), écrite au Lot 0, lue par B et D.
- `Ports::Communication::PushGatewayPort#deliver(subscription:, message:)` → `:delivered | :gone | :retry | :not_configured`.
- `Entities::Communication::PushMessage.for(candidate)` : les six gabarits (clés de `fr.yml` posées au Lot 0).
- `Entities::Communication::SendingWindow` : fenêtres d'Abidjan, `open?(time)`, `next_open_at(time)`.
- Seuil « interros / devoirs » : la constante `DEVOIRS_FROM = 3` remonte dans une entité partagée (`Entities::Classroom::SheetKind`), lue par l'écran « Ma classe » et par le Lot C.
- Chemins : `POST /push_subscriptions`, `PATCH /push_preference` (`turn_off`, `turn_on`, `postpone`).

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + fichiers partagés
- **Fichiers**     : `db/migrate/…_create_push_tables.rb` · `db/schema.rb`
                     `app/infrastructure/orm/communication/push_preference.rb` · `app/infrastructure/orm/communication/push_subscription.rb` · `app/infrastructure/orm/communication/push_delivery.rb`
                     `app/domain/entities/communication/push_candidate.rb` · `app/domain/entities/communication/push_message.rb` · `app/domain/entities/communication/push_motive.rb` · `app/domain/entities/communication/push_subscription.rb` · `app/domain/entities/communication/sending_window.rb` · `app/domain/entities/classroom/sheet_kind.rb` · `app/infrastructure/queries/classroom/student_assigned_sheets_query.rb` (lit la constante)
                     `app/domain/ports/communication/push_gateway_port.rb` · `app/domain/ports/communication/push_preference_repository_port.rb` · `app/domain/ports/communication/push_subscription_repository_port.rb` · `app/domain/ports/communication/push_delivery_repository_port.rb` · `app/domain/ports/communication/push_candidates_port.rb`
                     `app/infrastructure/queries/communication/push_candidates.rb` (composite des six) · `app/infrastructure/queries/communication/push_candidates/last_activity.rb`
                     `app/infrastructure/queries/communication/push_candidates/inactive.rb` · `…/assignment_due.rb` · `…/quiz_prep.rb` · `…/announcement.rb` · `…/result.rb` · `…/unfinished.rb` *(vides)*
                     `config/routes/communication.rb` · `config/locales/fr.yml` · `Gemfile` · `Gemfile.lock` · `config/recurring.yml` · `test/fixtures/push_*.yml`
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/communication/sending_window_test.rb` · `push_message_test.rb` (aucune donnée personnelle dans les six gabarits) · `push_motive_test.rb` (priorité) · `test/infrastructure/queries/communication/push_candidates/last_activity_test.rb`
- **Done quand**   : `bin/rails db:migrate` passe, Zeitwerk charge chaque constante (`bin/rails runner`), les tests du socle sont verts et les lots peuvent démarrer sans toucher un contrat

---

## Lot A — L'élève active les notifications sur le site, et les coupe dans son profil

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/communication/register_push_subscription.rb` · `turn_off_push.rb` · `turn_on_push.rb` · `postpone_push_invitation.rb`
                     `app/domain/policies/communication/push_subscription_policy.rb`
                     `app/infrastructure/repositories/communication/push_subscription_repository.rb` · `push_preference_repository.rb`
                     `app/infrastructure/queries/communication/push_invitation_query.rb`
                     `app/controllers/communication/push_subscriptions_controller.rb` · `push_preferences_controller.rb`
                     `app/views/communication/push_subscriptions/_invitation.html.erb` · `app/views/identity/profiles/_push_row.html.erb`
                     `app/views/assessment/session_results/show.html.erb` · `app/views/assessment/sheet_checks/create.turbo_stream.erb` · `app/views/identity/profiles/_student_information.html.erb`
                     `app/javascript/controllers/push_subscription_controller.js`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/communication/register_push_subscription_test.rb` (rattaché à la session, enseignant refusé, adresse connue = changement de propriétaire) · `turn_off_push_test.rb` · `postpone_push_invitation_test.rb` · `test/infrastructure/queries/communication/push_invitation_query_test.rb` (première réussite, déjà abonné, coupé, plus tard < 7 jours, coque Android) · `test/controllers/communication/push_subscriptions_controller_test.rb` · `push_preferences_controller_test.rb` · `test/system/push_invitation_test.rb`
- **Done quand**   : un élève qui réussit son premier exercice voit la carte, touche « Oui », autorise, et une ligne d'abonnement existe pour sa session ; « Couper » sur le profil la supprime et la carte ne revient plus ; captures 390 px et bureau envoyées

---

## Lot B — Le moteur d'envoi (Web Push), le motif « inactif » et la purge

- **Couche**       : domaine + infrastructure + ui (programme d'arrière-plan)
- **Fichiers**     : `app/domain/use_cases/communication/deliver_push_notifications.rb` · `purge_push_data.rb`
                     `app/infrastructure/repositories/communication/push_delivery_repository.rb`
                     `app/infrastructure/gateways/communication/web_push_gateway.rb`
                     `app/infrastructure/queries/communication/push_candidates/inactive.rb`
                     `app/jobs/communication/deliver_push_notifications_job.rb` · `purge_push_data_job.rb`
                     `app/views/pwa/service-worker.js`
- **Dépend de**    : Lot 0 ; et, pour `service-worker.js`, le Lot A du chantier `hors-connexion` fusionné dans `Develop` (sinon rebaser avant la PR : leurs écouteurs `fetch`/`activate` ne bougent pas, on ajoute `push` et `notificationclick`)
- **Test associé** : `test/domain/use_cases/communication/deliver_push_notifications_test.rb` (coupé, interrupteur, fenêtre, doublon, 4 h, priorité, relecture) · `purge_push_data_test.rb` · `test/infrastructure/gateways/communication/web_push_gateway_test.rb` (201, 404/410 → `:gone`, 5xx → `:retry`, clés absentes) · `test/infrastructure/queries/communication/push_candidates/inactive_test.rb` · `test/jobs/communication/deliver_push_notifications_job_test.rb`
- **Done quand**   : en recette, avec les clés VAPID de recette et l'interrupteur ouvert, un élève de recette abonné et inactif depuis 3 jours reçoit « Ta classe avance… » dans la fenêtre, une seule fois, et la toucher ouvre l'accueil

---

## Lot C — Motifs « devoir à rendre bientôt » et « préparer une interro »

- **Couche**       : infrastructure (requêtes de candidats)
- **Fichiers**     : `app/infrastructure/queries/communication/push_candidates/assignment_due.rb` · `app/infrastructure/queries/communication/push_candidates/quiz_prep.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/communication/push_candidates/assignment_due_test.rb` · `quiz_prep_test.rb` (1-2 exercices = interro, ≥ 3 = devoir, échéance demain à Abidjan, tout rendu = rien, classe quittée = rien, assignation archivée = rien)
- **Done quand**   : pour un jeu de recette avec une feuille de 2 exercices et une de 3 dues demain, la requête rend un candidat de chaque motif par élève non rendu, et aucun autre

---

## Lot D — Motifs « terminer un exercice commencé » et « résultat ou médaille »

- **Couche**       : infrastructure (requêtes de candidats)
- **Fichiers**     : `app/infrastructure/queries/communication/push_candidates/unfinished.rb` · `app/infrastructure/queries/communication/push_candidates/result.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/communication/push_candidates/unfinished_test.rb` (24 h sans réponse, moins de 7 jours, session close = rien) · `result_test.rb` (copie hors ligne reçue < 24 h, médaille > 2 h sans visite, visite depuis = rien)
- **Done quand**   : une session ouverte depuis 30 h et une médaille de 3 h sans visite donnent chacune un candidat, et rien d'autre

---

## Lot E — Motif « annonce de l'équipe »

- **Couche**       : infrastructure (requête de candidats)
- **Fichiers**     : `app/infrastructure/queries/communication/push_candidates/announcement.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/communication/push_candidates/announcement_test.rb` (auteur équipe seulement, règle de lecture de l'ADR-0078 réutilisée, retirée/archivée/terminée = rien, masquée par l'élève = rien, plus de 48 h = rien)
- **Done quand**   : une annonce nationale de l'équipe pour les élèves donne un candidat par élève abonné qui la lit, une annonce d'enseignant aucun

---

## Lot G — Fermeture de session et anonymisation

- **Couche**       : domaine + infrastructure (contexte `identity`, amendements)
- **Fichiers**     : `app/domain/use_cases/identity/sign_out.rb` · `app/domain/use_cases/identity/change_own_pin.rb` · `app/domain/use_cases/identity/change_own_contact.rb` · `app/domain/use_cases/identity/anonymize_user.rb`
                     `app/infrastructure/repositories/communication/push_data_eraser.rb`
                     le câblage de ces use cases dans leurs contrôleurs s'il injecte les dépendances (`app/controllers/identity/sessions_controller.rb` · `profile_pins_controller.rb` · `profile_contacts_controller.rb` · `app/controllers/teams/account_deletions_controller.rb`)
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/identity/sign_out_test.rb` · `change_own_pin_test.rb` · `change_own_contact_test.rb` · `anonymize_user_test.rb` (amendés : abonnements des sessions fermées supprimés ; anonymisation = zéro ligne dans les trois tables `push_*`) · `test/infrastructure/repositories/communication/push_data_eraser_test.rb`
- **Done quand**   : se déconnecter supprime l'abonnement de l'appareil ; anonymiser un élève de recette ne laisse aucune ligne `push_*`

---

## Lot H — Tuile « Notifications » du pilotage de l'équipe

- **Couche**       : infrastructure + ui
- **Fichiers**     : `app/infrastructure/queries/communication/push_usage_query.rb` · `app/views/teams/dashboards/_push_tile.html.erb` · `app/views/teams/dashboards/show.html.erb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/communication/push_usage_query_test.rb` (nombre fixe de requêtes, aucun nom) · `test/controllers/teams/dashboards_controller_test.rb` (amendé)
- **Done quand**   : un membre de l'équipe lit « 3 élèves abonnés · 4 abonnements » et les envois de la semaine par motif ; captures envoyées

## Décisions ouvertes

> Posées au porteur en un seul `AskUserQuestion` **avant** de lancer les lots. Le détail et l'option appliquée sont dans `journal.md` § À trancher. Aucune ne bloque le Lot 0.

- [ ] Moment de l'invitation — options : après la première réussite (choix du porteur, appliqué), après le premier exercice commencé, dès la première visite ; recommandé : appliqué, revu à deux semaines
- [ ] Fenêtres d'envoi — appliqué : 12-14 h et 17-20 h en semaine, 9-20 h le dimanche ; recommandé : appliqué
- [ ] Intervalle minimal — appliqué : 4 h ; autres : 2 h, 6 h ; recommandé : 4 h
- [ ] Annonces : de l'équipe seulement (appliqué) ou aussi de la direction et des enseignants ; recommandé : équipe seulement
- [ ] Motif « résultat » : copie hors ligne + médaille sans visite (appliqué), ou médaille seulement ; recommandé : appliqué
- [ ] Paliers « inactif » — appliqué : 3, 7, 14 jours ; recommandé : appliqué

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/communication.rb` | Lot 0 |
| `config/locales/fr.yml` | Lot 0 |
| `Gemfile`, `Gemfile.lock` | Lot 0 |
| `config/recurring.yml` | Lot 0 |
| `db/migrate/…`, `db/schema.rb` | Lot 0 |
| `test/fixtures/push_*.yml` | Lot 0 |
| `app/infrastructure/queries/communication/push_candidates/last_activity.rb` | Lot 0 (lu par B et D) |
| `…/push_candidates/inactive.rb` | Lot B (créé vide au Lot 0) |
| `…/push_candidates/assignment_due.rb`, `quiz_prep.rb` | Lot C (créés vides au Lot 0) |
| `…/push_candidates/unfinished.rb`, `result.rb` | Lot D (créés vides au Lot 0) |
| `…/push_candidates/announcement.rb` | Lot E (créé vide au Lot 0) |
| `app/infrastructure/repositories/communication/push_subscription_repository.rb` | Lot A (Lot G passe par `push_data_eraser.rb`, Lot B par le port) |
| `app/infrastructure/queries/classroom/student_assigned_sheets_query.rb` | Lot 0 |
| `app/views/pwa/service-worker.js` | Lot B (et le chantier `hors-connexion`, Lot A : ordre de fusion imposé) |
| `app/views/identity/profiles/_student_information.html.erb` | Lot A |
| `app/views/teams/dashboards/show.html.erb` | Lot H |
| `app/domain/use_cases/identity/*.rb` amendés | Lot G |

Contrôle mécanique (`awk … | sort | uniq -d`) : à relancer après toute modification de ce plan ; les seuls doublons attendus sont les fichiers créés vides au Lot 0 puis remplis par un lot.

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
- [ ] Couverture 100 % lignes et branches des fichiers touchés (ADR-0024)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Ici : en recette, il active les notifications avec le compte élève standard, reçoit une notification réelle dans la fenêtre, puis rejoue un chemin d'erreur — « Couper » puis passage de la tâche : rien ne part ; et un envoi hors fenêtre (horloge à 22 h) : rien ne part avant 12 h.
