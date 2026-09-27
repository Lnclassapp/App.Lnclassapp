# Blueprint: Policy

Une policy répond à **une** question d'autorisation, pour **un** use case, par un `Shared::Result` : succès, ou échec `:forbidden`. Elle vit dans le domaine, elle est pure, et elle se teste sans base. Le contrat est fixé par l'[ADR-0028](../decisions/adr/0028-policies-de-domaine-par-use-case.md), accepté le 2026-09-25, qui complète l'ADR-0004 §3.3 et l'ADR-0015.

> ⚠️ **Ancien dépôt.** Sa seule policy, `Policies::ClassroomAccessPolicy#authorized?`, renvoie un booléen. Elle n'est pas reprise : `Classroom::TeachPolicy` la remplace dans le projet cible. Ne l'étends pas, ne la copie pas.

## Structure

```ruby
# app/domain/policies/classroom/teach_policy.rb
# 🧠 DOMAINE · Policies::Classroom::TeachPolicy
# Rôle : autorise l'enseignant de la classe et l'équipe à agir sur une classe
# ADR  : 0028, 0030
module Policies
  module Classroom
    class TeachPolicy
      def call(actor:, classroom:)
        return Shared::Result.failure(:forbidden) if actor.nil?
        return Shared::Result.success if actor.role == :team
        return Shared::Result.success if actor.role == :teacher && classroom.teacher_ids.include?(actor.user_id)

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
```

**L'acteur** est un `Entities::Identity::Actor` (`user_id`, `role`, `team_role`, `school_id`), construit par le contrôleur à partir de la session. Un visiteur anonyme est `actor: nil`.

**Les faits** sont des entités déjà chargées par le use case (ici une `classroom` qui porte ses `teacher_ids`). Une policy ne lit jamais la base.

## Appel depuis un use case

```ruby
def call(actor:, classroom_public_id:, input:)
  return Shared::Result.failure(:invalid, errors: input.errors.to_hash) unless input.valid?

  classroom = @classroom_repository.find_by_public_id(classroom_public_id)
  return Shared::Result.failure(:not_found) unless classroom

  authorization = @policy.call(actor:, classroom:)
  return authorization if authorization.failure?

  # écrire seulement maintenant
end
```

La policy est **injectée** (`initialize(policy:, …)`), sans valeur par défaut. Le contrôleur traduit le refus par `RendersResult` : 403, ou redirection vers la connexion si l'acteur est anonyme.

## Lecture

Le contrôleur appelle la policy de lecture (`…::Read…Policy`) sur la `Row` renvoyée par la query, avant de rendre la page. Une policy de lecture peut répondre `:not_found` au lieu de `:forbidden` quand la réponse ne doit pas révéler que la ressource existe, par exemple un brouillon ([ADR-0035](../decisions/adr/0035-cycle-de-vie-et-propriete-du-contenu.md)). Une query de liste reçoit l'acteur et filtre par lui.

## Test associé (zéro base)

```ruby
# test/domain/policies/classroom/teach_policy_test.rb
class Policies::Classroom::TeachPolicyTest < ActiveSupport::TestCase
  Classroom = Data.define(:teacher_ids)

  def actor(role, user_id: 1) = Entities::Identity::Actor.new(user_id:, role:, team_role: nil, school_id: nil)

  test "autorise l'enseignant de la classe" do
    assert Policies::Classroom::TeachPolicy.new.call(actor: actor(:teacher), classroom: Classroom.new([1])).success?
  end

  test "refuse un enseignant d'une autre classe, un élève et l'anonyme" do
    policy = Policies::Classroom::TeachPolicy.new
    classroom = Classroom.new([2])

    assert_equal :forbidden, policy.call(actor: actor(:teacher), classroom:).code
    assert_equal :forbidden, policy.call(actor: actor(:student), classroom:).code
    assert_equal :forbidden, policy.call(actor: nil, classroom:).code
  end
end
```

## Règles

- Emplacement `app/domain/policies/<contexte>/`, namespace `Policies::<Contexte>::<Nom>Policy`. Aucune policy à la racine.
- Une policy par use case, même quand la règle tient en une ligne.
- Méthode unique `call(actor:, **faits)` qui renvoie un `Shared::Result`. Elle ne lève pas, ne redirige pas, ne rend rien.
- Refuser par défaut : la dernière ligne est un refus.
- Chaque policy a au moins un test de refus par rôle non autorisé ; chaque use case a un test « refus → rien n'est écrit ».
- Seuls `Identity::Authenticate`, `Identity::ResetPinWithCode` et `Identity::AcceptInvitation` n'ont pas de policy. `Classroom::JoinWithCode` en a une, `Classroom::JoinPolicy`, qui accepte l'anonyme.
- Zéro `Orm::`, zéro `Repositories::`, zéro SQL, zéro `current_user`.

## Erreurs fréquentes

| ❌ | ✅ |
|---|---|
| `authorized?` qui renvoie `true` / `false` | `call` qui renvoie un `Shared::Result` |
| La policy charge la classe par un repository | Le use case charge, la policy reçoit l'entité |
| Vérifier le rôle en dur dans le contrôleur | Une policy, appelée par le use case |
| Exempter un use case « parce qu'il est public » | Accepter `actor: nil` dans sa policy, comme `JoinPolicy` |
| Répondre `:forbidden` sur un brouillon | `:not_found` pour une lecture qui ne doit rien révéler |
| Tester la règle à travers un test de use case | Un test unitaire dans `test/domain/policies/<contexte>/` |
| Mettre la policy dans `app/policies/` (convention Pundit) | `app/domain/policies/<contexte>/` : c'est du domaine |
