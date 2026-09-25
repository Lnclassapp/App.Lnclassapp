# Blueprint: Presenter

> ⚠️ **Pattern documenté, pas encore instancié.**
> `app/presenters/` **n'existe pas** dans le dépôt et aucune classe `…Presenter` n'est définie (`grep -rn "Presenter" app/` ne retourne rien). L'ADR-0014 prévoit ce répertoire ; `docs/guide/conventions.md` §8 le classe dans les écarts connus : *« à créer à la première vraie nécessité, sinon à retirer des docs »*.
> Ce blueprint dit **comment** le créer le jour où c'est nécessaire. Ne pas créer `app/presenters/` « au cas où ».

Un Presenter isole le formatage d'affichage d'un objet (entité, record, hash de Query) pour garder les vues déclaratives.

## Quand le créer

Créer un Presenter **seulement si les trois conditions sont réunies** :

1. La vue porte plus de 3 branchements `if/else` sur les mêmes données.
2. Le même formatage est répété dans au moins 2 vues.
3. Ce n'est ni une règle métier (→ [Entity](entity.md)), ni une décision d'accès (→ [Policy](policy.md)), ni une agrégation de données (→ [Query](query.md)).

Sinon : un **helper** dans `app/helpers/` suffit. C'est la solution par défaut aujourd'hui.

## Structure

```ruby
# app/presenters/catalog/course_presenter.rb
# frozen_string_literal: true

# 🌐 DELIVERY · Catalog::CoursePresenter
# Rôle : formate un cours pour l'affichage (badges, libellés, dates)
# ADR  : 0014

module Catalog
  class CoursePresenter
    def initialize(course, view)
      @course = course   # Entities::Catalog::Course ou Orm::Course
      @view   = view     # view_context, pour link_to / tag / t
    end

    def status_badge
      label, tone = case @course.status
                    when "publié", "published" then [ @view.t(".published"), "success" ]
                    when "draft"               then [ @view.t(".draft"),     "warning" ]
                    else                            [ @view.t(".unknown"),   "neutral" ]
                    end

      @view.tag.span(label, class: "badge badge--#{tone}")
    end

    def essentials_count_label
      @view.t(".essentials_count", count: @course.essentials.size)
    end

    private

    attr_reader :course, :view
  end
end
```

Dans la vue :

```erb
<% presenter = Catalog::CoursePresenter.new(@course, self) %>
<%= presenter.status_badge %>
```

## Règles (le jour où on en crée un)

- Emplacement `app/presenters/<contexte>/`, namespace `<Contexte>::<Nom>Presenter`. Créer le répertoire dans le même commit que le premier presenter, et retirer la ligne correspondante de `conventions.md` §8.
- Reçoit l'objet **et** le `view_context` par le constructeur. Jamais de `ApplicationController.helpers`.
- **Lecture seule** : un Presenter ne modifie rien, ne requête rien, n'appelle aucun repository.
- Retourne du HTML sûr via `@view.tag` / `@view.link_to`, ou des chaînes traduites via `@view.t(".key")`. Jamais de `html_safe` sur de l'interpolation.
- Couche delivery : en-tête HITL `🌐 DELIVERY`.

## Erreurs fréquentes

| ❌ | ✅ |
|---|---|
| Créer `app/presenters/` sans presenter dedans | Attendre le premier vrai besoin |
| Mettre un Presenter dans `app/domain/` | Couche delivery, jamais domaine |
| `Presenter#publishable?` (règle métier) | La règle vit dans `Entities::Catalog::Course` |
| Requêter depuis le Presenter (`@course.essentials.count` déclenchant du SQL) | Passer les données déjà chargées par la Query |
| Chaînes françaises en dur | `@view.t(".key")` |
| Recréer un helper existant | Vérifier `app/helpers/` d'abord |
