# ADR-0004 : Autorisation Multi-Établissements des Enseignants et Isolation par Policy (`ClassroomAccessPolicy`)
<!-- index
titre: Autorisation multi-établissements des enseignants (`ClassroomAccessPolicy`)
statut: ⚠️ **Remplacé partiellement** par [0030](./0030-une-ecole-par-enseignant-et-creation-des-classes.md) *(§2, §3.1)* ; complété par [0028](./0028-policies-de-domaine-par-use-case.md) *(§3.3)*
problematique: Permettre à un professeur d'enseigner dans plusieurs lycées via `teacher_schools` et sécuriser l'attribution des cours par un objet Policy pur Ruby.
-->

| | |
|---|---|
| **Statut** | Remplacé partiellement — *voir l'avertissement ci-dessous* |
| **Date** | 2026-06-25 |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | [ADR-0030](./0030-une-ecole-par-enseignant-et-creation-des-classes.md) *(§2, §3.1)* |
| **Complété par** | [ADR-0028](./0028-policies-de-domaine-par-use-case.md) : §3.3 (la policy renvoie un `Result`, pour tous les use cases) |

---

> ⚠️ **Décision partiellement remplacée — une école par enseignant en V1.**
> Le §2 et le §3.1 sont remplacés par l'[ADR-0030](./0030-une-ecole-par-enseignant-et-creation-des-classes.md) le 2026-09-25 : une seule école `primary` par enseignant en V1, classes créées par l'équipe puis par la direction. Le §3.3 est complété par l'[ADR-0028](./0028-policies-de-domaine-par-use-case.md). Le principe d'une policy pure reste en vigueur.

## 1. Contexte et problématique
Dans l'enseignement secondaire ivoirien et africain, la majorité des professeurs de lycée (notamment dans les matières scientifiques comme les Maths, la Physique-Chimie et la SVT) dispensent des cours dans **plusieurs établissements scolaires différents** (ex: un lycée public en matinée et un ou deux collèges/lycées privés l'après-midi ou le samedi).

Si la table SQL `teachers` conservait une clé étrangère restrictive `school_id`, un professeur s'inscrivant sur Lnclass se verrait contraint d'être rattaché à un seul établissement. Il ne pourrait pas créer de classes ni suivre la progression de ses élèves inscrits dans ses autres écoles sans se créer plusieurs comptes téléphoniques différents, ce qui détruirait l'expérience utilisateur.

De plus, se posait le problème de la **sécurité et de la légitimité des assignations** : comment s'assurer qu'un professeur ne puisse modifier, assigner un examen ou consulter les résultats que pour les classes sur lesquelles il intervient réellement, et non pour toutes les classes d'un établissement ?

---

## 2. Moteurs de décision
* **Réalité Professionnelle Multi-Écoles :** Permettre à un seul profil enseignant (`Teacher`) de se voir autoriser l'accès et la création de classes sur un nombre illimité d'établissements scolaires.
* **Sécurité Découplée :** Empêcher qu'une vérification d'autorisation d'accès ne soit éparpillée sous forme de `if/else` ad-hoc dans les contrôleurs Rails.
* **Respect du DDD :** Matérialiser l'autorisation sous la forme d'un objet de domaine pur (`ClassroomAccessPolicy`) interrogeable par n'importe quel Use Case.

---

## 3. Décision
Nous avons retiré la colonne `school_id` de la table SQL `teachers` et avons restructuré les accès autour de deux piliers :
1. **La Table d'Autorisation `teacher_schools`** (`teacher_id`, `school_id`) : Liste formellement les établissements dans lesquels un enseignant est accrédité et autorisé à intervenir et créer des classes.
2. **La Table d'Activité Effective `teacher_classrooms`** (`teacher_id`, `classroom_id`) : Associe directement l'enseignant aux classes spécifiques qu'il gère au sein de ces écoles.
3. **La Policy de Domaine `Policies::ClassroomAccessPolicy`** : Objectif unique : recevoir un `teacher_id` et un `classroom_id` et répondre par un booléen strict (`true`/`false`) en interrogeant le port du Repository sans jamais dépendre de la session web.

---

## 4. Conséquences

### 🟢 Positives
* **Flexibilité Totale pour le Professeur :** Un enseignant gère l'ensemble de ses classes et établissements depuis son tableau de bord unique (`/teacher`).
* **Sécurité Infaillible et Réutilisable :** Que l'assignation d'un cours provienne d'une requête Web, d'un appel API mobile ou d'une tâche automatisée, la sécurité passe systématiquement par la même Policy.
* **Clarté Architecturale :** Les règles d'autorisation ne polluent pas les modèles d'entités ni les contrôleurs HTTP.

### 🔴 Coûts consentis
* **Jointures Supplémentaires :** Pour afficher la liste des écoles d'un professeur, l'ORM doit traverser la table de jointure `teacher_schools`.

---

## 5. Notes d'implémentation

Implémentation de l'objet de sécurité dans la couche Domaine :
```ruby
# app/domain/policies/classroom_access_policy.rb
module Policies
  class ClassroomAccessPolicy
    def initialize(classroom_repo:)
      @classroom_repo = classroom_repo
    end

    def authorized?(teacher_id:, classroom_id:)
      return false unless teacher_id && classroom_id

      classrooms = @classroom_repo.find_by_teacher(teacher_id)
      classrooms.any? { |c| c.id.to_s == classroom_id.to_s || c.id == classroom_id }
    end
  end
end
```

Utilisation systématique de la Policy dans un Use Case avant toute mutation de données :
```ruby
# app/domain/use_cases/assign_course_to_classroom.rb
module UseCases
  class AssignCourseToClassroom
    def initialize(assignment_repo:, classroom_access_policy:)
      @assignment_repo = assignment_repo
      @classroom_access_policy = classroom_access_policy
    end

    def execute(classroom_id:, course_id:, teacher_id:)
      # Vérification centralisée de l'autorisation du professeur sur cette classe
      unless @classroom_access_policy.authorized?(teacher_id: teacher_id, classroom_id: classroom_id)
        return OpenStruct.new(success?: false, errors: ["Classe non autorisée pour cet enseignant."])
      end

      # Exécution de l'assignation...
    end
  end
end
```
