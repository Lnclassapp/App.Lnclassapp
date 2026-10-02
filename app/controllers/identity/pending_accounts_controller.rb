# 🌐 DELIVERY · Identity::PendingAccountsController
# Rôle : écran de sortie d'un compte sans accueil (élève sans classe, enseignant sans école ou en attente) ; ne redirige jamais
# ADR  : 0030, 0040, 0063, 0071 · UDR : 0050, 0056
module Identity
  class PendingAccountsController < AuthenticatedController
    CASES = %i[student teacher].freeze
    PENDING = "pending".freeze

    skip_before_action :hold_pending_teacher

    def show
      @case = CASES.include?(current_actor.role) ? current_actor.role : :other
      return unless @case == :teacher

      @join_request = Queries::School::JoinRequestsQuery.new.status_for(teacher_id: current_actor.user_id)
      # Sans établissement ni demande en attente : le code d'établissement (ADR-0071), pré-rempli par le lien /e/<code>.
      return unless current_actor.school_id.nil? && @join_request&.status != PENDING

      @school_join = Dtos::School::SchoolJoinInput.new(school_code: prefill(params[:school_code].to_s))
    end

    private

    # Un code bien formé s'affiche « K7M-4QZ » ; un autre arrive tel quel, et reçoit son erreur à l'envoi (UDR-0056 §3.5).
    def prefill(raw)
      code = Entities::School::SchoolCode.normalize(raw)
      Entities::School::SchoolCode.valid?(code) ? Entities::School::SchoolCode.display(code) : raw
    end
  end
end
