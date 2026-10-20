# ADR-0092 : Quatre fonctions de direction en deux rangs de droits
<!-- index
titre: Fonctions de direction en deux rangs de droits (le changement de classe par la direction est retiré, Q5)
statut: Accepté
problematique: `school_staffs.position` obligatoire (`head`, `deputy`, `educator`, `secretary`), un chef actif par établissement (index partiel), rang gestion ou vie scolaire dans trois policies, fonction changée par l'équipe seule ; `Actor#staff_position`. Amende 0044, 0065, 0071, 0077. Chantier `espace-direction`.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-16 : Q1 à Q4, Q6 à Q9 acceptées ; Q5 retirée ; DIR-4) |
| **Date** | 2026-10-16 |
| **Chantier** | `docs/chantiers/espace-direction` |
| **Remplace** | — *(amende ADR-0044 §4, ADR-0065, ADR-0071 §4, ADR-0077 §4)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0044 (2026-09-25) prévoyait quatre fonctions de direction (Proviseur, Censeur, Éducateur, Secrétaire) dans une colonne `school_staffs.position`. L'ADR-0065 (version simple, 2026-09-28) a créé `school_staffs` **sans** cette colonne : un seul type de compte. Les chantiers suivants ont ajouté des gestes sans différencier les comptes : « + » et « − » d'un niveau, retrait et réintégration d'un enseignant (ADR-0071), retrait d'une autre direction (ADR-0077), archivage d'une classe ou d'un niveau (ADR-0088). Depuis l'ADR-0077, une direction **s'inscrit seule** avec le code d'établissement, trois comptes au plus par cette voie.

Au 2026-10-16, tout compte de direction peut donc tout faire, et rien ne dit qui il est. Une secrétaire inscrite par le code peut retirer un enseignant, archiver un niveau, ou, après 7 jours, retirer le chef d'établissement. Le vocabulaire de l'ADR-0044 est périmé : dans les lycées publics, le censeur est devenu « Adjoint au chef d'établissement » (ACE) ; dans le privé, on dit « Directeur des études » (porteur, 2026-10-01, grill 1 de `gestion-etablissement-direction`).

