# ADR-0007 : Gestion Modulaire du Contenu Pédagogique et Traçabilité Polymorphe

| | |
|---|---|
| **Statut** | Remplacé partiellement — *voir l'avertissement ci-dessous* |
| **Date** | 2026-07-15 |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | [ADR-0048](./0048-statuts-d-assignation-active-et-archived.md) *(§5 : statuts et types assignables)* |

---

> ⚠️ **Décision partiellement remplacée — les statuts d'assignation suivent l'ADR-0048.**
> Le §5 est remplacé par l'[ADR-0048](./0048-statuts-d-assignation-active-et-archived.md) le 2026-09-25 : statuts `active` et `archived`, types `Course`, `Essential` et `Exercise`, `assigned_by_id` vers `users`. La hiérarchie pédagogique et la table unique polymorphe restent en vigueur.

## 1. Contexte et problématique
Une plateforme éducative (LMS) s'articule autour d'une nomenclature stricte de contenus. Dans le système scolaire ivoirien, le contenu est hiérarchisé depuis la discipline globale jusqu'à l'évaluation individuelle.
De plus, la logique d'attribution des cours, fiches ou examens à des classes posait un défi de modelisation :
* Comment permettre à un enseignant ou à un administrateur d'assigner ou de "débloquer" un cours (`Course`), une fiche de synthèse (`Essential`) ou un sujet d'examen officiel (`ExamSubject`) pour une classe spécifique sans multiplier les tables de liaison disparates et les codes redondants dans les contrôleurs ?
* Comment savoir avec certitude **qui** (quel professeur précis ou quel membre de l'équipe admin) a assigné telle ressource à la classe, afin de maintenir une traçabilité d'audit sans faille ?

---

## 2. Moteurs de décision
* **Standardisation de la Hiérarchie Pédagogique :** Fixer un vocabulaire métier immuable (Ubiquitous Language) pour la chaîne d'enseignement.
* **Polymorphisme et Uniformité :** Gérer l'attribution de n'importe quelle ressource pédagogique à une classe à travers un modèle unifié et extensible.
* **Traçabilité de l'Émetteur :** Enregistrer systématiquement l'identifiant du créateur de l'assignation (`assigned_by_id`).

---

## 3. Décision
Nous avons structuré le contenu autour de l'arbre hiérarchique officiel suivant :
1. **`Material` (Matière) :** La discipline (Mathématiques, Physique-Chimie, SVT).
2. **`Course` (Cours / Unité d'Enseignement) :** Lié à une matière, un niveau (`Level`) et une série (`Series`).
3. **`Essential` (Fiche de Cours / Chapitre) :** Synthèse ou leçon rattachée à un cours (`course_id`).
4. **`Exercise` (Série d'Exercices) :** Rattachée à une fiche de cours (`essential_id`).
5. **`Question` & `Answer` :** Items d'évaluation constituant l'exercice.

Pour la distribution de ce contenu aux classes, nous avons créé l'entité et table polymorphe **`ClassroomAssignment`** :
* Elle lie une `Classroom` à un couple `(resource_type, resource_id)` où `resource_type` est restreint aux valeurs valides (`Course`, `Essential`, `ExamSubject`).
* Elle inclut la colonne de traçabilité **`assigned_by_id`** qui stocke l'ID de l'enseignant ou de l'administrateur à l'origine de la mise à disposition.

---

## 4. Conséquences

### 🟢 Positives
* **Extensibilité :** Demain, si nous ajoutons un nouveau type de contenu (ex: `VideoLesson` ou `AudioPodcast`), nous pourrons l'assigner aux classes via le même modèle `ClassroomAssignment` sans toucher au schéma SQL.
* **Audit Parfait :** Nous savons en permanence quel professeur a rendu actif quel chapitre pour sa classe.
* **Uniformité de l'UI :** La gestion des boutons "Assigner / Retirer" se factorise dans des partials communs.

### 🔴 Coûts consentis
* **Intégrité Référentielle Polymorphe :** Les bases de données relationnelles (PostgreSQL) ne peuvent pas imposer de clé étrangère stricte (`foreign_key: true`) sur des colonnes polymorphes (`resource_id`). L'intégrité doit être garantie par les validations de l'entité et les Repositories.

---

## 5. Notes d'implémentation

Validation de la ressource polymorphe dans l'entité du Domaine :
```ruby
# app/domain/entities/classroom_assignment.rb
module Entities
  class ClassroomAssignment
    include ActiveModel::Model

    attr_accessor :id, :classroom_id, :resource_type, :resource_id, :status, :assigned_at, :classroom, :resource

    validates :classroom_id, presence: true
    validates :resource_type, presence: true, inclusion: { in: %w[Course Essential ExamSubject] }
    validates :resource_id, presence: true

    STATUSES = {
      added: "added",
      active: "active",
      validated: "validated"
    }.freeze
  end
end
```

Logique d'assignation idempotente dans le Use Case :
```ruby
# app/domain/use_cases/assign_course_to_classroom.rb
def execute(classroom_id:, course_id:, teacher_id:)
  unless @classroom_access_policy.authorized?(teacher_id: teacher_id, classroom_id: classroom_id)
    return OpenStruct.new(success?: false, errors: ["Classe non autorisée."])
  end

  # Idempotence : on cherche d'abord si la ressource est déjà assignée
  assignment = @assignment_repo.find_by_classroom_and_resource(classroom_id, "Course", course_id)
  return OpenStruct.new(success?: true, assignment: assignment) if assignment

  assignment = Entities::ClassroomAssignment.new(
    classroom_id: classroom_id,
    resource_type: "Course",
    resource_id: course_id
  )

  if assignment.valid? && (result = @assignment_repo.save(assignment))
    OpenStruct.new(success?: true, assignment: result)
  else
    OpenStruct.new(success?: false, errors: assignment.errors.full_messages)
  end
end
```

---

## 6. Mise à jour (Juillet 2026)
Les cas d'utilisation d'assignation ont été refactorisés pour être entièrement génériques (`AssignResourceToClassroom` et `RemoveResourceFromClassroom`). Cela permet d'avoir un seul Use Case traitant tous les types de ressources, améliorant la localité de la logique d'autorisation.
