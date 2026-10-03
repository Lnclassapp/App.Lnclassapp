# ADR-0065 : La direction, invitée par l'équipe et connectée par PIN, lit son seul établissement

| | |
|---|---|
| **Statut** | Accepté *(par le porteur le 2026-09-29)* |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/espace-direction-simple`](../../chantiers/espace-direction-simple/prd.md) — critères DS-01 à DS-11 |
| **Amende** | [ADR-0044](./0044-rattachement-de-la-direction-par-invitation.md) : fonctions, second facteur, inviteurs, départ · [ADR-0025](./0025-pin-a-4-chiffres-comme-secret-d-authentification.md), compensation 5, pour `school_admin` |
| **Complète** | [ADR-0062](./0062-indicateurs-de-pilotage-lus-en-direct.md) (définitions et lecture en direct) |
| **Remplace** | — |
| **Remplacé par** | — *(amendé par [ADR-0069](./0069-annonces-trois-auteurs-classes-ciblees-et-retrait.md) le 2026-10-03, accepté le même jour : la direction écrit des annonces, hors de `/school-admin` ; §2, §4)* |

---

## 1. Contexte et problématique

L'ADR-0044 prévoyait une direction à quatre fonctions, invitée par l'équipe ou par un collègue, protégée par un second facteur TOTP. La conception complète de la V2 (branche `feature/espace-direction`) y ajoutait un matricule, des droits par fonction et une dizaine de gestes. Le porteur l'a écartée le 2026-09-28 : il veut d'abord deux pages en lecture seule, « la liste des enseignants, et le travail des élèves », et apprendre des vraies directions avant d'aller plus loin.

Aujourd'hui, le rôle `school_admin` existe dans le schéma, l'invitation de type `school_staff` aussi (ADR-0038), mais aucun compte de direction ne peut naître ni rien voir : son accueil est l'écran d'attente.

## 2. Moteurs de décision

1. Le moins de schéma et de gestes possible : rien qui présume de ce que voudront les directions.
2. Une direction ne lit que son établissement, et n'écrit rien.
3. Les chiffres reprennent des définitions déjà écrites (ADR-0062), lues en direct, en un nombre de requêtes fixe.
4. La même connexion que les enseignants : téléphone et PIN.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — La conception complète (ADR-0044 tel quel, matricule, droits par fonction) | Déjà écrite et relue | Jugée trop lourde par le porteur ; décide à la place des directions |
| B — Un enseignant « marqué direction » | Aucun rôle à activer | Mélange deux publics ; un enseignant verrait l'établissement entier |
| C — **Rôle `school_admin`, rattachement sans fonction, PIN seul, deux lectures** | Minimal ; réutilise l'invitation et les définitions du pilotage | Retenue — voir coûts |

## 4. Décision

> **Nous créons les comptes de direction par invitation de l'équipe, rattachés à un seul établissement, sans fonction ni second facteur, et nous leur donnons deux lectures de leur établissement : ses enseignants, et le travail de ses élèves.**

**Table `school_staffs`** (contexte `school`) : `user_id` (FK `users`, **index unique** : un établissement par compte), `school_id` (FK `schools`), `invited_by_id` (FK `users`), `created_at`. Clés en `ON DELETE RESTRICT` (ADR-0036). Ni `position`, ni `left_at` : aucun geste ne les utiliserait. La conception complète les ajoutera.

**Invitation** (table `invitations`, ADR-0038) :

- la contrainte `invitations_staff_has_school` devient `kind <> 'school_staff' OR school_id IS NOT NULL` ; `position` reste `NULL` ;
- `UseCases::Identity::InviteSchoolStaff`, policy `Policies::Identity::InviteSchoolStaffPolicy` : compte `team` de sous-rôle `admin` ou `field` (matrice de l'ADR-0038 ; en V1 tout compte `team` est `admin`) ;
- mêmes règles que `InviteTeamMember` : numéro au format, `:conflict` si le numéro a un compte ou une invitation en cours, jeton de 72 h affiché une fois ;
- établissement inconnu ou non actif : `:invalid` (`school: [:inactive]`) ;
- journal `invitation.sent`, `metadata: { kind: "school_staff", school_id: }`.

**Acceptation** : `UseCases::Identity::AcceptInvitation` accepte les deux types. Pour `school_staff`, dans la même transaction, il crée le compte `school_admin` puis la ligne `school_staffs` par `Ports::School::StaffRepositoryPort#attach(user_id:, school_id:, invited_by_id:, at:)`.

**Connexion** : téléphone et PIN (ADR-0050), sans second facteur. Rien ne change dans `ResolveSession` ni `SessionPolicy`, qui ne gardent que `team`. La session garde sa durée absolue de 12 h (`SessionLifetime`).

**Acteur** : `UserRepository#actor_for` remplit `school_id` depuis `school_staffs` pour un `school_admin`. `HomeDestination` mène la direction à `:school_admin_classrooms`.

**Lectures** (aucun use case : ADR-0006, ADR-0062) :

- `Policies::School::ReadOwnSchoolPolicy` : acteur `school_admin` avec un `school_id`, sinon `:forbidden` ;
- l'établissement lu est **toujours** `actor.school_id`, jamais un paramètre ;
- `Queries::School::SchoolTeachersQuery#call(school_id:)` ;
- `Queries::School::StudentWorkQuery#classrooms(school_id:)` et `#classroom(school_id:, public_id:)`, qui renvoie `nil` pour une classe d'un autre établissement : le contrôleur répond 404.

**Définitions** (une phrase chacune, chacune testée) :

