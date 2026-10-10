# 🌐 DELIVERY · Classroom::JoinsController
# Rôle : /c/<jeton> ouvre l'inscription élève, la classe déjà choisie, ou l'entrée de l'élève sans classe ; tout autre paramètre (ancien code compris), la voie standard avec l'alerte
# ADR  : 0026, 0028, 0040, 0041, 0050, 0085, 0088 · UDR : 0081, 0083
module Classroom
  class JoinsController < ApplicationController
    allow_unauthenticated_access
    # ADR-0041, ADR-0085 §4.1 : l'aperçu et l'entrée partagent le compteur ; au-delà, rien n'est révélé.
    rate_limit to: 10, within: 1.minute, by: -> { request.remote_ip }, with: -> { refuse_too_many }
    before_action :refuse_other_roles
    # IL-18 : l'élève déjà dans une classe active n'a rien à rejoindre ; son envoi est refusé par JoinAsStudent, en 403.
    before_action :send_enrolled_student_home, only: :new
    before_action :load_link

    # Le visiteur reçoit la page d'inscription, la classe dans son bandeau ; l'élève sans classe, la carte et son bouton ;
    # une classe complète se dit, sans formulaire.
    def new
      # ADR-0088 : le visiteur d'une classe archivée s'inscrit par la voie standard, averti.
      if current_actor.nil? && @preview.archived
        return redirect_to(new_student_registration_path, flash: { warning: t(".archived_alert") }, status: :see_other)
      end

      @form = Dtos::Classroom::StudentRegistrationInput.new(link_token:)
      render "classroom/student_registrations/new" unless current_actor || @link_full
    end

    # Le visiteur d'un lien s'inscrit par le formulaire de /student-signup : un envoi ici le ramène à la page du lien.
    # L'élève entre par le jeton, résolu de nouveau (voie « link », qui lève un retrait : ADR-0085 §4.3).
    def create
      return redirect_to(join_classroom_path(link_token), status: :see_other) if current_actor.nil?

      @form = Dtos::Classroom::StudentRegistrationInput.new(link_token:)
      result = join_as_student.call(actor: current_actor, dto: @form)
      return render_refusal(result) if result.code == :forbidden

      render_result result, form: :new, success: lambda { |_classroom|
        redirect_to student_home_path, notice: t("classroom.joins.create.welcome"), status: :see_other
      }
    end

    private

    # Seul un jeton de 12 caractères hexadécimaux ouvre une classe (UDR-0081 §3.4) ; un ancien code de classe n'est
    # jamais cherché.
    def link_token = @link_token ||= Dtos::Classroom::StudentRegistrationInput.normalize_link_token(params[:code])

    def refuse_too_many
      @rate_limited = true
      render :new, status: :too_many_requests
    end

    # Un compte non élève, ou une session d'équipe sans second facteur (sans acteur), n'a rien à faire ici.
    def refuse_other_roles
      return unless authenticated?

      render_forbidden unless current_actor && current_actor.student?
    end

    def send_enrolled_student_home
      redirect_to student_home_path if current_actor && Queries::Identity::HomeDestinationQuery.new.enrolled?(actor: current_actor)
    end

    # Lien invalide (jeton inconnu ou changé, classe archivée, établissement inactif, ancien code) : la voie standard,
    # avec l'alerte (IL-09).
    def load_link
      @preview = link_token && Queries::Classroom::JoinPreviewQuery.new.link(token: link_token)
      return @link_full = @preview.full if @preview

      target = current_actor ? new_student_classroom_choice_path : new_student_registration_path
      redirect_to target, flash: { link_invalid: true }, status: :see_other
    end

    # Un refus de JoinPolicy nomme sa raison : la page la montre, en 403.
    def render_refusal(result)
      add_errors(result)
      render :new, status: :forbidden
    end

    def join_as_student
      UseCases::Classroom::JoinAsStudent.new(
        classrooms: Repositories::Classroom::ClassroomRepository.new, schools: Repositories::School::SchoolRepository.new,
        taxonomy: Repositories::Catalog::TaxonomyRepository.new, memberships: Repositories::Classroom::MembershipRepository.new,
        policy: Policies::Classroom::JoinPolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
    end
  end
end
