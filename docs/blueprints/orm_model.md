# Blueprint: ORM Model

Le modèle ORM est la table SQL, rien de plus : associations, validations de persistance, scopes techniques. Il appartient strictement à l'infrastructure et n'est jamais visible depuis `app/domain/`.

**Quand l'utiliser** : à chaque nouvelle table. Il est consommé par les [Repositories](repository.md) et les [Queries](query.md), jamais directement par un contrôleur.

## Structure

```ruby
# app/infrastructure/orm/level.rb
# frozen_string_literal: true

# 🔌 INFRA · Orm::Level
# Rôle : table SQL levels (niveaux pédagogiques)
# ADR  : 0001, 0005, 0007

module Orm
  class Level < ApplicationRecord
    # 1. Table déclarée explicitement (le namespace Orm:: casse l'inflexion Rails)
    self.table_name = "levels"

    # 2. Concerns partagés
    include Sluggable   # FriendlyId sur :name + normalisation (titleize)
    has_nanoid          # macro d'ApplicationRecord : public_id = SecureRandom.base58(14)

    # 3. Associations — class_name et inverse_of toujours explicites
    belongs_to :team, class_name: "Orm::Team", optional: true, inverse_of: :levels

    has_many :level_series, class_name: "Orm::LevelSeries", foreign_key: :level_id,
             dependent: :destroy, inverse_of: :level
    has_many :series, through: :level_series, class_name: "Orm::Series"
    has_many :courses, class_name: "Orm::Course", foreign_key: :level_id,
             dependent: :destroy, inverse_of: :level

    # 4. Validations de persistance (unicité, longueur, présence de colonne)
    validates :name, presence: true, uniqueness: true

    # 5. Scopes techniques réutilisés par les Queries
    #    (ex. sur Orm::Course : :published, :with_details, :for_level, :for_material)
  end
end
```

Héritage commun (`app/models/application_record.rb`) :

```ruby
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def self.has_nanoid(field = :public_id)
    before_create do
      self.send("#{field}=", SecureRandom.base58(14)) if self.send(field).blank?
    end
  end

  scope :ordered, -> { order(created_at: :asc) }
  scope :recent,  -> { order(created_at: :desc) }
  scope :namming, -> { order(name: :asc) }
end
```

## Règles

- Emplacement `app/infrastructure/orm/`, namespace **`Orm::`** (jamais `ORM::`), fichier au singulier.
- `self.table_name = "..."` **obligatoire** : sans elle, Rails cherche `orm_levels`.
- `class_name: "Orm::…"` sur **toutes** les associations, et `inverse_of` dès qu'il existe une réciproque.
- **`has_nanoid` existe toujours** : c'est une macro définie dans `ApplicationRecord`. Depuis l'ADR-0017, la gem `nanoid` et le concern `PublicIdGenerator` ont été supprimés ; la macro utilise `SecureRandom.base58(14)`. Le nom est resté, l'implémentation a changé. Ne pas ajouter de gem d'identifiants.
  - `has_nanoid` (sans argument) remplit `public_id`.
  - `has_nanoid(:id)` remplit la clé primaire, pour les tables à PK string (`Orm::KnowledgeGap`).
- `include Sluggable` pour tout modèle exposé par un slug en URL : il branche FriendlyId sur `:name` et normalise le nom en `titleize` avant validation.
- Les `enum` Rails 8 s'écrivent `enum :schoolstatus, { draft: "draft", … }, prefix: true`.
- Aucune logique métier : pas de calcul de score, pas de règle d'autorisation. Cela vit dans `Entities::` ou `Policies::`.
- Callbacks à éviter — sauf génération d'identifiant/slug. L'orchestration appartient aux Use Cases.
- Intégrité anti-cascade (ADR-0005) : les références vers l'administration (`team_id`) se suppriment en `nullify`, pas en `cascade`.

## Erreurs fréquentes

| ❌ | ✅ |
|---|---|
| Oublier `self.table_name` | La déclarer systématiquement |
| `has_many :courses` sans `class_name: "Orm::Course"` | Toujours qualifier |
| Appeler `Orm::Course` depuis un contrôleur ou un Use Case | Passer par un Repository (écriture) ou une Query (lecture) |
| Croire que `has_nanoid` nécessite la gem `nanoid` | C'est `SecureRandom.base58(14)` depuis l'ADR-0017 |
| Réintroduire un concern `PublicIdGenerator` | Supprimé par l'ADR-0017 |
| `has_secure_token` à la place de `has_nanoid` | Refusé : impose 24 caractères, le standard du projet est 14 |
| Mettre une méthode métier (`def mastered?`) sur le modèle | Dans `Entities::` |
| `dependent: :destroy` sur une référence `team_id` | `optional: true` + `on_delete: :nullify` côté migration |
