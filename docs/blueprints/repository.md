# Blueprint: Repository

Le Repository est l'**adaptateur de persistance** : il implémente un [Port](port.md) du domaine avec ActiveRecord. Il reçoit et retourne des [Entities](entity.md), et manipule des `Orm::` en interne. C'est le seul endroit où record et entité se rencontrent.

**Quand l'utiliser** : pour toute écriture, et pour les lectures qui alimentent un Use Case. Les lectures d'affichage passent par une [Query](query.md).

## Structure

```ruby
# app/infrastructure/repositories/identity/school_repository.rb
# frozen_string_literal: true

# 🔌 INFRA · Repositories::Identity::SchoolRepository
# Rôle : traduit Orm::School ↔ Entities::Identity::School
# ADR  : 0001, 0015

module Repositories
  module Identity
    class SchoolRepository
      include Ports::Identity::SchoolRepositoryPort

      def find_all(filters = {})
        query = Orm::School.includes(:drena).recent
        query = query.where(drena_id: filters[:drena_id]) if filters[:drena_id].present?
        query = query.where("name ILIKE ?", "%#{filters[:query]}%") if filters[:query].present?

        query.map { |record| map_to_entity(record) }
      end

      def find_by_id(id)
        record = Orm::School.find_by(id: id)
        record ? map_to_entity(record) : nil
      end

      def find_by_slug(slug)
        record = Orm::School.friendly.find_by(slug: slug)
        record ? map_to_entity(record) : nil
      end

      def save(school_entity)
        record = Orm::School.find_or_initialize_by(id: school_entity.id)
        record.name         = school_entity.name
        record.schoolsigle  = school_entity.schoolsigle
        record.schoolstatus = school_entity.schoolstatus
        record.schooltype   = school_entity.schooltype
        record.drena_id     = school_entity.drena&.id

        if record.save
          # On renvoie au domaine ce que la base a généré (id, slug, public_id)
          school_entity.id        = record.id
          school_entity.slug      = record.slug
          school_entity.public_id = record.public_id
          true
        else
          record.errors.each { |e| school_entity.errors.add(e.attribute, e.message) }
          false
        end
      end

      def delete(id)
        record = Orm::School.find_by(id: id)
        return false unless record

        record.destroy
        record.destroyed?
      end

      private

      def map_to_entity(record)
        drena = if record.drena
          Entities::Identity::Drena.new(
            id: record.drena.id, name: record.drena.name,
            public_id: record.drena.public_id, slug: record.drena.slug
          )
        end

        Entities::Identity::School.new(
          id: record.id,
          name: record.name,
          public_id: record.public_id,
          schoolsigle: record.schoolsigle,
          schoolstatus: record.schoolstatus,
          schooltype: record.schooltype,
          slug: record.slug,
          drena: drena
        )
      end
    end
  end
end
```

## Règles

- Emplacement `app/infrastructure/repositories/<contexte>/`, namespace `Repositories::<Contexte>::<Nom>Repository`.
- **`include` du port correspondant**, systématiquement. Toute méthode du port non redéfinie lèvera `NotImplementedError` à l'exécution : c'est le filet de sécurité, pas un détail.
- Le namespace ORM s'écrit **`Orm::`**, jamais `ORM::` (`Orm::School`, `Orm::Course`).
- Signature d'entrée/sortie en **entités** : `find_by_id` retourne une `Entities::…` ou `nil`, jamais un record.
- Le mapping `record → entity` vit dans une méthode `private map_to_entity` (ou `map_<nom>`). Ne jamais faire `Entity.new(record.attributes.symbolize_keys)` : les colonnes SQL ne sont pas le contrat du domaine (`has_rich_text`, associations, colonnes techniques).
- `save` renvoie un booléen (ou l'entité mappée selon le port), et **recopie dans l'entité** les valeurs générées par la base : `id`, `slug`, `public_id`.
- En échec, recopier les erreurs ActiveRecord dans l'entité : `record.errors.each { |e| entity.errors.add(e.attribute, e.message) }`.
- `includes(...)` obligatoire dès qu'on mappe une association, sinon N+1.
- Les transactions vivent ici (`ActiveRecord::Base.transaction`), jamais dans le domaine.

## Erreurs fréquentes

| ❌ | ✅ |
|---|---|
| `ORM::School` | `Orm::School` |
| `include` du port, puis méthodes nommées différemment (`save_course` alors que le port déclare `save`) | Aligner les noms ; sinon le Use Case reçoit un `NotImplementedError` — c'est le cas aujourd'hui sur `Repositories::Catalog::CourseRepository` |
| `Entities::School.new(record.attributes.symbolize_keys)` | Mapping explicite champ par champ |
| Retourner un `Orm::School` à un Use Case | Retourner `Entities::Identity::School` |
| Oublier `includes` et mapper `record.drena` dans une boucle | `Orm::School.includes(:drena)` |
| `record.update!` (lève et casse le contrat `success?`) | `record.save` + report des erreurs |
| Mettre de la règle métier dans le mapping (calcul de statut, filtrage de droits) | La règle appartient à l'entité ou à la policy |
