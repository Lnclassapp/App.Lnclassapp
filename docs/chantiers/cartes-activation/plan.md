# Plan d'exécution — Cartes d'activation vendues au point relais

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Entrées : [memo](memo.md) (grill Q1 à Q13), [PRD](prd.md), ADR-XXXX-contexte-billing-cartes-activation, UDR-XXXX-abonnement-eleve, UDR-XXXX-caisse-equipe.

## Graphe

```
Lot 0 — SOCLE billing (séquentiel) : tables, ORM, entités, ports, dépôt des cartes, lecture de l'accès, routes, navigation, audit
  ↓
  ├─► Lot A  Créer les cartes et s'abonner avec un code     ┐  échéance : en production mercredi 11 novembre
  ├─► Lot B  Période gratuite et blocage                    ├─ parallèle   échéance : en production lundi 16 novembre
  └─► Lot C  Caisse : versements, annulation, commissions   ┘              échéance : en production vendredi 13 novembre
```

## Dispatch

```
Vague 1 : Lot 0                    → 1 agent (executant-lot), séquentiel
Vague 2 : Lot A ‖ Lot B ‖ Lot C    → 3 agents (executant-lot), worktrees isolés, après fusion du Lot 0 dans la branche de chantier
Challenger (phase 5)               → 1 agent distinct, sur la branche de chantier une fois A, B, C fusionnés
```

