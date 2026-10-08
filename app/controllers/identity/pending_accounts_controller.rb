# 🌐 DELIVERY · Identity::PendingAccountsController
# Rôle : écran de sortie d'un compte sans accueil (élève sans classe, enseignant sans école ou en attente) ; ne redirige jamais
# ADR  : 0030, 0036, 0040, 0063, 0071, 0083 · UDR : 0050, 0056, 0079 · l'élève qui a quitté sa classe y trouve son historique (lot R)
module Identity
  class PendingAccountsController < AuthenticatedController
    CASES = %i[student teacher].freeze
    PENDING = "pending".freeze

    # Listes DRENA → établissements de l'écran (UDR-0079 §3.9), aussi pour son re-rendu par PendingSchoolJoinsController.
    module SchoolChoice
      private

      # Seule une DRENA connue est cherchée (comme School::DrenaSchoolsController) : un identifiant forgé ne touche pas la base.
      def load_school_choice(drena_public_id)
        options = Queries::School::SchoolOptionsQuery.new
        drenas = options.drenas
        @drena_options = drenas.map { [ it.name, it.public_id ] }
        @school_options = drenas.any? { it.public_id == drena_public_id } ? options.schools_for(drena_public_id:) : []
      end
    end
    include SchoolChoice

    skip_before_action :hold_pending_teacher

    def show
      @case = CASES.include?(current_actor.role) ? current_actor.role : :other
      @archived = Queries::Classroom::StudentArchiveQuery.new.any?(student_id: current_actor.user_id) if @case == :student
      return unless @case == :teacher

      @join_request = Queries::School::JoinRequestsQuery.new.status_for(teacher_id: current_actor.user_id)
      # Sans établissement ni demande en attente : DRENA puis établissement (ADR-0083 §4.3). Sans JavaScript, la DRENA
      # choisie revient ici en GET (formulaire school-join-drena) ; avec, /drenas/:id/schools?scope=school_join sert le frame.
      return unless current_actor.school_id.nil? && @join_request&.status != PENDING

      @school_join = Dtos::School::SchoolJoinInput.new(
        drena_public_id: params.permit(school_join: :drena_public_id).dig(:school_join, :drena_public_id)
      )
      load_school_choice(@school_join.drena_public_id)
    end
  end
end