> **Retiré par le porteur (Q5, 2026-10-16).** La version proposée de cet ADR donnait aussi à la direction un geste « changer un élève de classe » (`UseCases::Classroom::MoveStudent`, voie d'arrivée `transfer`). Le porteur l'a retiré : l'élève change lui-même de classe (chantier `changement-etablissement-eleve`, ADR-0095). Aucune trace de ce geste ne reste dans la décision ; la direction garde le retrait d'un élève (ADR-0085 §4.5).

## 2. Moteurs de décision

1. **Une fonction déclarée ne doit pas suffire à se promouvoir.** Le code d'établissement circule chez les enseignants ; quiconque l'a peut s'inscrire comme direction (ADR-0077).
2. **Peu de règles, vérifiables** : deux rangs, pas une matrice par geste.
3. **Aucune direction sans fonction** : Lnclass n'est pas lancé, aucune direction n'est inscrite (réponse DIR-4 du porteur) ; il n'y a pas de compte antérieur à ménager.
4. Ne pas toucher la connexion ni le second facteur.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Pas de fonction (statu quo) | Rien à faire | Une secrétaire peut évincer le chef ; personne ne sait qui est qui |
| B — Rôles libres créés par l'établissement (ancien `school_roles`) | Souple | Écarté par l'ADR-0044 : incomparables d'un établissement à l'autre, droits impossibles à tester |
| C — **Quatre fonctions fermées, deux rangs de droits** | Vocabulaire du terrain, deux règles à tester | La fonction est déclarée par la personne : il faut un verrou (§4.3) |
| D — Une matrice geste par geste et fonction par fonction | Fine | Seize cases à tester pour quatre gestes, que personne n'a demandées |

Option C retenue.

## 4. Décision

> **Nous donnons à chaque compte de direction une fonction parmi quatre, obligatoire, choisie à l'arrivée et corrigée par l'équipe seule, avec un seul chef d'établissement actif ; nous rangeons ces fonctions en deux rangs, dont seul le rang « gestion » touche à la structure, aux enseignants et aux directions.**

### 4.1 Les fonctions

| Code | Libellé (public) | Libellé (privé, mixte) | Rang |
|---|---|---|---|
| `head` | Chef d'établissement | Chef d'établissement | `management` |
| `deputy` | Adjoint au chef d'établissement | Directeur des études | `management` |
| `educator` | Éducateur | Éducateur | `school_life` |
| `secretary` | Secrétaire | Secrétaire | `school_life` |

Le libellé de `deputy` suit `schools.school_type` (`public` ou non). À l'inscription par le code, l'établissement n'est pas encore connu : le radio se lit « Adjoint au chef d'établissement ou directeur des études ». Les libellés sont neutres, sans accord. `Entities::School::StaffPosition` porte la liste, le rang et la clé de libellé.

### 4.2 Schéma

Migration `20261016161500_add_position_to_school_staffs` :

```ruby
add_column :school_staffs, :position, :string           # puis NOT NULL, une fois les lignes existantes renseignées
add_check_constraint :school_staffs, "position IN ('head', 'deputy', 'educator', 'secretary')",
                     name: "school_staffs_position_values"
add_index :school_staffs, :school_id, unique: true, where: "position = 'head' AND archived_at IS NULL",
                                      name: "index_school_staffs_one_active_head"
# invitations.position (ADR-0044, jamais écrite) : nouvelles valeurs, obligatoire pour une invitation de direction
add_check_constraint :invitations, "position IN ('head', 'deputy', 'educator', 'secretary')", name: "invitations_position_values"
add_check_constraint :invitations, "kind <> 'school_staff' OR position IS NOT NULL", name: "invitations_staff_has_position"
```

**Lignes existantes (DIR-4).** Il n'en existe aucune en production. S'il en existait (une base de développement, une copie de recette), la migration **n'échoue pas** : chaque ligne `school_staffs` et chaque invitation de direction en attente sans fonction valide reçoit `deputy`. Pourquoi cette valeur : rang gestion, donc aucun geste perdu ; pas de second chef possible (l'index ne porte que sur `head`) ; aucun chef inventé. L'équipe corrige ensuite par « Changer la fonction ». Un échec propre a été écarté : il bloquerait chaque base de développement semée (les démos ont deux directions) pour un cas que la production n'a pas. Rejouable dans les deux sens ; prouvé par `test/db/add_position_to_school_staffs_migration_test.rb`.

### 4.3 Qui fixe la fonction, et les droits

- **À l'inscription par le code** : la personne choisit sa fonction ; le champ est obligatoire.
- **À l'invitation** : l'équipe choisit la fonction ; elle passe à `school_staffs.position` à l'acceptation.
- **Un seul `head` actif** par établissement. L'inscription, l'acceptation d'une invitation, le changement par l'équipe et la restauration relisent la règle **sous le verrou de la ligne `schools`** (celui du plafond de l'ADR-0077) ; l'index partiel tranche ce qui y échapperait : le repository attrape `ActiveRecord::RecordNotUnique` sur `index_school_staffs_one_active_head` dans un point de sauvegarde. Le refus est un 422 (`failure(:conflict, errors: { position: [:head_taken] })`), ou un 409 en toast pour la restauration, jamais une erreur 500. Le nom du chef actif n'est jamais dit.
- **Ensuite, seule l'équipe change une fonction** (`Policies::School::SetStaffPositionPolicy` : équipe `admin` ou `field`). Une direction ne change ni la sienne ni celle d'une autre.
- **Rang `management`** (`head`, `deputy`) : tous les gestes existants.
- **Rang `school_life`** (`educator`, `secretary`) : lecture de tout l'espace direction ; lien d'invitation (lecture, copie, partage) ; lien d'une classe, retrait d'un élève ; recherche d'un élève (UDR-0094). **Refusés** (403) : `ManageSchoolStructurePolicy` (« + », « − », archivage et restauration d'une classe ou d'un niveau), `ManageSchoolTeachersPolicy` (retrait, réintégration), `RemoveSchoolStaffPolicy` (retrait d'une direction).
- **Un acteur de direction sans fonction** (aucun en base, la colonne est `NOT NULL` ; seulement un acteur construit à la main) n'a que les lectures : `StaffPosition.management?(nil)` est faux. La règle se ferme par défaut.
- La règle des 7 jours de l'ADR-0077 reste, pour le rang `management`.
- L'équipe garde tous ses gestes ; les policies ne changent pas pour elle.