**Branche.** La session impose la branche `ccr-5a226b75-gfu543` (PR #504) : elle tient lieu de branche de chantier. Les lots partent de là :
`git worktree add ../lnclass-cartes-activation-lot-a -b feature/cartes-activation-lot-a ccr-5a226b75-gfu543`.

**Journées.** Dimanche 8 : Lot 0 puis A, B, C ; PR #504 fusionnée dans `Develop` le soir. Lundi 9 : train `Develop → Staging → main` pour mettre A, B et C en production avant le mercredi 11. Si un lot n'est pas vert dimanche soir, il repart lundi sur `feature/cartes-activation-2` et les deux autres partent seuls.

---

## Lot 0 — Socle billing

- **Couche**       : infrastructure + domaine (contrats) + fichiers partagés
- **Fichiers**     : db/migrate/20261108090000_create_billing_tables.rb
                     db/schema.rb
                     app/infrastructure/orm/billing/relay_point.rb
                     app/infrastructure/orm/billing/relay_point_school.rb
                     app/infrastructure/orm/billing/card_batch.rb
                     app/infrastructure/orm/billing/activation_card.rb
                     app/infrastructure/orm/billing/remittance.rb
                     app/domain/entities/billing/offer.rb
                     app/domain/entities/billing/access.rb
                     app/domain/entities/billing/activation_code.rb
                     app/domain/entities/billing/activation_card.rb
                     app/domain/entities/billing/card_batch.rb
                     app/domain/entities/billing/relay_point.rb
                     app/domain/entities/billing/remittance.rb
                     app/domain/ports/billing/relay_point_repository_port.rb
                     app/domain/ports/billing/card_repository_port.rb
                     app/domain/ports/billing/remittance_repository_port.rb
                     app/domain/ports/billing/student_access_port.rb
                     app/domain/policies/billing/manage_billing_policy.rb
                     app/domain/policies/billing/activate_card_policy.rb
                     app/infrastructure/repositories/billing/card_repository.rb
                     app/infrastructure/queries/billing/student_access_query.rb
                     app/domain/entities/identity/audit_action.rb
                     config/routes.rb
                     config/routes/billing.rb
                     config/routes/teams.rb
                     app/helpers/navigation_helper.rb
                     test/fixtures/billing/relay_points.yml
                     test/fixtures/billing/relay_point_schools.yml
                     test/fixtures/billing/card_batches.yml
                     test/fixtures/billing/activation_cards.yml
                     test/fixtures/billing/remittances.yml
- **Dépend de**    : —
- **Test associé** : test/domain/entities/billing/access_test.rb
                     test/domain/entities/billing/activation_code_test.rb
                     test/infrastructure/repositories/billing/card_repository_test.rb
                     test/infrastructure/queries/billing/student_access_query_test.rb
- **Done quand**   : `bin/rails db:migrate` crée les cinq tables `billing_*` ; `Access.for` rend `free` le 7e jour, `blocked` le 8e, `free` pour un compte antérieur au 2026-11-09 jusqu'au 2026-11-15 ; le dépôt des cartes refuse un code en double et une 2e carte activée pour le même élève et la même année ; les routes de l'élève et de l'équipe s'affichent dans `bin/rails routes -g billing` ; la navigation de l'équipe montre « Caisse ».

**Contrats gelés par ce lot** (signatures, à ne pas redéfinir dans A, B, C) :
- `CardRepositoryPort` : `create_batch(relay_point_id:, quantity:, unit_price_xof:, valid_until:, created_by_id:, at:)` → `CardBatch` avec ses cartes ; `cards_of_batch(batch_public_id:)` ; `lock_by_code(code:)` → `ActivationCard` ou `nil` (à appeler dans une transaction) ; `activate(card_id:, student_id:, school_id:, at:)` ; `subscribed_until(student_id:)` → `Date` ou `nil` ; `find_by_serial(serial:)` ; `cancel(card_id:, by_id:, reason:, at:)`.
- `RelayPointRepositoryPort` : `list`, `find(public_id:)`, `save(relay_point:, school_ids:)`, `for_school(school_id:)`.
- `RemittanceRepositoryPort` : `record(relay_point_id:, amount_xof:, received_at:, reference:, reason:, recorded_by_id:)`, `for_relay_point(relay_point_id:)`.
- `StudentAccessPort` : `call(student_id:, at:)` → `Entities::Billing::Access`.

---

## Lot A — Créer les cartes et s'abonner avec un code

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : app/domain/use_cases/billing/save_relay_point.rb
                     app/domain/use_cases/billing/create_card_batch.rb
                     app/domain/use_cases/billing/activate_card.rb
                     app/domain/dtos/billing/relay_point_input.rb
                     app/domain/dtos/billing/card_batch_input.rb
                     app/infrastructure/repositories/billing/relay_point_repository.rb
                     app/controllers/billing/subscriptions_controller.rb
                     app/controllers/billing/activations_controller.rb
                     app/controllers/teams/billing/relay_points_controller.rb
                     app/controllers/teams/billing/card_batches_controller.rb
                     app/views/billing/subscriptions/show.html.erb
                     app/views/billing/subscriptions/_status.html.erb
                     app/views/billing/subscriptions/_where_to_buy.html.erb
                     app/views/billing/subscriptions/_activation_form.html.erb
                     app/views/teams/billing/relay_points/index.html.erb
                     app/views/teams/billing/relay_points/show.html.erb
                     app/views/teams/billing/relay_points/new.html.erb
                     app/views/teams/billing/relay_points/edit.html.erb
                     app/views/teams/billing/relay_points/_form.html.erb
                     app/views/teams/billing/relay_points/_relay_point_row.html.erb
                     app/views/teams/billing/card_batches/new.html.erb
                     app/views/teams/billing/card_batches/show.html.erb
                     app/views/layouts/print.html.erb
                     app/javascript/controllers/print_controller.js
                     app/javascript/controllers/index.js
                     config/locales/billing/subscriptions.fr.yml
                     config/locales/teams/billing_relay_points.fr.yml
- **Dépend de**    : Lot 0
- **Test associé** : test/domain/use_cases/billing/save_relay_point_test.rb
                     test/domain/use_cases/billing/create_card_batch_test.rb
                     test/domain/use_cases/billing/activate_card_test.rb
                     test/controllers/billing/activations_controller_test.rb
                     test/controllers/billing/subscriptions_controller_test.rb
                     test/controllers/teams/billing/relay_points_controller_test.rb
                     test/controllers/teams/billing/card_batches_controller_test.rb
- **Done quand**   : dans l'application, un membre de l'équipe crée « Boutique Awa » rattachée à une école, crée un lot de 20 cartes et imprime la planche ; un élève de cette école ouvre Mon abonnement, y voit la Boutique Awa, saisit un code en minuscules avec espaces et lit « Ton abonnement est actif jusqu'au 31 juillet 2027 » ; un 2e élève qui saisit le même code lit « Cette carte a déjà été utilisée. » ; le 6e essai en 10 minutes est refusé.
- **Critères du PRD §4** : section « Activation » (9 critères) et « Points relais et lots » (3 critères).

---

## Lot B — Période gratuite et blocage

- **Couche**       : domaine + delivery + ui (+ semis)
- **Fichiers**     : app/domain/use_cases/assessment/start_exercise_session.rb
                     app/domain/use_cases/catalog/check_practice.rb
                     app/controllers/assessment/exercise_sessions_controller.rb
                     app/controllers/assessment/sheet_checks_controller.rb
                     app/controllers/catalog/practice_checks_controller.rb
                     app/controllers/concerns/redirects_subscription_required.rb
                     app/controllers/classroom/student_homes_controller.rb
                     app/views/classroom/student_homes/show.html.erb
                     app/views/billing/subscriptions/_home_notice.html.erb
                     config/locales/billing/access.fr.yml
                     db/seeds/standard/abonnements.rb
- **Dépend de**    : Lot 0
- **Test associé** : test/domain/use_cases/assessment/start_exercise_session_test.rb
                     test/domain/use_cases/catalog/check_practice_test.rb
                     test/controllers/assessment/exercise_sessions_controller_test.rb
                     test/controllers/catalog/practice_checks_controller_test.rb
                     test/integration/billing/free_period_test.rb
- **Done quand**   : avec l'horloge au 2026-11-15, un élève créé le 2026-11-09 voit « Il te reste 1 jour gratuit » sur son accueil et démarre un exercice ; au 2026-11-16, « Commencer » (exercice libre ou donné par l'enseignant) et la vérification d'une fiche le mènent à Mon abonnement sans rien créer ; ses leçons, ses exercices et son historique s'affichent ; un enseignant n'est jamais bloqué ; les élèves du jeu standard sont abonnés par un lot offert ; `bin/system-changed` est vert.
- **Critères du PRD §4** : section « Période gratuite et blocage » (8 critères).
- **Attention** : les fabriques de use case des contrôleurs passent `access: Queries::Billing::StudentAccessQuery.new`. Un test système existant qui voyage dans le temps au-delà de 7 jours après la création de son élève doit abonner cet élève (fixture `activation_cards`), jamais désactiver la garde.

