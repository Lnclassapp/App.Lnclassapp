# 🌐 DELIVERY · Classroom::StudentRegistrationsController
# Rôle : inscription élève publique : classe choisie dans la cascade, ou donnée par le jeton d'un lien ; succès : session, accueil élève
# ADR  : 0026, 0028, 0050, 0062, 0085 · UDR : 0079, 0081
module Classroom
  class StudentRegistrationsController < ApplicationController
    FIELDS = %i[last_name first_name gender contact pin pin_confirmation drena_public_id school_public_id level_slug
                classroom_public_id link_token].freeze
    # Repli sans JavaScript (UDR-0081 §3.3) : les choix reviennent en GET ; jamais les PIN, qui n'y sont pas relus.
    PICKER_FIELDS = %i[last_name first_name gender contact drena_public_id school_public_id level_slug
                       classroom_public_id].freeze

    allow_unauthenticated_access
    # ADR-0085 §4.6 : la règle de l'inscription, 5 envois par minute et par adresse.
    rate_limit to: 5, within: 1.minute, only: :create, by: -> { request.remote_ip }, with: -> { refuse_too_many_posts }
    helper_method :class_picker_lists

    def new
      return redirect_to_home if authenticated?

      @form = Dtos::Classroom::StudentRegistrationInput.new(**picker_params)
      # Posé par /c/<jeton> quand le lien n'est plus valable (UDR-0081 §3.4) ; lu une fois.
      @link_invalid = flash[:link_invalid].present?
    end

    def create
      @form = form_input
      result = register.call(actor: current_actor, dto: @form, ip: request.remote_ip, user_agent: request.user_agent)
      return render_refusal(result) if result.code == :forbidden

      show_link if result.failure?
      render_result result, form: :new, success: lambda { |registered|
        start_session(registered.token)
        redirect_to student_home_path, notice: t(".welcome"), status: :see_other
      }
    end

    private

    # Un refus de JoinPolicy (classe complète) ou un élève déjà inscrit : la raison en tête du formulaire, en 403.
    def render_refusal(result)
      return render_forbidden if result.errors.empty?

      show_link
      add_errors(result)
      render :new, status: :forbidden
    end

    # Un lien encore valable garde son bandeau ; devenu invalide depuis l'ouverture, il laisse la voie standard et l'alerte.
    def show_link
      @preview = @form.link_token && Queries::Classroom::JoinPreviewQuery.new.link(token: @form.link_token)
      @link_invalid = @form.link_token.present? && @preview.nil?
    end

    def refuse_too_many_posts
      @form = form_input
      show_link
      render_rate_limited(:new)
    end

    def form_input
      Dtos::Classroom::StudentRegistrationInput.new(**params.expect(student_registration: FIELDS).to_h.symbolize_keys)
    end

    def picker_params = params.fetch(:student_registration, {}).permit(*PICKER_FIELDS).to_h.symbolize_keys

    # Les quatre listes de la cascade, chacune seulement si le choix précédent lui appartient : un identifiant forgé ne
    # touche pas la base, et un choix orphelin vide les listes d'après. nil : liste non affichée.
    def class_picker_lists
      @class_picker_lists ||= begin
        drenas = options.drenas
        schools = (options.schools_for(drena_public_id: @form.drena_public_id) if drenas.any? { it.public_id == @form.drena_public_id })
        levels = (levels_of(@form.school_public_id) if schools&.any? { it.public_id == @form.school_public_id })
        classrooms = (classrooms_of(@form.school_public_id, @form.level_slug) if levels&.any? { it.slug == @form.level_slug })
        { drenas:, schools:, levels:, classrooms: }
      end
    end

    def options = @options ||= Queries::School::SchoolOptionsQuery.new
    def levels_of(school_public_id) = Queries::School::SchoolLevelsQuery.new.call(school_public_id:)

    def classrooms_of(school_public_id, level_slug)
      Queries::Classroom::LevelClassroomsQuery.new.call(school_public_id:, level_slug:)
    end

    def register
      UseCases::Classroom::RegisterStudent.new(
        classrooms: Repositories::Classroom::ClassroomRepository.new, schools: Repositories::School::SchoolRepository.new,
        taxonomy: Repositories::Catalog::TaxonomyRepository.new, registrations: Repositories::Identity::RegistrationRepository.new,
        memberships: Repositories::Classroom::MembershipRepository.new, sessions: Repositories::Identity::SessionRepository.new,
        policy: Policies::Classroom::JoinPolicy.new, transaction: Repositories::Shared::Transaction.new,
        digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end
