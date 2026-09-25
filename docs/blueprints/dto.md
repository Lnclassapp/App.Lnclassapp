# Blueprint: DTO (Data Transfer Object)

Le DTO est le **bouclier anti-corruption** du domaine. Aucun `params` Rails ne franchit la frontière hexagonale : le contrôleur transforme `params.permit(...)` en DTO, le DTO valide la forme des données, et le [Use Case](use_case.md) ne reçoit qu'un objet Ruby propre (ADR-0013, ADR-0014).

**Quand l'utiliser** : toute action d'écriture qui reçoit des données utilisateur (web ou API). Pas besoin de DTO pour une lecture (`index`, `show`).

## Structure

```ruby
# app/domain/dtos/course_dto.rb
# frozen_string_literal: true

# 🧠 DOMAINE · Dtos::CourseDto
# Rôle : valide les paramètres bruts de création/modification d'un cours
# ADR  : 0013, 0014

module Dtos
  class CourseDto
    include ActiveModel::Model

    attr_accessor :name, :slug, :subtitle, :material_id, :level_id, :series_id,
                  :status, :content, :image_cover, :published_at

    validates :name, :status, presence: true

    def to_h
      {
        name: name,
        slug: slug,
        subtitle: subtitle,
        material_id: material_id,
        level_id: level_id,
        series_id: series_id,
        status: status,
        content: content,
        image_cover: image_cover,
        published_at: published_at
      }.compact
    end
  end
end
```

### Variante typée

Quand on veut que la coercition de type soit faite par le DTO (ids de formulaire arrivant en `String`) :

```ruby
# app/domain/dtos/school/create_staff_dto.rb
module Dtos
  module School
    class CreateStaffDto
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :user_id,        :integer
      attribute :school_id,      :integer
      attribute :school_role_id, :integer

      validates :user_id, :school_id, :school_role_id, presence: true
    end
  end
end
```

### Chaîne complète

```ruby
# Contrôleur
dto = Dtos::CourseDto.new(course_params.to_h)

if dto.invalid?
  dto.errors.each { |e| @course.errors.add(e.attribute, e.message) }
  return render :new, status: :unprocessable_entity
end

use_case.execute_create(dto: dto)

# Use Case
entity = @entity_class.new(dto.to_h.merge(extra_attributes))
```

## Règles

- Emplacement `app/domain/dtos/`, namespace `Dtos::<Nom>Dto`. `conventions.md` prévoit `Dtos::<Contexte>::<Nom>` ; dans les faits, seul `Dtos::School::` est namespacé, les 10 autres DTO sont à plat (`Dtos::CourseDto`, `Dtos::ClassroomDto`, `Dtos::UserDto`…). **Suivre le voisinage** du DTO qu'on ajoute plutôt que d'ouvrir un nouveau namespace isolé.
- `include ActiveModel::Model` (+ `ActiveModel::Attributes` si typage) — dérogation explicitement accordée par l'ADR-0014 : ce sont les seules classes du domaine qui ont le droit d'aimer Rails.
- Un DTO valide la **forme** (présence, type, format), pas le **métier**. « Le nom est obligatoire » → DTO. « Un cours doit avoir un niveau existant » → [Entity](entity.md) ou [Use Case](use_case.md).
- **`to_h` avec `.compact`** : les clés `nil` sont retirées pour ne pas écraser des valeurs existantes lors d'un `execute_update`. `ManageResource#execute_update` itère sur `dto.to_h` et n'assigne que ce qui est présent.
- Le DTO transporte des **ids scalaires** (`level_id`, `material_id`), pas des entités. C'est le Repository qui résout les associations.
- Aucun comportement métier, aucune requête, aucun `Orm::`.
- Un DTO par intention si les champs divergent (`CreateStaffDto` ≠ `CreateRoleDto`), un seul DTO create/update si les champs sont identiques (`CourseDto`).

## Erreurs fréquentes

| ❌ | ✅ |
|---|---|
| Passer `params` ou `ActionController::Parameters` au Use Case | `Dtos::XxxDto.new(xxx_params.to_h)` |
| Oublier `.to_h` : `Dtos::CourseDto.new(course_params)` | `ActiveModel` refuse les `Parameters` → `.to_h` après `permit` |
| `to_h` sans `.compact` | Un `nil` non filtré efface la valeur en base lors d'une mise à jour |
| Dupliquer dans le DTO les validations métier de l'entité | Forme dans le DTO, invariants dans l'entité |
| Exposer des attributs que `permit` ne laisse pas passer (ou l'inverse) | Garder `permit` et `attr_accessor` alignés ; un attribut absent est silencieusement ignoré |
| Écrire un test qui valide un attribut inexistant | Aligner test et DTO — `test/domain/dtos/drena_dto_test.rb` teste aujourd'hui un `shortname` que `Dtos::DrenaDto` ne déclare pas |
| Mettre le DTO dans `app/dtos/` ou `app/forms/` | `app/domain/dtos/` |
