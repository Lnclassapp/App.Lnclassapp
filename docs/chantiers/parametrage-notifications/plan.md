# Plan d'exécution — Paramétrage et confirmation des notifications par l’équipe

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Entrées : [memo](memo.md) · [PRD](prd.md) · [ADR-XXXX-envois-de-notifications-regles-par-l-equipe](../../decisions/adr/XXXX-envois-de-notifications-regles-par-l-equipe.md) · [UDR-XXXX-ecran-notifications-de-l-equipe](../../decisions/udr/XXXX-ecran-notifications-de-l-equipe.md)

## Graphe

```
Lot 0 — SOCLE (séquentiel) : tables, entités, ports gelés, dépôts, routes, textes, navigation
  ↓
  ├─► Lot A « l'envoi n'ouvre que les motifs réglés ou validés, une par jour » ┐
  ├─► Lot B « un admin règle les motifs automatiques (page Notifications) »     │
  ├─► Lot C « l'équipe valide le plan du jour »                                 ├─ en parallèle
  └─► Lot D « une annonce prévient les élèves »                                 ┘
```

Les dépôts des deux nouveaux ports sont au Lot 0 : A les lit, B et C les écrivent ; les laisser à un lot vertical sérialiserait la vague 2.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + fichiers partagés
- **Fichiers**     : `db/migrate/<horodatage>_create_push_motive_settings_and_approvals.rb` (`push_motive_settings`, `push_motive_setting_changes`, `push_approvals`, `push_approval_recipients`, ADR §4.1)
                     `db/migrate/<horodatage>_add_push_requested_and_assignment_new.rb` (`messages.push_requested`, contrainte `push_deliveries_motive_check` élargie à `assignment_new`)
                     `db/schema.rb`
                     `app/infrastructure/orm/push_motive_setting.rb` · `app/infrastructure/orm/push_motive_setting_change.rb` · `app/infrastructure/orm/push_approval.rb` · `app/infrastructure/orm/push_approval_recipient.rb`
                     `app/domain/entities/communication/push_motive.rb` (`assignment_new` en 3e priorité, `AUTOMATABLE`, `PLANNABLE`)
                     `app/domain/entities/communication/push_motive_setting.rb` · `app/domain/entities/communication/push_approval.rb`
                     `app/domain/ports/communication/push_motive_setting_repository_port.rb` · `app/domain/ports/communication/push_approval_repository_port.rb` (contrats ADR §4.2, gelés)
                     `app/infrastructure/repositories/communication/push_motive_setting_repository.rb` · `app/infrastructure/repositories/communication/push_approval_repository.rb`
                     `config/routes/teams.rb` (`GET teams/notifications`, `GET teams/notifications/plan`, `PATCH teams/notifications/motives/:motive`, `POST teams/notifications/approvals`)
                     `config/locales/teams/push_settings.fr.yml` (tous les textes de l'UDR §3.10) · `config/locales/communication/push.fr.yml` (texte `assignment_new`)
                     `config/locales/teams/dashboards.fr.yml` (libellé `motives.assignment_new`, lien « Paramétrer ») · `config/locales/shared/navigation.fr.yml` (`push_settings`)
                     `app/helpers/navigation_helper.rb` (entrée « Notifications » du menu « Plus »)
                     `test/support/factories/push.rb` (fabriques réglage et validation)
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/communication/push_motive_test.rb` · `test/infrastructure/repositories/communication/push_motive_setting_repository_test.rb` · `test/infrastructure/repositories/communication/push_approval_repository_test.rb` (double validation → `:already_approved`, historique, purge) · `test/architecture/ports_shape_test.rb` (inchangé, doit passer)
- **Done quand**   : `bin/rails db:migrate` passe, une contrainte refuse `automatic` sur `inactive`, deux validations du même motif le même jour laissent une seule ligne, et l'entrée « Notifications » apparaît dans le menu « Plus » de l'équipe (page vide autorisée au Lot 0 : route vers un contrôleur absent = Lot B)

> **Le Lot 0 gèle les contrats.** Les lots A à D implémentent ou appellent les ports, ils ne les redéfinissent pas. Un lot qui a besoin de changer un port, une migration, une route ou une clé de texte **s'arrête** : le Lot 0 rouvre.

---

## Lot A — L'envoi n'ouvre que les motifs réglés ou validés, une par jour

- **Couche**       : domaine + infrastructure (job, requête)
- **Fichiers**     : `app/domain/use_cases/communication/deliver_push_notifications.rb` (filtre d'ouverture ADR §4.3, une par jour d'Abidjan, `min_interval:` retiré)
                     `app/jobs/communication/deliver_push_notifications_job.rb` (dépôts des réglages et validations ; plus de `PUSH_MIN_INTERVAL_HOURS`)
                     `app/infrastructure/queries/communication/push_candidates/assignment_new.rb` (nouveau motif, sur le modèle d'`AssignmentDue`)
                     `app/infrastructure/queries/communication/push_candidates.rb` (ajout de la source `AssignmentNew`)
                     `app/infrastructure/repositories/communication/push_data_eraser.rb` (destinataires de validation de l'élève)
                     `app/domain/use_cases/communication/purge_push_data.rb` · `app/jobs/communication/purge_push_data_job.rb` (validations et historique de plus de 90 jours)
                     `docs/decisions/adr/0146-notifications-web-push-aux-eleves.md` (bandeau « amendé par » en tête, §3.2 et §4)
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/communication/deliver_push_notifications_test.rb` (rien sans réglage ni validation ; motif automatique ; liste figée ; une par jour, la plus urgente ; le lendemain le motif repart) · `test/infrastructure/queries/communication/push_candidates/assignment_new_test.rb` (24 h, rendu, niveau) · `test/domain/use_cases/communication/purge_push_data_test.rb` · `test/jobs/communication/deliver_push_notifications_job_test.rb`
- **Done quand**   : sur Develop en local, avec l'interrupteur ouvert et des clés de test, un passage de la tâche n'envoie rien tant qu'aucune case n'est cochée ni aucun motif validé ; après avoir coché « Nouveaux exercices » dans la console et assigné 3 exercices, l'élève reçoit « Ton prof de … t'a donné 3 exercices. » et rien d'autre ce jour-là

---

## Lot B — Un admin règle les motifs automatiques (page « Notifications »)

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : `app/domain/policies/communication/manage_push_settings_policy.rb` (équipe `admin`) · `app/domain/policies/communication/view_push_settings_policy.rb` (toute l'équipe)
                     `app/domain/use_cases/communication/update_push_motive_setting.rb` (refus d'un motif hors `AUTOMATABLE`)
                     `app/infrastructure/queries/communication/push_settings_query.rb` (réglages, historique 14 jours, état de l'interrupteur et des clés)
                     `app/controllers/teams/push_settings_controller.rb` (`show`) · `app/controllers/teams/push_motive_settings_controller.rb` (`update`)
                     `app/views/teams/push_settings/show.html.erb` (page, bandeau, frame paresseux `push_plan` vers la route du Lot C) · `app/views/teams/push_settings/_banner.html.erb` · `app/views/teams/push_settings/_modes.html.erb` · `app/views/teams/push_settings/_mode.html.erb` · `app/views/teams/push_settings/_history.html.erb` · `app/views/teams/push_settings/_history_entry.html.erb`
                     `app/views/teams/push_motive_settings/update.turbo_stream.erb`
                     `app/javascript/controllers/push_switch_controller.js`
                     `app/views/teams/dashboards/_push_tile.html.erb` (lien « Paramétrer »)
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/communication/update_push_motive_setting_test.rb` (content/field refusés ; `inactive` refusé ; historique écrit) · `test/controllers/teams/push_settings_controller_test.rb` (enseignant refusé ; bandeau interrupteur fermé ; historique) · `test/controllers/teams/push_motive_settings_controller_test.rb` · `test/system/teams/push_settings_test.rb` (cocher « Devoir à rendre » à 390 px)
- **Done quand**   : un admin ouvre « Notifications » depuis le menu « Plus », coche « Devoir à rendre » sans rechargement, voit « Automatique depuis le …, par … » et la ligne dans l'historique ; un compte `content` voit la case désactivée

---

## Lot C — L'équipe valide le plan du jour

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/policies/communication/approve_push_policy.rb` (toute l'équipe)
                     `app/domain/use_cases/communication/approve_push_motive.rb` (recalcule la liste au moment de valider ; refus après la dernière fenêtre ; `:already_approved`)
                     `app/infrastructure/queries/communication/push_daily_plan_query.rb` (par motif : élèves distincts, établissements, texte ; ADR §4.4)
                     `app/controllers/teams/push_plans_controller.rb` (`show`, frame) · `app/controllers/teams/push_approvals_controller.rb` (`create`)
                     `app/views/teams/push_plans/show.html.erb` · `app/views/teams/push_plans/_motive.html.erb`
                     `app/views/teams/push_approvals/create.turbo_stream.erb` (remplace `push_plan_<motive>`, `prepend` dans `push_history_list` via le partial `teams/push_settings/_history_entry` du Lot B, rendu sans modification)
- **Dépend de**    : Lot 0 (le partial `_history_entry` du Lot B est **lu**, pas modifié ; si le Lot B n'est pas fusionné, le test de vue du Lot C rend la ligne avec une entrée de fabrique)
- **Test associé** : `test/domain/use_cases/communication/approve_push_motive_test.rb` (liste figée ; refus après 20 h ; double validation) · `test/infrastructure/queries/communication/push_daily_plan_query_test.rb` (3 élèves, 2 établissements, aucun nom ; motifs automatiques absents ; déjà envoyés exclus) · `test/controllers/teams/push_approvals_controller_test.rb` · `test/controllers/teams/push_plans_controller_test.rb` (état vide, état d'erreur)
- **Done quand**   : un membre de l'équipe voit « Élève inactif — 3 élèves » avec le texte et la répartition par établissement, clique « Valider l'envoi », confirme, et la ligne passe à « Validé par … à … — 3 élèves » ; une seconde validation affiche « Déjà validé par »

---

## Lot D — Une annonce prévient les élèves

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/entities/communication/message.rb` (`push_requested`) · `app/domain/dtos/communication/message_input.rb`
                     `app/domain/use_cases/communication/create_message.rb` · `app/domain/use_cases/communication/update_message.rb` (vrai seulement pour l'équipe et l'audience `all` ou `students`)
                     `app/infrastructure/repositories/communication/message_repository.rb`
                     `app/infrastructure/queries/communication/push_candidates/announcement.rb` (`.where(push_requested: true)`)
                     `app/controllers/communication/authored_messages_controller.rb` (paramètre permis pour l'équipe seulement)
                     `app/views/communication/authored_messages/_form.html.erb` · `app/views/communication/authored_messages/_row.html.erb`
                     `app/javascript/controllers/push_request_controller.js`
                     `config/locales/communication/authored_messages.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/communication/create_message_test.rb` (équipe + élèves → vrai ; enseignant ou direction forgé → faux ; audience enseignants → faux) · `test/infrastructure/queries/communication/push_candidates/announcement_test.rb` (sans la case → aucun candidat) · `test/controllers/communication/authored_messages_controller_test.rb`
- **Done quand**   : un membre de l'équipe publie une annonce « Élèves » avec « Prévenir les élèves » coché, la cloche apparaît sur sa ligne, et la requête de candidats rend les élèves lecteurs ; la case n'existe pas dans le formulaire d'un enseignant

---

## Rattachement des critères d'acceptation (PRD §4)

| Critère | Lot |
|---|---|
| rien ne part sans réglage ni validation | A |
| un motif automatique part seul | A |
| une relance validée part, figée à la validation | A (envoi) + C (enregistrement de la liste) |
| une par jour et par élève, la plus urgente | A |
| le lendemain, le motif encore valable repart | A |
| nouveaux exercices assignés · déjà rendus ou trop anciens | A |
| un rôle non admin ne change pas un réglage | B |
| une relance ne peut pas devenir automatique | B (use case) + 0 (contrainte) |
| un rôle non équipe ne voit pas l'écran | B |
| validation refusée après la dernière fenêtre | C |
| double validation | C (+ 0 : index unique) |
| annonce avec / sans « Prévenir les élèves » | D |
| la case n'existe pas hors équipe | D |
| le plan du jour montre ce qui partirait | C |
| interrupteur fermé | B |
| historique tracé | B (affichage) + C (entrée de validation) |

Aucun critère orphelin.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `db/migrate/*`, `db/schema.rb` | Lot 0 |
| `config/routes/teams.rb` | Lot 0 |
| `config/locales/teams/push_settings.fr.yml` (lu par B et C) | Lot 0 |
| `config/locales/communication/push.fr.yml` | Lot 0 |
| `config/locales/teams/dashboards.fr.yml` | Lot 0 |
| `config/locales/shared/navigation.fr.yml`, `app/helpers/navigation_helper.rb` | Lot 0 |
| `app/domain/entities/communication/push_motive.rb` (lu par A, B, C) | Lot 0 |
| dépôts `push_motive_setting_repository.rb`, `push_approval_repository.rb` (lus par A, écrits par B et C) | Lot 0 |
| `test/support/factories/push.rb` | Lot 0 |
| `app/infrastructure/queries/communication/push_candidates.rb` | Lot A |
| `app/views/teams/push_settings/_history_entry.html.erb` (rendu par C, sans modification) | Lot B |
| `app/views/teams/dashboards/_push_tile.html.erb` | Lot B |
| `app/infrastructure/queries/communication/push_candidates/announcement.rb` | Lot D |
| `app/javascript/controllers/index.js` | aucun (enregistrement automatique des contrôleurs) |

Vérification mécanique (`awk … | sort | uniq -d`) : à relancer après toute modification du plan ; sortie attendue vide.

## Dispatch

```
Vague 1 : Lot 0                            → 1 agent (executant-lot), séquentiel
Vague 2 : Lot A ‖ Lot B ‖ Lot C ‖ Lot D    → 4 agents (executant-lot), worktrees isolés
Vague 3 : revues (security-reviewer, silent-failure-hunter, pr-test-analyzer) sur le diff final, puis bin/ci-quiet une fois
```

Branche de chantier : `claude/happy-newton-rj5i1c` (imposée par la session ; elle tient lieu de `feature/parametrage-notifications`). Worktrees, une fois le Lot 0 fusionné dans la branche de chantier :

```bash
git worktree add ../lnclass-parametrage-notifications-lot-a -b feature/parametrage-notifications-lot-a claude/happy-newton-rj5i1c
```

(idem `-lot-b`, `-lot-c`, `-lot-d`). Tiret, pas slash.

**Journées** : le Lot 0 et la vague 2 tiennent dans une journée ; la PR unique vers `Develop` part le soir de la vague 2. Si la vague 2 déborde, les lots finis partent en PR le jour même, les autres repartent le lendemain de `Develop` sur `feature/parametrage-notifications-2`.

Consignes transmises à chaque agent de lot : chemins absolus et `git -C <worktree>` ; aucun fichier hors de son champ `Fichiers` (sinon il s'arrête et remonte) ; contrat de session (pas de question en fin de lot, décision réversible appliquée dans sa version prudente et notée dans `## À trancher` du journal).

## Décisions ouvertes

Aucune ne bloque le lancement : les trois points laissés sans réponse au grill sont appliqués dans leur version prudente et inscrits dans `## À trancher` du journal (liste figée, motif entier, validation jusqu'à 20 h).

- [x] Liste figée à la validation — appliqué (journal)
- [x] Validation d'un motif entier, répartition par établissement affichée — appliqué (journal)
- [x] Heure limite de validation : 20 h — appliqué (journal)

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

## Phase 5 — Challenger

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.

Parcours à rejouer : (1) un admin coche « Nouveaux exercices », un enseignant assigne 3 exercices, la tâche passe → une seule notification ; (2) un compte `content` tente de cocher une case → refus ; (3) validation d'« Élève inactif » après 20 h → refus. Captures à 390 px et sur ordinateur de la page « Notifications » et du formulaire d'annonce, envoyées au porteur, jamais commitées.

## Après la fusion (hors chantier)

`PUSH_DELIVERY_ENABLED` reste `false` sur les trois projets Hostinger jusqu'à la fusion et la vérification sur Develop ; son ouverture est un geste du porteur.
