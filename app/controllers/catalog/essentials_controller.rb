# 🌐 DELIVERY · Catalog::EssentialsController
# Rôle : page d'une fiche essentielle (CA-11, AS-37) : contenu, exercices, progression de l'élève (fiche ouverte retenue), menu de l'équipe,
#        bascules d'assignation de l'enseignant vers ses classes du niveau du cours (RE-21)
# ADR  : 0026, 0028, 0035, 0072, 0090 · UDR : 0006, 0007, 0015, 0069, 0085
module Catalog
  class EssentialsController < AuthenticatedController
    include ReadsOwnLevel

    def show
      essential = Repositories::Catalog::EssentialRepository.new.find_by_slug(slug: params[:slug])
      return render_not_found if essential.nil?
      return if refuse_out_of_level(course_id: essential.course_id)

      render_result Policies::Catalog::ReadPublishedPolicy.new.call(actor: current_actor, content: essential),
                    success: ->(_) { load_page(essential) }
    end

    private

    # L'entité ne sert qu'à la policy et au panneau de statut de l'équipe ; la vue lit la query.
    def load_page(essential)
      team = Policies::Catalog::ManageContentPolicy.new.call(actor: current_actor).success?
      @detail = Queries::Catalog::EssentialDetailQuery.new.call(course_slug: params[:course_slug], slug: essential.slug,
                                                                student_id:, include_unpublished: team)
      return render_not_found if @detail.nil?

      @status_record = essential if team
      @student = current_actor.student?
      @targets = assignment_targets if current_actor.teacher?
      record_read(essential) if @student && !prefetch?
    end

    # Turbo précharge un lien au survol ou au toucher (X-Sec-Purpose: prefetch) : ce n'est pas une ouverture. Les liens
    # de l'élève vers une fiche ne préchargent pas (data-turbo-prefetch="false"), pour que l'ouverture arrive ici.
    def prefetch?
      %w[X-Sec-Purpose Sec-Purpose Purpose].any? { request.headers[it].to_s.include?("prefetch") }
    end

    # ADR-0090 §4.1 : la fiche ouverte par l'élève fait « Reprendre » sur la page Cours. Une panne de la base ne bloque
    # jamais la fiche : elle est journalisée (config/initializers/error_reporting.rb). Toute autre erreur est un bogue.
    # Le Result est ignoré exprès : la page ne dépend pas de la lecture, le refus de la policy a déjà répondu 404 plus
    # haut (même policy), et la panne est déjà signalée par le use case.
    def record_read(essential)
      UseCases::Assessment::RecordEssentialRead.new(
        reads: Repositories::Assessment::EssentialReadRepository.new, policy: Policies::Catalog::ReadPublishedPolicy.new,
        reporter: Rails.error, recoverable: Repositories::Assessment::EssentialReadRepository::OUTAGES, clock: Time.zone
      ).call(actor: current_actor, essential:)
    end

    # UDR-0069 §3.8 : l'enseignant seul ; l'équipe n'a pas de classe, l'élève n'assigne pas.
    def assignment_targets
      Queries::Classroom::CatalogAssignmentTargetsQuery.new.call(
        teacher_id: current_actor.user_id, course_slug: @detail.course.slug,
        exercise_public_ids: @detail.exercises.select { it.status == "published" }.map(&:public_id)
      )
    end

    def student_id
      current_actor.user_id if current_actor.student?
    end
  end
end
