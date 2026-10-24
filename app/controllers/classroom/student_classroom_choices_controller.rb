# 🌐 DELIVERY · Classroom::StudentClassroomChoicesController
# Rôle : « Choisis ta classe » de l'élève sans classe active (archivée, ou retiré) : le code de la classe, ou la cascade, sa dernière école déjà choisie ; succès : accueil
# ADR  : 0026, 0040, 0062, 0085, XXXX-code-de-classe-a-six-caracteres (§4.5, §4.7) · UDR : 0081 (§3.3, §3.4, §3.5)
module Classroom
  class StudentClassroomChoicesController < AuthenticatedController
    include ClassPicker

    # Les listes de la cascade, relues en GET (repli sans JavaScript) ; le code n'y revient jamais.
    PICKER_FIELDS = %i[drena_public_id school_public_id level_slug classroom_public_id].freeze
    FIELDS = [ *PICKER_FIELDS, :join_code ].freeze

    allow_roles :student
    # ADR code-de-classe §4.5 : taper des codes connecté est la même devinette que la vérification, au même compteur que le lien.
    rate_limit **Classroom::JoinsController::LINK_RATE_LIMIT, only: :create, by: -> { request.remote_ip },
                                                                with: -> { render_rate_limited(:new) }
    # IL-18 : l'élève déjà dans une classe active n'a rien à choisir ; son envoi est refusé par JoinAsStudent, en 403.
    before_action :send_enrolled_home, only: :new

    # Sans choix envoyés (repli sans JavaScript, UDR-0081 §3.3), la DRENA et l'établissement de sa dernière classe.
    def new
      choices = picker_params.presence || last_school
      @form = Dtos::Classroom::StudentRegistrationInput.new(**choices)
      # Posé par /c/<jeton> quand le lien n'est plus valable (UDR-0081 §3.4) ; lu une fois.
      @link_invalid = flash[:link_invalid].present?
    end

    def create
      @form = form_input
      result = join.call(actor: current_actor, dto: @form)
      return render_refusal(result) if result.code == :forbidden

      render_result result, form: :new, success: lambda { |_classroom|
        redirect_to student_home_path, notice: t(".welcome"), status: :see_other
      }
    end

    private

    def form_input
      Dtos::Classroom::StudentRegistrationInput.new(**params.expect(student_classroom_choice: FIELDS).to_h.symbolize_keys)
    end

    def send_enrolled_home
      redirect_to student_home_path if Queries::Identity::HomeDestinationQuery.new.enrolled?(actor: current_actor)
    end

    # Un refus de JoinPolicy (retiré de cette classe, classe complète) ou un élève déjà inscrit : la raison en tête, en 403.
    # Un élève est toujours refusé avec sa raison ; les autres rôles sont arrêtés avant (allow_roles).
    def render_refusal(result)
      add_errors(result)
      render :new, status: :forbidden
    end

    # Une valeur qui n'est pas un hash (?student_classroom_choice=x) est écartée par permit, pas levée : la page s'ouvre vide.
    def picker_params = (params.permit(student_classroom_choice: PICKER_FIELDS)[:student_classroom_choice] || {}).to_h.symbolize_keys

    def last_school
      last = Queries::Classroom::StudentHomeQuery.new.last_classroom(student_id: current_actor.user_id)
      { drena_public_id: last.drena_public_id, school_public_id: last.school_public_id }
    end

    def join
      UseCases::Classroom::JoinAsStudent.new(
        classrooms: Repositories::Classroom::ClassroomRepository.new, schools: Repositories::School::SchoolRepository.new,
        taxonomy: Repositories::Catalog::TaxonomyRepository.new, memberships: Repositories::Classroom::MembershipRepository.new,
        policy: Policies::Classroom::JoinPolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
    end
  end
end
