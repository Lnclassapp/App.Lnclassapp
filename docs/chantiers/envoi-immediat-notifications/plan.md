# Plan d'exécution — Notifications envoyées dès l'événement

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot 0 — SOCLE (séquentiel)
  ↓
  ├─► Lot A  règle d'envoi       ┐
  ├─► Lot B  passage à l'événement├─ en parallèle
  └─► Lot C  écran Notifications ┘
```

Une seule PR vers `Develop` ; les lots se suivent dans la même session (petite taille, moins d'un jour).

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats)
- **Fichiers**     : `db/migrate/…_widen_push_motive_settings_check.rb` · `db/schema.rb`
                     `app/domain/entities/communication/push_motive.rb` (`EVENTS`, `REMINDERS`, `AUTOMATABLE = PRIORITY`)
                     `app/domain/ports/communication/push_pass_port.rb` (`request` → nil)
                     `app/infrastructure/gateways/communication/push_pass.rb` (enfile le job d'envoi ; un échec est signalé, jamais levé)
                     `config/locales/teams/push_settings.fr.yml` · `config/locales/teams/dashboards*.fr.yml` (« Exercice assigné ») *(partagés)*
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/communication/push_motive_test.rb` · `test/infrastructure/gateways/communication/push_pass_test.rb` · test de contrainte (les sept motifs acceptés)
- **Done quand**   : la base accepte une case pour chacun des sept motifs ; le port et son adaptateur existent

---

## Lot A — Règle d'envoi : case seule, événements à toute heure, rappels de 6 h à 21 h

- **Couche**       : domaine + infrastructure + config
- **Fichiers**     : `app/domain/entities/communication/reminder_hours.rb` (remplace `sending_window.rb`)
                     `app/domain/use_cases/communication/deliver_push_notifications.rb` (sans `approvals:`)
                     `app/jobs/communication/deliver_push_notifications_job.rb`
                     `config/recurring.yml` (passage de 12 h 20 retiré)
- **Dépend de**    : Lot 0
- **Test associé** : `deliver_push_notifications_test.rb` (critères 1, 3, 4, 7, 8) · `reminder_hours_test.rb` · `recurring_tasks_test.rb`
- **Done quand**   : un passage à 2 h envoie un événement coché et aucun rappel ; un motif décoché ne part jamais

---

## Lot B — Passage demandé à l'événement

- **Couche**       : domaine + delivery
- **Fichiers**     : `app/domain/use_cases/classroom/assign_exercise_batch.rb` · `create_message.rb` · `update_message.rb` · `publish_scheduled_messages.rb` · `assessment/close_exercise_session.rb` · `assessment/sync_offline_copy.rb` (argument `push_pass:`) et leurs points de câblage (contrôleurs, jobs)
- **Dépend de**    : Lot 0
- **Test associé** : un test par use case (critères 5 et 6) : demandé une fois après succès, jamais sur un refus
- **Done quand**   : assigner des exercices enfile un passage d'envoi

---

## Lot C — Écran « Notifications » : sept cases, plus de plan du jour

- **Couche**       : delivery + ui
- **Fichiers**     : `app/views/teams/push_settings/*` · retrait de `teams/push_plans/*`, `teams/push_approvals/*`, de leurs contrôleurs, routes (`config/routes/teams.rb`), de `ApprovePushMotive`, `PushDailyPlanQuery` · `app/infrastructure/queries/communication/push_settings_query.rb`
- **Dépend de**    : Lot 0
- **Test associé** : contrôleurs (critères 2, 9) · `test/system/teams/push_settings_test.rb`
- **Done quand**   : l'écran montre sept cases et l'historique, sans plan du jour ; captures 390 px et ordinateur envoyées

---

## Décisions ouvertes

- [ ] Résultat/médaille « tout de suite » : garder la condition « élève pas revenu depuis » et le délai de 2 h après une médaille (sinon l'élève, déjà dans l'application, reçoit la notification de ce qu'il voit) — options : garder les deux, retirer le délai seulement, retirer les deux ; recommandé : retirer le délai seulement (une copie hors ligne reçue et une médaille partent au passage demandé si l'élève n'est pas revenu depuis).

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/locales/teams/push_settings.fr.yml` | Lot 0 |
| `app/domain/entities/communication/push_motive.rb` | Lot 0 |
| `config/routes/teams.rb` | Lot C |
| `app/domain/use_cases/communication/deliver_push_notifications.rb` | Lot A |
| `app/domain/use_cases/communication/create_message.rb`, `update_message.rb` | Lot B |

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
