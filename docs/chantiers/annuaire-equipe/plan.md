# Plan d'exécution — Annuaire de l'équipe (« Comptes »)

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> **Écrit avec les recommandations du memo.** Q1 « rien d'automatique » supprime le Lot E ; Q2, Q4, Q7 changent le contenu des Lots C, A, D (voir chaque lot).

## Graphe

```
Lot 0 — SOCLE (séquentiel) : schéma, entité, port + repository, policies, journal, routes, renommage mécanique
  ↓
Lot A — Trouver un compte et lire sa fiche (UDR-0095, UDR-0096) : la fiche et son menu, que B, C, D remplissent
  ↓
  ├─► Lot B « Modifier nom, genre, numéro »      ┐
  ├─► Lot C « Désactiver, réactiver »            ├─ en parallèle, fichiers disjoints
  └─► Lot D « Anonymiser un adulte »             ┘
                     ↓ (après C et D)
                  Lot E « Anonymisation automatique à 30 jours » (Q1)
```

Pourquoi A n'est pas parallèle à B, C, D : leurs Turbo Streams remplacent `teams/accounts/_identity` et leurs modales s'ouvrent depuis `_actions`, deux partials de A. Les écrire au Lot 0 aurait mis de l'UI dans le socle.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + routes + renommage sans changement de comportement
- **Fichiers**     : `db/migrate/20261020000000_add_deactivation_to_users.rb` · `db/schema.rb`
                     `app/domain/entities/identity/user.rb` (`deactivated_at`, `#deactivated?`, `#anonymization_due_on`)
                     `app/domain/entities/identity/audit_action.rb` (`user.updated_by_team`, `user.deactivated`, `user.reactivated`)
                     `app/domain/ports/identity/user_repository_port.rb` (`update_identity`, `deactivate`, `reactivate`, `lock_active_admins`, `deactivated_before`)
                     `app/infrastructure/repositories/identity/user_repository.rb` (les cinq méthodes ; `authenticate` refuse un compte désactivé)
                     `app/domain/policies/identity/manage_account_policy.rb` (nouvelle, matrice Q5)
                     `app/domain/policies/identity/delete_user_policy.rb` (enseignant et équipe, jamais soi-même)
                     `config/routes/teams.rb` : `resources :accounts, only: %i[index show], param: :public_id` remplace `resource :account_lookup` ; sous `accounts/:public_id` : `resource :edit` (B), `resource :deactivation, only: %i[new create]` et `resource :reactivation, only: %i[new create]` (C) ; `account_deletion` inchangée
                     renommage mécanique : `app/controllers/teams/account_lookups_controller.rb` → `accounts_controller.rb` (`show` → `index`), `app/views/teams/account_lookups/*` → `app/views/teams/accounts/*`, `config/locales/teams/account_lookups.fr.yml` → `accounts.fr.yml`
                     appelants de `teams_account_lookup_path` : `app/controllers/teams/account_deletions_controller.rb`, `deletion_requests_controller.rb`, `second_factor_resets_controller.rb`, `app/views/teams/deletion_requests/index.html.erb`
                     `app/views/teams/homes/_shortcuts.html.erb` · `config/locales/teams/homes.fr.yml` (« Comptes », icône `users`)
                     tests renommés : `test/controllers/teams/account_lookups_controller_test.rb` → `accounts_controller_test.rb`, `test/system/teams/account_unlock_test.rb` (chemin seulement)
- **Dépend de**    : — (après validation de Q1 à Q8 par le porteur)
- **Test associé** : `test/infrastructure/repositories/identity/user_repository_test.rb` · `test/domain/entities/identity/user_test.rb` · `test/domain/policies/identity/manage_account_policy_test.rb` · `test/domain/policies/identity/delete_user_policy_test.rb` · `test/routing/teams_accounts_routing_test.rb` · la suite existante de « Débloquer un compte », verte sans changement d'assertion
- **Done quand**   : la migration passe et se rejoue ; un compte désactivé en base n'est plus authentifié ; la policy refuse soi-même et chaque case interdite de Q5 ; `/teams/accounts` fait exactement ce que faisait « Débloquer un compte », sous le libellé « Comptes »

---

## Lot A — Trouver un compte et lire sa fiche

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/identity/account_search_query.rb` (quatre rôles, filtres `role` et `state`, badge désactivé, photo)
                     `app/infrastructure/queries/identity/account_detail_query.rb` (nouvelle) · `app/infrastructure/queries/identity/account_lookup_query.rb` (supprimée)
                     `app/controllers/teams/accounts_controller.rb` (`index` cherche, `show`)
                     `app/views/teams/accounts/index.html.erb`, `_filters`, `_results`, `show.html.erb`, `_identity`, `_attachment`, `_actions` ; `_result.html.erb` supprimé
                     `app/views/teams/second_factor_resets/create.turbo_stream.erb` (cible `#account-identity`)
                     `config/locales/teams/accounts.fr.yml`
                     Q4 : `app/controllers/teams/dashboards_controller.rb`, `app/views/teams/dashboards/show.html.erb`, `_search.html.erb` (lien), `_search_results.html.erb` (supprimé), `config/locales/teams/dashboards.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/identity/account_search_query_test.rb` (rôles, filtres, anonymisé exclu, nombre de requêtes fixe) · `test/infrastructure/queries/identity/account_detail_query_test.rb` · `test/controllers/teams/accounts_controller_test.rb` (403 hors équipe, 404 anonymisé, frame) · `test/controllers/teams/dashboards_controller_test.rb` · `test/system/teams/accounts_test.rb` (remplace `account_unlock_test.rb`) · `test/system/finitions/team_accounts_test.rb`, `narrow_screens_test.rb` (390 px)
