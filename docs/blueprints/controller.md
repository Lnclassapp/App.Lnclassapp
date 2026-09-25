# Blueprint: Controller

Le contrôleur est un **mécanisme de livraison**. Il traduit HTTP → domaine et domaine → HTTP. Il câble les dépendances (repositories, queries), valide l'entrée via un [DTO](dto.md), appelle un [Use Case](use_case.md) ou une [Query](query.md), et rend.

## Structure

```ruby
# app/controllers/catalog/courses_controller.rb
# frozen_string_literal: true

# 🌐 DELIVERY · Catalog::CoursesController
# Rôle : CRUD HTTP du catalogue de cours
# ADR  : 0001, 0006, 0009

module Catalog
  class CoursesController < ApplicationController
    before_action :authenticate_user!
    before_action :authenticate_team!, only: [ :new, :create, :edit, :update, :destroy ]

    # LECTURE → Query
    def show
      details = Queries::CatalogQuery.new.get_course_details(params[:id])
      return redirect_to courses_path, alert: "Cours introuvable" unless details

      @course     = details.course
      @essentials = details.essentials
    end

    # ÉCRITURE → DTO puis Use Case
    def create
      dto = Dtos::CourseDto.new(course_params.to_h)

      if dto.invalid?
        @course = Entities::Course.new(course_params.to_h)
        dto.errors.each { |e| @course.errors.add(e.attribute, e.message) }
        set_collections
        return render :new, status: :unprocessable_entity
      end

      use_case = UseCases::Catalog::ManageResource.new(
        repo: course_repo, entity_class: Entities::Course
      )
      result = use_case.execute_create(dto: dto)

      if result.success?
        @course = result.resource
        respond_to do |format|
          format.html { redirect_to course_path(@course.slug), notice: t(".created") }
          format.turbo_stream { flash.now[:notice] = t(".created") }
        end
      else
        @course = Entities::Course.new(course_params.to_h)
        result.errors.each { |err| @course.errors.add(:base, err) }
        set_collections
        render :new, status: :unprocessable_entity
      end
    end

    private

    # Dépendances mémoïsées, injectées dans les Use Cases
    def course_repo
      @course_repo ||= Repositories::Catalog::CourseRepository.new
    end

    def set_collections
      @levels    = course_repo.all_levels
      @materials = course_repo.all_materials
    end

    def course_params
      params.require(:course).permit(:name, :slug, :subtitle, :level_id, :material_id, :series_id, :status, :content)
    end
  end
end
```

## Règles

- Emplacement `app/controllers/<contexte>/` (`catalog/`, `classroom/`, `identity/`, `assessment/`) ou par espace de rôle (`teachers/`, `students/`, `teams/`, `schoolstaff/`, `api/`).
- Les gardes `authenticate_<role>!` et `authorize_<role>!` sont **générées dynamiquement** par `CurrentUserConcern` pour chaque rôle de `CurrentUserConcern::ROLES` (`student`, `teacher`, `team`, `school_admin`, `parent`). Inutile de les écrire ; `current_teacher`, `team?`, `current_profile` sont disponibles de la même façon.
- **Zéro logique métier** et **zéro `Orm::`**. Pas de `Orm::Course.create`, pas de `where`.
- **Zéro `params` franchissant la frontière** : `params.require(...).permit(...)` → `Dtos::XxxDto` → Use Case (ADR-0013 / ADR-0014).
- Le contrôleur est le seul endroit qui **instancie** repositories et queries : `Repositories::Catalog::CourseRepository.new`, `Queries::CatalogQuery.new`. Mémoïser dans une méthode privée.
- Deux chemins, jamais mélangés : lecture → Query ; écriture → DTO + Use Case.
- Réponse d'échec : `render :new, status: :unprocessable_entity`. Hotwire en dépend.
- Textes d'interface via `t(".key")`, locale `:fr`. Jamais de chaîne française en dur dans un `notice:`.
- Double affichage des erreurs : celles du DTO (`e.attribute, e.message`) et celles du Use Case (`errors` → `add(:base, err)`).
- ⚠️ L'exemple ci-dessus reproduit le code réel, qui utilise l'entité **racine** `Entities::Course` (celle qui porte `status`, `level_id`, `material_id`). `Entities::Catalog::Course` existe en parallèle mais expose `level` / `material` en entités et **pas** de `status` : les deux ne sont pas interchangeables. Vérifier avec `grep attr_accessor` quelle entité correspond aux champs permis avant de brancher un contrôleur (voir `conventions.md` §8, « namespaces dupliqués »).

## Erreurs fréquentes

| ❌ | ✅ |
|---|---|
| `use_case.call(params)` | `Dtos::CourseDto.new(course_params.to_h)` puis `execute_create(dto:)` |
| `Orm::Course.find(params[:id])` dans une action | `Queries::CatalogQuery#get_course_details` ou `repo.find_by_slug` |
| Instancier le repository **dans** le Use Case | L'instancier ici et l'injecter |
| `render :new` sans statut | `render :new, status: :unprocessable_entity` |
| `notice: "Cours créé avec succès."` | `notice: t(".created")` |
| Mettre une règle d'accès en dur (`return unless current_user.teacher?`) pour une règle métier | `Policies::ClassroomAccessPolicy` ; le `before_action` ne couvre que l'authentification |
| Formater dans la vue avec 5 `if` | [Presenter](presenter.md) ou helper |
| Oublier `format.turbo_stream` alors que le formulaire est dans un frame | Répondre aux deux formats |
