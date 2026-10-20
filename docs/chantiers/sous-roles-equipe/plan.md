# Plan d'exécution — Sous-rôles de l'équipe appliqués

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> **Préalable** : réponses du porteur aux questions 1 à 10 du [memo](memo.md), reportées dans le PRD, l'ADR-0100 et les UDR-0116 à 0118, puis ces quatre décisions passées `Accepté`. Aucun lot ne démarre avant.

## Graphe

```
Lot 0 — SOCLE (séquentiel, court)
  matrice TeamCapabilities · Actor#may? · contrat du port UserRepositoryPort#change_team_role
  NavigationHelper + partials du shell · page 403 · routes · locales
  ↓
  ├─► Lot A « Contenu, taxonomie, imports, Référentiel »        ┐
  ├─► Lot B « Établissements, classes, direction »              ├─ en parallèle, fichiers disjoints
  ├─► Lot C « Comptes : sous-rôle, TOTP, PIN, jobs »            │
  └─► Lot D « Annonces, Pilotage, Croissance, accueil »         ┘
  ↓
Lot E — PORTE (séquentiel) : test de matrice sur toutes les routes, test d'architecture, captures, revue des membres
```

**5 lots de code + 1 lot de porte = 6 lots.** Quatre agents en parallèle après le Lot 0.

---

## Lot 0 — Socle

- **Couche**       : domaine (contrats) + delivery partagée + UI partagée
- **Fichiers**     : `app/domain/entities/identity/team_capabilities.rb` *(nouveau)*
                     `app/domain/entities/identity/actor.rb` (`may?`)
                     `app/domain/ports/identity/user_repository_port.rb` (`change_team_role(target_id:, team_role:)` → `Shared::Result` `:conflict` | `:not_found` ; contrat seul)
                     `app/helpers/navigation_helper.rb` (capacité par destination, acteur facultatif — UDR-0116 §3.1)
                     `app/views/shared/navigation/_sidebar.html.erb` · `_bottom_bar.html.erb` · `_more_menu.html.erb` · `_header.html.erb` · `_avatar_menu.html.erb`
                     `app/views/errors/forbidden.html.erb` (UDR-0116 §3.4)
                     `config/routes/teams.rb` (route `members/:user_public_id/team-role`, UDR-0118)
                     `config/locales/errors/*.fr.yml` · `config/locales/teams/invitations.fr.yml` (clés `teams.team_roles.*` et aides, UDR-0118) · `config/locales/teams/member_team_roles.fr.yml` *(nouveau)* · `config/locales/teams/homes.fr.yml` · `config/locales/teams/dashboards.fr.yml` · `config/locales/teams/account_lookups.fr.yml` · `config/locales/teams/imports.fr.yml` *(toutes les clés des lots A à D, écrites ici)*
