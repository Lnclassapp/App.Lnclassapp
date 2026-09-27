# Blueprint: Use Case

Un Use Case orchestre **une action métier**. Il reçoit un [DTO](dto.md) validé, construit ou charge des [Entities](entity.md), applique les règles, appelle les [Ports](port.md) et retourne un objet répondant à `success?`.

**Quand l'utiliser** : toute écriture (créer, modifier, supprimer, assigner, corriger). Une lecture pure d'affichage ne passe pas par un Use Case : elle passe par une [Query](query.md) (CQRS, ADR-0006 / ADR-0012).

## Structure

```ruby
# app/domain/use_cases/catalog/create_course.rb
# frozen_string_literal: true

# 🧠 DOMAINE · UseCases::Catalog::CreateCourse
# Rôle : valide et persiste un nouveau cours du catalogue
# ADR  : 0001, 0014

module UseCases
  module Catalog
    class CreateCourse
      Response = Struct.new(:success?, :course, :errors, keyword_init: true)

      def initialize(course_repository:)
        @course_repository = course_repository
      end

      def call(attributes: {})
        course = Entities::Catalog::Course.new(attributes)

        unless course.valid?
          return Response.new(success?: false, course: course, errors: course.errors.full_messages)
        end

        saved = @course_repository.save(course)

        if saved
          Response.new(success?: true, course: course, errors: [])
        else
          Response.new(success?: false, course: course, errors: course.errors.full_messages)
        end
      end
    end
  end
end
```

### Variante multi-actions (majoritaire dans le code)

Quand une seule classe couvre le CRUD d'une ressource, elle expose `execute_create` / `execute_update` / `execute_delete` — c'est la forme dominante (35 fichiers déclarent `execute*`, 10 déclarent `call`).

```ruby
# app/domain/use_cases/identity/manage_school.rb
module UseCases
  module Identity
    class ManageSchool
      Response = Struct.new(:success?, :school, :errors, keyword_init: true)

      def initialize(school_repository:)
        @school_repository = school_repository
      end

      def execute_create(attributes: {})
        school = Entities::Identity::School.new(attributes)
        return failure(school) unless school.valid?

        Response.new(success?: @school_repository.save(school), school: school, errors: [])
      end

      def execute_update(school, attributes: {})
        school.assign_attributes(attributes)
        return failure(school) unless school.valid?

        Response.new(success?: @school_repository.save(school), school: school, errors: [])
      end

      def execute_delete(id:)
        Response.new(success?: @school_repository.delete(id), school: nil, errors: [])
      end

      private

      def failure(school)
        Response.new(success?: false, school: school, errors: school.errors.full_messages)
      end
    end
  end
end
```

Un CRUD strictement générique (pas de règle métier propre) réutilise `UseCases::Catalog::ManageResource`, qui prend `repo:` et `entity_class:` et retourne un `OpenStruct` `success?` / `resource` / `errors` — voir [result.md](result.md) pour l'état du contrat de retour.

## Règles

- Emplacement `app/domain/use_cases/<contexte>/`, namespace `UseCases::<Contexte>::<Action>`.
- **Toutes** les dépendances sont injectées par `initialize` en mots-clés (`course_repository:`, `classroom_repo:`). Jamais de `Repositories::...new` à l'intérieur du Use Case : c'est le contrôleur qui câble.
- L'objet de retour est déclaré dans la classe : `Response = Struct.new(:success?, :<payload>, :errors, keyword_init: true)`. `errors` est **toujours** un tableau de chaînes (`full_messages`), jamais `nil`.
- La validation d'entrée appartient au [DTO](dto.md), la validation d'invariants à l'[Entity](entity.md), l'autorisation à la [Policy](policy.md). Le Use Case n'écrit aucune de ces règles : il les appelle.
- Zéro `Orm::`, zéro `ActiveRecord::Base.transaction`, zéro `params`. Si une opération doit être transactionnelle, la transaction vit dans le Repository.
- Un Use Case ne rend pas, ne redirige pas, ne connaît pas `flash` ni les routes.

## Erreurs fréquentes

| ❌ | ✅ |
|---|---|
| `def call` alors que le reste du contexte fait `execute_create` | S'aligner sur le contexte que l'on modifie ; voir `conventions.md` §8, le contrat n'est pas encore tranché |
| Instancier le repository dans le Use Case | L'injecter : `initialize(course_repository:)` |
| Retourner `nil` ou `false` en cas d'échec | Toujours retourner l'objet `Response`, avec `errors` peuplé |
| Appeler `repository.save` sans vérifier ce que le port expose réellement | `grep "def save" app/infrastructure/repositories/<contexte>/*.rb` — plusieurs repositories exposent `save_course` / `save_essential` et non `save` |
| Passer `params` ou un `ActionController::Parameters` au Use Case | Passer un DTO (`dto.to_h`) ou un hash de symboles |
| Faire de la lecture d'affichage (index, dashboard) dans un Use Case | Utiliser une [Query](query.md) |
| Mettre le contrôle d'accès en dur (`return unless teacher.school_id == ...`) | Injecter `Policies::ClassroomAccessPolicy` |
