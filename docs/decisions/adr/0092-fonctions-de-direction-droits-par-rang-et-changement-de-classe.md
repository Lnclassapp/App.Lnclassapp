# ADR-0092 : Quatre fonctions de direction en deux rangs de droits, et changement de classe d'un élève par la direction
<!-- index
titre: Fonctions de direction en deux rangs de droits ; changement de classe d'un élève par la direction
statut: Proposé
problematique: `school_staffs.position` (`head`, `deputy`, `educator`, `secretary`, NULL), un chef actif par établissement, rang gestion ou vie scolaire dans trois policies, fonction changée par l'équipe seule ; `classroom_students.joined_via = 'transfer'` et `UseCases::Classroom::MoveStudent`. Amende 0044, 0065, 0071, 0077, 0085. Chantier `espace-direction`.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | `docs/chantiers/espace-direction` |
| **Remplace** | — *(amende ADR-0044 §4, ADR-0065, ADR-0071 §4, ADR-0077 §4, ADR-0085 §4.5)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0044 (2026-09-25) prévoyait quatre fonctions de direction (Proviseur, Censeur, Éducateur, Secrétaire) dans une colonne `school_staffs.position`. L'ADR-0065 (version simple, 2026-09-28) a créé `school_staffs` **sans** cette colonne : un seul type de compte. Les chantiers suivants ont ajouté des gestes sans différencier les comptes : « + » et « − » d'un niveau, retrait et réintégration d'un enseignant (ADR-0071), retrait d'une autre direction (ADR-0077), archivage d'une classe ou d'un niveau (ADR-0088). Depuis l'ADR-0077, une direction **s'inscrit seule** avec le code d'établissement, trois comptes au plus par cette voie.

Au 2026-10-16, tout compte de direction peut donc tout faire, et rien ne dit qui il est. Une secrétaire inscrite par le code peut retirer un enseignant, archiver un niveau, ou, après 7 jours, retirer le chef d'établissement. Le vocabulaire de l'ADR-0044 est périmé : dans les lycées publics, le censeur est devenu « Adjoint au chef d'établissement » (ACE) ; dans le privé, on dit « Directeur des études » (porteur, 2026-10-01, grill 1 de `gestion-etablissement-direction`).

Second problème : la direction ne peut pas corriger la classe d'un élève. Depuis l'ADR-0085, l'élève choisit sa classe par une cascade (DRENA → établissement → niveau → classe), sans code : l'erreur de classe est facile. Le seul geste est le **retrait** (ADR-0085 §4.5), qui marque l'élève « retiré » de la classe et l'empêche d'y revenir sans le lien (`JoinPolicy`) ; l'élève doit ensuite rechoisir seul. Retirer puis attendre n'est pas corriger.

## 2. Moteurs de décision

1. **Aucune régression** pour les directions en production : un compte existant garde ses gestes.
2. **Une fonction déclarée ne doit pas suffire à se promouvoir.** Le code d'établissement circule chez les enseignants ; quiconque l'a peut s'inscrire comme direction (ADR-0077).
3. **Peu de règles, vérifiables** : deux rangs, pas une matrice par geste.
4. **Le changement de classe garde l'historique** : résultats à leurs devoirs, trace de qui a déplacé qui.
5. Ne pas toucher la connexion, l'inscription de l'élève ni le second facteur.

## 3. Options envisagées

### 3.1 Fonctions

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Pas de fonction (statu quo) | Rien à faire | Une secrétaire peut évincer le chef ; personne ne sait qui est qui |
| B — Rôles libres créés par l'établissement (ancien `school_roles`) | Souple | Écarté par l'ADR-0044 : incomparables d'un établissement à l'autre, droits impossibles à tester |
| C — **Quatre fonctions fermées, deux rangs de droits** | Vocabulaire du terrain, deux règles à tester | La fonction est déclarée par la personne : il faut un verrou (§4.2) |
| D — Une matrice geste par geste et fonction par fonction | Fin | Seize cases à tester pour quatre gestes, que personne n'a demandées ; la matrice se revoit avec de vraies directions (relecture du 2026-09-28, point 7) |

### 3.2 Changement de classe

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Retirer, puis l'élève rechoisit (statu quo) | Rien à faire | L'élève est marqué « retiré » ; il ne revient pas sans le lien ; la direction dépend de l'élève |
| B — **Un geste « changer de classe » de la direction, transactionnel** | Une action, un journal, l'élève n'a rien à faire | Une voie d'arrivée de plus (`transfer`) |
| C — Par matricule MENA (conception du 2026-09-28) | Identifiant stable | Une donnée de mineur de plus, l'inscription élève à changer ; sans code de classe, le nom suffit (memo, Q7) |

## 4. Décision

