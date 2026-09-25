# Blueprint: Objet de retour d'un Use Case

> ⚠️ **Divergence doc/code non tranchée — ne pas improviser.**
> Il n'existe **aucune classe `Shared::Result`** dans ce dépôt, et pas de répertoire `app/domain/shared/`. Les versions antérieures de ce blueprint en décrivaient une : c'était de la fiction.
> Réalité mesurée : **35 fichiers** de `app/domain/use_cases/` déclarent une méthode `execute*`, **10** déclarent `call`, et `OpenStruct` apparaît **~180 fois dans 44 fichiers** de `app/` (166 au relevé de `conventions.md` §8).
> Migrer vers un objet Result dédié est une **décision ouverte**, qui doit passer par un ADR (`docs/decisions/adr/`) avant toute implémentation. Voir [`docs/guide/conventions.md`](../guide/conventions.md) §8 « Écarts connus ».
> En attendant : **suivre le contrat majoritaire ci-dessous**, et s'aligner sur le contexte borné que l'on modifie.
> **Ce « en attendant » ne vaut que sur ce dépôt.** Sur le projet Rails cible, le contrat de retour est une décision de fondation à trancher par ADR avant le premier Lot 0 (registre du programme [`refonte-application`](../chantiers/refonte-application/feuille-de-route.md#3-registre-des-décisions-de-fondation)).

## Le contrat réel

Un Use Case retourne un objet qui répond à **`success?`**, à un **payload nommé** et à **`errors`** (toujours un `Array` de `String`).

Deux formes coexistent, toutes deux valides aujourd'hui.

### Forme 1 — `Struct` déclaré dans le Use Case (préférée pour du code neuf)

Le contrat est visible, typé par ses membres, et une faute de frappe lève une erreur.

```ruby
# app/domain/use_cases/catalog/create_course.rb
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

        if @course_repository.save(course)
          Response.new(success?: true, course: course, errors: [])
        else
          Response.new(success?: false, course: course, errors: course.errors.full_messages)
        end
      end
    end
  end
end
```

### Forme 2 — `OpenStruct` (dominante dans l'existant)

```ruby
# app/domain/use_cases/catalog/manage_resource.rb
def execute_create(dto:, **extra_attributes)
  entity = @entity_class.new(dto.to_h.merge(extra_attributes))
  return OpenStruct.new(success?: false, errors: entity.errors.full_messages) unless entity.valid?

  if (saved = save_entity(entity))
    OpenStruct.new(success?: true, resource: saved)
  else
    OpenStruct.new(success?: false, errors: entity.errors.full_messages)
  end
end
```

⚠️ Piège de la forme 2 : un `OpenStruct` répond `nil` à **n'importe quel** message. `result.errors` vaut `nil` sur une branche succès, et `result.resorce` (faute de frappe) vaut `nil` silencieusement. Peupler `errors: []` explicitement quand on veut pouvoir itérer sans garde.

### Consommation par le contrôleur

Identique dans les deux formes :

```ruby
result = use_case.execute_create(dto: dto)

if result.success?
  redirect_to course_path(result.resource.slug), notice: t(".created")
else
  Array(result.errors).each { |err| @course.errors.add(:base, err) }
  render :new, status: :unprocessable_entity
end
```

## Règles

- Un Use Case **retourne toujours** un objet répondant à `success?`. Jamais `nil`, jamais `false`, jamais l'entité nue, jamais une exception pour un échec métier attendu.
- Le membre d'erreurs s'appelle `errors` et contient des **chaînes** (`entity.errors.full_messages`), pas un `ActiveModel::Errors`.
- Le payload est nommé par le domaine : `course`, `school`, `resource`, `session`. Pas de `data` générique.
- `Struct.new(..., keyword_init: true)` est déclaré **dans** la classe du Use Case, sous le nom `Response`. Pas de classe de résultat partagée tant que l'ADR n'a pas tranché.
- **Ne pas créer `Shared::Result`, `Result`, `Success`, `Failure`** dans le cadre d'un lot ordinaire. Cela change le contrat de 45 use cases et de tous les contrôleurs : c'est un chantier avec ADR, pas un effet de bord.

## Erreurs fréquentes

| ❌ | ✅ |
|---|---|
| `Shared::Result.success(course)` | La classe n'existe pas → `NameError`. Utiliser `Response` ou `OpenStruct` |
| Retourner l'entité directement en cas de succès | Retourner l'objet de retour, toujours |
| `raise ArgumentError` pour une donnée invalide | `Response.new(success?: false, errors: [...])` |
| `result.errors.each` sur un `OpenStruct` de succès | `Array(result.errors).each`, ou peupler `errors: []` |
| Mélanger `call` et `execute_create` dans le même contexte | S'aligner sur le contexte existant |
| Introduire un objet Result maison « pour faire propre » | Ouvrir un ADR (`conventions.md` §8) |
