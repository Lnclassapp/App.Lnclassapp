# Blueprint: Objet de retour d'un Use Case

Tout use case renvoie un **`Shared::Result`**, et toute query un objet **`Data`**. Le contrat est fixé par l'[ADR-0026](../decisions/adr/0026-contrat-result-entites-et-dto.md), accepté le 2026-09-25.

> ⚠️ **Ancien dépôt.** `app/domain/shared/` n'y existe pas : ses use cases renvoient encore des `Struct` `Response` ou des `OpenStruct`. Ne migre pas un use case de l'ancien dépôt vers `Shared::Result` au détour d'un lot : c'est un chantier. Ce blueprint s'applique au projet cible et à tout code neuf écrit sur son modèle.

## Le contrat

```ruby
# app/domain/shared/result.rb
# 🧠 DOMAINE · Shared::Result
# Rôle : contrat de retour unique de tout use case
# ADR  : 0026
module Shared
  Result = Data.define(:value, :code, :errors) do
    def self.success(value = nil) = new(value:, code: nil, errors: {})

    def self.failure(code, errors: {})
      raise ArgumentError, "code d'erreur inconnu : #{code}" unless Result::ERROR_CODES.include?(code)

      new(value: nil, code:, errors:)
    end

    def success? = code.nil?
    def failure? = !success?
  end
  Result::ERROR_CODES = %i[forbidden not_found invalid conflict locked expired].freeze
end
```

| Code | Quand | HTTP (`RendersResult`) |
|---|---|---|
| `:forbidden` | la policy refuse | 403, ou redirection vers la connexion si anonyme |
| `:not_found` | la ressource n'existe pas pour cet acteur | 404 |
| `:invalid` | saisie invalide ; `errors` vaut `{ champ: [messages] }` | 422 |
| `:conflict` | l'état interdit l'action (question déjà répondue, élément encore référencé) ; `errors[:base]` explique | 422 |
| `:locked` | compte verrouillé ; `errors[:retry_after]` | 429 |
| `:expired` | jeton ou code périmé | 422 |

La liste est fermée : ajouter un code demande d'amender l'ADR-0026.

## Un use case

```ruby
# app/domain/use_cases/catalog/create_course.rb
# 🧠 DOMAINE · UseCases::Catalog::CreateCourse
# Rôle : crée un cours en brouillon
# ADR  : 0026, 0028, 0035
module UseCases
  module Catalog
    class CreateCourse
      def initialize(course_repository:, policy:)
        @course_repository = course_repository
        @policy = policy
      end

      def call(actor:, input:)
        return Shared::Result.failure(:invalid, errors: input.errors.to_hash) unless input.valid?

        authorization = @policy.call(actor:)
        return authorization if authorization.failure?

        Shared::Result.success(@course_repository.create(input.to_h.merge(status: "draft", author_id: actor.user_id)))
      end
    end
  end
end
```

L'ordre ne varie pas : valider le DTO (`:invalid`), charger les faits (`:not_found`), appeler la policy (`:forbidden`), écrire. Rien n'est écrit avant la dernière étape ([ADR-0028](../decisions/adr/0028-policies-de-domaine-par-use-case.md)).

## Le contrôleur

```ruby
result = UseCases::Catalog::CreateCourse.new(course_repository:, policy:).call(actor: current_actor, input:)
return render_result(result) if result.failure?

redirect_to teams_course_path(result.value.slug), notice: t(".created")
```

`render_result` vient du concern `RendersResult` (`app/controllers/concerns/renders_result.rb`). Pour `:invalid`, le contrôleur rend de nouveau le formulaire avec `result.errors`.

## Une query

Une query renvoie un `Data` défini dans la query (constante `Row`), un tableau de `Row` ou `nil`. Jamais une relation, un `Hash` ni un modèle `Orm::`. Les agrégations se font en SQL, jamais par `group_by` en mémoire.

## Règles

- Une seule méthode publique, `call`, à arguments nommés.
- On renvoie toujours un `Shared::Result` : jamais `nil`, jamais l'entité nue.
- Un cas métier attendu ne lève pas d'exception. Une exception signale un bug ou une panne d'infrastructure.
- `value` porte l'entité ou le `Data` utile ; `errors` est un `Hash`, jamais un `ActiveModel::Errors`.
- Les dépendances sont injectées **sans valeur par défaut**.
- Un use case qui écrit dans plusieurs tables reçoit `transaction:` (`Ports::Shared::TransactionPort`).

## Erreurs fréquentes

| ❌ | ✅ |
|---|---|
| `OpenStruct.new(success?: false, …)` ou un `Struct` `Response` local | `Shared::Result.failure(:invalid, errors: …)` |
| `Shared::Result.failure(:unauthorized)` | Un code de la liste fermée : `:forbidden` |
| `raise ActiveRecord::RecordNotFound` dans le domaine | `Shared::Result.failure(:not_found)` ; le domaine ignore ActiveRecord |
| `errors: ["Session terminée"]` | `errors: { base: [:session_completed] }`, traduit par la vue |
| Écrire puis appeler la policy | Policy d'abord, écriture ensuite |
| Une query qui renvoie `Orm::Course.where(…)` | Un tableau de `Row` |