> **Nous donnons à chaque compte de direction une fonction parmi quatre, choisie à l'arrivée et corrigée par l'équipe seule, avec un seul chef d'établissement actif ; nous rangeons ces fonctions en deux rangs, dont seul le rang « gestion » touche à la structure, aux enseignants et aux directions ; et nous donnons à toute direction un geste « changer de classe » sur les élèves de son établissement.**

### 4.1 Les fonctions

| Code | Libellé (public) | Libellé (privé, mixte) | Rang |
|---|---|---|---|
| `head` | Chef d'établissement | Chef d'établissement | `management` |
| `deputy` | Adjoint au chef d'établissement | Directeur des études | `management` |
| `educator` | Éducateur | Éducateur | `school_life` |
| `secretary` | Secrétaire | Secrétaire | `school_life` |
| `NULL` | Fonction à préciser | Fonction à préciser | `management` (compte antérieur, §4.4) |

Le libellé de `deputy` suit `schools.school_type` (`public` ou non), comme `Entities::School::School#plan_type`. Les libellés sont neutres, sans accord.

### 4.2 Schéma

```ruby
# db/migrate/<horodatage>_add_position_to_school_staffs.rb
add_column :school_staffs, :position, :string, null: true
add_check_constraint :school_staffs, "position IN ('head','deputy','educator','secretary')",
                     name: "school_staffs_position_values"
add_index :school_staffs, :school_id, unique: true, where: "position = 'head' AND archived_at IS NULL",
                                      name: "index_school_staffs_one_active_head"

# classroom_students.joined_via : la contrainte accepte « transfer »
remove_check_constraint :classroom_students, name: "classroom_students_joined_via_values"
add_check_constraint :classroom_students, "joined_via IN ('standard','link','code','transfer')",
                     name: "classroom_students_joined_via_values"
```

`invitations.position` existe déjà (ADR-0044, jamais écrite) : elle porte la fonction choisie par l'équipe et passe à `school_staffs.position` à l'acceptation. Les comptes existants gardent `position = NULL`. Aucune donnée n'est réécrite.

### 4.3 Qui fixe la fonction, et les droits

- **À l'inscription par le code** : la personne choisit sa fonction ; le champ est obligatoire.
- **À l'invitation** : l'équipe choisit la fonction.
- **Un seul `head` actif** par établissement, garanti par l'index unique partiel ; l'inscription, l'invitation, la correction et la restauration qui le violeraient sont refusées avec un message (422 ; `failure(:conflict, errors: { position: [:head_taken] })` rendu en formulaire), jamais par une erreur 500 : le repository attrape `ActiveRecord::RecordNotUnique` sur `index_school_staffs_one_active_head`. Le use case lit d'abord `StaffRepositoryPort#head_taken?(school_id:, except_user_id:)` pour le message ; l'index tranche la course.
- **Ensuite, seule l'équipe change une fonction.** Une direction ne change ni la sienne ni celle d'une autre. Exception : un compte sans fonction (`NULL`) **précise** la sienne, une fois.
- **Rang `management`** (`head`, `deputy`, `NULL`) : tous les gestes existants.
- **Rang `school_life`** (`educator`, `secretary`) : lecture de tout l'espace direction ; lien d'invitation (lecture, copie, partage) ; lien d'une classe, retrait d'un élève, changement de classe, recherche d'un élève. **Refusés** (403) : `ManageSchoolStructurePolicy` (« + », « − », archivage et restauration d'une classe ou d'un niveau), `ManageSchoolTeachersPolicy` (retrait, réintégration), `RemoveSchoolStaffPolicy` (retrait d'une direction).
- La règle des 7 jours de l'ADR-0077 (une direction nouvellement arrivée ne retire personne) reste, pour le rang `management`.
- L'équipe garde tous ses gestes ; les policies ne changent pas pour elle.

**Contrats.** `Entities::School::Staff` gagne `position` (ses appelants `Staff.new` — `StaffRepository#rows`, `SchoolAdmin::SchoolsController`, `Teams::SchoolStaffBlock` — passent la valeur). `Ports::School::StaffRepositoryPort` gagne `head_taken?(school_id:, except_user_id: nil)` et `set_position(school_id:, user_id:, position:)` (→ `Result` | `failure(:conflict)`) ; `attach` et `attach_by_code` reçoivent `position:` ; `restore` rend `failure(:conflict)` quand il ferait un second chef actif. `Entities::Identity::AuditAction` gagne `school_staff.position_set` et `student.moved`.

`Entities::Identity::Actor` reçoit `staff_position` (nil pour tout autre rôle), lu par `UserRepository` avec le rattachement actif, dans la même requête que `school_id`.

### 4.4 Comptes antérieurs

Un compte `school_admin` sans fonction garde le rang `management` jusqu'à ce que sa fonction soit renseignée : par lui-même (« Préciser ma fonction »), ou par l'équipe. Rien ne l'y oblige. Le nombre de ces comptes en production est compté avant la migration (memo, questions ouvertes).

