# ADR-0003 : Multi-Appartenance et Dénormalisation des Élèves (`Student` & `ClassroomStudent`)

| | |
|---|---|
| **Statut** | Accepté — *en production (schéma SQL migré, modèles ORM opérationnels)* |
| **Date** | 2026-06-20 |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | — |
| **Amendé par** | [ADR-0040](./0040-classe-principale-unique-de-l-eleve.md) : §2 et §4 (une classe principale active par élève) |

---

> ⚠️ **Décision amendée — une classe principale unique par élève.**
> Le §2 et le §4 sont amendés par l'[ADR-0040](./0040-classe-principale-unique-de-l-eleve.md) le 2026-09-25 : un index partiel garantit une seule classe principale active par élève, et une seule classe active jusqu'à la V3. La table de jointure `classroom_students` reste en vigueur.

## 1. Contexte et problématique
Dans la première conception (et dans d'anciens documents de planification comme `master_plan/mobile.md`), le modèle `Student` était modélisé de manière rigide par des relations `belongs_to` directes sur la table `students` (`classroom_id`, `school_id`, `level_id`, `series_id`).

Cette dénormalisation et restriction à une classe unique posaient deux problèmes majeurs :
1. **Impossibilité de la Multi-Appartenance :** Dans la réalité scolaire, un élève est rattaché à sa classe officielle de lycée (ex: Terminale D1 au Lycée Classique), mais s'inscrit très souvent à des cours du soir, des groupes de révision intensifs pour le BAC ou des classes virtuelles spécialisées créées par d'autres enseignants sur Lnclass.
2. **Redondance et Anomalies de Mise à Jour :** Stocker à la fois `classroom_id`, `level_id` et `school_id` sur la table `students` créait des redondances inutiles. Si un élève changeait de classe, il fallait veiller à mettre à jour manuellement son école et son niveau sous peine de créer des incohérences de données.

---

## 2. Moteurs de décision
* **Flexibilité Pédagogique (Multi-Classes) :** Permettre à un élève de joindre une infinité de classes (officielles ou virtuelles de soutien).
* **Normalisation en Base de Données :** Éliminer la redondance : l'école, le niveau et la série d'un élève se déduisent exclusivement des attributs de la classe à laquelle il participe.
* **Stabilité du Contrat d'Interface (Rétro-Compatibilité) :** Éviter de briser les centaines de vues, requêtes et entités du domaine qui demandent régulièrement `student.level` ou `student.school` pour les affichages de base.

---

## 3. Décision
Nous avons retiré les colonnes `classroom_id`, `school_id`, `level_id` et `series_id` de la table SQL `students` et introduit une table de jointure explicite **`classroom_students`** (`student_id`, `classroom_id`).

Pour concilier multi-appartenance et simplicité d'affichage, nous introduisons la colonne **`primary: boolean`** (`default: false`, non nul) sur la table de jointure `classroom_students` :
* Une inscription avec `primary: true` désigne la **classe principale et officielle** de l'élève.
* Une inscription avec `primary: false` désigne un groupe de soutien ou une classe secondaire.
* Le modèle ORM `Orm::Student` délègue intelligemment ses méthodes `#classroom`, `#school`, `#level` et `#series` en pointant vers son inscription principale (`primary_classroom`).

---

## 4. Conséquences

### 🟢 Positives
* **Évolutivité Pédagogique Sans Limite :** Un élève peut rejoindre n'importe quel cours du soir avec un simple code de classe sans perdre son attachement à son établissement d'origine.
* **Intégrité Sereine :** Finie la désynchronisation entre la classe d'un élève et l'école enregistrée sur son profil.
* **Continuité du Code :** La couche Domaine et les anciennes vues continuent d'appeler `#classroom`, `#level` ou `#school_id` de manière totalement transparente grâce aux méthodes de délégation de l'ORM.

### 🔴 Coûts consentis
* **Complexité Légère des Requêtes SQL :** Pour faire des statistiques globales ou lister les élèves d'un niveau donné, il est désormais nécessaire d'ajouter une jointure SQL (`joins(classroom_students: :classroom)`) en filtrant sur `where(classroom_students: { primary: true })`.

---

## 5. Notes d'implémentation

Extrait du schéma SQL (`db/schema.rb`) illustrant la table de jointure et son index unique :
```ruby
create_table "classroom_students", force: :cascade do |t|
  t.bigint "classroom_id", null: false
  t.datetime "created_at", null: false
  t.datetime "joined_at"
  t.boolean "primary", default: false, null: false
  t.bigint "student_id", null: false
  t.datetime "updated_at", null: false
  t.index ["classroom_id"], name: "index_classroom_students_on_classroom_id"
  t.index ["student_id", "classroom_id"], name: "index_classroom_students_on_student_id_and_classroom_id", unique: true
  t.index ["student_id"], name: "index_classroom_students_on_student_id"
end
```

Extrait de `Orm::Student` montrant comment la dénormalisation est simulée proprement pour protéger les contrats de lecture :
```ruby
# app/infrastructure/orm/student.rb
module Orm
  class Student < ApplicationRecord
    self.table_name = "students"

    has_many :classroom_students, class_name: "Orm::ClassroomStudent", foreign_key: :student_id, dependent: :destroy
    has_many :classrooms, through: :classroom_students, class_name: "Orm::Classroom"

    def primary_classroom
      classrooms.merge(Orm::ClassroomStudent.where(primary: true)).first || classrooms.first
    end

    def classroom; primary_classroom; end
    def level; primary_classroom&.level; end
    def series; primary_classroom&.series; end
    def school; primary_classroom&.school; end
    def classroom_id; primary_classroom&.id; end
    def school_id; primary_classroom&.school_id; end
  end
end
```

### Cas du formulaire d'inscription (Wizard)
Lors de l'inscription d'un élève via le wizard (`Students::RegistrationsController`), les données d'établissement (DRENA, École, Niveau, Classe) ou le code unique de classe sont conservées de manière éphémère dans des champs cachés (`reg_attrs`). 
Le cas d'utilisation `UseCases::RegisterStudent` résout dynamiquement la classe à partir de ces informations (ou du code unique). Les attributs `drena_id` ou `school_id` ne sont jamais stockés dans la table `students`, garantissant ainsi la pureté de la dénormalisation imposée par le présent ADR.
