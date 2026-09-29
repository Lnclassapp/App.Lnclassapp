# Journal — Espace direction, version simple

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Remplacer la conception complète de la V2 par deux pages en lecture seule | Le porteur la juge « une usine à gaz » ; apprendre d'abord des vraies directions | ADR-0065 |
| 2026-09-28 | Un seul type de compte direction, sans fonction ni second facteur | Réponses 1 et 2 du porteur | ADR-0065, amendement de l'ADR-0044 |
| 2026-09-28 | Le taux de rendu compte les paires élève × devoir rendues, et tout se lit sur les élèves présents | La page d'une classe montre « devoirs rendus / devoirs donnés » par élève : le taux de la classe doit en être la moyenne, sinon deux pages se contredisent | ADR-0065 §4 |
| 2026-09-28 | L'accueil de la direction (`HomeDestination`) appartient au Lot C, pas au Lot 0 | Le Lot 0 doit laisser l'application verte ; une redirection vers une page absente ne l'est pas | Non |
| 2026-09-28 | Numéros ADR-0065 et UDR-0052, les suivants libres dans `Develop` | Consigne du porteur ; la branche `feature/espace-direction` utilise les mêmes numéros | Non (noté en coût dans l'ADR-0065) |

## Ce qui a dérapé

- La V2 a d'abord été conçue en grand (65 critères, trois ADR, deux UDR, un Lot 0a codé) avant qu'une seule direction réelle ne l'ait vue. Leçon : pour un public qu'on ne connaît pas encore, livrer la plus petite page utile et écouter.

## Ce qu'on a appris sur la codebase

- Le rôle `school_admin`, l'invitation `school_staff` et la navigation de la direction existent depuis la V1, mais la contrainte `invitations_staff_has_school` et `Entities::Identity::Invitation` exigent une fonction : il faut les assouplir.
- `SessionPolicy` et `ResolveSession` ne gardent que `team` : une direction se connecte déjà par PIN seul, sans rien changer à la session.
- `SchoolDetailQuery#teachers` fait déjà la jointure enseignant → matière qu'il faut pour « Enseignants ».

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Retirer une direction à l'écran | Hors du périmètre simple | `annuaire-equipe` (backlog) |
| Second facteur de la direction | Décision du porteur | `espace-direction` (backlog), dès qu'une direction écrit |
| Rendu exact par exercice | Grossier mais suffisant pour une première lecture | `rapports-de-classe` (V3) |

## Lot 0 — Socle (2026-09-29)

**Statut au premier passage : arrêté, pas vert** (rouvert plus bas). Deux fichiers hors du champ `Fichiers` sont nécessaires pour que `bin/rails test` et `bin/rails test:system` passent ; conformément à la consigne, l'agent s'est arrêté au lieu de les écrire.

Fait (branche `feature/espace-direction-simple-lot-0`) :

- migration `20260929100000_create_school_staffs` (table `school_staffs`, contrainte `invitations_staff_has_school` assouplie) ; `db/schema.rb` réduit aux seuls changements réels ;
- `Orm::SchoolStaff`, `Orm::User#school_staff` ; `UserRepository#actor_for` remplit `school_id` d'une direction depuis `school_staffs` ;
- `Entities::Identity::Invitation` : fonction facultative ; `Ports::School::StaffRepositoryPort#attach(user_id:, school_id:, invited_by_id:, at:)` ; `Policies::School::ReadOwnSchoolPolicy#call(actor:)` ;
- routes `school_admin_classrooms`, `school_admin_classroom`, `school_admin_teachers` (GET seul, `config/routes/school_admin.rb`), `school_staff_invitations`, `new_school_staff_invitation` ; `SchoolAdmin::BaseController` (garde par la policy, 403) ;
- navigation de la direction à deux entrées ; fabrique `create_school_admin(school:)` ; cas `school_admin` retiré de `role_homes_test.rb`.

Bloquants (à trancher par le porteur, puis rouvrir le Lot 0) :

| Porte | Échec | Fichier manquant au Lot 0 |
|---|---|---|
| `bin/rails test` | `test/architecture/port_contracts_test.rb` exige exactement un adaptateur par port : `Ports::School::StaffRepositoryPort` n'en a aucun avant le Lot A | `app/infrastructure/repositories/school/staff_repository.rb` (+ `test/infrastructure/repositories/school/staff_repository_test.rb`), à remonter du Lot A au Lot 0 |
| `bin/rails test:system` | `test/system/design_system_test.rb:340` attend « Accueil » actif dans la démonstration du shell de chaque rôle ; la direction n'a plus d'accueil | `app/views/design/shell.html.erb` (`content_for :nav_key` = première destination du rôle) ou le test lui-même |

Écarts au plan et à l'UDR-0052 :

- **Clé de navigation `:student_work`, pas `:classrooms`.** `shared/navigation/_link` tire le libellé de la clé (`shared.navigation.<clé>`) et `classrooms` vaut déjà « Classes » pour l'enseignant. Sans toucher au partiel (hors champ), la destination de la direction s'appelle `:student_work` (« Travail des élèves »). **Le Lot C déclare donc `content_for :nav_key, "student_work"`**, pas `"classrooms"`. La clé `students` (« Élèves »), qui ne servait qu'à l'ancienne navigation de la direction, est retirée.
- `test/infrastructure/orm/models_test.rb` (hors champ) : nombre de modèles `Orm::` 34 → 35, conséquence mécanique de `Orm::SchoolStaff`.
- La fabrique `create_invitation(kind: "school_staff")` garde sa fonction `"principal"` par défaut (`test/support/factories_test.rb`, hors champ, l'attend) ; les tests passent `position: nil`.
- `SchoolAdmin::BaseController` n'a pas de test propre au Lot 0 (aucune action avant les Lots B et C) ; ses refus sont testés par les contrôleurs des Lots B et C (DS-11).

Portes, lancées une fois : `bin/rubocop` 0 offense (990 fichiers) ; `CI=1 PARALLEL_WORKERS=2 bin/rails test` 2342 tests, **1 échec** (`PortContractsTest`), 7 skips préexistants (tests de performance sous `PERF=1`), couverture 100 % lignes (8450/8450) et branches (2065/2065) ; `COVERAGE=0 bin/rails test:system` 195 tests, **1 échec** (`design_system_test.rb:340`) ; `bin/brakeman -q --no-pager` 0 alerte.

### Lot 0 rouvert (2026-09-29) — vert

Décision de l'orchestrateur : les deux fichiers bloquants remontent au Lot 0 (plan mis à jour : `Fichiers` des Lots 0 et A, tableau de collision, note du Lot C).

- `Repositories::School::StaffRepository#attach` (+ `test/infrastructure/repositories/school/staff_repository_test.rb`) : écrit la ligne `school_staffs` datée de `at`, rend `true` ; un second rattachement lève `RecordNotUnique`. Le Lot A l'utilise, il ne l'écrit plus.
- `design/shell` déclare comme `nav_key` la première destination du rôle. `test/system/design_system_test.rb:340` codait « Accueil » en dur pour **chaque** rôle, direction comprise : il attend maintenant le libellé de la première destination du rôle, seule assertion juste depuis que la direction n'a plus d'accueil (UDR-0052 §2.1).
- UDR-0052 : amendement daté du 2026-09-29, clé de navigation `student_work`.

Portes, lancées une fois : `bin/rubocop` 0 offense (992 fichiers) ; `CI=1 PARALLEL_WORKERS=2 bin/rails test` 2344 tests, 0 échec, 0 erreur, 7 skips préexistants (`PERF=1`), couverture 100 % lignes (8457/8457) et branches (2065/2065) ; `COVERAGE=0 bin/rails test:system` 195 tests, 0 échec ; `bin/brakeman -q --no-pager` 0 alerte.

## Clôture

| | |
|---|---|
| **Livré le** | — |
| **PR** | — |
| **ADR produits** | [0065](../../decisions/adr/0065-espace-direction-simple-en-lecture-seule.md) |
| **UDR produits** | [0052](../../decisions/udr/0052-espace-direction-simple.md) |

## Lot A — L'équipe invite, la direction crée son compte (2026-09-29)

**Statut : vert.** Branche `feature/espace-direction-simple-lot-a`. Critères DS-01 à DS-04.

Fait :

- `Policies::Identity::InviteSchoolStaffPolicy` : compte `team` de sous-rôle `admin` ou `field`.
- `Dtos::Identity::SchoolStaffInvitationInput` (numéro seul ; `school_public_id` vient de l'adresse de la fiche) et `UseCases::Identity::InviteSchoolStaff` : mêmes règles que `InviteTeamMember` ; établissement inconnu `:not_found` (404), non actif (brouillon compris) `:invalid` `school: [:inactive]` ; invitation `school_staff` sans fonction ; journal `invitation.sent` `{ kind:, school_id: }`.
- `AcceptInvitation` accepte les deux types : `school_staff` → compte `school_admin`, puis `StaffRepositoryPort#attach` dans la même transaction ; journal `invitation.accepted` `{ kind:, school_id: }` pour la direction.
- `Teams::StaffInvitationsController` et ses vues (`new`, `_created`, `created`, `create.turbo_stream`) : modale de l'UDR-0019 réduite au numéro, refus « Cet établissement n'est pas actif. » en tête de la modale, lien affiché une fois, `Cache-Control: no-store`.
- Fiche : « Inviter la direction » en premier dans le menu ⋮, pour un établissement actif seulement.
- Acceptation : variante direction (encadré « Vous rejoignez <établissement> comme direction. », toast « Votre compte est créé. Connectez-vous avec votre numéro et votre PIN. »).
- Profil : plus de badge « Compte en attente » pour la direction ; ligne « Établissement ». Shell : le nom de l'établissement sous le nom (`ShellUserQuery`).

Écarts au plan et à l'UDR-0052 :

- **`app/infrastructure/repositories/identity/invitation_repository.rb` n'a pas changé** : `create` acceptait déjà `school_id:` et `position: nil`.
- **Un test hors du champ, modifié par conséquence mécanique** : `test/controllers/identity/profiles_controller_test.rb` attendait le badge « Compte en attente » de la direction, que l'UDR-0052 retire ; le cas devient « la direction lit son établissement » (profil et shell). Les tests d'intégration de l'acceptation (page de la variante, toast, compte rattaché) sont dans `test/controllers/teams/staff_invitations_controller_test.rb`, pour ne pas toucher `test/controllers/identity/invitations_controller_test.rb`.
- **Page d'acceptation : titre et accueil de la variante direction** (« Créer votre compte de direction », « Bienvenue sur Lnclass »…) en plus de l'encadré prescrit : l'accueil « Bienvenue dans l'équipe Lnclass » aurait menti à la direction. Les clés `identity.invitations.show.*` propres à chaque type passent sous `team.` et `school_staff.`.
- **Le nom de l'établissement de la page d'acceptation** se lit par `SchoolRepository#find_by_id` depuis le contrôleur (helper `invitation_school_name`), y compris quand le formulaire est re-rendu en 422 ; l'entité `Invitation` (Lot 0) n'a pas été touchée.
- `DTO#school` renvoie `school_public_id` : ActiveModel lit l'attribut qui porte l'erreur `school: [:inactive]` de l'ADR-0065.
- Les tests d'intégration et système invitent le **0799000009**, pas le 0700000009 du PRD : la fabrique donne aux comptes `team` des numéros `07` + séquence, et le 0700000009 est déjà pris dès la 9ᵉ fabrication (échec intermittent vu par le pre-commit, 422 au lieu de 200).
- Après connexion, la direction arrive encore sur l'écran d'attente : son accueil « Travail des élèves » est au Lot C. Le test système de DS-03 ne vérifie donc pas la page d'arrivée, seulement l'absence de second facteur et le profil.

Portes, lancées une fois : `bin/rubocop` 0 offense (1000 fichiers) ; `CI=1 PARALLEL_WORKERS=2 bin/rails test` 2367 tests, 0 échec, 0 erreur, 7 skips préexistants (`PERF=1`), couverture 100 % lignes (8552/8552) et branches (2095/2095) ; `COVERAGE=0 bin/rails test:system` 196 tests, **3 échecs et 2 erreurs de délai** (`boucle_pedagogique_test`, `teams/essential_management_test`, `identity/cold_start_test`, `error_paths_test`, `school/classrooms_by_level_test`) sous une charge de 21 à 26 (trois lots en parallèle sur la machine), aucun dans un fichier touché par le lot ; relancés seuls pour diagnostic, ces 5 fichiers passent (27 tests, 0 échec) ; `bin/brakeman -q --no-pager` 0 alerte.
