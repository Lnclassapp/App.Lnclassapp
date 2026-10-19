# ADR-0103 : Les matières d'un enseignant vivent dans une table de jointure `teacher_materials`, attachées à l'enseignant et non à la classe, 1 à 3, modifiées par lui seul
<!-- index
titre: Matières de l'enseignant — table de jointure par enseignant, 1 à 3, sans principale
statut: Proposé *(2026-10-16, en attente des réponses Q1 à Q11 du porteur)* — *amende 0083 (§ inscription), 0101 (§4.4)*
problematique: `teacher_profiles.material_id` n'admet qu'une matière ; un enseignant bivalent (PC et SVT, Maths et PC) n'a pas sa seconde matière dans le catalogue, la page de classe, l'accueil. Table `teacher_materials(teacher_id, material_id)` copiée depuis `material_id` puis colonne retirée ; matières par enseignant, pas par classe ni par établissement ; 1 à 3, ordre d'ajout, pas de principale ; ports `material_ids` ; remplacement complet de la liste.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/enseignant-plusieurs-matieres`](../../chantiers/enseignant-plusieurs-matieres/memo.md) · programme `refonte-application`, hors vague |
| **Remplace** | — |
| **Amende** | [ADR-0083](0083-inscription-enseignant-en-deux-voies.md) (champ « Matière » de l'inscription) · [ADR-0101](0101-remediation-implicite-exercice-propose-et-lecture-enseignant.md) §4.4 (« matière » → « matières ») |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ancienne application stockait `teachers.material_id` : **une** matière par enseignant. La refonte l'a reconduite dans `teacher_profiles.material_id` (ADR-0027), non nulle, écrite une fois par l'inscription (ADR-0083) et jamais modifiée ensuite.

Le porteur demande, le 2026-10-16, qu'un enseignant puisse avoir « plusieurs disciplines au sein de l'établissement ». C'est le cas courant au collège et dans le privé : Physique-Chimie et SVT, Mathématiques et Physique-Chimie, Histoire-Géographie et EDHC.

L'inventaire du memo compte, sur `Develop` :

- **7 lectures qui filtrent** par la matière (`TeacherAudienceQuery`, `CourseCatalogQuery` via le contrôleur, `ClassroomOverviewQuery#courses`, `TeacherHomeQuery` ×2, `TeacherFollowUpsQuery`, et `ClassroomGapsQuery` cadrée par l'ADR-0101) ;
- **9 lectures qui l'affichent** à côté d'un nom (en-tête, profil, signature d'annonce, listes de la direction et de l'équipe, comptes par matière) ;
- **une seule écriture** (`RegistrationRepository#create_teacher`) ;
- **aucune policy** : la matière restreint ce que l'enseignant **voit**, jamais ce qu'il **peut** faire.

Deux faits pèsent sur le modèle :

1. `teacher_classrooms` admet déjà plusieurs enseignants par classe (index unique `(teacher_id, classroom_id)`), sans dire qui enseigne quoi.
2. `multi-etablissements-enseignant` (ADR-0094), cadré le même jour, introduit un **établissement courant** de session et laisse la matière hors périmètre (« elle vaut pour tous ses établissements »).

## 2. Moteurs de décision

1. **Dire ce que dit la demande** : une discipline est un attribut de l'enseignant, pas d'une classe.
2. **Aucune étape de plus** pour l'enseignant qui n'a qu'une matière : son inscription, ses classes et ses écrans restent identiques.
3. **Une migration sans perte et rejouable**, en deux temps, pour que les lots parallèles ne cassent pas les lectures pas encore converties.
4. **Ne créer aucun droit** : la matière reste une lecture. Ajouter une matière ne demande donc ni preuve ni validation.
5. **Se composer avec l'établissement courant** (ADR-0094) sans second sélecteur.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — **Table de jointure par enseignant** `teacher_materials(teacher_id, material_id)` | Le modèle de `teacher_schools` (ADR-0030), connu ; une copie suffit à migrer ; contraintes et FK en base ; « N enseignants » par matière en une jointure | Sur la page d'une classe, les cours de **toutes** ses matières au niveau de la classe, même celle qu'il n'y enseigne pas |
| B — Matière **par liaison** : `teacher_classrooms.material_id` (unique `teacher_id, classroom_id, material_id`) | Précis : chaque classe ne montre que la matière qu'il y enseigne ; deux enseignants d'une classe se distinguent | « Mes classes » demande une matière par classe (une étape de plus pour tous) ; `TeachingRepository#declare`/`withdraw` changent de clé ; le catalogue et l'accueil, sans classe, n'ont plus de matière de repli ; une migration qui devine |
| C — Colonne tableau `teacher_profiles.material_ids bigint[]` | Une colonne, pas de table | Pas de FK vers `materials` (la suppression d'une matière ne serait plus protégée) ; jointures en `ANY()` ; contraire aux tables de jointure du dépôt |
| D — A **et** B : la liste de l'enseignant, puis une matière facultative par liaison | Le plus précis | Les coûts de B, pour un bruit que personne n'a encore constaté |
| E — A plus une **matière courante** de session (comme `sessions.current_school_id`) | Écrans identiques à aujourd'hui, une matière à la fois | Un enseignant de PC et SVT dans la **même** classe changerait de matière à chaque geste ; un second sélecteur à côté de celui de l'établissement |

## 4. Décision

> **Nous stockons les matières d'un enseignant dans une table de jointure `teacher_materials(teacher_id, material_id, created_at)`, attachée à l'enseignant (ni à la classe, ni à l'établissement), de 1 à 3 lignes, rangées par ordre d'ajout, sans matière principale. L'enseignant les remplace lui-même, en entier, depuis son profil. Toutes les lectures « sa matière » deviennent « ses matières » ; `teacher_profiles.material_id` est copiée puis retirée.**

### 4.1 Schéma

- `teacher_materials` : `teacher_id` (FK `users`, `on_delete: :restrict`), `material_id` (FK `materials`, `on_delete: :restrict`), `created_at`. Index unique `(teacher_id, material_id)` ; index `(material_id)`.
- **Pas de colonne `primary`** (memo Q4). L'ordre est `(created_at, id)` : la matière de l'inscription vient en premier.
- **Pas de `school_id`** (memo Q7) : les matières valent dans tous les établissements de l'enseignant. L'établissement courant de l'ADR-0094 borne les **classes** ; les matières bornent les **cours**.
- `teacher_classrooms` est **inchangée** (option B écartée). Si le bruit de la page de classe gêne à l'usage, une colonne facultative `teacher_classrooms.material_id` s'ajoutera (option D) sans toucher à ce qui suit.
- `teacher_profiles` reste : elle porte `referral_token`, `joined_via`, `onboarding_completed_at`.

### 4.2 Règle de domaine

`Entities::Identity::TeacherMaterials` (valeur pure) : `MAX = 3`, `MIN = 1`. `TeacherMaterials.build(ids)` dédoublonne en gardant l'ordre, puis renvoie un `Shared::Result` : échec `:invalid` avec `errors: { material_slugs: [:blank] }` sous 1, `[:too_many]` au-delà de 3.

### 4.3 Contrats de ports (gelés au Lot 0)

| Port | Avant | Après |
|---|---|---|
| `Entities::Identity::TeacherProfile` | `Data.define(:user_id, :material_id, :onboarding_completed_at)` | `Data.define(:user_id, :material_ids, :onboarding_completed_at)` — `material_ids` : `Array<Integer>`, ordre d'ajout, jamais vide |
| `Ports::Identity::TeacherProfileRepositoryPort` | `#find_by_user_id`, `#complete_onboarding` | + `#replace_materials(user_id:, material_ids:)` → `true` ; remplace **toute** la liste dans la transaction de l'appelant, garde le `created_at` des matières conservées (l'ordre ne bouge pas) |
| `Ports::Identity::RegistrationRepositoryPort` | `#create_teacher(user:, pin:, material_id:, joined_via:)` | `#create_teacher(user:, pin:, material_ids:, joined_via:)` |
| `Ports::Catalog::TaxonomyRepositoryPort` | `#find_material(slug:)` | inchangé (au plus 3 appels) |

Lectures (queries, pas de port) : chaque `material_id` scalaire d'une query devient `material_ids` ; chaque `material_name`/`material_category`/`material_slug` d'une ligne « enseignant » devient `materials: [MaterialTag(name, shortname, category, slug)]`, dans l'ordre d'ajout. `Queries::Identity::TeacherMaterialsQuery.tags_for(teacher_ids:)` les lit en **une** requête pour toute une liste (pas de N+1 dans « Enseignants »).

### 4.4 Écriture

- **Inscription** (`RegisterTeacher`) : `material_slug` (obligatoire) et `second_material_slug` (facultatif) ; doublon ignoré ; slug inconnu → `:invalid` sur le champ (`:inclusion`), comme aujourd'hui.
- **Profil** : `UseCases::Identity::UpdateTeacherMaterials(actor:, material_slugs:, ip:)` → `Policies::Identity::ManageOwnMaterialsPolicy` (enseignant, sur son propre compte ; `:forbidden` pour tout autre rôle) → résolution des slugs (`:inclusion`) → `TeacherMaterials.build` → transaction : `replace_materials`, puis audit `profile.materials_changed` avec `metadata: { from: [slugs], to: [slugs] }`. Une liste identique n'écrit rien et réussit.
- **Remplacer, pas ajouter** : deux onglets ne peuvent pas dépasser le plafond, puisque chaque écriture pose une liste complète déjà bornée. Aucun verrou n'est nécessaire.
- **Retirer une matière** ne touche à rien d'autre : les assignations faites dans cette matière restent actives (memo Q9).

### 4.5 Lectures

| Lecture | Règle |
|---|---|
| Catalogue (`TeacherAudienceQuery`, `CourseCatalogQuery`) | `Scope(audience:, material_ids:)` ; `where(material_id: material_ids)` ; le filtre `material=<slug>` restreint à l'intérieur |
| Page de classe (`ClassroomOverviewQuery#courses`) | cours du niveau et de la série de la classe, dans `material_ids` ; tri : ordre des matières de l'enseignant, puis nom du cours |
| Remédiation (`ClassroomGapsQuery#summary`, ADR-0101 §4.4) | inchangée dans son code : elle prend les slugs des cours de la page de classe, donc toutes ses matières |
| Accueil (`TeacherHomeQuery`, `TeacherFollowUpsQuery`) | `materials: [MaterialTag]` ; score moyen et « Activités » sur `material_ids` |
| Étiquettes (en-tête, profil, signature, direction, équipe) | `MaterialTag` dans l'ordre ; le **nom** quand il n'y en a qu'une, les **noms courts** (`materials.shortname`) séparés par « , » au-delà |
| Comptes de l'équipe (`MaterialsQuery`) | « N enseignants » = lignes `teacher_materials` de la matière : un enseignant de deux matières compte dans chacune |
| Suppression d'une matière (`TaxonomyRepository#delete_material`) | refusée si une ligne `teacher_materials` la porte |

### 4.6 Migration des données (deux temps)

1. **Lot 0 — étendre.** Créer `teacher_materials` et y copier, dans la même migration, une ligne par `teacher_profiles` (`created_at` du profil). `teacher_profiles.material_id` reste, **écrite en double** par `create_teacher` et `replace_materials` (= la première matière), pour que les lectures non encore converties restent justes pendant les lots parallèles.
2. **Lot Z — contracter.** Quand plus aucune lecture ne la lit, retirer `teacher_profiles.material_id`, son index, sa FK et l'écriture double. Migration réversible : `down` rajoute la colonne nullable et la remplit avec la première matière.

Aucune donnée n'est devinée : chaque enseignant existant a exactement la matière qu'il avait.

## 5. Conséquences

### 🟢 Positives

- L'enseignant bivalent n'a plus besoin d'un second compte ; celui d'une seule matière ne voit **rien** changer.
- Aucune policy n'est réécrite ; aucune route existante ne change ; la sécurité ne dépend pas de la matière.
- Un modèle déjà connu du dépôt (`teacher_schools`), une migration par copie, rejouable.
- Le compte par matière de l'équipe devient juste pour les bivalents.
- `multi-etablissements-enseignant` et ce chantier se composent : établissement courant × matières, deux filtres indépendants.

### 🔴 Coûts consentis

- **Le bruit de la page de classe** : un enseignant de Maths (6ème) et de PC (3ème) voit, en 3ème, les cours de Maths aussi. Assumé jusqu'à preuve du contraire (option D en réserve).
- **Les matières ne sont pas vérifiées** : un enseignant peut s'en déclarer trois qu'il n'enseigne pas. Sans droit attaché, le risque se limite à ses propres écrans et à sa signature.
- **Deux temps de migration** : la colonne vit en double le temps des lots, et le Lot Z est un lot à part entière, à ne pas oublier.
- **Quinze lectures à réécrire**, dont six partagées avec `multi-etablissements-enseignant` : les deux chantiers ne peuvent pas tourner en parallèle sur ces fichiers.
- La signature d'annonce mêle nom (une matière) et noms courts (plusieurs) : deux formes à tester.

## 6. Notes d'implémentation

```ruby
# db/migrate/2026101…_create_teacher_materials.rb
# ADR-0103 §4.6, temps 1 : la liste des matières de l'enseignant, copiée de teacher_profiles.material_id (qui reste
# écrite en double jusqu'au Lot Z). Une ligne par profil ; rejouable.
class CreateTeacherMaterials < ActiveRecord::Migration[8.1]
  def up
    create_table :teacher_materials do |t|
      t.bigint :teacher_id, null: false
      t.references :material, null: false, foreign_key: { on_delete: :restrict }
      t.datetime :created_at, null: false
    end
    add_index :teacher_materials, %i[teacher_id material_id], unique: true
    add_foreign_key :teacher_materials, :users, column: :teacher_id, on_delete: :restrict
    execute <<~SQL.squish
      INSERT INTO teacher_materials (teacher_id, material_id, created_at)
      SELECT user_id, material_id, created_at FROM teacher_profiles
      ON CONFLICT (teacher_id, material_id) DO NOTHING
    SQL
  end

  def down = drop_table(:teacher_materials)
end
```

```ruby
# app/domain/entities/identity/teacher_materials.rb
# 🧠 DOMAINE · Entities::Identity::TeacherMaterials
# Rôle : la liste des matières d'un enseignant : 1 à 3, sans doublon, dans l'ordre d'ajout
# ADR  : 0103
module Entities
  module Identity
    module TeacherMaterials
      MIN = 1
      MAX = 3

      # ids : identifiants de matières, dans l'ordre voulu. → Shared::Result (value : les ids dédoublonnés)
      def self.build(ids)
        unique = ids.compact.uniq
        return Shared::Result.failure(:invalid, errors: { material_slugs: [ :blank ] }) if unique.size < MIN
        return Shared::Result.failure(:invalid, errors: { material_slugs: [ :too_many ] }) if unique.size > MAX

        Shared::Result.success(unique)
      end
    end
  end
end
```

```ruby
# app/infrastructure/repositories/identity/teacher_profile_repository.rb (extrait)
def replace_materials(user_id:, material_ids:)
  Orm::TeacherMaterial.where(teacher_id: user_id).where.not(material_id: material_ids).delete_all
  kept = Orm::TeacherMaterial.where(teacher_id: user_id).pluck(:material_id)
  now = Time.current
  # Même created_at pour les ajoutées : l'id, croissant dans l'ordre d'insertion, départage (tri (created_at, id)).
  rows = (material_ids - kept).map { |id| { teacher_id: user_id, material_id: id, created_at: now } }
  Orm::TeacherMaterial.insert_all!(rows) if rows.any?
  Orm::TeacherProfile.where(user_id:).update_all(material_id: material_ids.first, updated_at: now) # écriture double, retirée au Lot Z
  true
end
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/identity/teacher_materials_test.rb` : 0, 1, 3, 4 matières ; doublons ; ordre conservé.
- `test/domain/use_cases/identity/update_teacher_materials_test.rb` : refus pour élève, direction, équipe (`:forbidden`) ; slug inconnu (`:inclusion`) ; liste vide ; 4 matières ; liste identique sans audit ; audit `profile.materials_changed` sinon.
- `test/db/migrate/create_teacher_materials_test.rb` (ou test de schéma) : autant de lignes `teacher_materials` que de `teacher_profiles` après la migration.
- `test/infrastructure/queries/**` : chaque query listée au §4.5 a un cas « enseignant de deux matières » et garde son cas « une matière » inchangé.
- Après le Lot Z : `grep -rn "teacher_profiles.material_id\|TeacherProfile.*material_id\|teacher_profile: :material" app db/seeds test/support` ne trouve rien, et `db/schema.rb` n'a plus `material_id` dans `teacher_profiles`.

## 8. Remplace, complète, amende

- **Amende** l'[ADR-0083](0083-inscription-enseignant-en-deux-voies.md) : l'inscription standard et l'inscription par lien demandent « Matière » **et** « Autre matière (facultatif) » ([UDR-0125](../udr/0125-matieres-de-l-enseignant-a-l-inscription-et-au-profil.md)).
- **Amende** l'[ADR-0101](0101-remediation-implicite-exercice-propose-et-lecture-enseignant.md) §4.4, puce « Fiches » : « matière de l'enseignant » se lit « **matières** de l'enseignant ». Le code de `ClassroomGapsQuery` ne change pas (il lit les slugs des cours de la page).
- **Complète** l'[ADR-0027](0027-contextes-bornes-et-arborescence.md) : `teacher_materials` appartient au contexte `identity`, à côté de `teacher_profiles`.
- **S'appuie sur** l'[ADR-0030](0030-une-ecole-par-enseignant-et-creation-des-classes.md) (modèle de `teacher_schools`), l'[ADR-0094](0094-enseignant-multi-etablissements-et-etablissement-courant.md) (établissement courant, indépendant des matières), l'[ADR-0034](0034-reprise-des-donnees-et-referentiel-seede.md) (matières du référentiel, suppression protégée).
- **Amende** les UDR-0026, 0027, 0041, 0062, 0069, 0071, 0077, 0079, 0121 et 0052 par les [UDR-0125](../udr/0125-matieres-de-l-enseignant-a-l-inscription-et-au-profil.md), [UDR-0126](../udr/0126-plusieurs-matieres-dans-le-catalogue-et-l-accueil-enseignant.md) et [UDR-0127](../udr/0127-plusieurs-matieres-sur-la-page-de-classe-et-dans-les-listes.md).
