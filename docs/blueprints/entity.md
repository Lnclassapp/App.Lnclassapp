# Blueprint: Entity

L'entité porte les données et les **règles métier** d'un concept du domaine. Elle est instanciée en mémoire par un Repository (lecture) ou par un Use Case (écriture), et ne connaît ni SQL, ni HTTP.

**Quand l'utiliser** : dès qu'un concept a des invariants (« un cours sans niveau n'existe pas »), une identité et un cycle de vie. Un objet de lecture jetable n'est pas une entité : c'est le retour d'une [Query](query.md).

## Structure

```ruby
# app/domain/entities/catalog/course.rb
# frozen_string_literal: true

# 🧠 DOMAINE · Entities::Catalog::Course
# Rôle : un cours du catalogue, rattaché à un niveau et à une matière
# ADR  : 0001, 0014

module Entities
  module Catalog
    class Course
      include ActiveModel::Model

      attr_accessor :id, :name, :slug, :subtitle, :content,
                    :level, :series, :material, :essentials

      validates :name,     presence: { message: "doit être rempli(e)" }
      validates :slug,     presence: { message: "doit être rempli(e)" }
      validates :level,    presence: { message: "doit être fourni(e)" }
      validates :material, presence: { message: "doit être fourni(e)" }

      def initialize(attributes = {})
        super
        @essentials ||= []
      end

      # Règle métier : pure, en mémoire, aucune requête
      def published?
        content.present? && essentials.any?
      end

      def to_param
        slug.presence || id.to_s
      end
    end
  end
end
```

## Règles

- Emplacement `app/domain/entities/<contexte>/`, namespace `Entities::<Contexte>::<Nom>`.
- `include ActiveModel::Model` + `attr_accessor` : c'est la forme majoritaire (37 entités sur 37 incluent `ActiveModel::Model`). `ActiveModel::Attributes` est toléré quand on veut du typage (`Entities::SchoolStaff`, `Entities::SchoolRole`) — ne pas mélanger les deux styles dans un même contexte.
- Les associations sont d'**autres entités**, pas des ids : `course.level` est un `Entities::Catalog::Level`, jamais un `Orm::Level`. C'est le Repository qui hydrate.
- Messages de validation en **français**, explicitement (`message: "doit être rempli(e)"`), car les tests du domaine les asserte au mot près.
- `to_param` est autorisé : c'est du formatage d'identifiant, pas de la vue.
- Aucun `ActiveRecord`, aucun `Orm::`, aucun `find`/`where`/`save`.

## Erreurs fréquentes

| ❌ | ✅ |
|---|---|
| Créer l'entité à la racine (`app/domain/entities/course.rb`) | La créer sous son contexte (`entities/catalog/course.rb`) |
| `attr_accessor :level_id` seul | `attr_accessor :level` (entité) ; l'id reste un détail du Repository |
| `validates :name, presence: true` (message anglais par défaut) | `presence: { message: "doit être rempli(e)" }` |
| Appeler `course.save` depuis l'entité | Le Use Case appelle `repository.save(course)` |
| Mettre du formatage de vue (`badge_class`, `humanized_status`) dans l'entité | Le laisser au helper ou au [Presenter](presenter.md) |
| Oublier `super` dans un `initialize` surchargé — les attributs ne sont plus assignés | Toujours `super` en première ligne |