- **Dépend de**    : réponses du porteur ; ADR-0100, UDR-0116 à 0118 `Accepté`
- **Test associé** : `test/domain/entities/identity/team_capabilities_test.rb` (13 capacités, 39 cases, capacité inconnue → `ArgumentError`) ; `test/domain/entities/identity/actor_test.rb` (`may?` faux hors équipe) ; `test/helpers/navigation_helper_test.rb` (entrées par sous-rôle, `bottom_bar_size` 5/4/5) ; `test/controllers/errors/forbidden_page_test.rb` *(nouveau, texte de l'équipe)*
- **Done quand**   : la matrice se lit en un fichier et ses tests passent ; un membre « Contenu » connecté ne voit plus « Établissements » dans le shell à 390 px ; les lots A à D peuvent démarrer sans toucher un fichier partagé

---

## Lot A — Contenu, taxonomie, imports, Référentiel

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/policies/catalog/manage_content_policy.rb` · `manage_taxonomy_policy.rb` · `read_published_policy.rb`
                     `app/domain/policies/assessment/reveal_answers_policy.rb`
                     `app/domain/policies/communication/manage_articles_policy.rb` · `manage_illustrations_policy.rb`
                     `app/domain/entities/catalog/import_kind.rb` (`allowed_kinds(actor)`)
                     `app/infrastructure/queries/catalog/import_reports_query.rb` (`kinds:`)
                     `app/controllers/teams/imports_controller.rb` · `app/views/teams/imports/index.html.erb` · `new.html.erb`
                     `app/controllers/catalog/courses_controller.rb` · `app/views/catalog/courses/index.html.erb` · `_page.html.erb` · `show.html.erb`
                     `app/controllers/teams/referentials_controller.rb` · `app/views/teams/referentials/_summary.html.erb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/policies/catalog/manage_content_policy_test.rb` · `manage_taxonomy_policy_test.rb` · `test/domain/policies/communication/manage_illustrations_policy_test.rb` · `manage_articles_policy_test.rb` (refus `field` sur chacune) ; `test/domain/entities/catalog/import_kind_test.rb` (`allowed_kinds`) ; `test/controllers/teams/imports_controller_test.rb` (liste et `new` filtrés, `kind` interdit → 403) ; `test/controllers/catalog/courses_controller_test.rb` (boutons absents pour `field`)
- **Done quand**   : Fanta (terrain) reçoit 403 sur `/teams/courses/new`, `/teams/levels/new`, `/teams/blog`, `/teams/announcement-illustrations` et sur un import « exercises » ; `/courses` et `/teams/imports` ne lui montrent aucun geste de contenu ; Koffi (contenu) garde tout cela

---

## Lot B — Établissements, classes, direction

- **Couche**       : domaine + delivery
- **Fichiers**     : `app/domain/policies/school/manage_school_policy.rb` · `manage_school_structure_policy.rb` · `remove_school_staff_policy.rb` · `restore_school_staff_policy.rb`
                     `app/domain/policies/identity/invite_school_staff_policy.rb`
                     `app/domain/policies/classroom/manage_classroom_policy.rb` · `manage_classroom_plan_policy.rb` · `read_classroom_policy.rb` · `teach_policy.rb` · `follow_assignment_policy.rb` · `manage_classroom_members_policy.rb`
                     `app/domain/policies/assessment/read_session_policy.rb`
- **Dépend de**    : Lot 0
- **Test associé** : un test de refus `content` par policy : `test/domain/policies/school/*_test.rb` · `test/domain/policies/classroom/*_test.rb` · `test/domain/policies/assessment/read_session_policy_test.rb` · `test/domain/policies/identity/invite_school_staff_policy_test.rb`
- **Done quand**   : Koffi (contenu) reçoit 403 sur la fiche d'un établissement, le barème, la régénération d'un code, la validation d'un enseignant en attente, l'invitation d'une direction, la page d'une classe et la session d'un élève ; Fanta (terrain) garde tout cela

---

## Lot C — Comptes : changer un sous-rôle, second facteur, PIN, jobs

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/policies/identity/invite_team_policy.rb` · `reset_second_factor_policy.rb` · `delete_user_policy.rb` · `read_user_policy.rb` · `issue_pin_recovery_code_policy.rb`
                     `app/domain/policies/identity/change_team_role_policy.rb` *(nouveau)*
                     `app/domain/use_cases/identity/change_team_role.rb` *(nouveau)* · `app/domain/dtos/identity/team_role_change_input.rb` *(nouveau)*
                     `app/infrastructure/repositories/identity/user_repository.rb` (`change_team_role`, transaction, `FOR UPDATE` sur les admins)
                     `app/controllers/teams/jobs_base_controller.rb` *(nouveau)* · `config/application.rb` (base de Mission Control)
                     `app/controllers/teams/member_team_roles_controller.rb` *(nouveau)* · `app/views/teams/member_team_roles/edit.html.erb` · `update.turbo_stream.erb` *(nouveaux)*
                     `app/views/teams/shared/_team_role_fields.html.erb` *(nouveau)* · `app/views/teams/invitations/new.html.erb`
                     `app/controllers/teams/account_lookups_controller.rb` · `app/views/teams/account_lookups/_result.html.erb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/identity/change_team_role_test.rb` (soi-même, non-admin, dernier admin, cibles hors équipe, sous-rôle inconnu, même sous-rôle, journal) ; `test/infrastructure/repositories/identity/user_repository_change_team_role_test.rb` (deux rétrogradations concurrentes → un seul succès) ; `test/domain/policies/identity/*_test.rb` (refus `content` et `field` sur `manage_team`, `erase_accounts` ; refus `content` sur `read_people`) ; `test/controllers/teams/member_team_roles_controller_test.rb` ; `test/integration/teams/mission_control_access_test.rb` (403 pour `content` et `field`)
- **Done quand**   : Awa (admin) passe Koffi de « Contenu » à « Terrain » depuis la fiche de son compte, et Koffi voit le shell du terrain à sa page suivante ; Fanta (terrain) n'a ni « Réinitialiser le second facteur » ni « Changer le rôle » et reçoit 403 sur `/teams/jobs` ; Koffi reçoit 403 sur `/teams/accounts`

---

## Lot D — Annonces, Pilotage, Croissance, accueil

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : `app/domain/policies/communication/publish_policy.rb` · `read_file_policy.rb`
                     `app/domain/entities/communication/message.rb` (`moderatable_by?`, branche équipe)
                     `app/controllers/communication/moderations_controller.rb` · `app/views/communication/moderations/index.html.erb` · `app/views/communication/shared/_tabs.html.erb`
                     `app/controllers/communication/authored_messages_controller.rb` · `app/views/communication/authored_messages/index.html.erb` (local `can_moderate` des onglets)
                     `app/domain/policies/school/read_indicators_policy.rb` · `app/domain/policies/identity/read_growth_policy.rb`
                     `app/controllers/teams/dashboards_controller.rb` · `app/views/teams/dashboards/show.html.erb`
                     `app/controllers/teams/homes_controller.rb` · `app/views/teams/homes/show.html.erb` · `_shortcuts.html.erb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/entities/communication/message_test.rb` (refus de modération `content`) ; `test/domain/policies/communication/publish_policy_test.rb` (les trois publient) ; `test/controllers/teams/dashboards_controller_test.rb` (contenu : indicateurs sans recherche ni inscriptions récentes ; frame de recherche → 403) ; `test/controllers/teams/homes_controller_test.rb` (raccourcis et sections par sous-rôle, frame du contenu récent → 403 pour `field`) ; `test/controllers/communication/moderations_controller_test.rb`
- **Done quand**   : Koffi (contenu) ouvre le Pilotage et voit les indicateurs sans aucun nom ni numéro, reçoit 404 en retirant l'annonce d'un enseignant, et son accueil n'a ni « Établissements » ni « Débloquer un compte » ; Fanta (terrain) n'a ni « Nouveau cours » ni « Blog » ni la carte « Activité »

---

## Lot E — Porte de la V4

- **Couche**       : tests + preuve
- **Fichiers**     : `test/integration/teams/sub_role_matrix_test.rb` *(nouveau : toutes les routes `GET` de `config/routes/teams.rb`, Mission Control compris, × 3 sous-rôles ; une route sans capacité déclarée échoue)*
                     `test/architecture/team_policies_use_capabilities_test.rb` *(nouveau : aucune policy ne teste `team?` hors `SecondFactorPolicy`)*
                     `docs/chantiers/sous-roles-equipe/journal.md`
- **Dépend de**    : Lots A, B, C, D
- **Test associé** : les deux fichiers ci-dessus ; `bin/ci-quiet`
- **Done quand**   : les 13 cases vides ont leur refus vert ; le test de matrice passe sur toutes les routes ; captures des UDR-0116 à 0118 envoyées au porteur (390 px et ordinateur) ; le porteur a relu la liste des membres de l'équipe en production et leur sous-rôle (memo, question 7) ; `bin/ci` écrit dans la PR

---

## Vérification de collision

> Deux lots ne listent jamais le même fichier.

| Fichier | Lot propriétaire |
|---|---|
| `app/domain/entities/identity/actor.rb`, `team_capabilities.rb` | Lot 0 |
| `app/domain/ports/identity/user_repository_port.rb` | Lot 0 |
| `app/helpers/navigation_helper.rb`, `app/views/shared/navigation/*` | Lot 0 |
| `app/views/errors/forbidden.html.erb` | Lot 0 |
| `config/routes/teams.rb` | Lot 0 |
| `config/locales/**` (toutes les clés du chantier) | Lot 0 |
| `app/domain/policies/catalog/*`, `assessment/reveal_answers_policy.rb`, `communication/manage_*` | Lot A |
| `app/domain/entities/catalog/import_kind.rb`, imports, `catalog/courses/*`, `teams/referentials/*` | Lot A |
| `app/domain/policies/school/manage_*`, `remove_*`, `restore_*`, `classroom/*` (6), `assessment/read_session_policy.rb`, `identity/invite_school_staff_policy.rb` | Lot B |
| `app/domain/policies/identity/{invite_team,reset_second_factor,delete_user,read_user,issue_pin_recovery_code,change_team_role}_policy.rb` | Lot C |
| `app/infrastructure/repositories/identity/user_repository.rb`, `config/application.rb`, `teams/member_team_roles/*`, `teams/account_lookups/*`, `teams/invitations/new.html.erb`, `teams/shared/_team_role_fields.html.erb` | Lot C |
| `app/domain/policies/communication/{publish,read_file}_policy.rb`, `entities/communication/message.rb`, moderations, `_tabs`, `authored_messages_controller.rb` | Lot D |
| `app/domain/policies/school/read_indicators_policy.rb`, `identity/read_growth_policy.rb`, `teams/dashboards/*`, `teams/homes/*` | Lot D |
| `test/integration/teams/sub_role_matrix_test.rb`, `test/architecture/*` | Lot E |

`_tabs.html.erb` est rendu par trois pages : `moderations/index`, `authored_messages/index` (Lot D) et `inboxes/show`, que l'équipe n'atteint jamais (`InboxesController` la redirige vers « Mes annonces ») : `inboxes` reste hors du chantier, le local `can_moderate` a la valeur `false` par défaut.

## Portes de sortie

- [ ] Réponses du porteur reportées ; ADR-0100 et UDR-0116 à 0118 `Accepté`
- [ ] Tous les lots sont `Done`
- [ ] Un rôle distinct de l'auteur a **exécuté** le résultat : connexion sous chacun des trois sous-rôles, parcours du PRD §3 refait dans l'application
- [ ] Pureté du domaine, rubocop, tests, parcours système : au vert (`bin/ci-quiet`, puis `bin/ci` écrit dans la PR)
- [ ] Sous-agents de revue (`security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`) une fois sur le diff final : policies et use case touchés
- [ ] Captures des trois UDR envoyées au porteur, non commitées
- [ ] Index ADR / UDR régénérés par `script/docs/build_index` au commit de clôture ; feuille de route (V4, Q9, tableau de collision) et `docs/chantiers/README.md` mis à jour à la clôture
- [ ] `journal.md` complété