| Chiffre | Définition |
|---|---|
| Classe | Classe `active` de l'année scolaire en cours de l'établissement (ADR-0062) |
| Enseignant de l'établissement | Compte enseignant non anonymisé rattaché à l'établissement (`teacher_schools`, principal ou non) ; un enseignant en attente n'en est pas |
| Classes d'un enseignant | Les classes de l'établissement qu'il a déclarées (`teacher_classrooms`) |
| Élève d'une classe | Élève non anonymisé dont l'adhésion à la classe n'est pas quittée |
| Devoir donné | Ligne `classroom_assignments` de la classe, tous statuts |
| Devoir rendu (par un élève) | Devoir de la classe pour lequel l'élève a au moins une session `completed`, `kind = 'standard'`, qui lui est rattachée (`classroom_assignment_id`) |
| Taux de rendu d'une classe | Devoirs rendus par ses élèves ÷ (élèves × devoirs donnés), arrondi ; « — » sans élève ou sans devoir |
| Score moyen d'un élève | Moyenne arrondie des `score_percent` de ses sessions rendues dans la classe ; « — » s'il n'en a aucune |
| Moyenne d'une classe | Moyenne arrondie des `score_percent` des sessions rendues par ses élèves ; « — » si **moins de 5 élèves** ont rendu (`MIN_STUDENTS_FOR_AVERAGE = 5`) |

Les sessions de remédiation (ADR-0043) ne comptent pas. Tri : classes par niveau (`levels.position`) puis nom ; élèves et enseignants par nom. Pas de pagination : un établissement a au plus 77 classes (ADR-0030), une classe quelques dizaines d'élèves.

**Nombre de requêtes** : fixe, quel que soit le volume ; un test le vérifie en triplant les données.

## 5. Conséquences

### 🟢 Positives

- Une direction a un compte et deux pages utiles, sans rien décider à la place des directions réelles.
- Aucune écriture : aucune policy de geste, aucun journal nouveau, aucun risque de modifier les données d'un autre.
- Les définitions « classe » et « élève » sont celles du pilotage de l'équipe.

### 🔴 Coûts consentis

- **Des noms et des scores de mineurs derrière un PIN à 4 chiffres.** La compensation 5 de l'ADR-0025 (second facteur des rôles privilégiés) ne s'applique plus à `school_admin`. Restent : la limite de débit et le verrouillage de la connexion (ADR-0050), la session de 12 h, la lecture seule, un seul établissement. À revoir dès qu'une direction pourra écrire.
- **Aucun retrait de direction** à l'écran : un compte parti ou invité par erreur se retire en console jusqu'à `annuaire-equipe`.
- **Le rendu est grossier** : une session terminée sur un exercice d'un cours assigné suffit à rendre le cours. Un rendu exact attend `rapports-de-classe` (V3).
- **Un élève parti emporte ses résultats** hors des chiffres de la classe.
- **Numérotation** : la branche `feature/espace-direction` utilise aussi les numéros 0065 à 0067. Reprise, elle devra renuméroter ses ADR.

## 6. Notes d'implémentation

```ruby
# db/migrate/…_create_school_staffs.rb
class CreateSchoolStaffs < ActiveRecord::Migration[8.1]
  def change
    create_table :school_staffs do |t|
      t.references :user, null: false, foreign_key: { on_delete: :restrict }, index: { unique: true }
      t.references :school, null: false, foreign_key: { on_delete: :restrict }
      t.references :invited_by, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :created_at, null: false
    end
    remove_check_constraint :invitations, name: "invitations_staff_has_school"
    add_check_constraint :invitations, "kind <> 'school_staff' OR school_id IS NOT NULL", name: "invitations_staff_has_school"
  end
end
```

```ruby
# app/infrastructure/queries/school/student_work_query.rb
module Queries
  module School
    class StudentWorkQuery
      MIN_STUDENTS_FOR_AVERAGE = 5
      # submission_rate, average_percent : nil → « — »
      ClassroomRow = Data.define(:public_id, :name, :level_name, :students_count, :assignments_count,
                                 :submission_rate, :average_percent)
      StudentRow = Data.define(:display_name, :submitted_count, :average_percent)
      Overview = Data.define(:school_name, :school_year, :classrooms)
      Detail = Data.define(:classroom, :students)

      def classrooms(school_id:, school_year: Entities::Classroom::SchoolYear.current(Date.current)) = … # → Overview
      def classroom(school_id:, public_id:, school_year: Entities::Classroom::SchoolYear.current(Date.current)) = … # → Detail | nil
    end
  end
end
```

## 7. Comment vérifier que la décision est respectée

- `test/db/schema_constraints_test.rb` : un second rattachement du même compte lève `RecordNotUnique` ; une invitation `school_staff` sans `position` est acceptée, sans `school_id` refusée.
- `test/domain/use_cases/identity/accept_invitation_test.rb` : une invitation de direction crée un `school_admin` rattaché, sans second facteur.
- `test/domain/policies/school/read_own_school_policy_test.rb` : refus pour `teacher`, `student`, `team` et une direction sans établissement.
- `test/infrastructure/queries/school/student_work_query_test.rb` et `school_teachers_query_test.rb` : un test par ligne du tableau §4, données d'un autre établissement absentes, nombre de requêtes constant.
- `test/controllers/school_admin/classrooms_controller_test.rb` et `teachers_controller_test.rb` : chaque page refusée aux autres rôles ; la classe d'un autre établissement donne 404. `test/routing/school_admin_routes_test.rb` : aucune route d'écriture sous `/school-admin`.
