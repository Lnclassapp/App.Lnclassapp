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

**Statut : arrêté, pas vert.** Deux fichiers hors du champ `Fichiers` sont nécessaires pour que `bin/rails test` et `bin/rails test:system` passent ; conformément à la consigne, l'agent s'est arrêté au lieu de les écrire.

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

## Clôture

| | |
|---|---|
| **Livré le** | — |
| **PR** | — |
| **ADR produits** | [0065](../../decisions/adr/0065-espace-direction-simple-en-lecture-seule.md) |
| **UDR produits** | [0052](../../decisions/udr/0052-espace-direction-simple.md) |