---

## Lot C — Caisse : versements, annulation, commissions

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : app/domain/use_cases/billing/cancel_card.rb
                     app/domain/use_cases/billing/record_remittance.rb
                     app/domain/dtos/billing/remittance_input.rb
                     app/domain/entities/billing/commission_week.rb
                     app/infrastructure/repositories/billing/remittance_repository.rb
                     app/infrastructure/queries/billing/cashbox_query.rb
                     app/controllers/teams/billing/cashboxes_controller.rb
                     app/controllers/teams/billing/remittances_controller.rb
                     app/controllers/teams/billing/card_cancellations_controller.rb
                     app/views/teams/billing/cashboxes/show.html.erb
                     app/views/teams/billing/cashboxes/_week.html.erb
                     app/views/teams/billing/cashboxes/_relays.html.erb
                     app/views/teams/billing/cashboxes/_schools.html.erb
                     app/views/teams/billing/remittances/new.html.erb
                     app/views/teams/billing/remittances/_form.html.erb
                     app/views/teams/billing/remittances/create.turbo_stream.erb
                     app/views/teams/billing/card_cancellations/show.html.erb
                     config/locales/teams/billing_cashbox.fr.yml
- **Dépend de**    : Lot 0
- **Test associé** : test/domain/entities/billing/commission_week_test.rb
                     test/domain/use_cases/billing/cancel_card_test.rb
                     test/domain/use_cases/billing/record_remittance_test.rb
                     test/infrastructure/queries/billing/cashbox_query_test.rb
                     test/controllers/teams/billing/cashboxes_controller_test.rb
                     test/controllers/teams/billing/remittances_controller_test.rb
                     test/controllers/teams/billing/card_cancellations_controller_test.rb
- **Done quand**   : avec les fixtures (20 cartes à la Boutique Awa, 3 activées, 2 annulées, 20 000 F versés), la caisse affiche « reste dû 10 000 F » et « 15 en circulation » ; le vendredi 2026-11-13, « À payer ce vendredi » montre 400 F pour 2 activations du jeudi ; l'école cumule 3 000 F ; annuler la carte N° d'une carte activée est refusé ; un versement négatif avec motif ramène le total et les deux lignes restent.
- **Critères du PRD §4** : section « Caisse » (6 critères).

---

## Vérification de collision

> Doublons cherchés avec `awk … | sort | uniq -d` : aucun. Fichiers partagés et leur unique propriétaire :

| Fichier | Lot propriétaire |
|---|---|
| `config/routes.rb`, `config/routes/billing.rb`, `config/routes/teams.rb` | Lot 0 |
| `app/helpers/navigation_helper.rb` (entrée « Caisse ») | Lot 0 |
| `app/domain/entities/identity/audit_action.rb` | Lot 0 |
| `app/infrastructure/orm/billing/*` | Lot 0 |
| `app/infrastructure/repositories/billing/card_repository.rb` (utilisé par A, B, C) | Lot 0 |
| `app/infrastructure/queries/billing/student_access_query.rb` (utilisé par A et B) | Lot 0 |
| `test/fixtures/billing/*` | Lot 0 |
| `db/migrate/…`, `db/schema.rb` | Lot 0 |
| `app/views/layouts/print.html.erb`, `app/javascript/controllers/index.js` | Lot A |
| `app/views/billing/subscriptions/*` sauf `_home_notice` | Lot A |
| `app/views/billing/subscriptions/_home_notice.html.erb`, `app/views/classroom/student_homes/show.html.erb` | Lot B |
| `config/locales/billing/subscriptions.fr.yml` | Lot A |
| `config/locales/billing/access.fr.yml` | Lot B |
| `config/locales/teams/billing_relay_points.fr.yml` | Lot A |
| `config/locales/teams/billing_cashbox.fr.yml` | Lot C |

## Décisions ouvertes

- [ ] **Numéro WhatsApp de l'équipe** affiché quand l'école de l'élève n'a pas de point relais (UDR-XXXX-abonnement-eleve §3.4). Recommandation : le numéro professionnel du porteur.

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
> Pour ce chantier : il crée un point relais et un lot, imprime la planche, abonne un élève bloqué avec un code tapé en minuscules, puis tente le même code avec un 2e élève (refus) ; il saisit un versement et vérifie le reste dû de la caisse ; captures à 390 px et sur ordinateur de Mon abonnement (bloqué, abonné) et de la caisse.