- **Done quand**   : l'équipe tape « kone », voit élève, enseignant, direction et équipe, filtre « Enseignant », ouvre la fiche, émet un code PIN depuis le menu « Actions » ; le menu montre « Modifier », « Désactiver », « Anonymiser » selon Q5 (leurs modales répondent 404 jusqu'aux Lots B à D) ; Pilotage n'a plus de recherche (Q4)

---

## Lot B — Modifier le nom, le genre, le numéro

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : `app/domain/dtos/identity/account_input.rb`
                     `app/domain/use_cases/identity/update_account.rb`
                     `app/controllers/teams/account_edits_controller.rb`
                     `app/views/teams/account_edits/edit.html.erb`, `update.turbo_stream.erb`
                     `config/locales/teams/account_edits.fr.yml`
- **Dépend de**    : Lot A
- **Test associé** : `test/domain/use_cases/identity/update_account_test.rb` (numéro pris, hors format, sessions fermées au seul changement de numéro, journal sans valeurs, rôle ignoré) · `test/controllers/teams/account_edits_controller_test.rb` (403 `content`, 403 `field` sur l'équipe, 422) · `test/system/teams/account_edit_test.rb`
- **Done quand**   : l'équipe corrige « Aicha Kone » en « Aïcha Koné » depuis la fiche, la fiche change sans rechargement ; un numéro changé déconnecte le titulaire, qui se reconnecte avec le nouveau

---

## Lot C — Désactiver, réactiver

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : `app/domain/use_cases/identity/deactivate_account.rb`, `reactivate_account.rb`
                     `app/controllers/teams/account_deactivations_controller.rb`, `account_reactivations_controller.rb`
                     `app/views/teams/account_deactivations/new.html.erb`, `create.turbo_stream.erb`
                     `app/views/teams/account_reactivations/new.html.erb`, `create.turbo_stream.erb`
                     `config/locales/teams/account_deactivations.fr.yml`, `account_reactivations.fr.yml`
                     Q2 : la direction passe par `UseCases::School::ArchiveSchoolStaff` / `RestoreSchoolStaff`, appelés par ces contrôleurs ; aucun fichier de `school` modifié
- **Dépend de**    : Lot A
- **Test associé** : `test/domain/use_cases/identity/deactivate_account_test.rb` (soi-même, dernier admin, sessions, journal) · `reactivate_account_test.rb` · `test/integration/identity/last_admin_concurrency_test.rb` (deux threads) · `test/integration/identity/deactivated_login_test.rb` (bon PIN refusé, message neutre) · `test/controllers/teams/account_deactivations_controller_test.rb` · `test/system/teams/account_deactivation_test.rb`
- **Done quand**   : l'équipe désactive un enseignant connecté, il est déconnecté et son bon PIN est refusé ; la fiche annonce l'échéance (adulte) ou « sans échéance » (élève) ; la réactivation lui rend la connexion ; le dernier `admin` ne se désactive pas, même sous deux requêtes simultanées ; une direction est retirée comme par sa fiche d'établissement

---

## Lot D — Anonymiser un enseignant ou un membre de l'équipe

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : `app/domain/use_cases/identity/anonymize_user.rb` (enseignant : retrait de ses établissements et devoirs actifs archivés par les ports de `DetachTeacher`, Q7 ; équipe ; garde du dernier admin ; `metadata.reason`)
                     `app/domain/dtos/identity/deletion_request_input.rb` (`confirmation_name`)
                     `app/controllers/teams/account_deletions_controller.rb`
                     `app/views/teams/account_deletions/new.html.erb`, `create.turbo_stream.erb`
                     `config/locales/teams/account_deletions.fr.yml`
- **Dépend de**    : Lot A
- **Test associé** : `test/domain/use_cases/identity/anonymize_user_test.rb` (enseignant, équipe, dernier admin, soi-même, élève inchangé) · `test/infrastructure/repositories/identity/anonymize_teacher_test.rb` (base réelle : classes quittées, devoirs archivés, annonces gardées) · `test/controllers/teams/account_deletions_controller_test.rb` (nom tapé faux : 422) · `test/system/teams/account_deletion_test.rb` (étendu)
- **Done quand**   : l'`admin` anonymise un enseignant en tapant son nom ; il disparaît de la recherche, ses classes n'ont plus d'enseignant, ses annonces sont signées « Compte supprimé » ; l'anonymisation d'un élève se comporte comme avant

---

## Lot E — Anonymisation automatique à 30 jours (si Q1 l'accepte)

- **Couche**       : domaine + infrastructure (job)
- **Fichiers**     : `app/domain/use_cases/identity/anonymize_deactivated_users.rb`
                     `app/domain/policies/identity/anonymize_deactivated_users_policy.rb`
                     `app/jobs/identity/anonymize_deactivated_users_job.rb`
                     `config/recurring.yml` (4 h 15)
- **Dépend de**    : Lot C, Lot D
- **Test associé** : `test/domain/use_cases/identity/anonymize_deactivated_users_test.rb` (31 jours oui, 29 non, élève jamais, réactivé sauté, échec isolé, second passage sans effet) · `test/jobs/identity/anonymize_deactivated_users_job_test.rb` · `test/jobs/recurring_tasks_test.rb`
- **Done quand**   : un enseignant désactivé il y a 31 jours est anonymisé par la tâche du jour, un élève désactivé il y a 60 jours ne l'est pas ; un échec est visible dans `/teams/jobs`

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/teams.rb` | Lot 0 |
| `db/migrate/*`, `db/schema.rb` | Lot 0 |
| `app/domain/entities/identity/user.rb`, `audit_action.rb` | Lot 0 |
| `app/domain/ports/identity/user_repository_port.rb`, `app/infrastructure/repositories/identity/user_repository.rb` | Lot 0 |
| `app/domain/policies/identity/manage_account_policy.rb`, `delete_user_policy.rb` | Lot 0 |
| `app/views/teams/homes/_shortcuts.html.erb`, `config/locales/teams/homes.fr.yml` | Lot 0 |
| `app/controllers/teams/deletion_requests_controller.rb`, `second_factor_resets_controller.rb`, `app/views/teams/deletion_requests/index.html.erb` | Lot 0 |
| `app/controllers/teams/accounts_controller.rb`, `app/views/teams/accounts/*`, `config/locales/teams/accounts.fr.yml` | Lot 0 (renommage), puis Lot A |
| `app/infrastructure/queries/identity/account_search_query.rb`, `account_detail_query.rb` | Lot A |
| `app/views/teams/second_factor_resets/create.turbo_stream.erb` | Lot A |
| `app/controllers/teams/dashboards_controller.rb`, `app/views/teams/dashboards/*`, `config/locales/teams/dashboards.fr.yml` | Lot A |
| `app/domain/use_cases/identity/update_account.rb`, `app/controllers/teams/account_edits_controller.rb`, `app/views/teams/account_edits/*`, `config/locales/teams/account_edits.fr.yml` | Lot B |
| `app/domain/use_cases/identity/deactivate_account.rb`, `reactivate_account.rb`, `app/controllers/teams/account_(de\|re)activations_controller.rb`, leurs vues et locales | Lot C |
| `app/domain/use_cases/identity/anonymize_user.rb`, `app/domain/dtos/identity/deletion_request_input.rb`, `app/controllers/teams/account_deletions_controller.rb` (après Lot 0), `app/views/teams/account_deletions/*`, `config/locales/teams/account_deletions.fr.yml` | Lot D |
| `config/recurring.yml`, `app/jobs/identity/anonymize_deactivated_users_job.rb` | Lot E |

Les Lots B, C, D lisent `teams/accounts/_identity` et `_attachment` (Turbo Stream `replace`) sans les modifier. `account_deletions_controller.rb` est touché par le Lot 0 (une ligne de redirection) puis par le Lot D seul : séquentiel, pas de collision.

**Hors chantier, à surveiller** : `installation-pwa` (V4) ajoute aussi des colonnes à `users` (feuille de route, tableau de collision) : migrations séparées, la seconde fusion rejoue `db:migrate`. `sous-roles-equipe` (V4) réécrit `ManageAccountPolicy` et `DeleteUserPolicy` **après** ce chantier.

## Portes de sortie

- [ ] Q1 à Q8 répondues par le porteur, et le memo, le PRD, l'ADR-0093 et ce plan amendés en conséquence **avant** le Lot 0
- [ ] Tous les lots sont `Done`
- [ ] Un rôle distinct de l'auteur a **exécuté** le résultat : recherche, fiche, modifier, désactiver puis se connecter avec le bon PIN, réactiver, anonymiser ; captures à 390 px et sur ordinateur, menu « Actions » ouvert
- [ ] `bin/ci-quiet` vert, verdict collé dans la PR
- [ ] Revue `security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer` sur le diff final (use cases, policies, routes touchés)
- [ ] ADR-0093 et UDR-0095 à 0097 indexés au commit de clôture (`script/docs/build_index`) ; UDR-0020 et UDR-0049 marquées amendées
- [ ] `journal.md` complété ; ligne `annuaire-equipe` de `docs/chantiers/README.md` déplacée à la clôture
