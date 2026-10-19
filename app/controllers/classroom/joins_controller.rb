# 🌐 DELIVERY · Classroom::JoinsController
# Rôle : /c/<jeton> ouvre l'inscription élève, la classe déjà choisie, ou l'entrée de l'élève sans classe ; tout autre paramètre (ancien code compris), la voie standard avec l'alerte
# ADR  : 0026, 0028, 0040, 0041, 0050, 0085, 0088, 0095 · UDR : 0081, 0083, 0102
module Classroom
  class JoinsController < ApplicationController
    allow_unauthenticated_access
    # ADR-0041, ADR-0085 §4.1 : l'aperçu et l'entrée partagent le compteur ; au-delà, rien n'est révélé. La confirmation
    # d'un changement par lien (StudentClassroomChangesController) compte dans le même compteur.
    LINK_RATE_LIMIT = { to: 10, within: 1.minute, scope: "classroom/joins" }.freeze
    rate_limit **LINK_RATE_LIMIT, by: -> { request.remote_ip }, with: -> { refuse_too_many }
    before_action :refuse_other_roles
    # UDR-0102 §3.3 : l'élève déjà dans une classe active va à la confirmation du changement ; son envoi ici reste
    # refusé par JoinAsStudent, en 403 (IL-18).
    before_action :send_enrolled_student_on, only: :new
    before_action :load_link

    # Le visiteur reçoit la page d'inscription, la classe dans son bandeau ; l'élève sans classe, la carte et son bouton ;
    # une classe complète se dit, sans formulaire.
    def new
      # IL-09 : le visiteur du lien d'une classe archivée retombe sur la voie standard, comme pour un lien changé ; rien
      # de la classe ne lui est révélé (l'élève connecté, lui, lit le bandeau « archivée », ADR-0088).
      if current_actor.nil? && @preview.archived
        return redirect_to(new_student_registration_path, flash: { link_invalid: true }, status: :see_other)
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

    # Le lien d'une autre classe ouverte : « Changer de classe ? » ; sa propre classe, un lien mort ou archivé : l'accueil.
    def send_enrolled_student_on
      preview = Queries::Classroom::ClassroomChangePreviewQuery.new
      current = current_actor && preview.current(student_id: current_actor.user_id)
      return unless current

      target = preview.linked(token: link_token)
      return redirect_to(confirm_student_classroom_change_path(link_token:), status: :see_other) if target && target.public_id != current.public_id

      redirect_to student_home_path
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