### 4.5 Changement de classe

`UseCases::Classroom::MoveStudent.call(actor:, classroom_public_id:, student_public_id:, target_public_id:)` :

1. verrouille les deux classes, dans l'ordre croissant de leur `id` (deux changements croisés ne s'interbloquent pas) ;
2. `MoveStudentPolicy` : acteur `school_admin`, établissement actif, les deux classes dans l'établissement de l'acteur ; sinon `:not_found` (comme `ManageClassroomMembersPolicy`), `:forbidden` pour un autre rôle ;
3. refuse si une des deux classes est archivée (`failure(:forbidden, errors: { base: [:classroom_archived] })`, 403), si la cible est la classe actuelle (`failure(:invalid, errors: { target: [:already_member] })`, 422), si la cible est pleine (`failure(:invalid, errors: { target: [:classroom_full] })`, 422, même seuil que `JoinPolicy` : `Classroom#full?`), si l'élève n'a pas d'adhésion active à la classe d'origine (`:not_found`, 404) ;
4. `memberships.leave_primary(student_id:, at:)` puis `memberships.add_primary(classroom_id: target, student_id:, via: "transfer", at:)` : l'adhésion d'origine est **close sans marque de retrait** (`left_at` seul) ; une adhésion close à la cible est **rouverte** (contrat existant de `add_primary`), retrait levé ;
5. journal `student.moved`, données `{ from: <public_id>, to: <public_id> }`, auteur = acteur.

Aucun port ne change : `leave_primary` et `add_primary` existent ; seul `StudentArrivalChannel::WRITABLE` gagne `transfer`. Les sessions et résultats restent attachés à leurs devoirs (ADR-0036). L'élève voit les devoirs de sa nouvelle classe à sa requête suivante.

## 5. Conséquences

### 🟢 Positives

- Une secrétaire ou un éducateur ne peut plus évincer le chef, archiver un niveau ni retirer un enseignant.
- Le bloc « Direction » dit qui est qui ; l'équipe sait à qui elle parle.
- La direction corrige une erreur de classe en un geste, journalisé ; l'enseignant voit l'élève arriver « Nouveau ».
- Aucune régression : les comptes existants gardent tout.

### 🔴 Coûts consentis

- **La fonction est déclarée.** Une personne qui a le code peut se dire « Adjoint au chef d'établissement » et obtenir le rang gestion. Le verrou porte sur le seul chef ; le reste repose sur le plafond de trois comptes (ADR-0077), la règle des 7 jours et la correction par l'équipe.
- **Un compte sans fonction garde le rang gestion indéfiniment** s'il ne la précise pas. Une seconde étape (forcer le choix) demandera une décision.
- Un établissement dont le chef est archivé sans remplaçant reste géré par ses adjoints ; sans adjoint, par l'équipe seule pour le retrait des directions.
- Le changement de classe est réservé à la direction : un enseignant qui constate l'erreur passe par elle.
- `classroom_students.joined_via` gagne une valeur : les vues qui la traduisent (`_roster`, page de classe de la direction) doivent la connaître.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/school/staff_position.rb
module Entities
  module School
    module StaffPosition
      ALL = %w[head deputy educator secretary].freeze
      MANAGEMENT = %w[head deputy].freeze

      # nil : compte antérieur au chantier espace-direction, qui garde tous ses gestes (ADR-0092 §4.4).
      def self.management?(position) = position.nil? || MANAGEMENT.include?(position)

      # Clé de libellé : « deputy » se lit selon le type d'établissement (public ou non).
      def self.label_key(position, school_type:)
        return "missing" if position.nil?
        return "deputy_#{school_type == 'public' ? 'public' : 'private'}" if position == "deputy"

        position
      end
    end
  end
end
```

```ruby
# app/domain/policies/school/manage_school_structure_policy.rb (extrait)
return Shared::Result.success if actor.school_admin? && actor.school_id == school.id && school.status == ACTIVE &&
                                 Entities::School::StaffPosition.management?(actor.staff_position)
```

## 7. Comment vérifier que la décision est respectée

- `test/db/schema_constraints_test.rb` : valeurs de `position`, un seul `head` actif, `transfer` accepté.
- `test/domain/entities/school/staff_position_test.rb` : rang et libellés.
- `test/domain/policies/school/{manage_school_structure,manage_school_teachers,remove_school_staff}_policy_test.rb` : refus pour `educator` et `secretary`, succès pour `head`, `deputy`, `nil`.
- `test/domain/use_cases/classroom/move_student_test.rb` et `test/integration/school_admin/student_move_concurrency_test.rb` : une seule classe principale active après deux changements simultanés.
- `test/system/school_admin/staff_positions_test.rb` : une secrétaire ne voit aucun geste de gestion.
