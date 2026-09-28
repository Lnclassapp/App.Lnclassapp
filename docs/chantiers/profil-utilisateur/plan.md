# Plan d'exécution — Page profil de chaque utilisateur

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot). Specs : [`prd.md`](prd.md). Décisions : [ADR-0055](../../decisions/adr/0055-profil-modification-de-soi-et-revocation-des-sessions.md), [UDR-0041](../../decisions/udr/0041-page-profil.md).

## Graphe

```
Lot 0 — SOCLE (séquentiel) : méthodes de port et adaptateurs, vérification du PIN actuel, actions d'audit, routes
  ↓
  ├─► Lot A  Lire son profil et modifier son nom      ┐
  ├─► Lot B  Changer son numéro                        ├─ en parallèle (3 agents, worktrees isolés)
  └─► Lot C  Changer son PIN                           ┘
```

Dispatch :

```
Vague 1 : Lot 0              → 1 agent, séquentiel
Vague 2 : Lot A ‖ Lot B ‖ Lot C → 3 agents, worktrees isolés depuis feature/profil-utilisateur, Lot 0 mergé
```

Les lots B et C ouvrent leur modale par `open_in_modal` dans leur test système tant que la page du Lot A n'est pas fusionnée ; les boutons de la page (Lot A) pointent vers les routes gelées au Lot 0.

---

## Lot 0 — Socle

- **Couche**       : domaine (contrats) + infrastructure (adaptateurs partagés) + routes
- **Fichiers**     : `app/domain/ports/identity/user_repository_port.rb` (modifié : `update_name`, `update_contact`)
                     `app/domain/ports/identity/session_repository_port.rb` (modifié : `destroy_all_except`)
                     `app/infrastructure/repositories/identity/user_repository.rb` (modifié)
                     `app/infrastructure/repositories/identity/session_repository.rb` (modifié)
                     `app/domain/entities/identity/audit_action.rb` (modifié : `profile.name_changed`, `contact.changed`, `pin.changed`)
                     `app/domain/use_cases/identity/verify_own_pin.rb` (vérifie le PIN actuel, compte l'échec et verrouille comme la connexion ; partagé par B et C)
                     `config/routes/identity.rb` (modifié : `resource :profile`, `profile/name`, `profile/contact`, `profile/pin`)
- **Dépend de**    : —
- **Test associé** : `test/infrastructure/repositories/identity/user_repository_test.rb`
                     `test/infrastructure/repositories/identity/session_repository_test.rb`
                     `test/domain/use_cases/identity/verify_own_pin_test.rb`
                     `test/domain/entities/identity/audit_action_test.rb`
- **Done quand**   : `update_contact` rend `:conflict` sur un numéro pris ; `destroy_all_except` garde la session donnée et elle seule ; un PIN faux passé à `VerifyOwnPin` compte un échec et verrouille au seuil ; les quatre routes existent et répondent 404 tant que leurs contrôleurs ne sont pas livrés

---

## Lot A — Lire son profil et modifier son nom

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/identity/profile_query.rb`
                     `app/domain/use_cases/identity/update_own_name.rb`
                     `app/controllers/identity/profiles_controller.rb`
                     `app/controllers/identity/profile_names_controller.rb`
                     `app/views/identity/profiles/show.html.erb`
                     `app/views/identity/profiles/_information.html.erb`
                     `app/views/identity/profile_names/edit.html.erb`
                     `app/views/identity/profile_names/update.turbo_stream.erb`
                     `config/locales/identity/profiles.fr.yml`
                     `test/system/role_homes_test.rb` (modifié : « Mon profil » actif)
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/identity/profile_query_test.rb`
                     `test/domain/use_cases/identity/update_own_name_test.rb`
                     `test/controllers/identity/profiles_controller_test.rb`
                     `test/controllers/identity/profile_names_controller_test.rb`
                     `test/system/identity/profile_test.rb`
- **Critères**     : PR-01, PR-02, PR-03
- **Done quand**   : un élève, un enseignant et un membre de l'équipe ouvrent « Mon profil » depuis le menu du compte et voient les informations de leur rôle ; l'élève corrige son prénom dans la modale, la carte se met à jour sans rechargement, et son enseignant voit le nouveau nom

---

## Lot B — Changer son numéro

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : `app/domain/use_cases/identity/change_own_contact.rb`
                     `app/domain/dtos/identity/contact_change_input.rb`
                     `app/controllers/identity/profile_contacts_controller.rb`
                     `app/views/identity/profile_contacts/edit.html.erb`
                     `config/locales/identity/profile_contacts.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/identity/change_own_contact_test.rb`
                     `test/controllers/identity/profile_contacts_controller_test.rb`
                     `test/system/identity/profile_contact_test.rb`
- **Critères**     : PR-04, PR-05, PR-07 (par le numéro)
- **Done quand**   : un élève change son numéro avec son PIN actuel et une double saisie, se reconnecte avec le nouveau numéro, son autre session est fermée ; un numéro pris donne le message neutre ; un PIN faux compte un échec

---

## Lot C — Changer son PIN

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : `app/domain/use_cases/identity/change_own_pin.rb`
                     `app/domain/dtos/identity/pin_change_input.rb`
                     `app/controllers/identity/profile_pins_controller.rb`
                     `app/views/identity/profile_pins/edit.html.erb`
                     `config/locales/identity/profile_pins.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/identity/change_own_pin_test.rb`
                     `test/controllers/identity/profile_pins_controller_test.rb`
                     `test/system/identity/profile_pin_test.rb`
- **Critères**     : PR-06, PR-07 (par le PIN)
- **Done quand**   : un enseignant change son PIN, se reconnecte avec le nouveau, l'ancien est refusé, et la session d'un second navigateur ramène à la connexion ; au seuil d'échecs, le compte est verrouillé

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/identity.rb` | Lot 0 |
| `app/infrastructure/repositories/identity/user_repository.rb` | Lot 0 (A et B l'utilisent) |
| `app/infrastructure/repositories/identity/session_repository.rb` | Lot 0 (B et C l'utilisent) |
| `app/domain/use_cases/identity/verify_own_pin.rb` | Lot 0 (B et C l'utilisent) |
| `app/domain/entities/identity/audit_action.rb` | Lot 0 |
| `config/locales/identity/*.fr.yml` | un fichier par lot : `profiles` (A), `profile_contacts` (B), `profile_pins` (C) |
| `test/system/role_homes_test.rb` | Lot A |
| `app/helpers/navigation_helper.rb` | aucun : l'entrée devient active d'elle-même dès que `profile_path` existe (Lot 0) |

Commande de contrôle (sortie vide attendue) :

```bash
awk '/^## Vérification de collision/{exit} 1' docs/chantiers/profil-utilisateur/plan.md \
  | grep -oE '(app|test|config|db|lib)/[A-Za-z0-9_/.-]+\.(rb|erb|yml|js)' | sort | uniq -d
```

Traçabilité des critères : PR-01, PR-02, PR-03 → Lot A ; PR-04, PR-05 → Lot B ; PR-06 → Lot C ; PR-07 → Lot 0 (`VerifyOwnPin`), prouvé par B et C. Aucun critère orphelin.

---

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md`
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md`
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
