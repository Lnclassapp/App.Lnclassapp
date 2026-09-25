# Blueprint: Policy

Une Policy répond à **une** question d'autorisation métier par `true` / `false`. Elle vit dans le domaine, elle est pure, et elle est testée isolément avec des fakes (ADR-0004, ADR-0015).

**Quand l'utiliser** : dès qu'une règle d'accès dépend de données métier (« ce professeur intervient-il dans cette classe ? »). Une simple vérification de rôle n'est pas une Policy : c'est `authenticate_teacher!` dans le contrôleur.

## Structure

```ruby
# app/domain/policies/classroom_access_policy.rb
# frozen_string_literal: true

# 🧠 DOMAINE · Policies::ClassroomAccessPolicy
# Rôle : un enseignant est-il autorisé sur cette classe ?
# ADR  : 0003, 0004, 0015

module Policies
  class ClassroomAccessPolicy
    def initialize(classroom_repo:)
      @classroom_repo = classroom_repo
    end

    def authorized?(teacher_id:, classroom_id:)
      return false unless teacher_id && classroom_id

      classrooms = @classroom_repo.find_by_teacher(teacher_id)
      classrooms.any? { |c| c.id.to_s == classroom_id.to_s }
    end
  end
end
```

### Appel depuis un contrôleur

```ruby
# app/controllers/assessment/classroom_exercises_controller.rb
def set_classroom
  @classroom = Orm::Classroom.friendly.find(params[:classroom_id])
  policy = Policies::ClassroomAccessPolicy.new(
    classroom_repo: Repositories::Classroom::ClassroomRepository.new
  )

  unless policy.authorized?(teacher_id: current_teacher.id, classroom_id: @classroom.id)
    redirect_to root_path, alert: t(".unauthorized")
  end
end
```

### Appel depuis un Use Case

```ruby
def execute_assign(classroom_id:, resource_type:, resource_id:, teacher_id:)
  unless @classroom_access_policy.authorized?(teacher_id: teacher_id, classroom_id: classroom_id)
    return OpenStruct.new(success?: false, errors: [ "Accès refusé à cette classe." ])
  end
  # ...
end
```

### Test associé (fake en mémoire, zéro base)

```ruby
# test/domain/policies/classroom_access_policy_test.rb
class ClassroomAccessPolicyTest < ActiveSupport::TestCase
  class FakeClassroomRepository
    def initialize(classrooms = [])
      @classrooms = classrooms
    end

    def find_by_teacher(_teacher_id)
      @classrooms
    end
  end

  FakeClassroom = Struct.new(:id)

  test "autorise l'enseignant intervenant dans la classe" do
    policy = Policies::ClassroomAccessPolicy.new(
      classroom_repo: FakeClassroomRepository.new([ FakeClassroom.new(123) ])
    )

    assert policy.authorized?(teacher_id: 456, classroom_id: 123)
    assert policy.authorized?(teacher_id: 456, classroom_id: "123")   # id venant de l'URL
    assert_not policy.authorized?(teacher_id: 456, classroom_id: 999)
    assert_not policy.authorized?(teacher_id: nil, classroom_id: 123)
  end
end
```

## Règles

- Emplacement `app/domain/policies/`, namespace `Policies::<Nom>Policy` (pas de sous-dossier par contexte aujourd'hui : une seule policy existe, `ClassroomAccessPolicy`).
- Méthode publique unique, **prédicat** : `authorized?`, `can_publish?`. Elle retourne un booléen, elle ne lève pas, elle ne redirige pas, elle ne rend rien.
- **Toutes** les dépendances sont injectées en mots-clés : `initialize(classroom_repo:)`. Une Policy ne construit jamais un `Repositories::…` elle-même — ce serait de l'infrastructure dans le domaine.
- Garde de nullité en première ligne : `return false unless teacher_id && classroom_id`. Refuser par défaut.
- Comparaison d'identifiants **en chaînes** (`c.id.to_s == classroom_id.to_s`) : les ids arrivent en `String` depuis les URL et en `Integer` depuis l'ORM.
- La Policy est testée **isolément** (ADR-0015). Le test du Use Case vérifie l'orchestration (« refuse quand la policy dit non »), pas les 50 permutations de la règle.
- Zéro `Orm::`, zéro SQL, zéro `current_user`.

## Erreurs fréquentes

| ❌ | ✅ |
|---|---|
| Valeur par défaut instanciant l'infra : `def initialize(policy: Policies::ClassroomAccessPolicy.new)` | La policy exige `classroom_repo:` → `ArgumentError` à l'exécution. Injecter depuis le contrôleur : c'est le cas non corrigé dans `UseCases::Classroom::ManageClassroomAssignment` |
| Dupliquer la règle d'accès en dur dans chaque contrôleur | Une Policy, appelée partout |
| `c.id == classroom_id` sans `to_s` | Comparer en chaînes : `"12"` ≠ `12` |
| Retourner un message ou lever `AccessDenied` | Retourner un booléen ; le refus est formulé par l'appelant |
| Tester la règle à travers un test de Use Case | Test unitaire dédié dans `test/domain/policies/` |
| Toucher la base dans le test de policy | `FakeClassroomRepository` en mémoire |
| Mettre la Policy dans `app/policies/` (convention Pundit) | `app/domain/policies/` — c'est du domaine |