**Contrats.** `Entities::School::Staff` gagne `position` et `head?`. `Ports::School::StaffRepositoryPort` : `attach(..., position:)` → `:attached | :head_taken` ; `attach_by_code(..., position:)` → `:attached | :cap_reached | :head_taken` ; `head_taken?(school_id:, except_user_id: nil)` ; `set_position(user_id:, position:)` → `:set | :unchanged | :head_taken | :not_found` ; `restore` rend aussi `:head_taken`. `Entities::Identity::AuditAction` gagne `school_staff.position_set` (données `{ school_id, from, to }`) ; `school_staff.registered` et `invitation.sent` portent la `position`.

`Entities::Identity::Actor` reçoit `staff_position` (nil pour tout autre rôle) et `school_management?`, lus par `UserRepository#actor_for` avec le rattachement actif, **dans la même requête** que `school_id` (`pick(:school_id, :position)`).

### 4.4 Affichage par policy

Les contrôleurs de la direction calculent chaque drapeau de geste par sa policy (`SchoolAdmin::BaseController#gesture_allowed?`) ; aucune vue ne recopie la règle de rang. Quand la policy refuse sur un établissement actif, c'est la fonction qui en prive : la note de l'UDR-0092 §3.5 le dit.

## 5. Conséquences

### 🟢 Positives

- Une secrétaire ou un éducateur ne peut plus évincer le chef, archiver un niveau ni retirer un enseignant.
- Le bloc « Direction » dit qui est qui ; l'équipe sait à qui elle parle.
- Aucune direction sans fonction : pas de règle transitoire à faire vivre.

### 🔴 Coûts consentis

- **La fonction est déclarée.** Une personne qui a le code peut se dire « Adjoint au chef d'établissement » et obtenir le rang gestion. Le verrou porte sur le seul chef ; le reste repose sur le plafond de trois comptes (ADR-0077), la règle des 7 jours et la correction par l'équipe.
- Un établissement dont le chef est archivé sans remplaçant reste géré par ses adjoints ; sans adjoint, par l'équipe seule pour le retrait des directions.
- Une invitation de chef acceptée après l'arrivée d'un autre chef par le code est refusée à l'acceptation : l'équipe envoie une nouvelle invitation.

## 6. Notes d'implémentation

```ruby
# app/domain/policies/school/manage_school_structure_policy.rb (extrait)
return Shared::Result.success if actor.school_management? && actor.school_id == school.id && school.status == ACTIVE
```

## 7. Comment vérifier que la décision est respectée

- `test/db/schema_constraints_test.rb` (ED-01, ED-02) et `test/db/add_position_to_school_staffs_migration_test.rb`.
- `test/domain/entities/school/staff_position_test.rb` : rang et libellés (ED-03).
- `test/domain/policies/school/{manage_school_structure,manage_school_teachers,remove_school_staff,set_staff_position}_policy_test.rb` : refus pour `educator`, `secretary` et l'absence de fonction ; succès pour `head`, `deputy`.
- `test/infrastructure/repositories/school/staff_repository_test.rb` et `test/integration/identity/school_staff_registration_concurrency_test.rb` (ED-13) : un seul chef actif, même sous deux inscriptions simultanées.
- `test/controllers/school_admin/school_life_rights_test.rb` : requêtes forgées en 403, gestes masqués.
